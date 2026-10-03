-- ============================================================
-- Scout América FC — script central
-- ============================================================
-- Cada Ação Rápida do Automator chama este arquivo passando o nome
-- do evento, por exemplo: "finalizacao_nossa".
-- O script lê o tempo do vídeo (YouTube no Chrome ou QuickTime),
-- confere se está tudo certo e grava uma linha no CSV do jogo.
--
-- Colunas do CSV:
--   evento, segundos_video, tempo, origem, horario
--   (tempo = 1 ou 2, conforme o último início de tempo marcado)
-- ============================================================

-- ---------- CONFIGURAÇÕES (mude só aqui) ----------

-- Pasta dos jogos, dentro de Documentos.
property PASTA_SCOUT : "Scout"

-- QuickTime: vídeos mais curtos que isto (em segundos) são ignorados.
-- Serve para nunca ler o tempo de uma gravação de tela ou de um recorte.
property DURACAO_MINIMA_JOGO : 300

-- Sons (ficam em /System/Library/Sounds).
property SOM_OK : "Tink"
property SOM_ERRO : "Basso"

-- ---------- PROGRAMA PRINCIPAL ----------

on run argv
	set evento to item 1 of argv
	try
		set {segundos, origem} to lerTempoDoVideo()
		set arquivo to arquivoDoJogo()
		conferirFonte(arquivo, origem)
		set tempoJogo to tempoAtual(arquivo)
		gravarLinha(arquivo, evento, segundos, tempoJogo, origem)
		tocarSom(SOM_OK)
	on error mensagem number numero
		if numero is -128 then return -- cancelado pelo usuário
		avisar(mensagem)
	end try
end run

-- ---------- LEITURA DO TEMPO DO VÍDEO ----------

-- Decide a fonte pelo aplicativo que está na frente.
on lerTempoDoVideo()
	set appDaFrente to (path to frontmost application) as text
	if appDaFrente contains "Google Chrome" then
		return {lerYouTube(), "youtube"}
	else if appDaFrente contains "QuickTime Player" then
		return {lerQuickTime(), "quicktime"}
	else
		error "Deixe o Chrome (YouTube) ou o QuickTime na frente antes de apertar o atalho." number 1000
	end if
end lerTempoDoVideo

-- YouTube: lê o currentTime do vídeo da aba ativa do Chrome.
-- Se estiver passando anúncio, avisa e não grava.
on lerYouTube()
	set js to "(function(){" & ¬
		"var p=document.querySelector('.html5-video-player');" & ¬
		"var v=document.querySelector('video.html5-main-video')||document.querySelector('video');" & ¬
		"if(!v)return 'SEM_VIDEO';" & ¬
		"if(p&&(p.classList.contains('ad-showing')||p.classList.contains('ad-interrupting')))return 'ANUNCIO';" & ¬
		"return v.currentTime.toFixed(1);" & ¬
		"})()"

	tell application "Google Chrome"
		if (count of windows) is 0 then error "Nenhuma janela do Chrome aberta." number 1000
		set aba to active tab of front window
		set endereco to URL of aba
		if endereco does not contain "youtube.com" then error "A aba ativa do Chrome não é um vídeo do YouTube." number 1000
		try
			set resultado to execute aba javascript js
		on error
			error "O Chrome bloqueou a leitura do tempo. Ative no Chrome: Visualizar > Desenvolvedor > Permitir JavaScript de Eventos Apple." number 1000
		end try
	end tell

	if resultado is missing value or resultado is "" then error "Não consegui ler o tempo do YouTube. Tente de novo." number 1000
	if resultado is "SEM_VIDEO" then error "Não achei o vídeo na aba do YouTube." number 1000
	if resultado is "ANUNCIO" then error "Está passando anúncio. Espere o jogo voltar e aperte de novo." number 1000
	return resultado
end lerYouTube

