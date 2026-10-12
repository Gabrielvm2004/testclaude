#!/bin/bash
# Renomeia os artigos de Estudos para "TÍTULO - Autor (Ano).pdf" e move os que estavam
# na pasta errada (aulas do Reservatório de Dopamina, trabalhos da faculdade, fichas
# do Tubarões...). Os nomes foram escritos a partir do arquivo artigos_info.tsv.
#
# - Mostra o plano antes (abre no TextEdit) e só aplica se você confirmar.
# - Nunca apaga nem sobrescreve. Se já existir um arquivo IDÊNTICO com o novo nome,
#   o repetido vai para "Downloads/Duplicados (pode apagar)"; se for diferente,
#   ganha " (2)" no nome.
# - Cria um script para DESFAZER tudo.
#
# Como usar (no Terminal):  bash ~/Downloads/renomear_artigos.sh
# VERSAO 2 (com TCC/Referências)

case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in *UTF-8*|*utf8*) ;; *) export LC_ALL=en_US.UTF-8 ;; esac

DATA="$(date +%Y-%m-%d_%H-%M-%S)"
PLANO="$HOME/Downloads/PLANO_artigos_$DATA.txt"
DESFAZER="$HOME/Downloads/DESFAZER_artigos_$DATA.sh"
DUPLICADOS="$HOME/Downloads/Duplicados (pode apagar)"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

tamanho() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null; }
iguais() { [ -f "$1" ] && [ -f "$2" ] && [ "$(tamanho "$1")" = "$(tamanho "$2")" ] && cmp -s "$1" "$2"; }
livre() {   # dir nome -> caminho que ainda não existe ("nome (2).pdf"...)
  local dir="$1" nome="$2" k=2
  if [ ! -e "$dir/$nome" ]; then echo "$dir/$nome"; return; fi
  while [ -e "$dir/${nome%.*} ($k).${nome##*.}" ]; do k=$((k + 1)); done
  echo "$dir/${nome%.*} ($k).${nome##*.}"
}

# ---------- Lista: arquivo atual | nome novo | pasta nova (vazia = mesma) ----------
sed -n "/^: <<'__LISTA__'$/,/^__LISTA__$/p" "$0" | sed '1d;$d' > "$TMPD/lista"

ORIG=(); NOVO=(); DEST=(); faltando=0
while IFS=$'\t' read -r rel nome pasta; do
  [ -z "$rel" ] && continue
  src="$HOME/$rel"
  if [ ! -e "$src" ]; then faltando=$((faltando + 1)); echo "$rel" >> "$TMPD/faltando"; continue; fi
  if [ -n "$pasta" ]; then dir="$HOME/Documents/$pasta"; else dir="${src%/*}"; fi
  ORIG+=("$src"); NOVO+=("$nome"); DEST+=("$dir")
done < "$TMPD/lista"

