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
--
-- Eventos aceitos:
--   ganhamos_posse (= começou a posse nossa), perdemos_posse (= começou a posse deles),
--   finalizacao_nossa,
--   finalizacao_concedida, subida_pressao, corrida_para_tras,
--   inicio_1t, inicio_2t, desfazer, novo_jogo
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

-- Mostrar também um aviso na tela quando grava (true = sim, false = só o som).
property AVISO_NA_TELA : true

-- ---------- PROGRAMA PRINCIPAL ----------

on run argv
	set evento to item 1 of argv
	try
		if evento is "novo_jogo" then
			novoJogo()
		else if evento is "desfazer" then
			desfazer()
		else
			registrar(evento)
		end if
	on error mensagem number numero
		if numero is -128 then return -- cancelado pelo usuário
		avisar(mensagem)
	end try
end run

-- ---------- REGISTRAR UM EVENTO ----------

on registrar(evento)
	if nomeDoEvento(evento) is evento then error "Evento desconhecido: " & evento & ". Confira a Ação Rápida." number 1000
	set arquivo to jogoAtual()
	set {segundos, origem} to lerTempoDoVideo()
	set {tempoJogo, primeiraOrigem, relogio} to lerEstado(arquivo, segundos)

	-- Não misturar YouTube e QuickTime no mesmo jogo.
	if primeiraOrigem is not "" and primeiraOrigem is not origem then
		error "Este jogo começou com " & primeiraOrigem & " e o registro veio de " & origem & "." number 1000
	end if

	if evento is "inicio_1t" then
		set tempoJogo to "1"
	else if evento is "inicio_2t" then
		set tempoJogo to "2"
	else
		if tempoJogo is "" then error "Marque antes o início do 1º tempo (⌃⌥7)." number 1000
	end if

	gravarLinha(arquivo, evento, segundos, tempoJogo, origem)
	confirmar(nomeDoEvento(evento) & " — " & tempoJogo & "º T, vídeo " & relogio, "")
end registrar

-- Lê do CSV o estado do jogo. A conta com o tempo do vídeo é feita no awk,
-- que sempre usa ponto decimal (o Mac em português usa vírgula).
-- Devolve: tempo atual (1/2) | primeira origem | mm:ss
on lerEstado(arquivo, segundos)
	set programa to "BEGIN{FS=\",\"} NR==1{next} " & ¬
		"{if(o==\"\" && $4!=\"\") o=$4} " & ¬
		"$1==\"inicio_1t\"{tp=1} " & ¬
		"$1==\"inicio_2t\"{tp=2} " & ¬
		"END{ s=int(t+0.5); printf \"%s|%s|%d:%02d\", tp, o, int(s/60), s%60 }"
	set resultado to do shell script "awk -v t=" & segundos & " " & quoted form of programa & " " & quoted form of arquivo
	return dividir(resultado, "|")
end lerEstado

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
on jogoAtual()
	set ponteiro to pastaScout() & ".jogo_atual"
	set arquivo to do shell script "f=$(cat " & quoted form of ponteiro & " 2>/dev/null); if [ -n \"$f\" ] && [ -f \"$f\" ]; then echo \"$f\"; fi"
	if arquivo is "" then error "Nenhum jogo aberto. Comece com ⌃⌥9 (Novo jogo)." number 1000
	return arquivo
end jogoAtual

on gravarLinha(arquivo, evento, segundos, tempoJogo, origem)
	do shell script "printf '%s,%s,%s,%s,%s\\n' " & ¬
		quoted form of evento & " " & quoted form of segundos & " " & ¬
		quoted form of tempoJogo & " " & quoted form of origem & ¬
		" \"$(date '+%Y-%m-%d %H:%M:%S')\" >> " & quoted form of arquivo
end gravarLinha

-- ---------- NOVO JOGO (⌃⌥9) ----------

on novoJogo()
	set adversario to perguntarTexto("Adversário:", "")
	set adversario to limparNome(adversario)
	if adversario is "" then error "Informe o adversário." number 1000

	set hoje to do shell script "date +%Y-%m-%d"
	set dataJogo to perguntarTexto("Data do jogo (AAAA-MM-DD):", hoje)
	if (do shell script "echo " & quoted form of dataJogo & " | grep -Ec '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || true") is not "1" then
		error "Data inválida. Use o formato AAAA-MM-DD (ex.: " & hoje & ")." number 1000
	end if

	set categoria to escolher("Categoria:", {"Profissional", "Sub-20"})
	set mando to escolher("Mando:", {"Casa", "Fora"})

	set pasta to pastaScout()
	set arquivo to pasta & dataJogo & "_" & categoria & "_" & adversario & "_" & mando & ".csv"
	set existe to (do shell script "[ -f " & quoted form of arquivo & " ] && echo sim || echo nao") is "sim"
	if existe then
		perguntarSimNao("Esse jogo já existe. Continuar marcando nele?", "Continuar")
	else
		do shell script "mkdir -p " & quoted form of pasta & ¬
			"; echo 'evento,segundos_video,tempo,origem,horario' > " & quoted form of arquivo
	end if
	do shell script "echo " & quoted form of arquivo & " > " & quoted form of (pasta & ".jogo_atual")

	confirmar("Jogo: América x " & adversario & " (" & categoria & ", " & mando & ")", "No início do 1º tempo, aperte ⌃⌥7.")