-- QuickTime: escolhe o vídeo do jogo, ignorando gravações de tela e recortes.
--   1) se algum vídeo do jogo estiver tocando, usa ele;
--   2) senão, usa o que está mais na frente.
on lerQuickTime()
	set tocando to missing value
	set daFrente to missing value
	tell application "QuickTime Player"
		repeat with janela in windows -- as janelas vêm da frente para trás
			try
				set doc to document of janela
				set nome to name of doc
				set duracao to duration of doc
				if (not my ehGravacaoDeTela(nome)) and duracao ≥ (my DURACAO_MINIMA_JOGO) then
					if daFrente is missing value then set daFrente to doc
					if tocando is missing value and (playing of doc) then set tocando to doc
				end if
			end try
		end repeat
		if tocando is not missing value then
			set t to current time of tocando
		else if daFrente is not missing value then
			set t to current time of daFrente
		else
			error "Não achei o vídeo do jogo no QuickTime." number 1000
		end if
	end tell
	return formatarSegundos(t)
end lerQuickTime

on ehGravacaoDeTela(nome)
	return (nome starts with "Gravação de Tela") or (nome starts with "Screen Recording")
end ehGravacaoDeTela

-- Escreve sempre com ponto decimal (ex.: 1234.5), mesmo com o Mac em português.
on formatarSegundos(t)
	set n to round (t * 10) rounding as taught in school
	return ((n div 10) as text) & "." & ((n mod 10) as text)
end formatarSegundos

-- ---------- ARQUIVO DO JOGO ----------

on pastaScout()
	return (POSIX path of (path to documents folder)) & PASTA_SCOUT & "/"
end pastaScout

-- O caminho do jogo atual fica guardado em Documentos/Scout/.jogo_atual
-- Etapa 1: se não houver jogo, cria um "teste_<data>.csv".
-- (Na Etapa 2 isso vira a ação "Novo jogo".)
on arquivoDoJogo()
	set pasta to pastaScout()
	set ponteiro to pasta & ".jogo_atual"
	set arquivo to do shell script "f=$(cat " & quoted form of ponteiro & " 2>/dev/null); if [ -n \"$f\" ] && [ -f \"$f\" ]; then echo \"$f\"; fi"
	if arquivo is "" then
		set arquivo to pasta & "teste_" & (do shell script "date +%Y-%m-%d") & ".csv"
		criarJogo(arquivo)
	end if
	return arquivo
end arquivoDoJogo

on criarJogo(arquivo)
	set pasta to pastaScout()
	do shell script "mkdir -p " & quoted form of pasta & ¬
		"; [ -f " & quoted form of arquivo & " ] || echo 'evento,segundos_video,tempo,origem,horario' > " & quoted form of arquivo & ¬
		"; echo " & quoted form of arquivo & " > " & quoted form of (pasta & ".jogo_atual")
end criarJogo

-- Não deixa misturar YouTube e QuickTime no mesmo jogo.
on conferirFonte(arquivo, origem)
	set primeira to do shell script "awk -F, 'NR>1 && $4!=\"\" {print $4; exit}' " & quoted form of arquivo
	if primeira is not "" and primeira is not origem then
		error "Este jogo começou com " & primeira & " e o registro veio de " & origem & ". Nada foi gravado." number 1000
	end if
end conferirFonte

-- 1 ou 2, conforme o último início de tempo marcado (vazio se nenhum).
on tempoAtual(arquivo)
	return do shell script "awk -F, '$1==\"inicio_1t\"{t=1} $1==\"inicio_2t\"{t=2} END{print t}' " & quoted form of arquivo
end tempoAtual

on gravarLinha(arquivo, evento, segundos, tempoJogo, origem)
	do shell script "printf '%s,%s,%s,%s,%s\\n' " & ¬
		quoted form of evento & " " & quoted form of segundos & " " & ¬
		quoted form of tempoJogo & " " & quoted form of origem & ¬
		" \"$(date '+%Y-%m-%d %H:%M:%S')\" >> " & quoted form of arquivo
end gravarLinha

-- ---------- AVISOS ----------

on tocarSom(nome)
	do shell script "afplay /System/Library/Sounds/" & nome & ".aiff > /dev/null 2>&1 &"
end tocarSom

on avisar(mensagem)
	tocarSom(SOM_ERRO)
	display notification mensagem with title "Scout – nada gravado"
end avisar