# ---------- Plano ----------
{
  echo "PLANO DE RENOMEAÇÃO DOS ARTIGOS — $DATA"
  echo "Nada foi mudado ainda. Volte ao Terminal para confirmar."
  echo "Formato:  NOVO NOME   <-   nome atual   (agrupado pela pasta onde o artigo vai ficar)"
  echo
  i=0
  while [ $i -lt ${#ORIG[@]} ]; do
    d="${DEST[$i]#$HOME/Documents/}"
    printf '%s\t   %s   <-   %s\n' "$d" "${NOVO[$i]}" "${ORIG[$i]##*/}"
    i=$((i + 1))
  done | sort -t$'\t' -k1,1 -s | awk -F'\t' '$1!=g{g=$1; print "\n=== " g " ==="} {print $2}'
  if [ $faltando -gt 0 ]; then
    echo; echo "=== NÃO ENCONTRADOS (já foram movidos ou renomeados; serão ignorados) ==="
    cat "$TMPD/faltando"
  fi
} > "$PLANO"

echo
echo "Artigos a renomear: ${#ORIG[@]}"
[ $faltando -gt 0 ] && echo "Não encontrados (serão ignorados): $faltando"
echo "Por pasta de destino:"
i=0; while [ $i -lt ${#ORIG[@]} ]; do echo "${DEST[$i]#$HOME/Documents/}"; i=$((i + 1)); done | sort | uniq -c | sort -rn
echo
echo "O plano completo está em: $PLANO"
open -e "$PLANO" 2>/dev/null
printf "Aplicar? (s = sim / n = não) "
read -r ok
if [ "$ok" != "s" ] && [ "$ok" != "S" ]; then echo "Cancelado. Nada foi alterado."; exit 0; fi

# ---------- Aplica (o desfazer volta na ordem inversa) ----------
PASSOS="$TMPD/passos"; : > "$PASSOS"
gerar_desfazer() {
  { echo "#!/bin/bash"; echo "# Desfaz a renomeação dos artigos feita em $DATA"
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$PASSOS"; } > "$DESFAZER"
}
trap 'gerar_desfazer; rm -rf "$TMPD"' EXIT

feitos=0; dup=0; erros=0
i=0
while [ $i -lt ${#ORIG[@]} ]; do
  src="${ORIG[$i]}"; dir="${DEST[$i]}"; nome="${NOVO[$i]}"
  i=$((i + 1))
  [ -e "$src" ] || continue
  [ "$src" = "$dir/$nome" ] && continue
  if [ -e "$dir/$nome" ] && iguais "$src" "$dir/$nome"; then
    dir="$DUPLICADOS"; nome="${src##*/}"
  fi
  mkdir -p "$dir"
  alvo="$(livre "$dir" "$nome")"
  if mv "$src" "$alvo"; then
    printf 'mkdir -p %q && mv -n %q %q\n' "${src%/*}" "$alvo" "$src" >> "$PASSOS"
    [ "$dir" = "$DUPLICADOS" ] && dup=$((dup + 1)) || feitos=$((feitos + 1))
  else
    erros=$((erros + 1))
  fi
done

echo
echo "Pronto! $feitos artigos renomeados e $dup cópias idênticas separadas em Duplicados."
[ $erros -gt 0 ] && echo "Atenção: $erros não puderam ser renomeados (veja as mensagens acima)."
echo "Para desfazer:"
echo "  bash \"$DESFAZER\""
exit 0

: <<'__LISTA__'
Documents/Estudos/A classificar/1236027618 1733940369775.pdf	CARDIORESPIRATORY FITNESS AND MORTALITY RISK ACROSS THE SPECTRA OF AGE, RACE, AND SEX - Kokkinos et al. (2022).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/A classificar/2021 Defendingin4-4-2or5-3-2formation-smalldifferencesinfootballerscollectivetacticalbehaviours.pdf	DEFENDING IN 4-4-2 OR 5-3-2 FORMATION - SMALL DIFFERENCES IN FOOTBALLERS' COLLECTIVE TACTICAL BEHAVIOURS (2021).pdf	Estudos/Futebol
Documents/Estudos/A classificar/4941184050 1734093774636.pdf	RESERVATÓRIO DE DOPAMINA - PLANILHA CAMINHADA COM TROTE 2.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/A classificar/5390796299 1734092186780.pdf	EFFECTIVENESS OF PHYSICAL ACTIVITY INTERVENTIONS FOR IMPROVING DEPRESSION, ANXIETY AND DISTRESS - Singh et al. (2023).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/A classificar/5533001807 1734093766676.pdf	RESERVATÓRIO DE DOPAMINA - PLANILHA CAMINHADA COM TROTE 1.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/A classificar/ARTIGO BASQ..pdf	BASQUETE - ARTIGO 119 FIEP (2014).pdf	
Documents/Estudos/A classificar/Bernardo Morais.pdf	FICHA DE ATLETA - BERNARDO MORAIS (2013) - VOLANTE.pdf	Trabalhos Anteriores/Tubarões/Jogadores
Documents/Estudos/A classificar/ClementePetiotCoutinho-C1FoundationsofSSG.pdf	FOUNDATIONS OF SMALL-SIDED GAMES - Clemente, Petiot e Coutinho (2025).pdf	TCC/Referências
Documents/Estudos/A classificar/Engenharia do Jogo.pdf	ENGENHARIA DO JOGO.pdf	TCC/Referências
Documents/Estudos/A classificar/Gabriel Vitor.pdf	CARTA PESSOAL - GABRIEL VITOR.pdf	Pessoal
Documents/Estudos/A classificar/Gabriel-Vitor.pdf	CARTA PESSOAL - GABRIEL VITOR.pdf	Pessoal
Documents/Estudos/A classificar/La planificacion futbolistica española.pdf · versión 1.pdf	LA PLANIFICACIÓN FUTBOLÍSTICA ESPAÑOLA (2018).pdf	Estudos/Futebol
Documents/Estudos/A classificar/Lageetal2006Practiceschedulesandnumberofskillsascontextualinterferencefactorsinthelearningofpos JHMS.pdf	PRACTICE SCHEDULES AND NUMBER OF SKILLS AS CONTEXTUAL INTERFERENCE FACTORS IN THE LEARNING OF POSITIONING TIMING TASKS - Lage et al. (2006).pdf	Estudos/Aprendizagem Motora
Documents/Estudos/A classificar/Matheus Rosal (09) - LE (1).pdf	FICHA DE ATLETA - MATHEUS ROSAL (2009) - LATERAL ESQUERDO.pdf	Trabalhos Anteriores/Tubarões/Jogadores
Documents/Estudos/A classificar/Matheus Rosal (09) - LE (2).pdf	FICHA DE ATLETA - MATHEUS ROSAL (2009) - LATERAL ESQUERDO (com data de nascimento).pdf	Trabalhos Anteriores/Tubarões/Jogadores
Documents/Estudos/A classificar/Mirassol - São Paulo 3-0.pdf	RELATÓRIO DE JOGO WYSCOUT - MIRASSOL 3X0 SÃO PAULO - PAULISTA (2026-01-12).pdf	Estudos/Futebol
Documents/Estudos/A classificar/PONTOS ANATOMICOS.pdf	MARCAÇÃO DE PONTOS DE REFERÊNCIA ANATÔMICOS - Petreça (2023).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/A classificar/Rebuilding Milo - Aaron Horschig.pdf	REBUILDING MILO - Horschig (2023).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/A classificar/Vilar SM 2012.pdf	THE ROLE OF ECOLOGICAL DYNAMICS IN ANALYSING PERFORMANCE IN TEAM SPORTS - Vilar et al. (2012).pdf	Estudos/Futebol
Documents/Estudos/A classificar/chart (1).pdf	GRÁFICO RENDIMENTO X RESULTADO - TUB X MAITÁ, CT BARÃO E JAGUAR.pdf	Trabalhos Anteriores/Tubarões/Relatórios
Documents/Estudos/A classificar/chart.pdf	GRÁFICO RENDIMENTO X RESULTADO - TUB X MAITÁ, CT BARÃO E JAGUAR.pdf	Trabalhos Anteriores/Tubarões/Relatórios
Documents/Estudos/A classificar/fiepgeral,+Artigo+119+-+Pag+444+a+447.pdf	BASQUETE - ARTIGO 119 FIEP (2014).pdf	
Documents/Estudos/A classificar/o-acto-tc3a1tico-no-jogo.pdf	O ACTO TÁCTICO NO JOGO (2011).pdf	Estudos/Futebol
Documents/Estudos/A classificar/termo-de-adesao-secretaria-aprovado-174241544967db2659cd07e.pdf	TERMO DE ADESÃO - SECRETARIA (APROVADO).pdf	Pessoal
Documents/Estudos/Aprendizagem Motora/10430044939 1734092167633.pdf	ASSOCIATION OF CARDIORESPIRATORY FITNESS WITH LONG-TERM MORTALITY AMONG ADULTS UNDERGOING EXERCISE TREADMILL TESTING - Mandsager et al. (2018).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/11358-Texto do artigo-52567-2-10-20210607.pdf	TEORIA BIOECOLÓGICA APLICADA AO ESPORTE - UMA REVISÃO INTEGRATIVA - Santos et al. (2019).pdf	
Documents/Estudos/Aprendizagem Motora/1614079958 1734092418745.pdf	FOOT CORE TRAINING TO PREVENT RUNNING-RELATED INJURIES - Taddei et al. (2020).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/210+FOCO.pdf	SISTEMAS DE PROTEÇÃO AMBIENTAL EM ATERROS SANITÁRIOS - Medeiros, Cabral e Lima (2023).pdf	Estudos/A classificar
Documents/Estudos/Aprendizagem Motora/279-Texto do artigo-1371-1-10-20150702.pdf	A INFLUÊNCIA DO FUTSAL NO DESENVOLVIMENTO MOTOR EM ADOLESCENTES DE 13 E 14 ANOS - RBFF (2015).pdf	
Documents/Estudos/Aprendizagem Motora/28069-Article-325905-1-10-20220404.pdf	APPLICATION OF MOTOR LEARNING AND NEUROSCIENCE KNOWLEDGE IN BASKETBALL TRAINING - UNDER-13 CASE REPORT (2022).pdf	
Documents/Estudos/Aprendizagem Motora/3723470147 1733925822165.pdf	REPLICATION AND ANALYSIS OF EBBINGHAUS' FORGETTING CURVE - Murre e Dros (2015).pdf	Estudos/Neurociência
Documents/Estudos/Aprendizagem Motora/3988567846 1734094247934.pdf	THE ASSOCIATION BETWEEN RUNNING INJURIES AND TRAINING PARAMETERS - A SYSTEMATIC REVIEW - Fredette et al. (2022).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/4344968973 1734092703513.pdf	RUNNING TECHNIQUE IS AN IMPORTANT COMPONENT OF RUNNING ECONOMY AND PERFORMANCE - Folland et al. (2017).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/5000387645 1734092196001.pdf	LEISURE-TIME RUNNING REDUCES ALL-CAUSE AND CARDIOVASCULAR MORTALITY RISK - Lee et al. (2014).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/54132-Article Text-751375230585-1-10-20210728.pdf	ENSINO-APRENDIZAGEM INCIDENTAL E SEUS EFEITOS SOBRE O CONHECIMENTO TÁTICO PROCESSUAL E A COORDENAÇÃO MOTORA COM BOLA - Lages et al. (2021).pdf	
Documents/Estudos/Aprendizagem Motora/5763944036 1733936933540.pdf	RESERVATÓRIO DE DOPAMINA - AULA 004 - DINHEIRO.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Aprendizagem Motora/745JogoComoConteudo.pdf	O JOGO COMO CONTEÚDO DA EDUCAÇÃO FÍSICA E SUAS POSSIBILIDADES CO-EDUCATIVAS - Silva e Sampaio (2012).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/782-Texto do artigo-3429-1-10-20200119.pdf	PRÁTICA CONSTANTE NA ESTABILIZAÇÃO E ADAPTAÇÃO DAS HABILIDADES MOTORAS - RBFF (2020).pdf	
Documents/Estudos/Aprendizagem Motora/8900841537 1733940360506.pdf	ASSOCIATION OF CARDIORESPIRATORY FITNESS WITH LONG-TERM MORTALITY AMONG ADULTS UNDERGOING EXERCISE TREADMILL TESTING - Mandsager et al. (2018).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/8917830167 1734092273954.pdf	THE INFLUENCE OF RUNNING ON LOWER LIMB CARTILAGE - A SYSTEMATIC REVIEW - Khan et al. (2022).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/A-IMPORTÂNCIA-DA-PERCEPÇÃO-PARA-A-PRÁTICA-DO-FUTEBOL.pdf	A IMPORTÂNCIA DA PERCEPÇÃO PARA A PRÁTICA DO FUTEBOL - Carvalho (2010).pdf	
Documents/Estudos/Aprendizagem Motora/Amatria et al..pdf	OTIMIZAÇÃO DOS FORMATOS DE JOGO NO FUTEBOL SUB-10 - Amatria et al. (2016) [PT].pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/Aprendizagem motora e prática constante- variada LAGE.pdf	AUMENTO GRADUAL DA VARIABILIDADE DE PRÁTICA - Januário et al. (2016).pdf	
Documents/Estudos/Aprendizagem Motora/ArtgGreh (1).pdf	ABORDAGEM SISTÊMICA DO JOGO DE FUTEBOL - MODA OU NECESSIDADE - Garganta e Gréhaigne (1999).pdf	TCC/Referências
Documents/Estudos/Aprendizagem Motora/ArtgGreh.pdf	ABORDAGEM SISTÊMICA DO JOGO DE FUTEBOL - MODA OU NECESSIDADE - Garganta e Gréhaigne (1999).pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/Artigo-EspecializaoPrecoce-RevistaMdica.pdf	O QUE O PEDIATRA PRECISA SABER SOBRE O PROCESSO DE INICIAÇÃO ESPORTIVA - Pereira et al. (2019).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/As dinamicas de cooperacao no seio das e.pdf	AS DINÂMICAS DE COOPERAÇÃO NAS EQUIPAS - FORMAÇÃO NO CLUBE (2023).pdf	
Documents/Estudos/Aprendizagem Motora/Business Plan Presentation in Dark Purple and Pink Geometric Style.pdf	PLANO DE NEGÓCIO - SERVIÇO DE VÍDEO PARA PAIS - Medeiros e Silva (2025).pdf	Pessoal
Documents/Estudos/Aprendizagem Motora/CONTROLE POSTURAL.pdf	ADAPTABILIDADE DE RESPOSTAS POSTURAIS AUTOMÁTICAS A PERTURBAÇÕES EXTRÍNSECAS - Azzi (2017).pdf	
Documents/Estudos/Aprendizagem Motora/COORDENAÇÃO MOTORA GLOBAL E ESPORTE.pdf	ASSOCIAÇÃO ENTRE A COORDENAÇÃO MOTORA GLOBAL E A PRÁTICA ESPORTIVA ORGANIZADA EM CRIANÇAS - Cipriano (2022).pdf	
Documents/Estudos/Aprendizagem Motora/CORUNHA09.pdf	IDENTIFICAÇÃO, SELEÇÃO E PROMOÇÃO DE TALENTOS NOS JOGOS DESPORTIVOS - Garganta (2009).pdf	
Documents/Estudos/Aprendizagem Motora/Cap táticas básicas e fam. habilidades motoras.pdf	ESTRUTURAS DE ENSINO DOS ESPORTES NO PROGRAMA SEGUNDO TEMPO - CAPÍTULO 2 (2013).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/Coordenacao motora e funcoes executivas possiveis.pdf	COORDENAÇÃO MOTORA E FUNÇÕES EXECUTIVAS - POSSÍVEIS ASSOCIAÇÕES (2022).pdf	
Documents/Estudos/Aprendizagem Motora/DESENVOLVIMENTO DE HABILIDADES ESPECIFICAS DO FUTE.pdf	DESENVOLVIMENTO DE HABILIDADES ESPECÍFICAS DO FUTEBOL EM JOGADORES INICIANTES - Fernandes e França.pdf	
Documents/Estudos/Aprendizagem Motora/DESENVOLVIMENTO DO TIMMING ANTECIPATÓRIO EM CRIANÇAS.pdf	DESENVOLVIMENTO DE TIMING ANTECIPATÓRIO EM CRIANÇAS - Ferraz (dissertação).pdf	
Documents/Estudos/Aprendizagem Motora/DESENVOLVIMENTO MOTOR E COGNITIVO ATRAVÉS DO LÚDICO.pdf	A EDUCAÇÃO FÍSICA E O DESENVOLVIMENTO MOTOR E COGNITIVO DO ALUNO ATRAVÉS DO LÚDICO - Faria et al. (2020).pdf	
Documents/Estudos/Aprendizagem Motora/DESONVOLVIMENTO MOTOR LUDICIDADE.pdf	DESENVOLVIMENTO MOTOR NA EDUCAÇÃO INFANTIL ATRAVÉS DA LUDICIDADE - Delvalle et al. (2021).pdf	
Documents/Estudos/Aprendizagem Motora/DUPLA TAREFA NO DESEMPENHO TÁTICO.pdf	HOW DO COGNITIVE AND MOTOR DUAL-TASKS DURING SMALL-SIDED GAMES IMPACT THE TACTICAL PERFORMANCE OF YOUTH SOCCER PLAYERS - Moreira et al. (2025).pdf	
Documents/Estudos/Aprendizagem Motora/DUPLA TAREFA.pdf	APRENDIZAGEM EM TAREFA MOTORA DUAL - EFEITO DA DISTRIBUIÇÃO DE ATENÇÃO ENTRE AS MÃOS - Carvalho (2017).pdf	
Documents/Estudos/Aprendizagem Motora/Diferentes abordagens de pesquisa científica e suas classificações.pdf	AS DIFERENTES ABORDAGENS DE PESQUISA CIENTÍFICA E SUAS CLASSIFICAÇÕES - Souza et al. (2016).pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/Documento sem título.pdf	FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/EIChabilidadesesportivasfinal.pdf	TREINAMENTO TÉCNICO - INTERFERÊNCIA CONTEXTUAL NO ENSINO-APRENDIZAGEM DE HABILIDADES ESPORTIVAS - Lage e Benda (2007).pdf	
Documents/Estudos/Aprendizagem Motora/Esporte de aventura processo instrucional e situac.pdf	ESPORTE DE AVENTURA - PROCESSO INSTRUCIONAL E SITUAÇÕES DE RISCO - Paixão (2010).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/Evidnciasdevalidadedecontedodotestedecoordenaomotoracombola.pdf	CONTENT VALIDITY EVIDENCES IN THE MOTOR COORDINATION TEST WITH BALL (2020).pdf	
Documents/Estudos/Aprendizagem Motora/Fichamento Raab 2003.pdf	FICHAMENTO - RAAB (2003) - Gabriel Vitor (TCC II).pdf	TCC
Documents/Estudos/Aprendizagem Motora/Frequencia de Feedback - Tertuliano.pdf	EFEITOS DA FREQUÊNCIA DE FEEDBACK NA APRENDIZAGEM DO SAQUE DO VOLEIBOL - Tertuliano et al. (2008).pdf	
Documents/Estudos/Aprendizagem Motora/GRECO APRENDIZAGEM INCIDENTAL.pdf	ENSINO-APRENDIZAGEM INCIDENTAL E SEUS EFEITOS SOBRE O CONHECIMENTO TÁTICO PROCESSUAL E A COORDENAÇÃO MOTORA COM BOLA - Lages et al. (2021).pdf	
Documents/Estudos/Aprendizagem Motora/INTERVENÇÃO PROFISSIONAL NOS ESPORTES DE.pdf	INTERVENÇÃO PROFISSIONAL NOS ESPORTES DE AVENTURA - UMA PERSPECTIVA CONCEITUAL (2022).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/MET. 4.pdf	A INFLUÊNCIA DOS MÉTODOS DE ENSINO-APRENDIZAGEM-TREINAMENTO NO CONHECIMENTO TÁTICO PROCESSUAL NO FUTSAL - Moreira, Matias e Greco (2013).pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/Marcos Cordeiro Bueno (Canguru).pdf	O FETICHE DA CAPOEIRA PATRIMÔNIO - Bueno (2012) (dissertação).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/Matheus Rosal (09) - LE.pdf	FICHA DE ATLETA - MATHEUS ROSAL (2009) - LATERAL ESQUERDO (com histórico de lesões).pdf	Trabalhos Anteriores/Tubarões/Jogadores
Documents/Estudos/Aprendizagem Motora/Neurofisiologia da ação motora.pdf	THE NEUROPHYSIOLOGY OF CONTINUOUS ACTION MONITORING - Wilken et al. (2023).pdf	Estudos/Neurociência
Documents/Estudos/Aprendizagem Motora/PAPEL DO PROC VISUAL NO CONTROLE MOTOR.pdf	THE ROLE OF VISUAL PROCESSING IN MOTOR LEARNING AND CONTROL - INSIGHTS FROM ELECTROENCEPHALOGRAPHY - Krigolson (2015).pdf	
Documents/Estudos/Aprendizagem Motora/PizzeraRaab Doesmotororvisualexperienceenhancethedetectionofdeceptivemovementsinfootball 2012.pdf	DOES MOTOR OR VISUAL EXPERIENCE ENHANCE THE DETECTION OF DECEPTIVE MOVEMENTS IN FOOTBALL - Pizzera e Raab (2012).pdf	
Documents/Estudos/Aprendizagem Motora/RELATÃ RIO VOLEI- Carolina Monique.pdf	FACULDADE - RELATÓRIO DE MONITORIA VÔLEI - Carolina Monique (2023).pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/RESUMO ARTIGO.pdf	FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/Relatório Saúde.pdf	FACULDADE - RELATÓRIO DE EXPERIÊNCIA - TRIAGEM PRÉ-EXERCÍCIO - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/Resumo Artigo (2).pdf	FACULDADE - RESUMO DE ARTIGO - ABORDAGENS DE PESQUISA CIENTÍFICA - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/Ribeiro-Silvaetal2022b.pdf	VALIDAÇÃO DE CONTEÚDO DE LISTAS DE CHECAGEM PARA HABILIDADES MOTORAS FUNDAMENTAIS - Ribeiro-Silva et al. (2022).pdf	
Documents/Estudos/Aprendizagem Motora/Sarajrvietal.2023 Skill-relatedstudiesfromyouthtohigh-performancefootball-ascopingreview.pdf	SKILL-RELATED STUDIES FROM YOUTH TO HIGH-PERFORMANCE FOOTBALL - A SCOPING REVIEW - Sarajärvi et al. (2023).pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/TESE MESTRADO COMPORTAMENTO MOTOR.pdf	A PRÁTICA CONSTANTE-VARIADA E A AQUISIÇÃO DE HABILIDADES MOTORAS - Corrêa (2007) (tese).pdf	
Documents/Estudos/Aprendizagem Motora/The Effects of Mental Fatigue on Anaerobic Power and Power Endurance Performance.pdf	THE EFFECTS OF MENTAL FATIGUE ON ANAEROBIC POWER AND POWER ENDURANCE PERFORMANCE - Gonzalez et al. (2024).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/almeidapfeifer,+EXT RevExt 17 pdf 4 Projeto+de+extensão+Jogando+para+aprender.pdf	PROJETO DE EXTENSÃO JOGANDO PARA APRENDER - CAPACIDADES COORDENATIVAS E TÁTICAS BÁSICAS - Pinheiro et al. (2019).pdf	
Documents/Estudos/Aprendizagem Motora/consolidação memoria motora.pdf	ACUTE EXERCISE BEFORE AND AFTER MOTOR PRACTICE ENHANCES MOTOR MEMORY CONSOLIDATION - Jespersen et al. (2023).pdf	
Documents/Estudos/Aprendizagem Motora/coppinavarro,+72-240-1-CE.pdf	A UTILIZAÇÃO DE JOGOS EDUCATIVOS PARA O APRENDIZADO DO FUTEBOL NA INICIAÇÃO SUB-11 - RBFF (2012).pdf	
Documents/Estudos/Aprendizagem Motora/ebook 4aab1b1e-9e8d-4fea-8ede-fc0c14f6cfc4.pdf	APROFUNDANDO O JOGO - OS DETALHES DO FUTEBOL - PRIMEIRO ENCONTRO (ebook).pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/engajamento cognitivo e prática aleatória.pdf	TASK ENGAGEMENT AND MENTAL WORKLOAD IN VARIATION AND REPETITION OF A MOTOR SKILL - Lelis-Torres et al. (2017).pdf	
Documents/Estudos/Aprendizagem Motora/fcogn-1-1505513.pdf	ASKING THE RIGHT QUESTIONS - PARADIGMS USED TO INVESTIGATE INTERACTIONS - Kalra et al. (2024).pdf	Estudos/Neurociência
Documents/Estudos/Aprendizagem Motora/fpsyg-15-1385289.pdf	COMPARISON OF TGFU, SPORT EDUCATION, COMBINED AND LINEAR PEDAGOGY - Ghorbanzadeh et al. (2024).pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/fspor-05-1256847 (1) (1).pdf	SELF-REPORTED VISUAL SYMPTOMS AND HIGH VISUAL DEMAND ACTIVITIES IN PROFESSIONAL FOOTBALL PLAYERS - Jorge et al. (2023) [PT].pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/fspor-05-1256847 (1).pdf	SELF-REPORTED VISUAL SYMPTOMS AND HIGH VISUAL DEMAND ACTIVITIES IN PROFESSIONAL FOOTBALL PLAYERS - Jorge et al. (2023) [PT].pdf	Estudos/Futebol
Documents/Estudos/Aprendizagem Motora/gallahue-d-l-a-educac3a7c3a3o-fc3adsica-desenvolvimentista.pdf	EDUCAÇÃO FÍSICA DESENVOLVIMENTISTA - Gallahue.pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/hebinck-et-al-2025-perceptions-and-adaptation-strategies-in-fundamental-movement-skills-among-children-with-physical.pdf	PERCEPTIONS AND ADAPTATION STRATEGIES IN FUNDAMENTAL MOVEMENT SKILLS AMONG CHILDREN WITH PHYSICAL DISABILITIES - Hebinck et al. (2025).pdf	
Documents/Estudos/Aprendizagem Motora/ilovepdf merged (1) organized.pdf	FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/ilovepdf merged (1).pdf	FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/ilovepdf merged.pdf	FACULDADE - DECLARAÇÃO DE ACEITE DE SUPERVISÃO DE ESTÁGIO E DOCUMENTOS.pdf	Faculdade
Documents/Estudos/Aprendizagem Motora/influencia da complexidade tom. de decisão implicita e explicita.pdf	DECISION MAKING IN SPORTS - INFLUENCE OF COMPLEXITY ON IMPLICIT AND EXPLICIT LEARNING - Raab (2003).pdf	
Documents/Estudos/Aprendizagem Motora/lbassis,+MARCO+PAULO+STIGGER.pdf	POLÍTICAS SOCIAIS EM LAZER, ESPORTES E PARTICIPAÇÃO - Stigger.pdf	Estudos/Pedagogia do Esporte
Documents/Estudos/Aprendizagem Motora/nahasetal 2010.pdf	LAZER ATIVO - PROGRAMA DE PROMOÇÃO DE ESTILOS DE VIDA ATIVOS PARA O TRABALHADOR DA INDÚSTRIA - Nahas et al. (2010).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Aprendizagem Motora/paper u bb2a00a2-aa78-447f-b3b2-6f0ca8c9d820 (1).pdf	TOMADA DE DECISÕES NO ESPORTE - INFLUÊNCIA DA COMPLEXIDADE NA APRENDIZAGEM IMPLÍCITA E EXPLÍCITA - Raab (2003) [PT].pdf	
Documents/Estudos/Aprendizagem Motora/paper u bb2a00a2-aa78-447f-b3b2-6f0ca8c9d820.pdf	DECISION MAKING IN SPORTS - INFLUENCE OF COMPLEXITY ON IMPLICIT AND EXPLICIT LEARNING - Raab (2003).pdf	
Documents/Estudos/Aprendizagem Motora/petiot-et-al-2023-the-key-role-of-context-in-team-sports-training-the-value-of-played-form-activities-in-practice.pdf	THE KEY ROLE OF CONTEXT IN TEAM SPORTS TRAINING - THE VALUE OF PLAYED-FORM ACTIVITIES - Petiot et al. (2023).pdf	TCC/Referências
Documents/Estudos/Aprendizagem Motora/pre+print.pdf	EDUCAÇÃO FÍSICA DESENVOLVIMENTISTA NA EDUCAÇÃO INFANTIL E HABILIDADES MOTORAS FUNDAMENTAIS - Briet e Polastri (preprint).pdf	
Documents/Estudos/Aprendizagem Motora/precisao de CR.pdf	PRECISÃO DE CONHECIMENTO DE RESULTADOS NA APRENDIZAGEM MOTORA EM CRIANÇAS E ADULTOS - Beltrão et al. (2011).pdf	
Documents/Estudos/Aprendizagem Motora/psicomurcia,+(258-267)+Performance+of+e-Sports+Games+with+Data+Envelopment+Analysis (1).pdf	PERFORMANCE OF E-SPORTS GAMES WITH DATA ENVELOPMENT ANALYSIS (2022) [PT].pdf	Estudos/A classificar
Documents/Estudos/Aprendizagem Motora/psicomurcia,+(258-267)+Performance+of+e-Sports+Games+with+Data+Envelopment+Analysis.pdf	PERFORMANCE OF E-SPORTS GAMES WITH DATA ENVELOPMENT ANALYSIS (2022).pdf	Estudos/A classificar
Documents/Estudos/Aprendizagem Motora/s41598-017-15343-3.pdf	TASK ENGAGEMENT AND MENTAL WORKLOAD IN VARIATION AND REPETITION OF A MOTOR SKILL - Lelis-Torres et al. (2017).pdf	
Documents/Estudos/Aprendizagem Motora/symposia.pdf	16TH EUROPEAN CONGRESS OF SPORT AND EXERCISE PSYCHOLOGY - SYMPOSIA (2022).pdf	Estudos/Neurociência
Documents/Estudos/Fisiologia e Treinamento/$RGT3CMB.pdf	COMPOSIÇÃO CORPORAL - AULA (2023).pdf	
Documents/Estudos/Fisiologia e Treinamento/$RK9ZQED.pdf	CINEANTROPOMETRIA - AULA - Petreça (2023).pdf	
Documents/Estudos/Fisiologia e Treinamento/100 - O MELHOR PRESENTE QUE VOCÊ PODE SE DAR (melhore seu VO2).pdf	RESERVATÓRIO DE DOPAMINA - AULA 100 - MELHORE SEU VO2.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Fisiologia e Treinamento/1382663733 1734092175849.pdf	EFFECT OF EXERCISE TRAINING FOR FIVE YEARS ON ALL CAUSE MORTALITY IN OLDER ADULTS - GENERATION 100 - Stensvold et al. (2020).pdf	
Documents/Estudos/Fisiologia e Treinamento/27922-Article-324361-1-10-20220330.pdf	TEMPO DOS RALLYS NO FUTSAL E SEU VIÉS FISIOLÓGICO (2022).pdf	
Documents/Estudos/Fisiologia e Treinamento/4364748224 1734094260349.pdf	THE EFFECT OF PERIODISATION AND TRAINING INTENSITY DISTRIBUTION ON MIDDLE- AND LONG-DISTANCE RUNNING PERFORMANCE - Kenneally et al. (2018).pdf	
Documents/Estudos/Fisiologia e Treinamento/5898-Texto do Artigo-16360-1-10-20120326.pdf	BAIXO PESO AO NASCER E SUA RELAÇÃO COM OBESIDADE E SÍNDROME METABÓLICA NA INFÂNCIA (2010).pdf	
Documents/Estudos/Fisiologia e Treinamento/6909254802 1734093782624.pdf	RESERVATÓRIO DE DOPAMINA - PLANILHA 5 KM EM 10 SEMANAS - INICIANTE.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Fisiologia e Treinamento/6993037767 1734092213612.pdf	META-ANALYSES OF THE EFFECTS OF HABITUAL RUNNING ON INDICES OF HEALTH IN PHYSICALLY INACTIVE ADULTS - Hespanhol Junior et al. (2015).pdf	
Documents/Estudos/Fisiologia e Treinamento/8684343348 1733939795564.pdf	RESERVATÓRIO DE DOPAMINA - AULA 015 - FURE A BOLHA HOMEOSTÁTICA.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Fisiologia e Treinamento/8VPm6d5Jqmz3FZd8C8jzVVp.pdf	EFEITOS DO HIIT E DO TREINAMENTO CONTÍNUO EM RATOS DIABÉTICOS (2022).pdf	
Documents/Estudos/Fisiologia e Treinamento/ARTIGO INDICADORES FISIOLOGICOS DE UM JOGO.pdf	RESPOSTAS DE INDICADORES FISIOLÓGICOS A UM JOGO DE FUTEBOL - Bezerra et al. (2016).pdf	
Documents/Estudos/Fisiologia e Treinamento/Af Brochura exs SUMMIT.pdf	PARADIGMA INFLEXÍVEL - O TREINO DA FLEXIBILIDADE - Vilaça-Alves (2017).pdf	
Documents/Estudos/Fisiologia e Treinamento/Anatomia Humana (Elaine Mar (1).pdf	ANATOMIA HUMANA - Marieb, Wilhelm e Mallatt (7ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/Anatomia Humana (Elaine Mar.pdf	ANATOMIA HUMANA - Marieb, Wilhelm e Mallatt (7ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/Apresentação Slides Corporativo Minimalista Azul.pdf	FACULDADE - APRESENTAÇÃO - EXERGAMES E EXERCÍCIO AERÓBICO NO DIABETES TIPO 1 - David Gabriel, Gabriel Vitor e Vinicius Branco.pdf	Faculdade
Documents/Estudos/Fisiologia e Treinamento/Article (1).pdf	24-HOUR BLOOD RESPONSE - EXERGAMING VS AEROBIC EXERCISE IN TYPE-1 DIABETES - Gomes et al. (2025) [PT].pdf	
Documents/Estudos/Fisiologia e Treinamento/Article.pdf	24-HOUR BLOOD RESPONSE - EXERGAMING VS AEROBIC EXERCISE IN TYPE-1 DIABETES - Gomes et al. (2025).pdf	
Documents/Estudos/Fisiologia e Treinamento/Avanços-no-Treinamento-Funciona-Michael-Boyle.pdf	AVANÇOS NO TREINAMENTO FUNCIONAL - Boyle (2014).pdf	
Documents/Estudos/Fisiologia e Treinamento/BIOMECANICA-BASICA.pdf	BIOMECÂNICA BÁSICA.pdf	
Documents/Estudos/Fisiologia e Treinamento/Blue and White Professional Science Project Presen 240311 210353.pdf	FACULDADE - APRESENTAÇÃO - FISIOLOGIA DOS RINS - Oliveira et al. (2024).pdf	Faculdade
Documents/Estudos/Fisiologia e Treinamento/CORRIDA DE DANIELS.pdf	FÓRMULA DE CORRIDA DE DANIELS - Daniels (2012) (2ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/Dee Unglaub Silverthorn - Fisiologia Humana Uma Abordagem Integrada.pdf	FISIOLOGIA HUMANA - UMA ABORDAGEM INTEGRADA - Silverthorn (2017) (7ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/EFEITOS DE DIFERENTES FREQUENCIAS TREINAMENTO MUSCULAR.pdf	EFEITO DE DIFERENTES FREQUÊNCIAS DE TREINAMENTO NA FORÇA MÁXIMA E HIPERTROFIA - Neves (2018).pdf	
Documents/Estudos/Fisiologia e Treinamento/EXERCICIOS TERAPÊUTICOS CONDROMALÁCIA.pdf	EXERCÍCIOS TERAPÊUTICOS NA PREVENÇÃO DA CONDROMALÁCIA PATELOFEMORAL EM ATLETAS (2008).pdf	
Documents/Estudos/Fisiologia e Treinamento/Fisiologia Humana - SILVERTHORN.pdf	FISIOLOGIA HUMANA - UMA ABORDAGEM INTEGRADA - Silverthorn (2017) (7ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/Fisiologia da Micção 20240311 205812 0000.pdf	FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA MICÇÃO - Batista et al. (2024).pdf	Faculdade
Documents/Estudos/Fisiologia e Treinamento/Fisiologia da Secreção Renal.pdf	FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA SECREÇÃO RENAL - Ginnari et al. (2024).pdf	Faculdade
Documents/Estudos/Fisiologia e Treinamento/Fisiologia do Exercicio Nutri William D. McArdle, Frank I.pdf	FISIOLOGIA DO EXERCÍCIO - NUTRIÇÃO, ENERGIA E DESEMPENHO HUMANO - McArdle, Katch e Katch (8ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/G3 RESPOSTAS DO SONO ÀS CARGAS DE TREINAMENTO.pdf	RESPOSTAS DO SONO ÀS CARGAS DE TREINAMENTO EM JOVENS NADADORES DURANTE O POLIMENTO (2022).pdf	
Documents/Estudos/Fisiologia e Treinamento/GUYTON 231228 112249.pdf	TRATADO DE FISIOLOGIA MÉDICA - Guyton e Hall (12ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/Genética Molecular Humana -- Tom Strachan, Andrew P Read -- Único, 4, 2012 -- Artmed.pdf	GENÉTICA MOLECULAR HUMANA - Strachan e Read (2012) (4ª ed.).pdf	
Documents/Estudos/Fisiologia e Treinamento/JULIA PERRUSI.pdf	AVALIAÇÃO FÍSICA - JULIA PERRUSI (2024).pdf	Pessoal
Documents/Estudos/Fisiologia e Treinamento/Livro - Lesões no esporte - Uma abordagem anatômica.pdf	LESÕES NO ESPORTE - UMA ABORDAGEM ANATÔMICA (livro).pdf	
Documents/Estudos/Fisiologia e Treinamento/Livro+Periodizao+Esportiva+Prof+Dr+Charles+Lopes+2018.pdf	PERIODIZAÇÃO ESPORTIVA - Lopes (2018) (livro).pdf	
Documents/Estudos/Fisiologia e Treinamento/METODOS DE TREINAMENTO ESTAB. CENTRAL.pdf	MÉTODOS DE TREINAMENTO DA ESTABILIZAÇÃO CENTRAL (CORE) - Santos e Freitas (2010).pdf	
Documents/Estudos/Fisiologia e Treinamento/NutSleepRec.pdf	NUTRITION, SLEEP AND RECOVERY - Halson (2008).pdf	
Documents/Estudos/Fisiologia e Treinamento/PERIODIZAÇÃO CORRIDA.pdf	PERIODIZAÇÃO DA CORRIDA.pdf	
Documents/Estudos/Fisiologia e Treinamento/SOMATOTIPO.pdf	SOMATOTIPO - AULA - Petreça (2024).pdf	
Documents/Estudos/Fisiologia e Treinamento/TREINAMENTO BARCELONA.pdf	TREINAMENTO BARCELONA - APUNTS EDUCACIÓN FÍSICA Y DEPORTES 142 (2020).pdf	Estudos/Futebol
Documents/Estudos/Fisiologia e Treinamento/TRIENAMENTO CORE DOR LOMBAR.pdf	INFLUÊNCIA DO TREINAMENTO DE ESTABILIZAÇÃO CENTRAL SOBRE A DOR E ESTABILIDADE LOMBAR - Reinehr, Carpes e Mota (2008).pdf	
Documents/Estudos/Fisiologia e Treinamento/The effectiveness of proprioceptive training for improving.pdf	THE EFFECTIVENESS OF PROPRIOCEPTIVE TRAINING FOR IMPROVING MOTOR FUNCTION - Aman et al. (2015).pdf	
Documents/Estudos/Fisiologia e Treinamento/The myth of core stability.pdf	THE MYTH OF CORE STABILITY - Lederman (2010).pdf	
Documents/Estudos/Fisiologia e Treinamento/Treinamento de corrida de rua (1).pdf	TREINAMENTO DE CORRIDA DE RUA - Evangelista (2016).pdf	
Documents/Estudos/Fisiologia e Treinamento/Treinamento de corrida de rua.pdf	TREINAMENTO DE CORRIDA DE RUA - Evangelista (2016).pdf	
Documents/Estudos/Fisiologia e Treinamento/core artigo bom.pdf	EFEITOS DO TREINAMENTO DE CORE VS PLIOMÉTRICO SOBRE O EQUILÍBRIO EM JOVENS JOGADORES DE FUTEBOL (2022).pdf	
Documents/Estudos/Fisiologia e Treinamento/core.pdf	DEDICATED TRAINING OF EXPLOSIVE STRENGTH IN THE ABDOMINAL CORE OF SOCCER PLAYERS (2022).pdf	
Documents/Estudos/Fisiologia e Treinamento/download.pdf	RUNNING INTRALIMB COORDINATION AFTER A FOOT CORE EXERCISE PROGRAM IN RECREATIONAL RUNNERS (2024).pdf	
Documents/Estudos/Fisiologia e Treinamento/fisiologia do trio.pdf	FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA FUNÇÃO RENAL - Souza et al. (2024).pdf	Faculdade
Documents/Estudos/Fisiologia e Treinamento/optimal reactive strength index is it an accurate.1.pdf	OPTIMAL REACTIVE STRENGTH INDEX - IS IT AN ACCURATE VARIABLE TO OPTIMIZE PLYOMETRIC TRAINING.pdf	
Documents/Estudos/Futebol/01Dissertacao-CaiquedeNovaesAndrade-2023-Completo.pdf	A INFLUÊNCIA DA MANIPULAÇÃO DE TAREFA EM JOGOS REDUZIDOS SOBRE O COMPORTAMENTO CRIATIVO - Andrade (2023) (dissertação).pdf	TCC/Referências
Documents/Estudos/Futebol/1-s2.0-S2667239122000570-main.pdf	TEAM DECISION-MAKING BEHAVIOR - AN ECOLOGICAL DYNAMICS APPROACH - Araújo et al. (2022).pdf	
Documents/Estudos/Futebol/162-AOTeste de conhecimento tatico do levantador de voleibol.pdf	TESTE DE CONHECIMENTO TÁTICO DECLARATIVO PARA O LEVANTADOR DE VOLEIBOL - Matias e Greco (2009).pdf	
Documents/Estudos/Futebol/170204-Textodoartigo-418475-1-10-20200705.pdf	PEQUENOS JOGOS NO FUTEBOL - PRINCÍPIOS TÁTICOS EM SUPERIORIDADE NUMÉRICA - Praça, Teoldo e Greco (2018).pdf	
Documents/Estudos/Futebol/1737553639541LIC C TREINADOR DE FUTEBOL.pdf	LICENÇA C - TREINADOR DE FUTEBOL (2025).pdf	
Documents/Estudos/Futebol/2017.BritoeSousaetal.RBFF.pdf	AVALIAÇÃO DE JOGADORES DE FUTEBOL - Brito, Sousa et al. (2017).pdf	
Documents/Estudos/Futebol/2018-Dambrozetal-Existerelaoentreaqualidadedasaestticaseonmerodeaceleraesedesaceleraesdejogadoresdefutebol.pdf	EXISTE RELAÇÃO ENTRE A QUALIDADE DAS AÇÕES TÁTICAS E O NÚMERO DE ACELERAÇÕES E DESACELERAÇÕES - Dambroz et al. (2018).pdf	
Documents/Estudos/Futebol/2019-Ainfluencianoresultadomomentaneodapartidanaamplitudeeprofundidadedacirculacaodabolaempequenosjogosnofutebl.pdf	INFLUÊNCIA DO RESULTADO MOMENTÂNEO NA AMPLITUDE E PROFUNDIDADE DA CIRCULAÇÃO DA BOLA EM PEQUENOS JOGOS (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/2019Bettegaetal Formartreinadoresejogadoresnascategoriasdebase.pdf	FORMAR O TREINADOR E O JOGADOR NAS CATEGORIAS DE BASE DO FUTEBOL - Bettega et al. (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/2020 Clemente Castillo Arcos.pdf	TACTICAL ANALYSIS ACCORDING TO AGE-LEVEL GROUPS DURING A 4 VS 4 PLUS GOALKEEPERS SMALL-SIDED GAME - Clemente, Castillo e Los Arcos (2020).pdf	
Documents/Estudos/Futebol/2020Machadoetal TacticalBehaviourofYouthSoccerPlayers-DifferencesDependingonTaskConstraintModificationAgeandSkillLevel.pdf	TACTICAL BEHAVIOUR OF YOUTH SOCCER PLAYERS - TASK CONSTRAINT MODIFICATION, AGE AND SKILL LEVEL - Machado et al. (2020).pdf	
Documents/Estudos/Futebol/2022-Junioretal-Comparaodacapacidadedetomadadedecisodejogadoresdefuteboldascategoriassub-11esub-13deescolasdefutebol.pdf	COMPARAÇÃO DA CAPACIDADE DE TOMADA DE DECISÃO DE JOGADORES SUB-11 E SUB-13 - Junior, Machado e Teoldo (2022).pdf	
Documents/Estudos/Futebol/2025.Analysingtheinfluenceofnumericalimbalanceonindividualtacticalbehaviour.Nunes.pdf	ANALYSING THE INFLUENCE OF NUMERICAL IMBALANCE ON INDIVIDUAL TACTICAL BEHAVIOUR IN SOCCER - Nunes et al. (2025).pdf	TCC/Referências
Documents/Estudos/Futebol/2025.Observationalresearchinfootball.FoundationsperformanceanalysisandpurposefuluseofAI.Praa.pdf	OBSERVATIONAL RESEARCH IN FOOTBALL - FOUNDATIONS, PERFORMANCE ANALYSIS AND PURPOSEFUL USE OF AI - Praça et al. (2025).pdf	
Documents/Estudos/Futebol/28662-148180-1-PB.pdf	COMPORTAMENTO TÁTICO EM PEQUENOS JOGOS NO FUTEBOL - CONHECIMENTO TÁTICO E SUPERIORIDADE NUMÉRICA - Praça et al. (2016).pdf	TCC/Referências
Documents/Estudos/Futebol/3.5.1.25 Casanovaetal..pdf	THE GAZE BEHAVIOURS AND DEFENSIVE TACTICAL PERFORMANCE OF FOOTBALL PLAYERS DURING SMALL-SIDED GAMES - Casanova et al. (2022).pdf	
Documents/Estudos/Futebol/4048067687 1734092259960.pdf	THE ASSOCIATION OF RECREATIONAL AND COMPETITIVE RUNNING WITH HIP AND KNEE OSTEOARTHRITIS - Alentorn-Geli et al. (2017).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Futebol/4935-Texto do Artigo-23300-1-10-20150104.pdf	REVISTA CINERGIS - ARTIGO (2014).pdf	
Documents/Estudos/Futebol/59 - Futebol - referências sobre a organização do jogo.pdf	FUTEBOL - REFERÊNCIAS PARA A ORGANIZAÇÃO DO JOGO - Quina (2001).pdf	
Documents/Estudos/Futebol/859-Texto do artigo-3849-1-10-20200907.pdf	ANÁLISE DO TREINAMENTO TÁTICO PROCESSUAL NO FUTEBOL - RBFF (2020).pdf	
Documents/Estudos/Futebol/923-Texto do artigo-4379-1-10-20210509.pdf	A INFLUÊNCIA DOS ASPECTOS COGNITIVOS SUBJACENTES À TOMADA DE DECISÃO - RBFF (2021).pdf	
Documents/Estudos/Futebol/A Emergencia da Tomada de Decisao no Futebol da De.pdf	A EMERGÊNCIA DA TOMADA DE DECISÃO NO FUTEBOL - DA DECISÃO INDIVIDUAL PARA A COLETIVA - Duarte et al. (2010).pdf	TCC/Referências
Documents/Estudos/Futebol/A Tomada de Decisão no Futsal (Bruno Travassos).pdf	A TOMADA DE DECISÃO NO FUTSAL - Travassos (livro).pdf	
Documents/Estudos/Futebol/A competicao na iniciacao ao futebol consideracoes.pdf	A COMPETIÇÃO NA INICIAÇÃO AO FUTEBOL - ORGANIZAÇÃO DO JOGO E AMBIENTE COMPETITIVO (2020).pdf	
Documents/Estudos/Futebol/ARTIGO BASQ. (1) pt.pdf	AVALIAÇÃO DO CONHECIMENTO TÁTICO PROCESSUAL - KORA - APLICAÇÃO NO BASQUETEBOL - Morales et al. (2006) [PT].pdf	
Documents/Estudos/Futebol/ARTIGO MET.1.pdf	EVIDÊNCIA DE VALIDADE DO TESTE DE CONHECIMENTO TÁTICO PROCESSUAL - TCTP-OE - Greco et al. (2015).pdf	
Documents/Estudos/Futebol/AVALIAÇÃO COMP TÁTICO ARTIGO.pdf	PROPOSTA DE AVALIAÇÃO DO COMPORTAMENTO TÁTICO BASEADA EM PRINCÍPIOS FUNDAMENTAIS DO JOGO - Teoldo, Garganta e Greco (2011).pdf	
Documents/Estudos/Futebol/AVALIAÇÃO FISICA FUTEBOL SUB 20 ARTIGO.pdf	AVALIAÇÃO DE POTÊNCIA, FLEXIBILIDADE, FADIGA E ESTABILIDADE EM ATLETAS SUB-20 DE FUTEBOL (2024).pdf	
Documents/Estudos/Futebol/AVANÇOS ENSINO DOS JEC ARTIGO 2017.pdf	O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - AVANÇOS METODOLÓGICOS - Galatti et al. (2017).pdf	
Documents/Estudos/Futebol/Almeidaetal.2017.pdf	INFLUENCE OF SCORING MODE AND AGE GROUP ON PASSING ACTIONS DURING SMALL-SIDED GAMES - Almeida et al. (2017).pdf	TCC/Referências
Documents/Estudos/Futebol/Amatria et al..pdf	OPTIMIZATION OF GAME FORMATS IN U-10 SOCCER USING LOGISTIC REGRESSION ANALYSIS - Amatria et al. (2016).pdf	
Documents/Estudos/Futebol/Andre Villas Boas.pdf	ANDRÉ VILLAS-BOAS (livro).pdf	
Documents/Estudos/Futebol/Applying Different Strategies of Task Constraint M.pdf	APPLYING DIFFERENT STRATEGIES OF TASK CONSTRAINT MANIPULATION IN SMALL-SIDED AND CONDITIONED GAMES - Machado et al. (2022).pdf	TCC/Referências
Documents/Estudos/Futebol/Arajo et al 2025.pdf	THE ECOLOGICAL DYNAMICS OF COGNIZANT ACTION IN SPORT - Araújo et al. (2025).pdf	
Documents/Estudos/Futebol/AraujoRenshawDavids2020 Tenenbaum.pdf	COGNITION, EMOTION AND ACTION IN SPORT - AN ECOLOGICAL DYNAMICS PERSPECTIVE - Araújo, Davids e Renshaw (2020).pdf	TCC/Referências
Documents/Estudos/Futebol/ArtigoFutebol2.pdf	ARTIGO FUTEBOL 2 (2025).pdf	
Documents/Estudos/Futebol/AspectosBiolgicosnoFutebolv.2FINAL.pdf	ASPECTOS BIOLÓGICOS NO FUTEBOL - UNIVERSO DO FUTEBOL - Ferrari et al. (2025) (livro).pdf	
Documents/Estudos/Futebol/BS Art 51815-10.pdf	CONTEMPORARY PRACTICES OF PORTUGUESE AND BRAZILIAN COACHES IN DESIGNING SMALL-SIDED GAMES - Clemente et al. (2023).pdf	
Documents/Estudos/Futebol/BUSCA VISUAL 2X1.pdf	THE EFFECTS OF PHYSIOLOGICAL DEMANDS ON VISUAL SEARCH BEHAVIOURS DURING 2 VS 1 + GK - Casanova et al. (2022).pdf	
Documents/Estudos/Futebol/BUSCA VISUAL CHUTE FUTSAL.pdf	COORDENAÇÃO INTERPESSOAL E BUSCA VISUAL NA EXECUÇÃO DO CHUTE NO FUTSAL - Oliveira (2019) (dissertação).pdf	
Documents/Estudos/Futebol/COMP.TÁTICO E INF. PEQUENOS JOGOS NO CONHECIMENTO.pdf	COMPORTAMENTO TÁTICO EM PEQUENOS JOGOS NO FUTEBOL - CONHECIMENTO TÁTICO E SUPERIORIDADE NUMÉRICA - Praça et al. (2016).pdf	
Documents/Estudos/Futebol/COMPARAÇÃO JOGOS REDUZIDOS X OFICIAL.pdf	COMPARING THE TACTICAL BEHAVIOR OF YOUNG SOCCER PLAYERS IN FULL- AND SMALL-SIDED GAMES (2024).pdf	
Documents/Estudos/Futebol/CONCEITOS MODELO DE JOGO....pdf	MODELO DE JOGO, ESTRATÉGIA, ESTILO E TÁTICA DE JOGO - CONCEPÇÕES PARA COMPREENDER O JOGO ESPORTIVO (2022).pdf	
Documents/Estudos/Futebol/Capitulo5.JogosReduzidoscomomeiodetreinamentonoFuteboleFutsal.pdf	TREINANDO POR MEIO DE JOGOS NO FUTEBOL E NO FUTSAL - Aquino e Machado (2021) (capítulo 5).pdf	
Documents/Estudos/Futebol/Capturing homeostatic behaviour in elite football (1) (1) (1).pdf	ANALISANDO O COMPORTAMENTO HOMEOSTÁTICO EM EQUIPES DE FUTEBOL DE ELITE (2026) [PT].pdf	TCC/Referências
Documents/Estudos/Futebol/Capturing homeostatic behaviour in elite football (1) (1).pdf	ANALISANDO O COMPORTAMENTO HOMEOSTÁTICO EM EQUIPES DE FUTEBOL DE ELITE (2026) [PT].pdf	
Documents/Estudos/Futebol/Capturing homeostatic behaviour in elite football.pdf	CAPTURING HOMEOSTATIC BEHAVIOUR IN ELITE FOOTBALL TEAMS - SYNCHRONISATION TENDENCIES (2026).pdf	
Documents/Estudos/Futebol/Casoetal.2026Anecologicalperspectiveonintra-teamcommunicationinteamsports.pdf	AN ECOLOGICAL PERSPECTIVE ON INTRA-TEAM COMMUNICATION IN TEAM SPORTS - Caso et al. (2026).pdf	TCC/Referências
Documents/Estudos/Futebol/Chmura Gabbettetal 2025 FootballWorldCupeditorial FootballStudies.pdf	FIFA WORLD CUP 2026 - PERFORMANCE UNDER PRESSURE - SCIENTIFIC GUIDELINES - Chmura, Gabbett et al. (2025).pdf	
Documents/Estudos/Futebol/Contextualization of soccer analysis with tactical.pdf	CONTEXTUALIZATION OF SOCCER ANALYSIS WITH TACTICAL PERIODIZATION AND MACHINE LEARNING - Biermann et al. (2025).pdf	TCC/Referências
Documents/Estudos/Futebol/DINÂMICA ECOLOGICA DA AÇÃO CONSCIENTE.pdf	THE ECOLOGICAL DYNAMICS OF COGNIZANT ACTION IN SPORT - Araújo et al. (2025).pdf	TCC/Referências
Documents/Estudos/Futebol/DTP FutebolSeusContextos Digital.pdf	FUTEBOL E SEUS CONTEXTOS - Oliveira e Haiachi (2023) (livro).pdf	TCC/Referências
Documents/Estudos/Futebol/Defensivetransitioninelitemensfootballkeyfactorsimpactingballrecoveryandmatchoutcomes.pdf	DEFENSIVE TRANSITION IN ELITE MEN'S FOOTBALL - KEY FACTORS IMPACTING BALL RECOVERY AND MATCH OUTCOMES (2025).pdf	
Documents/Estudos/Futebol/Dialnet-IniciacaoEFormacaoDeAtletasEmFutsalDesenvolvimento-5712054.pdf	INICIAÇÃO E FORMAÇÃO DE ATLETAS EM FUTSAL - DESENVOLVIMENTO TÉCNICO-TÁTICO - RBFF (2016).pdf	
Documents/Estudos/Futebol/Dialnet-SearchingForMemories-9287283.pdf	SEARCHING FOR MEMORIES - NARRATIVES - Retos (2024).pdf	
Documents/Estudos/Futebol/Diferentes estratégias de manip.pdf	APLICANDO DIFERENTES ESTRATÉGIAS DE MANIPULAÇÃO DE RESTRIÇÕES EM JOGOS REDUZIDOS - Góes, Machado et al. (2022) [PT].pdf	TCC/Referências
Documents/Estudos/Futebol/EFEITO DO CORINGA NO JOGO DE FUTEBOL.pdf	EFFECT OF AN INSIDE FLOATER ON SOCCER PLAYERS TACTICAL BEHAVIOUR IN SMALL SIDED GAMES - Moniz et al. (2020).pdf	TCC/Referências
Documents/Estudos/Futebol/EFEITOS DOS JOGOS SUCESSIVOS.pdf	O EFEITO DE JOGOS SUCESSIVOS NOS PARÂMETROS DE DESEMPENHO FÍSICO DE JOVENS JOGADORES - Zanetti (2018) (dissertação).pdf	
Documents/Estudos/Futebol/EXPLICANDO O 'JOGO DE POSIÇÃO'.pdf	EXPLICANDO O JOGO DE POSIÇÃO - Andrade (2017).pdf	
Documents/Estudos/Futebol/EXPLORATORY TACTICAL .en.pt.pdf	ESCALAS DE TEMPO PARA COMPORTAMENTO TÁTICO EXPLORATÓRIO EM JOGOS DE FUTEBOL (2015) [PT].pdf	
Documents/Estudos/Futebol/Ecological Dynamic Approach and Young Soccer Playe.pdf	ECOLOGICAL DYNAMIC APPROACH AND YOUNG SOCCER PLAYER TRAINING - THE AIM IS THE FLEXIBLE BEHAVIOR - Sannicandro (2023).pdf	TCC/Referências
Documents/Estudos/Futebol/Ecological dynamics of cognizant action.pdf	THE ECOLOGICAL DYNAMICS OF COGNIZANT ACTION IN SPORT - Araújo et al. (2025).pdf	
Documents/Estudos/Futebol/Effects of a Creative Teaching-Based Training Prog.pdf	EFFECTS OF A CREATIVE TEACHING-BASED TRAINING PROGRAMME ON TACTICAL KNOWLEDGE - Duda et al. (2026).pdf	TCC/Referências
Documents/Estudos/Futebol/Em busca de padroes de jogo da fase ofensiva em pe.pdf	EM BUSCA DE PADRÕES DE JOGO DA FASE OFENSIVA EM PEQUENOS JOGOS DE FUTEBOL - Praça et al. (2017).pdf	TCC/Referências
Documents/Estudos/Futebol/Evolution of playing styles in UEFA European championships- trends from 2012 to 2024.pdf	EVOLUTION OF PLAYING STYLES IN UEFA EUROPEAN CHAMPIONSHIPS - TRENDS FROM 2012 TO 2024 (2025).pdf	
Documents/Estudos/Futebol/FUTSAL TEMPO DE RALLY.pdf	TEMPO DOS RALLYS NO FUTSAL E SEU VIÉS FISIOLÓGICO (2022).pdf	
Documents/Estudos/Futebol/Filipa Dias (2005) Practica deliberada - Entrevista a Frade.pdf	DE PRINCIPIANTE A EXPERTO - PRÁTICA DELIBERADA - ENTREVISTA A FRADE - Dias (2005).pdf	
Documents/Estudos/Futebol/Football AConstraints-LedApproach.pdf	FOOTBALL - A CONSTRAINTS-LED APPROACH (PORTUGAL) - Ribeiro et al. (2025) (capítulo).pdf	TCC/Referências
Documents/Estudos/Futebol/How Do Young Soccer Players Train A 5-Year Analysis of Weekly Training Load and its Variability Between Age Groups in an Elite Youth Academy.pdf	HOW DO YOUNG SOCCER PLAYERS TRAIN - 5-YEAR ANALYSIS OF WEEKLY TRAINING LOAD IN AN ELITE YOUTH ACADEMY (2024).pdf	
Documents/Estudos/Futebol/HowDoestheAdjustmentofTrainingTaskDifficultyLevelInfluenceTacticalBehaviorinSoccer-1.pdf	HOW DOES THE ADJUSTMENT OF TRAINING TASK DIFFICULTY LEVEL INFLUENCE TACTICAL BEHAVIOR IN SOCCER (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/IJSS Casanovaetal..pdf	THE CONTRIBUTION OF PERCEPTUAL AND COGNITIVE SKILLS IN ANTICIPATION PERFORMANCE - Casanova et al. (2014).pdf	TCC/Referências
Documents/Estudos/Futebol/Impact of the number of players on the emergence o.pdf	IMPACT OF THE NUMBER OF PLAYERS ON CREATIVE MOVEMENTS IN SMALL-SIDED SOCCER GAMES - Ueda et al. (2023).pdf	TCC/Referências
Documents/Estudos/Futebol/JOGOS COM X SEM LIMITAÇÃO DE PASSES.pdf	JOGOS REDUZIDOS DE FUTSAL - COM E SEM LIMITAÇÃO DE PASSES (2021).pdf	
Documents/Estudos/Futebol/JOGOS REDUZIDOS E APRENDIZAGEM NO FUTSAL.pdf	JOGOS REDUZIDOS E APRENDIZAGEM NO FUTSAL - Novaes (2022) (tese).pdf	
Documents/Estudos/Futebol/JOGOS REDUZIDOS MARCOS REIS.pdf	JOGOS REDUZIDOS COMO HÓLONS NO FUTEBOL - ABORDAGEM SISTÊMICA HIERÁRQUICA - Reis (2021).pdf	TCC/Referências
Documents/Estudos/Futebol/LÓGICA DO JOGO DE FUTEBOL.pdf	O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf	TCC/Referências
Documents/Estudos/Futebol/MARCOS REIS.pdf	EMBODIED COGNITION WITH AND WITHOUT MENTAL REPRESENTATIONS - EMBODIED CHOICES IN SPORTS - Raab (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/MEC.pdf	FACULDADE - METODOLOGIA DOS ESPORTES COLETIVOS - ATIVIDADES - Grupo Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Futebol/MET. 3.pdf	EVIDÊNCIA DE VALIDADE DO TESTE DE CONHECIMENTO TÁTICO PROCESSUAL - TCTP-OE - Greco et al. (2015).pdf	
Documents/Estudos/Futebol/MODALIDADE FUTSAL.pdf	FACULDADE - PLANO MODALIDADE FUTSAL (2026).pdf	Faculdade
Documents/Estudos/Futebol/MachadoGonzlez-VlloraRocaTeoldo IJPAS2024Developingcognitivemotordecision-makingskillsthroughtacticalprinciplesandSSGsinyouthsoccer.pdf	DEVELOPING COGNITIVE AND MOTOR DECISION-MAKING THROUGH TACTICAL PRINCIPLES AND SSGS IN YOUTH SOCCER - Machado et al. (2024).pdf	TCC/Referências
Documents/Estudos/Futebol/Match Analysis in Team Ball Sports An Umbrella Review of Systematic Reviews and Meta-Analyses (1) (1).pdf	ANÁLISE DE PARTIDAS EM ESPORTES COLETIVOS - REVISÃO GUARDA-CHUVA - Sarmento et al. (2022) [PT].pdf	
Documents/Estudos/Futebol/Match Analysis in Team Ball Sports An Umbrella Review of Systematic Reviews and Meta-Analyses.pdf	MATCH ANALYSIS IN TEAM BALL SPORTS - AN UMBRELLA REVIEW - Sarmento et al. (2022).pdf	
Documents/Estudos/Futebol/Mestrado FernandoSeabra.pdf	IDENTIFICAÇÃO E ANÁLISE DE PADRÕES DE CIRCULAÇÃO DA BOLA NO FUTEBOL - Seabra (2010) (dissertação).pdf	
Documents/Estudos/Futebol/Metodología Cuaderno táctico.pdf	METODOLOGÍA - CUADERNO TÁCTICO - González Fuster (2016).pdf	
Documents/Estudos/Futebol/Modelo de jogo e proc. de ensino.pdf	MODELO DE JOGO E PROCESSO DE ENSINO NO FUTEBOL - PRINCÍPIOS GLOBAIS E ESPECÍFICOS - Casarin et al. (2011).pdf	
Documents/Estudos/Futebol/O-ensino-do-futebol JULIO GARGANTA.pdf	O ENSINO DO FUTEBOL - IDEIAS, FUNDAMENTOS E PRÁTICAS - Garganta et al. (2014).pdf	
Documents/Estudos/Futebol/OS FRUTOS DO COMPORTAMENTO CRIATIVO EM ESPORTES COLETIVOS.pdf	THE SPAWNS OF CREATIVE BEHAVIOR IN TEAM SPORTS - A CREATIVITY DEVELOPMENTAL FRAMEWORK - Santos et al. (2016).pdf	
Documents/Estudos/Futebol/PLANILHA GABRIEL VITOR-2 - 1..pdf	FACULDADE - FICHA ANTROPOMÉTRICA - Gabriel Vitor e Vinicius Branco (2025).pdf	Faculdade
Documents/Estudos/Futebol/Praa 2024 Kinesiology.pdf	QUANTIFYING WITHIN-MATCHES TACTICAL BEHAVIORS USING POSITION DATA - THE EFFECT OF GOAL SCORING - Praça et al. (2024).pdf	
Documents/Estudos/Futebol/PrePrint ChallengeFrameworkforCOACHING dEC2021 JSS.pdf	AN EXTENDED CHALLENGE-BASED FRAMEWORK FOR PRACTICE DESIGN IN SPORTS COACHING - Hodges e Lohse (2021).pdf	TCC/Referências
Documents/Estudos/Futebol/RGPublishedinAJSPOSituationAwareness.pdf	SITUATION AWARENESS - SENSEMAKING AND DECISION MAKING IN PHYSICAL ACTIVITIES - Godbout (2023).pdf	TCC/Referências
Documents/Estudos/Futebol/Raab et al 2009 IJSE Discovery learning in sports.pdf	DISCOVERY LEARNING IN SPORTS - Raab et al. (2009).pdf	TCC/Referências
Documents/Estudos/Futebol/Re-FramingPerformanceAnalysisinSportScienceandPsychologyfromanEcologicalDynamicsPerspective-TowardaCorresponsiveRelationalandCulturallySituatedPractice.pdf	RE-FRAMING PERFORMANCE ANALYSIS FROM AN ECOLOGICAL DYNAMICS PERSPECTIVE (2025).pdf	TCC/Referências
Documents/Estudos/Futebol/Reconceptualizing movement behavior in sport as a.pdf	(RE)CONCEPTUALIZING MOVEMENT BEHAVIOR IN SPORT AS A PROBLEM-SOLVING ACTIVITY - Myszka, Yearby e Davids (2023).pdf	TCC/Referências
Documents/Estudos/Futebol/RelativeAgeEffectSportsHelsenEtAl 2005.pdf	THE RELATIVE AGE EFFECT IN YOUTH SOCCER ACROSS EUROPE - Helsen et al. (2005).pdf	
Documents/Estudos/Futebol/Restrições de tarefa para diferentes faixas etárias.pdf	DESENVOLVENDO RESTRIÇÕES DE TAREFAS PARA DIFERENTES FAIXAS ETÁRIAS NO FUTEBOL - REGRAS PARA FLUTUADORES [PT].pdf	TCC/Referências
Documents/Estudos/Futebol/SINERGIAS GRUPAIS.pdf	TEAM SYNERGIES IN SPORT - THEORY AND MEASURES - Araújo e Davids (2016).pdf	TCC/Referências
Documents/Estudos/Futebol/SISTEMATIZAÇÃO ENSINO TÁTICO 10-11 ANOS.pdf	PROPOSTA DE SISTEMATIZAÇÃO DO ENSINO DO FUTEBOL BASEADA EM JOGOS - 10 A 11 ANOS (2015).pdf	
Documents/Estudos/Futebol/Seifert Araujo Davids PDF.pdf	UNDERSTANDING SKILLED ADAPTIVE BEHAVIOR - ROLE OF ACTION AND PERCEPTION - Seifert, Araújo e Davids (2022).pdf	
Documents/Estudos/Futebol/Sistema inteligente de apoio a decisao tatica no f.pdf	SISTEMA INTELIGENTE DE APOIO À DECISÃO TÁTICA NO FUTEBOL (2025).pdf	
Documents/Estudos/Futebol/Sport Practitioners as Sport Ecology Designers How.pdf	SPORT PRACTITIONERS AS SPORT ECOLOGY DESIGNERS - Woods et al. (2020).pdf	
Documents/Estudos/Futebol/Sportpedagogyinplayed-formpracticeinsoccerthearticulationbetweencontentsandcontexts.pdf	SPORT PEDAGOGY IN PLAYED-FORM PRACTICE IN SOCCER - CONTENTS AND CONTEXTS (2024).pdf	TCC/Referências
Documents/Estudos/Futebol/TESE DOUTORADO MARCOS REIS.pdf	A HABILIDADE MOTORA PASSE E A ORGANIZAÇÃO HIERÁRQUICA EM EQUIPES DE FUTEBOL - Reis (2022) (tese).pdf	TCC/Referências
Documents/Estudos/Futebol/TOMADA DE DECISÃO.pdf	THE ASSOCIATION BETWEEN PERCEPTUAL-COGNITIVE PROCESSES AND RESPONSE TIME IN DECISION MAKING - Cardoso et al. (2021).pdf	
Documents/Estudos/Futebol/Talent Development in Sport Requires Athlete Enric.pdf	TALENT DEVELOPMENT IN SPORT REQUIRES ATHLETE ENRICHMENT - NONLINEAR PEDAGOGY AND ATHLETIC SKILLS MODEL (2021).pdf	
Documents/Estudos/Futebol/Talento Cérebro Decisão Futebol.pdf	TALENTO, CÉREBRO E DECISÃO NO FUTEBOL.pdf	TCC/Referências
Documents/Estudos/Futebol/The enjoyment of small-sided games a narrative rev.pdf	THE ENJOYMENT OF SMALL-SIDED GAMES - A NARRATIVE REVIEW - Clemente et al. (2025).pdf	
Documents/Estudos/Futebol/The influence of the field orientation on the repr.pdf	THE INFLUENCE OF FIELD ORIENTATION ON POSITIONAL DYNAMICS IN SOCCER SMALL-SIDED GAMES - Couto et al. (2024).pdf	
Documents/Estudos/Futebol/The key role of context in team sports training Th.pdf	THE KEY ROLE OF CONTEXT IN TEAM SPORTS TRAINING - THE VALUE OF PLAYED-FORM ACTIVITIES - Petiot et al. (2023).pdf	
Documents/Estudos/Futebol/There is no copy and paste but there is resonation and inhabitation Integrating a contemporary player development framework in football from a compl (2).pdf	THERE IS NO COPY AND PASTE BUT THERE IS RESONATION AND INHABITATION - PLAYER DEVELOPMENT FRAMEWORK (2025) [PT].pdf	
Documents/Estudos/Futebol/There is no copy and paste but there is resonation and inhabitation Integrating a contemporary player development framework in football from a compl.pdf	THERE IS NO COPY AND PASTE BUT THERE IS RESONATION AND INHABITATION - PLAYER DEVELOPMENT FRAMEWORK (2025).pdf	
Documents/Estudos/Futebol/ThevalueofopposedandunopposedpracticeAnecologicaldynamicsrationaleforskilldevelopment (1) (1).pdf	O VALOR DA PRÁTICA COM E SEM OPOSIÇÃO - DINÂMICA ECOLÓGICA (2025) [PT].pdf	TCC/Referências
Documents/Estudos/Futebol/ThevalueofopposedandunopposedpracticeAnecologicaldynamicsrationaleforskilldevelopment.pdf	THE VALUE OF OPPOSED AND UNOPPOSED PRACTICE - AN ECOLOGICAL DYNAMICS RATIONALE FOR SKILL DEVELOPMENT (2025).pdf	
Documents/Estudos/Futebol/Tom. de decisao futebol e fustsal (1).pdf	THE ECOLOGICAL AND COGNITIVE APPROACHES TO DECISION MAKING IN FOOTBALL AND FUTSAL - RBFF (2021) [PT].pdf	
Documents/Estudos/Futebol/Tom. de decisao futebol e fustsal.pdf	THE ECOLOGICAL AND COGNITIVE APPROACHES TO DECISION MAKING IN FOOTBALL AND FUTSAL - RBFF (2021).pdf	TCC/Referências
Documents/Estudos/Futebol/Tomada de decisão criativa por meio do passe (1).pdf	TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v2).pdf	TCC
Documents/Estudos/Futebol/Tomada de decisão criativa por meio do passe (2).pdf	TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v3).pdf	TCC
Documents/Estudos/Futebol/Tomada de decisão criativa por meio do passe.pdf	TCC - TOMADA DE DECISÃO CRIATIVA POR MEIO DO PASSE - Gabriel Vitor (apresentação v1).pdf	TCC
Documents/Estudos/Futebol/Travassosetal 2012 Representativedesign JSS.pdf	INCREASING UNCERTAINTY IMPROVES REPRESENTATIVE DESIGN OF PASSING PRACTICE TASKS - Travassos et al. (2012).pdf	TCC/Referências
Documents/Estudos/Futebol/UCL Technical-Report 2025 DIGITAL compressed compressed (1).pdf	UEFA CHAMPIONS LEAGUE TECHNICAL REPORT 2024-25 (comprimido).pdf	
Documents/Estudos/Futebol/UCL Technical-Report 2025 DIGITAL compressed compressed removed.pdf	UEFA CHAMPIONS LEAGUE TECHNICAL REPORT 2024-25 (comprimido, páginas removidas).pdf	
Documents/Estudos/Futebol/UCL Technical-Report 2025 DIGITAL compressed compressed.pdf	UEFA CHAMPIONS LEAGUE TECHNICAL REPORT 2024-25 (comprimido).pdf	
Documents/Estudos/Futebol/UCL Technical-Report 2025 DIGITAL compressed.pdf	UEFA CHAMPIONS LEAGUE TECHNICAL REPORT 2024-25 (comprimido).pdf	
Documents/Estudos/Futebol/UCL Technical-Report 2025 DIGITAL.pdf	UEFA CHAMPIONS LEAGUE TECHNICAL REPORT 2024-25.pdf	
Documents/Estudos/Futebol/Watrick_2016_INICIACAO E FORMACAO DE ATLETAS EM FUTSAL  DESENVOLVIMENTO TECNICO TATICO E METODOLOGIAS DE ENSINO.pdf	INICIAÇÃO E FORMAÇÃO DE ATLETAS EM FUTSAL - DESENVOLVIMENTO TÉCNICO-TÁTICO - Watrick (2016).pdf	
Documents/Estudos/Futebol/WhattolookforinsettingsportstrainingtasksforyoungplayersAnalysisofthenumericalconfigurationofplayersandcourtsizeconstraintson.pdf	WHAT TO LOOK FOR IN SETTING SPORTS TRAINING TASKS FOR YOUNG PLAYERS - NUMERICAL CONFIGURATION AND COURT SIZE (2023).pdf	TCC/Referências
Documents/Estudos/Futebol/Woodsetal.2020 Wayfinding.pdf	WAYFINDING - ECOLOGICAL PERSPECTIVES OF NAVIGATING DYNAMIC ENVIRONMENTS - Woods et al. (2020).pdf	TCC/Referências
Documents/Estudos/Futebol/apresentação OTÁVIO AUGUSTO - DARWIN.pdf	APRESENTAÇÃO - OTÁVIO AUGUSTO - TREINADOR NÁUTICO SUB-17 (2021).pdf	
Documents/Estudos/Futebol/artigo cooperação futebol.pdf	YOU'LL NEVER WALK ALONE - A COOPERAÇÃO COMO PARADIGMA DAS DINÂMICAS NO FUTEBOL (2013).pdf	TCC/Referências
Documents/Estudos/Futebol/artigo keith davids.pdf	THE CONSTRAINT-LED APPROACH TO ENHANCING TEAM SYNERGIES IN SPORT - Ramos et al. (2020).pdf	
Documents/Estudos/Futebol/artigo recup posse de bola.pdf	HOW DO ELITE SOCCER TEAMS PERFORM TO BALL RECOVERY - Fernandes et al. (2020).pdf	
Documents/Estudos/Futebol/comportamento visual futebol.pdf	SELF-REPORTED VISUAL SYMPTOMS AND HIGH VISUAL DEMAND ACTIVITIES IN PROFESSIONAL FOOTBALL PLAYERS - Jorge et al. (2023) [PT].pdf	
Documents/Estudos/Futebol/download.pdf	A INFLUÊNCIA DOS MÉTODOS DE ENSINO-APRENDIZAGEM-TREINAMENTO NA INTELIGÊNCIA E CRIATIVIDADE TÁTICA NO FUTSAL - Silva e Greco.pdf	
Documents/Estudos/Futebol/evando,+Artigo+14^J+FUT^J+v.+27^J+n.+1^J+2023+-+pronto+publicação.pdf	FORMAÇÃO DE ATLETAS NA CATEGORIA SUB-13 EM UM CLUBE DE GOIÂNIA - ESTUDO DE CASO (2023).pdf	
Documents/Estudos/Futebol/fphys-15-1341791.pdf	FRONTIERS IN PHYSIOLOGY 15-1341791 - Branquinho et al. (2024).pdf	
Documents/Estudos/Futebol/fpsyg-07-01282.pdf	THE SPAWNS OF CREATIVE BEHAVIOR IN TEAM SPORTS - A CREATIVITY DEVELOPMENTAL FRAMEWORK - Santos et al. (2016).pdf	
Documents/Estudos/Futebol/fpsyg-07-01449.pdf	TEAM SYNERGIES IN SPORT - THEORY AND MEASURES - Araújo e Davids (2016).pdf	
Documents/Estudos/Futebol/fpsyg-08-01387.pdf	LONG-TERM PRACTICE WITH DOMAIN-SPECIFIC TASK CONSTRAINTS INFLUENCES PERCEPTUAL SKILLS - Oppici et al. (2017).pdf	TCC/Referências
Documents/Estudos/Futebol/fpsyg-10-01825.pdf	EMBODIED COGNITION WITH AND WITHOUT MENTAL REPRESENTATIONS - EMBODIED CHOICES IN SPORTS - Raab (2019).pdf	
Documents/Estudos/Futebol/fpsyg-10-02090.pdf	DEVELOPING CREATIVITY TO ENHANCE HUMAN POTENTIAL IN SPORT - A WICKED TRANSDISCIPLINARY CHALLENGE - Vaughan et al. (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/fpsyg-11-00654.pdf	SPORT PRACTITIONERS AS SPORT ECOLOGY DESIGNERS - Woods et al. (2020).pdf	
Documents/Estudos/Futebol/fpsyg-12-578332.pdf	IDENTIFICATION OF PATTERNS IN OFFENSIVE SEQUENCES THAT END IN A GOAL IN EUROPEAN FUTSAL - Murillo et al. (2021).pdf	
Documents/Estudos/Futebol/fpsyg-12-637085.pdf	CONTRASTING LEARNING PSYCHOLOGY THEORIES APPLIED TO THE TEACHING OF TACTICS IN SOCCER - Petiot et al. (2021).pdf	
Documents/Estudos/Futebol/fpsyg-12-661262.pdf	MONITORING AND BEHAVIOR OF BIOMOTOR SKILLS IN FUTSAL ATHLETES DURING A SEASON - Oliveira et al. (2021).pdf	
Documents/Estudos/Futebol/francisco,+FF 720 N54V13 392-401.pdf	TEMPO DE POSSE DE BOLA INDIVIDUAL - RBFF (2022).pdf	
Documents/Estudos/Futebol/fspor-05-1256847.pdf	SELF-REPORTED VISUAL SYMPTOMS AND HIGH VISUAL DEMAND ACTIVITIES IN PROFESSIONAL FOOTBALL PLAYERS - Jorge et al. (2023).pdf	
Documents/Estudos/Futebol/fspor-06-1376024.pdf	SPACE AND PLAYERS' NUMBER CONSTRAINS THE LOAD DEMANDS IN YOUTH FUTSAL - Gomes, Travassos et al. (2024).pdf	
Documents/Estudos/Futebol/fspor-06-1441125.pdf	IMPACT OF IMPLICIT VS EXPLICIT INSTRUCTIONS ON TACTICAL PERFORMANCE IN UNDER-20 SOCCER PLAYERS - Abreu et al. (2024).pdf	
Documents/Estudos/Futebol/ijerph-19-00711.pdf	ALWAYS PAY ATTENTION TO WHICH MODEL OF MOTOR LEARNING YOU ARE USING - Schöllhorn et al. (2022).pdf	
Documents/Estudos/Futebol/jphyseduc v29i1 2974.pdf	CONHECIMENTO TÁTICO DECLARATIVO E PROCESSUAL NO FUTEBOL - SUB-14 E SUB-15 - Silva et al. (2018).pdf	
Documents/Estudos/Futebol/klatt2019.pdf	CREATIVE AND INTUITIVE DECISION-MAKING PROCESSES - BRAZILIAN AND GERMAN SOCCER COACHES AND PLAYERS - Klatt et al. (2019).pdf	TCC/Referências
Documents/Estudos/Futebol/machado2019.pdf	HOW DOES THE ADJUSTMENT OF TRAINING TASK DIFFICULTY LEVEL INFLUENCE TACTICAL BEHAVIOR IN SOCCER - Machado et al. (2019).pdf	
Documents/Estudos/Futebol/mannetal2007metajsep.pdf	PERCEPTUAL-COGNITIVE EXPERTISE IN SPORT - A META-ANALYSIS - Mann et al. (2007).pdf	TCC/Referências
Documents/Estudos/Futebol/mehta-et-al-2023-examining-how-data-becomes-information-for-an-upcoming-opponent-in-football.pdf	EXAMINING HOW DATA BECOMES INFORMATION FOR AN UPCOMING OPPONENT IN FOOTBALL - Mehta et al. (2023).pdf	
Documents/Estudos/Futebol/motrizef,+ITC form.pdf	PRINCÍPIOS TÁTICOS DO JOGO DE FUTEBOL - CONCEITOS E APLICAÇÃO - Teoldo, Garganta e Greco (2009).pdf	
Documents/Estudos/Futebol/ngarrido,+MOT v16n4 393-399.pdf	COMPARISON BETWEEN UNDER-13 AND UNDER-15 SOCCER PLAYERS IN SMALL-SIDED AND CONDITIONED GAMES - Silva et al. (2021).pdf	
Documents/Estudos/Futebol/niosaprendizajeyftbolhaciauncompromisosaludable-110117041103-phpapp01.pdf	NIÑOS, APRENDIZAJE Y FÚTBOL - HACIA UN COMPROMISO SALUDABLE - Garganta (2006).pdf	
Documents/Estudos/Futebol/papel do contexto ativ 1.pdf	O PAPEL FUNDAMENTAL DO CONTEXTO NO TREINAMENTO DE ESPORTES COLETIVOS - Petiot et al. (2024) [PT].pdf	
Documents/Estudos/Futebol/petiotetal2025.pdf	THE SCOPE OF INTENTIONALITY SUPPORTING THE DESIGN OF PLAYED-FORM PRACTICE IN SOCCER - Petiot et al. (2025).pdf	
Documents/Estudos/Futebol/praca-et-al-2024-positioning-to-win-key-position-based-performance-indicators-in-elite-soccer.pdf	POSITIONING TO WIN - KEY POSITION-BASED PERFORMANCE INDICATORS IN ELITE SOCCER - Praça et al. (2024).pdf	
Documents/Estudos/Futebol/ric accepted time scales football (1).pdf	TIME SCALES FOR EXPLORATORY TACTICAL BEHAVIOUR IN FOOTBALL SMALL-SIDED GAMES - Ric et al. (2016).pdf	
Documents/Estudos/Futebol/ric accepted time scales football.pdf	TIME SCALES FOR EXPLORATORY TACTICAL BEHAVIOUR IN FOOTBALL SMALL-SIDED GAMES - Ric et al. (2016).pdf	
Documents/Estudos/Futebol/s40798-022-00454-7.pdf	MATCH ANALYSIS IN TEAM BALL SPORTS - AN UMBRELLA REVIEW - Sarmento et al. (2022).pdf	
Documents/Estudos/Futebol/s41598-019-49969-2.pdf	DEFINING A HISTORIC FOOTBALL TEAM - NETWORK SCIENCE AND GUARDIOLA'S FC BARCELONA - Buldú et al. (2019).pdf	
Documents/Estudos/Futebol/santos-et-al-2025-capturing-meso-level-synchronisation-tendencies-in-elite-football-teams-a-novel-method-for-analysing.pdf	CAPTURING MESO-LEVEL SYNCHRONISATION TENDENCIES IN ELITE FOOTBALL TEAMS - Santos et al. (2025).pdf	
Documents/Estudos/Futebol/scaglia jogos coletivos.pdf	O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf	
Documents/Estudos/Futebol/sensors-22-04435.pdf	APPLYING DIFFERENT STRATEGIES OF TASK CONSTRAINT MANIPULATION IN SMALL-SIDED AND CONDITIONED GAMES - Machado et al. (2022).pdf	TCC/Referências
Documents/Estudos/Futebol/traduzir.pdf	DESENVOLVENDO RESTRIÇÕES DE TAREFAS PARA DIFERENTES FAIXAS ETÁRIAS NO FUTEBOL - REGRAS PARA FLUTUADORES [PT].pdf	
Documents/Estudos/Inglês/20 questions, english evaluation..pdf	INGLÊS - 20 QUESTIONS - ENGLISH EVALUATION.pdf	
Documents/Estudos/Inglês/english questions variety.pdf	INGLÊS - ENGLISH QUESTIONS VARIETY.pdf	
Documents/Estudos/Inglês/present continuous tense mrs curious esl reading comprehension exercises worksheet.pdf	INGLÊS - PRESENT CONTINUOUS - MRS CURIOUS - READING COMPREHENSION.pdf	
Documents/Estudos/Neurociência/1-s2.0-S1053810024000679-main.pdf	THE MODEL OF THE BRAIN AS A COMPLEX SYSTEM - Scharfen et al. (2024).pdf	
Documents/Estudos/Neurociência/10090369221 1738160510456.pdf	ADAPTIVE CODING OF REWARD VALUE BY DOPAMINE NEURONS - Tobler et al. (2005).pdf	
Documents/Estudos/Neurociência/10182305259 1733860369336.pdf	EARLIER DEVELOPMENT OF THE ACCUMBENS RELATIVE TO ORBITOFRONTAL CORTEX - RISK-TAKING IN ADOLESCENTS - Galvan et al. (2006).pdf	
Documents/Estudos/Neurociência/10422792869 1733858129517.pdf	THE SLEEP-DEPRIVED HUMAN BRAIN - Krause et al. (2017).pdf	
Documents/Estudos/Neurociência/10829376245 1733940036291.pdf	RESERVATÓRIO DE DOPAMINA - AULA 138 - EFEITOS DO EXERCÍCIO FÍSICO NO CÉREBRO (PARTE 2).pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/122 - COMO SEU CÉREBRO MUDA COM A EXPERIÊNCIA (neuroplasticidade).pdf	RESERVATÓRIO DE DOPAMINA - AULA 122 - COMO SEU CÉREBRO MUDA COM A EXPERIÊNCIA (NEUROPLASTICIDADE).pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/12322-Texto do artigo-64351-1-10-20221020.pdf	COORDENAÇÃO MOTORA E FUNÇÕES EXECUTIVAS - POSSÍVEIS ASSOCIAÇÕES - Nava, Zacaron et al. (2021).pdf	
Documents/Estudos/Neurociência/1370434750 1733925834378.pdf	RETRIEVAL PRACTICE PRODUCES MORE LEARNING THAN ELABORATIVE STUDYING WITH CONCEPT MAPPING - Karpicke e Blunt (2011).pdf	
Documents/Estudos/Neurociência/1992360776 1733940858916.pdf	RESERVATÓRIO DE DOPAMINA - AULA 066 - COMO O ESTRESSE POTENCIALIZA HÁBITOS RUINS.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/2414392833 1733938045276.pdf	SEPARATE NEURAL SYSTEMS VALUE IMMEDIATE AND DELAYED MONETARY REWARDS - McClure et al. (2004).pdf	
Documents/Estudos/Neurociência/2541207486 1733939960615.pdf	BE SMART, EXERCISE YOUR HEART - EXERCISE EFFECTS ON BRAIN AND COGNITION - Hillman, Erickson e Kramer (2008).pdf	
Documents/Estudos/Neurociência/3073629527 1733938018809.pdf	RESERVATÓRIO DE DOPAMINA - AULA 080 - COMO O CÉREBRO TOMA DECISÃO.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/3402343039 1734092222061.pdf	RUNNING AS A KEY LIFESTYLE MEDICINE FOR LONGEVITY - Lee et al. (2017).pdf	Estudos/Fisiologia e Treinamento
Documents/Estudos/Neurociência/4286937527 1733937409981.pdf	RESERVATÓRIO DE DOPAMINA - AULA 105 - FOMO E REDE SOCIAL.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/4616366850 1733938613964.pdf	RESERVATÓRIO DE DOPAMINA - AULA 079 - A NEUROCIÊNCIA DA CRIATIVIDADE.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/4775020567 1733938623521.pdf	ROBUST PREDICTION OF INDIVIDUAL CREATIVE ABILITY FROM BRAIN FUNCTIONAL CONNECTIVITY - Beaty et al. (2018).pdf	
Documents/Estudos/Neurociência/4814920698 1733940867253.pdf	STRESS SIGNALLING PATHWAYS THAT IMPAIR PREFRONTAL CORTEX STRUCTURE AND FUNCTION - Arnsten (2009).pdf	
Documents/Estudos/Neurociência/4865825142 1733511782661.pdf	EARLY INFANT PREFRONTAL GRAY MATTER VOLUME AND INFANT EMOTIONALITY - Zhang et al. (2023).pdf	
Documents/Estudos/Neurociência/53509-Texto do Artigo-210753-1-10-20230324.pdf	ALÉM DO ATLÂNTICO NEGRO - ARTES VISUAIS - Monteiro (2023).pdf	Estudos/A classificar
Documents/Estudos/Neurociência/5572109234 1733936750547.pdf	VENTRAL HIPPOCAMPUS INTERACTS WITH PRELIMBIC CORTEX DURING INHIBITION OF THREAT RESPONSE VIA LEARNED SAFETY (2019).pdf	
Documents/Estudos/Neurociência/5944396394 1733938029227.pdf	ADDICTION - BEYOND DOPAMINE REWARD CIRCUITRY - Volkow et al. (2011).pdf	
Documents/Estudos/Neurociência/6195005601 1733937168918.pdf	RESERVATÓRIO DE DOPAMINA - AULA 045 - COMO FAZER UMA BOA APRESENTAÇÃO.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/7119999234 1733938438524.pdf	RESERVATÓRIO DE DOPAMINA - AULA 085 - NEUROCIÊNCIA SOCIAL (PARTE 1).pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/7772367922 1733508161291.pdf	THE IMPORTANCE OF A DEVELOPMENTAL PERSPECTIVE IN PSYCHIATRY - Thapar e Riglin (2020).pdf	
Documents/Estudos/Neurociência/8238716225 1733925811891.pdf	RESERVATÓRIO DE DOPAMINA - AULA 078 - TÉCNICAS DE ESTUDO.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/8245858505 1733938457047.pdf	THE FUNCTIONAL BASIS OF FACE EVALUATION - Oosterhof e Todorov (2008).pdf	
Documents/Estudos/Neurociência/8271515499 1733860360733.pdf	DYNAMIC MAPPING OF HUMAN CORTICAL DEVELOPMENT DURING CHILDHOOD THROUGH EARLY ADULTHOOD - Gogtay et al. (2004).pdf	
Documents/Estudos/Neurociência/8481206160 1738160502416.pdf	RESERVATÓRIO DE DOPAMINA - AULA 152 - A DOPAMINA RESPONDE AO VALOR RELATIVO.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/8504094926 1733936185583.pdf	RESERVATÓRIO DE DOPAMINA - AULA 057 - O QUE SÃO E ONDE FICAM AS MEMÓRIAS.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/9237296406 1733860351591.pdf	RESERVATÓRIO DE DOPAMINA - AULA 117 - O SISTEMA DE RECOMPENSA DO ADOLESCENTE.pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/9633087190 1733938036882.pdf	DUAL-PROCESSING ACCOUNTS OF REASONING, JUDGMENT, AND SOCIAL COGNITION - Evans (2008).pdf	
Documents/Estudos/Neurociência/978-3-642-75348-0.pdf	LIVRO SPRINGER 978-3-642-75348-0.pdf	
Documents/Estudos/Neurociência/9840471613 1733936197313.pdf	THE MOLECULAR AND SYSTEMS BIOLOGY OF MEMORY - Kandel, Dudai e Mayford (2014).pdf	
Documents/Estudos/Neurociência/9973094142 1733936741053.pdf	RESERVATÓRIO DE DOPAMINA - AULA 036 - SINAL DE SEGURANÇA (MODULE SUA AMÍGDALA).pdf	Estudos/Neurociência/Reservatório de Dopamina
Documents/Estudos/Neurociência/A Evolução do Cérebro Sistema Nervoso, Psicologia e -- Paulo Dalgalarrondo -- 2011 -- Artmed -- 9788582711736.pdf	A EVOLUÇÃO DO CÉREBRO - SISTEMA NERVOSO, PSICOLOGIA E PSICOPATOLOGIA - Dalgalarrondo (2011).pdf	
Documents/Estudos/Neurociência/ARTIGO BOM SOBRE JOGO- BUSCAR ASSOCIAÇÕES C NEURO.pdf	O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf	Estudos/Futebol
Documents/Estudos/Neurociência/ARTIGO PÉ DO NEYMAR.pdf	EFFICIENT FOOT MOTOR CONTROL BY NEYMAR'S BRAIN - Naito e Hirose (2014).pdf	
Documents/Estudos/Neurociência/ARTIGO QUE POUCO RELACIONA NEUROCIENCIA E LUDICIDADE.pdf	A NEUROCIÊNCIA E AS METODOLOGIAS DINÂMICAS PARA ALUNOS COM DÉFICIT COGNITIVO (2024).pdf	
Documents/Estudos/Neurociência/Apresentação - Neurociência Aplicada ao Movimento Humano.pdf	APRESENTAÇÃO - NEUROCIÊNCIA APLICADA AO MOVIMENTO HUMANO - Gabriel Vitor (2026).pdf	
Documents/Estudos/Neurociência/Apresentação Básica Minimalista Azul.pdf	FACULDADE - VISITA TÉCNICA ESCOLINHA INOCOOP CITY - Grupo Gabriel Vitor (2026).pdf	Faculdade
Documents/Estudos/Neurociência/As Bases Biológicas do comportamento - Introdução à Neurociência - Marcus Lira Brandão.pdf	AS BASES BIOLÓGICAS DO COMPORTAMENTO - INTRODUÇÃO À NEUROCIÊNCIA - Brandão (2008).pdf	
Documents/Estudos/Neurociência/Beyond The Computer Brain In Sport.pdf	BEYOND THE COMPUTER BRAIN IN SPORT.pdf	
Documents/Estudos/Neurociência/Blue & white company profile presentation (2).pdf	RELATÓRIO DE COMPETIÇÃO - COPA PERNAMBUCANA U-16 - TUBARÕES FC - Gabriel Vitor.pdf	Trabalhos Anteriores/Tubarões/Relatórios
Documents/Estudos/Neurociência/Blue & white company profile presentation (3).pdf	RELATÓRIO DE COMPETIÇÃO - COPA PERNAMBUCANA U-16 - TUBARÕES FC - Gabriel Vitor.pdf	Trabalhos Anteriores/Tubarões/Relatórios
Documents/Estudos/Neurociência/Blue & white company profile presentation.pdf	RELATÓRIO DE COMPETIÇÃO - COPA PERNAMBUCANA U-16 - TUBARÕES FC - Gabriel Vitor.pdf	Trabalhos Anteriores/Tubarões/Relatórios
Documents/Estudos/Neurociência/CÉREBRO NEUROPLÁSTICO.pdf	THE NEUROPLASTIC BRAIN - CURRENT BREAKTHROUGHS AND EMERGING FRONTIERS - Gazerani (2025).pdf	
Documents/Estudos/Neurociência/COGNIÇÃO RAAB E MARCOS REIS.pdf	EMBODIED COGNITION WITH AND WITHOUT MENTAL REPRESENTATIONS - EMBODIED CHOICES IN SPORTS - Raab (2019).pdf	
Documents/Estudos/Neurociência/Cognition in elite soccer players a general model.pdf	COGNITION IN ELITE SOCCER PLAYERS - A GENERAL MODEL - Habekost et al. (2024).pdf	
Documents/Estudos/Neurociência/Cognitive functions and special working capacity i.pdf	COGNITIVE FUNCTIONS AND SPECIAL WORKING CAPACITY IN ELITE BOXERS - Korobeynikov et al. (2023).pdf	
Documents/Estudos/Neurociência/Contrib+046.pdf	IMPACTOS DO USO DE CIGARROS ELETRÔNICOS NA SAÚDE MENTAL, FÍSICA E COMPORTAMENTAL (2025).pdf	
Documents/Estudos/Neurociência/Cortical dynamics are differentially associated wi.pdf	CORTICAL DYNAMICS AND DECISION-MAKING STRATEGIES IN HUMAN WAYFINDING - AN EEG STUDY - Huang et al. (2025).pdf	
Documents/Estudos/Neurociência/DESENVOLVIMENTO INFANTIL E PLASTICIDADE CEREBRAL A.pdf	DESENVOLVIMENTO INFANTIL E PLASTICIDADE CEREBRAL - A IMPORTÂNCIA DOS PRIMEIROS ANOS (2025).pdf	
Documents/Estudos/Neurociência/Documento sem título.pdf	FACULDADE - ATIVIDADE FISIOLOGIA DO SISTEMA RESPIRATÓRIO - Gabriel Vitor (2023).pdf	Faculdade
Documents/Estudos/Neurociência/Expertise and perceptual-cognitive performance in (1).pdf	EXPERTISE AND PERCEPTUAL-COGNITIVE PERFORMANCE IN SOCCER - A REVIEW [PT].pdf	
Documents/Estudos/Neurociência/Expertise and perceptual-cognitive performance in (2).pdf	EXPERTISE AND PERCEPTUAL-COGNITIVE PERFORMANCE IN SOCCER - A REVIEW [PT].pdf	
Documents/Estudos/Neurociência/Expertise and perceptual-cognitive performance in (3).pdf	EXPERTISE AND PERCEPTUAL-COGNITIVE PERFORMANCE IN SOCCER - A REVIEW [PT].pdf	
Documents/Estudos/Neurociência/FUNCIONAMENTO COGNITIVO JOGO IDOSOS E ADOLESCENTES.pdf	O FUNCIONAMENTO COGNITIVO DE IDOSOS E ADOLESCENTES NUM CONTEXTO DE JOGO DE REGRAS - Santos, Rossetti e Ortega (2008).pdf	
Documents/Estudos/Neurociência/FUTEBOL E FUNÇÕES EXECUTIVAS.pdf	EFEITO DA PRÁTICA DO FUTEBOL NAS FUNÇÕES EXECUTIVAS DE CRIANÇAS (2021).pdf	
Documents/Estudos/Neurociência/Flexible Defense Succeeds Creative Attacks-A Simul.pdf	FLEXIBLE DEFENSE SUCCEEDS CREATIVE ATTACKS - SIMULATION BASED ON POSITION DATA - Memmert, Imkamp e Perl (2021).pdf	TCC/Referências
Documents/Estudos/Neurociência/Fluxograma de processos.pdf	FLUXOGRAMA DE PROCESSOS - ANÁLISE DE DESEMPENHO (2026).pdf	América-PE
Documents/Estudos/Neurociência/Fraquezas do "perceptuak cognitive training.pdf	EVALUATING WEAKNESSES OF PERCEPTUAL-COGNITIVE TRAINING AND BRAIN TRAINING IN SPORT - Renshaw et al. (2019).pdf	
Documents/Estudos/Neurociência/Fraquezas do perceptuak cognitive training.pdf	EVALUATING WEAKNESSES OF PERCEPTUAL-COGNITIVE TRAINING AND BRAIN TRAINING IN SPORT - Renshaw et al. (2019) [PT].pdf	
Documents/Estudos/Neurociência/FrontSportsActLiving 2023 EditorialMentalfatigueandsportfromthelabtothefield (1).pdf	MENTAL FATIGUE AND SPORT - FROM THE LAB TO THE FIELD - Lopes et al. (2023).pdf	
Documents/Estudos/Neurociência/FrontSportsActLiving 2023 EditorialMentalfatigueandsportfromthelabtothefield (2).pdf	MENTAL FATIGUE AND SPORT - FROM THE LAB TO THE FIELD - Lopes et al. (2023).pdf	
Documents/Estudos/Neurociência/FrontSportsActLiving 2023 EditorialMentalfatigueandsportfromthelabtothefield.pdf	MENTAL FATIGUE AND SPORT - FROM THE LAB TO THE FIELD - Lopes et al. (2023).pdf	
Documents/Estudos/Neurociência/IMPORTANCIA DO EXERCICIO PARA A NEUROCPLASTICIDADE.pdf	A IMPORTÂNCIA DO EXERCÍCIO FÍSICO PARA NEUROPLASTICIDADE E APRENDIZADO (2019).pdf	
Documents/Estudos/Neurociência/INTERAÇÃO AFETIVIDADE E COGNIÇÃO.pdf	RELAÇÕES ENTRE A AFETIVIDADE E A INTELIGÊNCIA NO DESENVOLVIMENTO MENTAL DA CRIANÇA - Piaget (2017).pdf	
Documents/Estudos/Neurociência/JOGOS DIGITAIS E CONT. INIBITÓRIO.pdf	JOGOS DIGITAIS E APRIMORAMENTO DO CONTROLE INIBITÓRIO EM CRIANÇAS (2019).pdf	
Documents/Estudos/Neurociência/KANDEL - 5Ed, Principios da Neurociencia.pdf	PRINCÍPIOS DE NEUROCIÊNCIAS - Kandel et al. (5ª ed.).pdf	
Documents/Estudos/Neurociência/Livro Metodologia da Pesquisa - Comum a todos os cursos.pdf	METODOLOGIA DA PESQUISA - Silva (2017) (livro).pdf	Faculdade
Documents/Estudos/Neurociência/MCER2013Koziol.pdf	CONSENSUS PAPER - THE CEREBELLUM'S ROLE IN MOVEMENT AND COGNITION - Koziol et al. (2014).pdf	
Documents/Estudos/Neurociência/Modern Futdo futuro (1).pdf	FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2026).pdf	Faculdade
Documents/Estudos/Neurociência/Modern Futdo futuro.pdf	FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2025).pdf	Faculdade
Documents/Estudos/Neurociência/NEUROCIENCIA DO APRENDIZADO E MOTRICIDADE.pdf	POSSIBILIDADES DE APRENDIZAGEM - NEUROCIÊNCIA DO APRENDIZADO E MOTRICIDADE (2015).pdf	
Documents/Estudos/Neurociência/NEUROCIÊNCIA NOS JEC.pdf	A IMPORTÂNCIA DA NEUROCIÊNCIA PARA O ESPORTE COLETIVO - UMA REVISÃO NARRATIVA (2017).pdf	
Documents/Estudos/Neurociência/NatureNP2008.pdf	MIRROR NEURONS AND THEIR CLINICAL RELEVANCE - Rizzolatti, Fabbri-Destro e Cattaneo (2009).pdf	
Documents/Estudos/Neurociência/Neuro Coaching Framework.pdf	NEURO COACHING FRAMEWORK.pdf	
Documents/Estudos/Neurociência/Neurociencia Aplicada Cardinali.pdf	NEUROCIENCIA APLICADA - Cardinali (2012) (livro).pdf	
Documents/Estudos/Neurociência/Neurociência e Aprendizagem.pdf	NEUROCIÊNCIA E APRENDIZAGEM - Gazarini (2024).pdf	
Documents/Estudos/Neurociência/O QUE O CEREBRO TEM PARA NOS CONTAR.pdf	O QUE O CÉREBRO TEM PARA CONTAR - Ramachandran (livro).pdf	
Documents/Estudos/Neurociência/PAPEL DAS FUNÇÕES EXECUTIVAS NO ESPORTE- META ANALISE.pdf	PAPEL DAS FUNÇÕES EXECUTIVAS NO ESPORTE - META-ANÁLISE (2025).pdf	
Documents/Estudos/Neurociência/Paper published Frontiers in Aging, Brain Functional Training , 2024 (1).pdf	BRAIN FUNCTIONAL TRAINING - FRONTIERS IN AGING (2024) [PT].pdf	
Documents/Estudos/Neurociência/Paper published Frontiers in Aging, Brain Functional Training , 2024.pdf	BRAIN FUNCTIONAL TRAINING - FRONTIERS IN AGING (2024).pdf	
Documents/Estudos/Neurociência/Perceptual-cognitive processes underlying creative.pdf	PERCEPTUAL-COGNITIVE PROCESSES UNDERLYING CREATIVE EXPERT PERFORMANCE IN SOCCER - Roca et al. (2021).pdf	
Documents/Estudos/Neurociência/Perceptual-cognitive skills and talent development.pdf	PERCEPTUAL-COGNITIVE SKILLS AND TALENT DEVELOPMENT ENVIRONMENTS IN SOCCER - A SCOPING REVIEW - Triggs et al. (2025).pdf	
Documents/Estudos/Neurociência/Practice_organization_and_the_level_of_mental_effo.pdf	PRACTICE ORGANIZATION AND THE LEVEL OF MENTAL EFFORT VIA PUPIL DILATION - Ferreira et al. (2025).pdf	
Documents/Estudos/Neurociência/Psiquiatria Clínica Um Guia para Médicos e Profissionais da Saúde Mental - Amaury Cantilino.pdf	PSIQUIATRIA CLÍNICA - UM GUIA PARA MÉDICOS E PROFISSIONAIS DA SAÚDE MENTAL - Cantilino e Monteiro (2023).pdf	
Documents/Estudos/Neurociência/Psiquiatria do Estilo de Vida.pdf	PSIQUIATRIA DO ESTILO DE VIDA - Carvalho, Lafer e Schuch (2022).pdf	
Documents/Estudos/Neurociência/Rapido-e-Devagar-Daniel-Kahneman.pdf	RÁPIDO E DEVAGAR - DUAS FORMAS DE PENSAR - Kahneman.pdf	
Documents/Estudos/Neurociência/Robert M. Sapolsky - Comporte-se - A biologia humana em nosso melhor e pior (Em Portugues do Brasil).pdf	COMPORTE-SE - A BIOLOGIA HUMANA EM NOSSO MELHOR E PIOR - Sapolsky.pdf	
Documents/Estudos/Neurociência/RomingerKoschutnigetal.2021-Brainactivationduringtheobservation.pdf	BRAIN ACTIVATION DURING THE OBSERVATION - Rominger, Koschutnig et al. (2021).pdf	
Documents/Estudos/Neurociência/SAÚDE MENTAL.pdf	FACULDADE - ATIVIDADE FÍSICA E SAÚDE MENTAL - Grupo Gabriel Vitor.pdf	Faculdade
Documents/Estudos/Neurociência/TRAJETÓRIA MOV HUMANO.pdf	MOVEMENT MATTERS - DEVELOPMENTAL TRAJECTORY OF EMBODIED PLANNING - Musculus et al. (2021).pdf	
Documents/Estudos/Neurociência/The Effects of Mental Fatigue on Anaerobic Power and Power Endurance Performance.pdf	THE EFFECTS OF MENTAL FATIGUE ON ANAEROBIC POWER AND POWER ENDURANCE PERFORMANCE - Gonzalez et al. (2024) [PT].pdf	
Documents/Estudos/Neurociência/The impact of brain functional connecti...er players A resting state fMRI study.pdf	THE IMPACT OF BRAIN FUNCTIONAL CONNECTIVITY IN SOCCER PLAYERS - A RESTING STATE FMRI STUDY (2024).pdf	
Documents/Estudos/Neurociência/The peoples game evolutionary perspectives on the.pdf	THE PEOPLE'S GAME - EVOLUTIONARY PERSPECTIVES ON THE NEUROSCIENCE OF FOOTBALL FANDOM - Butler (2025).pdf	
Documents/Estudos/Neurociência/The times they are a-changin’ a proposal on how brain flexibility goes beyond the obvious to include the concepts of “upward” and “downward” to neuroplasticity.pdf	THE TIMES THEY ARE A-CHANGIN' - BRAIN FLEXIBILITY AND UPWARD AND DOWNWARD NEUROPLASTICITY.pdf	
Documents/Estudos/Neurociência/Thinking While Playing- Exploring Cognitive Load and Passing Accuracy in Football Training.pdf	THINKING WHILE PLAYING - COGNITIVE LOAD AND PASSING ACCURACY IN FOOTBALL TRAINING - Oliveira et al. (2025).pdf	
Documents/Estudos/Neurociência/Understanding and Assessing the Interconnectedness.pdf	UNDERSTANDING AND ASSESSING THE INTERCONNECTEDNESS OF MOTOR AND COGNITIVE DEVELOPMENT - DUAL TASK (2024).pdf	
Documents/Estudos/Neurociência/What Cognitive Mechanism When Where and Why Explor.pdf	WHAT COGNITIVE MECHANISM, WHEN, WHERE, AND WHY - DECISION MAKING OF RUGBY PLAYERS - Ashford et al. (2021).pdf	
Documents/Estudos/Neurociência/What is a task An ideomotor perspective.pdf	WHAT IS A TASK - AN IDEOMOTOR PERSPECTIVE - Künzell et al. (2018).pdf	
Documents/Estudos/Neurociência/atenção e memoria artigo.pdf	A CONSTRUÇÃO DA ATENÇÃO A PARTIR DA MEMÓRIA - Helene e Xavier (2003).pdf	
Documents/Estudos/Neurociência/evolução filogenética sistema nervoso.pdf	CONSIDERAÇÕES SOBRE A EVOLUÇÃO FILOGENÉTICA DO SISTEMA NERVOSO E A CONSCIÊNCIA (2006).pdf	
Documents/Estudos/Neurociência/fcogn-01-1004576.pdf	PERCEPTION - A DYNAMIC INTERPLAY BETWEEN GENETICS AND NEUROPLASTICITY - Proverbio (2022).pdf	
Documents/Estudos/Neurociência/fcogn-03-1367569.pdf	THE EFFECTS OF ACUTE EXERCISE ON LONG-TERM EPISODIC MEMORY - META-ANALYSIS - Qazi et al. (2024).pdf	
Documents/Estudos/Neurociência/fcogn-03-1386375.pdf	CREATIVITY IN MOTION - MEANINGFUL MOVEMENT AND CREATIVE COGNITION - Frith et al. (2024).pdf	
Documents/Estudos/Neurociência/fcogn-2-1361748.pdf	EMBODIED COGNITION PERSPECTIVES WITHIN EARLY EXECUTIVE FUNCTION DEVELOPMENT - Pearce et al. (2025).pdf	
Documents/Estudos/Neurociência/flexib cognitiva.pdf	EL ESTUDIO DE LA COGNICIÓN - HACIA UNA PERSPECTIVA CORPORIZADA - Espinel Quirós et al. (2024).pdf	
Documents/Estudos/Neurociência/fnhum-08-00594.pdf	EFFICIENT FOOT MOTOR CONTROL BY NEYMAR'S BRAIN - Naito e Hirose (2014).pdf	
Documents/Estudos/Neurociência/fnhum-17-1189841.pdf	CHARACTERISTICS OF BRAIN ACTIVATION IN HIGH-LEVEL FOOTBALL PLAYERS DURING DECISION-MAKING - Huang et al. (2023).pdf	
Documents/Estudos/Neurociência/fspor-06-1441607.pdf	PERFORMANCE AND PHYSICAL ACTIVITY - PLAYFUL ACTIVITIES IN DANISH ESPORTS CLUBS - Østergaard (2024).pdf	
Documents/Estudos/Neurociência/kandel2009.pdf	KANDEL - JOURNAL OF NEUROSCIENCE 40TH ANNIVERSARY RETROSPECTIVE (2009).pdf	
Documents/Estudos/Neurociência/mecanismos de neuroplasticidade.pdf	MECHANISMS OF LEARNING AND PLASTICITY IN CHILDHOOD AND ADOLESCENCE - Fandakova e Hartley (2020).pdf	
Documents/Estudos/Neurociência/nuerobiologia e reablitação.pdf	TRANSCRANIAL ELECTRICAL STIMULATION FOR PROCEDURAL LEARNING AND REHABILITATION - Lapenta et al. (2024).pdf	
Documents/Estudos/Neurociência/outramargem,+1.+PERSPECTIVAS+SOBRE+A+RELAÇÃO+ENTRE+ÉTICA+E+RELIGIÃO.pdf	PERSPECTIVAS SOBRE A RELAÇÃO ENTRE ÉTICA E RELIGIÃO - Veliq (2021).pdf	Estudos/A classificar
Documents/Estudos/Neurociência/percepction.pdf	PERCEIVING - Albright (2015).pdf	
Documents/Estudos/Neurociência/s12662-020-00699-y.pdf	GERMAN JOURNAL OF EXERCISE AND SPORT RESEARCH - Scharfen et al. (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/11222-+O+JOGO+DE+BOLA+DE+QUEIMADA.pdf	O JOGO DE BOLA DE QUEIMADA - Silva et al. (2023).pdf	
Documents/Estudos/Pedagogia do Esporte/205-Texto do artigo-1175-1-10-20140827.pdf	RBFF - ARTIGO (2014).pdf	
Documents/Estudos/Pedagogia do Esporte/2460-Texto do artigo-4059-1-10-20171221.pdf	LUDICIDADE - DA ETIMOLOGIA DA PALAVRA À COMPLEXIDADE DO CONCEITO - Massa (2015).pdf	
Documents/Estudos/Pedagogia do Esporte/7527-libre.pdf	PRÁTICAS CORPORAIS NA NATUREZA - POR UMA EDUCAÇÃO AMBIENTAL (2011).pdf	
Documents/Estudos/Pedagogia do Esporte/823298102-Pablo-Greco-Iniciacao-Esportiva-Universal-Vol-2-1.pdf	INICIAÇÃO ESPORTIVA UNIVERSAL - VOLUME 2 - Greco (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/ALCIDES SCAGLIA - PEDAGOGIA, FUTEBOL & RUA.pdf	PEDAGOGIA, FUTEBOL E RUA - Scaglia (2021) (amostra).pdf	
Documents/Estudos/Pedagogia do Esporte/APOSTILA - Iniciação esportiva-1.pdf	INICIAÇÃO ESPORTIVA APLICADA A ESPORTES DE RAQUETE - ATIVIDADES COORDENATIVAS (apostila).pdf	
Documents/Estudos/Pedagogia do Esporte/ARTIGO JOGO PIAGET (1).pdf	JOGOS E PIAGET - Soares e Rezende (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/ARTIGO JOGO PIAGET.pdf	JOGOS E PIAGET - Soares e Rezende (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/ARTIGO SOBRE BRINCAR.pdf	A BRINCAR, A BRINCAR - LÓGICAS E SENTIDOS DE FUTURAS EDUCADORAS DE INFÂNCIA (2020).pdf	
Documents/Estudos/Pedagogia do Esporte/BettegaMachadoPasquarelliAquinoScaglia2021-PedagogiadoEsporte BasesEpistemolgicaseArticulaesparaoEnsinoEsportivo.pdf	PEDAGOGIA DO ESPORTE - BASES EPISTEMOLÓGICAS E ARTICULAÇÕES PARA O ENSINO ESPORTIVO - Bettega et al. (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/D E C L A R A Ç Ã O.pdf	TCC - TERMO DE ACEITE DE ORIENTAÇÃO VOLUNTÁRIA (2026).pdf	TCC
Documents/Estudos/Pedagogia do Esporte/ENSINARDEFRENTEPARATRS UMAPROPOSTACENTRADANAFINALIZAOPARAESCOLINHASDEFUTSALEFUTEBOL.pdf	ENSINAR DE FRENTE PARA TRÁS - PROPOSTA CENTRADA NA FINALIZAÇÃO PARA ESCOLINHAS DE FUTSAL E FUTEBOL - Rigon.pdf	
Documents/Estudos/Pedagogia do Esporte/Educação Física Escolar GO TANI.pdf	EDUCAÇÃO FÍSICA ESCOLAR - FUNDAMENTOS DE UMA ABORDAGEM DESENVOLVIMENTISTA - Tani et al. (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/Escola da Bola.pdf	ESCOLA DA BOLA (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/INICIAÇÃO ESPORTIVA UNIIVERSAL 1.pdf	INICIAÇÃO ESPORTIVA UNIVERSAL - VOLUME 1 - Greco e Benda (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/LUDOPEDAGOGIA.pdf	LUDOPEDAGOGIA - CONTRIBUIÇÕES NA EDUCAÇÃO INFANTIL - Silva (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/Livro Pedagogia do Esporte descobrindo novos caminhos.pdf	PEDAGOGIA DO ESPORTE - DESCOBRINDO NOVOS CAMINHOS (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/MESTRADO JOGOS POPULARES.pdf	AS APRENDIZAGENS INTERATIVAS E COGNITIVAS EM JOGOS POPULARES - Cruz (2014) (dissertação).pdf	
Documents/Estudos/Pedagogia do Esporte/PABLO GRECO & RODOLFO BENDA - INICIAÇÃO ESPORTIVA UNIVERSAL - VOL. 1.pdf	INICIAÇÃO ESPORTIVA UNIVERSAL - VOLUME 1 - Greco e Benda (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/PEDAGOGIA DO ESPORTE - TENSÃO NA CIÊNCIA.pdf	PEDAGOGIA DO ESPORTE - TENSÃO NA CIÊNCIA E O ENSINO DOS JOGOS ESPORTIVOS (2014).pdf	
Documents/Estudos/Pedagogia do Esporte/PEDAGOGIA DO ESPORTE ARTIGO.pdf	PEDAGOGIA DO ESPORTE - TENSÃO NA CIÊNCIA E O ENSINO DOS JOGOS ESPORTIVOS (2014).pdf	
Documents/Estudos/Pedagogia do Esporte/PEDAGOGIA DO JOGO.pdf	PEDAGOGIA DO JOGO - Scaglia (2022).pdf	
Documents/Estudos/Pedagogia do Esporte/Pedagogia do esporte.pdf	PEDAGOGIA DO ESPORTE E DAS LUTAS - EM BUSCA DE APROXIMAÇÕES - Rufino e Darido (2012).pdf	
Documents/Estudos/Pedagogia do Esporte/Pedagogia-do-esporte-Riller-Silva-Reverdito- -Alcides-José-Scaglia-f51d25c5ee8550806370c0b8a36d6af9.pdf	PEDAGOGIA DO ESPORTE - Reverdito e Scaglia (livro).pdf	
Documents/Estudos/Pedagogia do Esporte/Queimado 2, regras!.pdf	O JOGO DE BOLA DE QUEIMADA - Silva et al. (2023).pdf	
Documents/Estudos/Pedagogia do Esporte/Queimado.pdf	ENSINO-APRENDIZAGEM DE ESPORTES COLETIVOS A PARTIR DE UM JOGO DE QUEIMADA - Sadi (2008).pdf	
Documents/Estudos/Pedagogia do Esporte/Scaglia AlcidesJose M.pdf	O FUTEBOL QUE SE APRENDE E O FUTEBOL QUE SE ENSINA - Scaglia (1999) (dissertação).pdf	
Documents/Estudos/Pedagogia do Esporte/TGFU E INICIAÇÃO ESPORTIVA.pdf	A PROPOSTA PEDAGÓGICA DO TEACHING GAMES FOR UNDERSTANDING - REFLEXÕES SOBRE A INICIAÇÃO ESPORTIVA - Bolonhini e Paes (2009).pdf	
Documents/Estudos/Pedagogia do Esporte/Tese - Scaglia (2003). O futebol e os jogos de brincadeiras de bola com os pés.pdf	O FUTEBOL E OS JOGOS-BRINCADEIRAS DE BOLA COM OS PÉS - Scaglia (2003) (tese).pdf	
Documents/Estudos/Pedagogia do Esporte/The Role of Nonlinear Pedagogy in Supporting the D.pdf	THE ROLE OF NONLINEAR PEDAGOGY IN SUPPORTING THE DESIGN OF MODIFIED GAMES IN JUNIOR SPORTS - Chow et al. (2021).pdf	
Documents/Estudos/Pedagogia do Esporte/Ugrinowotschetal2014TransitionIefficiencyMotriz.pdf	TRANSITION I EFFICIENCY - Ugrinowitsch et al. (2014).pdf	
Documents/Estudos/Pedagogia do Esporte/andreamarques,+2-51337 MARTINS URRA DANTAS Ed27.pdf	DIVERSÃO SOBRE RODAS - JOGOS E BRINCADEIRAS TRADICIONAIS PARA A INICIAÇÃO AO SKATE (2022).pdf	
Documents/Estudos/Pedagogia do Esporte/nathaliadias,+Gerente+da+revista,+12+-+Os+jogos+na+sociedade.pdf	OS JOGOS NA SOCIEDADE CONTEMPORÂNEA - INFLUÊNCIAS DOS AVANÇOS TECNOLÓGICOS (2017).pdf	
Documents/Estudos/Pedagogia do Esporte/pri2602,+Rev4-2013-p227-249.pdf	O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf	
Documents/Estudos/Pedagogia do Esporte/robertob,+02+Artigo.pdf	A OPERACIONALIZAÇÃO DO ESPORTE EM ESCOLAS DE INICIAÇÃO - O FUTEBOL QUE SE PROPÕE (2015).pdf	
Documents/Estudos/Pedagogia do Esporte/scaglia alcidesjose d.pdf	O FUTEBOL E OS JOGOS-BRINCADEIRAS DE BOLA COM OS PÉS - Scaglia (2003) (tese).pdf	
__LISTA__