end novoJogo

-- Tira caracteres que atrapalham o nome do arquivo.
on limparNome(texto)
	return do shell script "echo " & quoted form of texto & " | tr '_,/:' '    ' | sed -E 's/  +/ /g; s/^ //; s/ $//'"
end limparNome

-- ---------- DESFAZER (⌃⌥0) ----------

-- Apaga a última linha do CSV (nunca o cabeçalho).
-- (janela_amostra só existe em jogos antigos, da época da amostra de 15 min.)
on desfazer()
	set arquivo to jogoAtual()
	set resultado to do shell script "f=" & quoted form of arquivo & "; " & ¬
		"u=$(tail -n 1 \"$f\"); " & ¬
		"case \"$u\" in evento,*|janela_amostra,*|'') echo NADA; exit 0;; esac; " & ¬
		"sed '$d' \"$f\" > \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; " & ¬
		"echo \"$u\" | awk -F, '{s=int($2+0.5); printf \"%s|%s|%d:%02d\", $1, $3, int(s/60), s%60}'"
	if resultado is "NADA" then error "Não há registro para desfazer." number 1000
	set {evento, tempoJogo, relogio} to dividir(resultado, "|")
	confirmar("Desfeito: " & nomeDoEvento(evento) & " — " & tempoJogo & "º T, vídeo " & relogio, "")
end desfazer

-- ---------- NOMES ----------

on nomeDoEvento(evento)
	-- (os nomes internos ficaram por compatibilidade com os jogos já marcados)
	if evento is "ganhamos_posse" then return "Posse nossa"
	if evento is "perdemos_posse" then return "Posse deles"
	if evento is "finalizacao_nossa" then return "Finalização nossa"
	if evento is "finalizacao_concedida" then return "Finalização concedida"
	if evento is "subida_pressao" then return "Subida de pressão"
	if evento is "corrida_para_tras" then return "Corrida para trás"
	if evento is "inicio_1t" then return "Início do 1º tempo"
	if evento is "inicio_2t" then return "Início do 2º tempo"
	return evento
end nomeDoEvento

-- ---------- AVISOS E PERGUNTAS ----------

on tocarSom(nome)
	-- Toca até o fim (≈0,3 s). Em segundo plano o som era cortado
	-- quando a Ação Rápida terminava.
	try
		do shell script "afplay /System/Library/Sounds/" & nome & ".aiff"
	end try
end tocarSom

on confirmar(mensagem, extra)
	tocarSom(SOM_OK)
	if extra is not "" then
		display notification extra with title "Scout ✓" subtitle mensagem
	else if AVISO_NA_TELA then
		display notification mensagem with title "Scout ✓"
	end if
end confirmar

on avisar(mensagem)
	tocarSom(SOM_ERRO)
	display notification mensagem with title "Scout – nada gravado"
end avisar

-- As perguntas aparecem dentro do app da frente, para o teclado ir para elas.
on perguntarTexto(pergunta, padrao)
	set appDaFrente to (path to frontmost application) as text
	tell application appDaFrente
		activate
		set resposta to text returned of (display dialog pergunta default answer padrao with title "Scout – Novo jogo")
	end tell
	return resposta
end perguntarTexto

on escolher(pergunta, opcoes)
	set appDaFrente to (path to frontmost application) as text
	tell application appDaFrente
		activate
		set resposta to choose from list opcoes with prompt pergunta with title "Scout – Novo jogo" default items {item 1 of opcoes}
	end tell
	if resposta is false then error number -128
	return item 1 of resposta
end escolher

on perguntarSimNao(pergunta, botaoSim)
	set appDaFrente to (path to frontmost application) as text
	tell application appDaFrente
		activate
		display dialog pergunta buttons {"Cancelar", botaoSim} default button botaoSim cancel button "Cancelar" with title "Scout – Novo jogo"
	end tell
end perguntarSimNao

-- ---------- UTILITÁRIOS ----------

on dividir(texto, separador)
	set antigos to AppleScript's text item delimiters
	set AppleScript's text item delimiters to separador
	set partes to text items of texto
	set AppleScript's text item delimiters to antigos
	return partes
end dividir
