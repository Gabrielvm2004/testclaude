#!/bin/bash
# Organiza Downloads, Mesa e Documentos por ETAPAS, com um PLANO para revisar antes.
#
# - Analisa cada item (nome + conteúdo dos PDFs pelo Spotlight) e decide o destino.
# - Arquivos de trabalho sem nome de clube vão para o clube da época em que foram
#   baixados (antes da chegada ao América = Tubarões).
# - Mostra o plano (abre no TextEdit) e só aplica se você confirmar.
# - Só vão para "Duplicados" arquivos 100% IDÊNTICOS (comparados byte a byte).
#   Versões com mudanças mantêm o número no nome e nunca são juntadas.
# - Nunca apaga nada, nunca sobrescreve, e cria um script para DESFAZER.
# - Não mexe na pasta Scout nem em arquivos .csv (automação do Scout).
#
# Como usar (no Terminal):  bash ~/Downloads/organizar_e_renomear.sh

# ======================= CONFIGURE AQUI =======================
DOC="$HOME/Documents"
DL="$HOME/Downloads"
EST="$DOC/Estudos"
AM="$DOC/América-PE"
BEN="$DOC/Benfica"
ANT="$DOC/Trabalhos Anteriores"
TUB="$ANT/Tubarões"

# Clube: o nome manda; se o nome não diz, manda a data em que o arquivo foi baixado.
CHEGADA_AMERICA="2026-07-26"           # a partir desta data -> América-PE; antes -> Tubarões
PALAVRAS_AMERICA="america"
PALAVRAS_TUBAROES="tubaroes, tub"

# Pastas que serão organizadas (só os itens soltos nelas, não o que já está em subpastas).
ORIGENS=("$DL" "$HOME/Desktop")

# Pastas antigas de Documentos que mudam de lugar:  antiga | nova
MIGRAR="
$DOC/NEURO               | $EST/Neurociência
$DOC/APREND. MOTORA      | $EST/Aprendizagem Motora
$DOC/FUTEBOL             | $EST/Futebol
$DOC/JOGOS CAMERA ABERTA | $AM/Jogos/Câmera Aberta
"

# Pastas criadas vazias, prontas para usar.
CRIAR="
$BEN/Planos de Aula e Treinos
$BEN/Fotos e Vídeos
"

# Regras:  destino | palavras-chave | tipos aceitos (vazio = todos) | ler conteúdo? (s)
# - {CLUBE} = América-PE ou Trabalhos Anteriores/Tubarões (pelo nome ou pela data).
# - Palavra no nome = 3 pontos; no conteúdo do PDF = 2. Ganha quem tiver mais pontos;
#   no empate, ganha a regra que aparece primeiro.
# - As palavras pegam o começo das palavras do nome ("neuro" pega "neurociência").
# - "pasta" nos tipos = aceita pastas. Regra sem palavras vale para o tipo inteiro.
REGRAS="
$DL/Instaladores (pode apagar)   | | dmg, pkg, mpkg, exe, app
{CLUBE}/Capturas de Tela         | captura de tela, screenshot
{CLUBE}/Gravações de Tela        | gravacao de tela
$DOC/TCC                         | tcc, monografia, orientador, orientacao voluntaria, termo de aceite, projeto de pesquisa, preprojeto, pre projeto, relatorio de andamento, parecer orientador
$ANT/AABB                        | aabb
$BEN                             | benfica
$EST/Futebol/Vídeos de Referência | barcelona, city, palmeiras, inter vs, ned v jap, cotinthians, corinthians, tactical cam | mov, mp4, m4v
{CLUBE}/Jogos                    | america, tubaroes, tub, amistoso, 1 tempo, 2 tempo, 1o tempo, primeiro tempo, segundo tempo, x | mov, mp4, m4v
{CLUBE}/Relatórios               | america, tubaroes, autoanalise, elenco, relatorio dados, controle de cartoes, boletim
{CLUBE}/Modelo de Jogo           | slide deck, principios para tarefas
{CLUBE}/Treinos                  | plano de treino, plano treino, planilhas de treino, mini campinho, microciclo, treino diego, diego avelar
{CLUBE}/Adversários/Retrô        | retro
{CLUBE}/Adversários/Treze        | treze
{CLUBE}/Adversários/Náutico      | nautico
{CLUBE}/Adversários/Sport        | sport | mov, mp4, m4v, pasta, png, jpg, jpeg
{CLUBE}/Adversários/CRB          | crb
{CLUBE}/Adversários/Santa Cruz   | santa cruz
{CLUBE}/Adversários/Petrolina    | petrolina
{CLUBE}/Adversários/Torres       | torres
{CLUBE}/Adversários/Santa Fé     | santa fe
{CLUBE}/Adversários/Jaguar       | jaguar
{CLUBE}/Adversários/Barão        | barao
{CLUBE}/Adversários/CT Lúcio     | ct lucio
{CLUBE}/Adversários/Maitá        | maita
{CLUBE}/Adversários/Geral        | adversario, adversarios
{CLUBE}/Wyscout                  | wyplaylist, wyscout, playlist
$DOC/Projetos Claude             | claude, testclaude, dashboard, codigo, canvas, banco de exercicios, instagram card, guia compartilhamento, future model, apresentacao atletas
$EST/Neurociência        | neuro, cerebr, cognic, cognit, plasticid, kandel, sapolsky, funcoes executivas, executive, brain, memoria, atencao, psiquiatr, saude mental, kahneman, rapido e devagar, cortical, inibitorio, flexib | | s
$EST/Aprendizagem Motora | motor, motora, motric, aprendizagem, coordenac, coordenativ, habilidade, controle postural, desenvolvimento motor, gallahue, timming, timing, pratica, practice, skill, contextual, feedback, dupla tarefa | | s
$EST/Pedagogia do Esporte | pedagogia, iniciacao esportiva, ludic, ludo, brincar, brincadeira, piaget, queimad, jogos populares, lazer, educacao fisica, scaglia, greco, tgfu, nonlinear, escola da bola | | s
$EST/Futebol             | futebol, futsal, football, soccer, tatic, tactic, jogo de posicao, jogos reduzidos, small sided, ssg, tomada de decisao, decision, ecologic, constraint, restricoes, modelo de jogo, match analysis, performance analysis, ucl, villas boas, garganta, travassos, uefa, world cup, talent, talento | | s
$EST/Fisiologia e Treinamento | fisiolog, treinamento, corrida, core, anatomia, biomecanic, guyton, silverthorn, mcardle, vo2, sono, sleep, lesoes, propriocep, somatotip, condromalac, periodiz, muscular, strength, genetica, nutri | | s
$EST/Inglês              | english, present continuous, questions
$DOC/Faculdade            | estagio, bacharelado, aula, cdh, prova, monitoria, apostila, termo de compromisso, termo de encaminhamento, ficha de, plano de atividade, relatorio das atividades, avaliacoes, atividade, estratificacao, diabetes, promocao, pnps, conferencia, tept, plano de aula, modelo de plano, roteiro, estudo de caso, declaracao, termo de anuencia, termo assentimento, documentos estagio, esef, upe
$DOC/Pessoal              | curriculo, carro, harry potter, whatsapp image, photo, fotos compradas, assinatura digital, logo safadinha, corridinha
"

# Para onde vai o que nenhuma regra reconheceu (por tipo). O resto fica onde está.
PADRAO="
mov, mp4, m4v, avi, mkv            | {CLUBE}/Cortes de Vídeo
pdf, epub, doc, docx, pptx, ppt    | $EST/A classificar
png, jpg, jpeg, heic, webp, gif    | $HOME/Pictures/Imagens dos Downloads
html, gs, md, txt                  | $DOC/Projetos Claude
"

# Cores das pastas em destaque (1 laranja, 2 vermelho, 3 amarelo, 4 azul, 5 roxo, 6 verde).
DESTAQUES="
$DOC/TCC | 2
$DOC/Scout | 4
$AM | 6
$BEN | 6
$EST | 3
$EST/Aprendizagem Motora | 5
"
# ==============================================================

case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in *UTF-8*|*utf8*) ;; *) export LC_ALL=en_US.UTF-8 ;; esac

ESTE_SCRIPT="${0##*/}"
DATA="$(date +%Y-%m-%d_%H-%M-%S)"
DESFAZER="$DL/DESFAZER_organizacao_$DATA.sh"
PLANO="$DL/PLANO_organizacao_$DATA.txt"
DUPLICADOS="$DL/Duplicados (pode apagar)"
ZIPS="$DL/Zips já extraídos (pode apagar)"
SEP=$'\x1f'

# O Mac pode guardar "ç" como "c" + sinal separado (forma NFD). O perl junta/remove
# os sinais, para "Gravação", "Náutico" etc. serem reconhecidos de qualquer forma.
normalizar() {   # sem acento, minúsculas, só letras/números separados por um espaço
  printf '%s\n' "$1" | perl -CSD -MUnicode::Normalize -pe '$_ = lc NFD($_); s/\pM//g; s/[^a-z0-9\n]+/ /g'
}
nfc() {   # forma "normal" dos acentos, para os nomes novos e as limpezas
  printf '%s\n' "$1" | perl -CSD -MUnicode::Normalize -pe '$_ = NFC($_)'
}
aparar() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; echo "${s%"${s##*[![:space:]]}"}"; }
minusculas() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
tamanho() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null; }
relativo() { echo "${1/#$HOME\//}"; }

separar() {   # "foto.jpg" -> BASE="foto" EXT=".jpg"
  case "$1" in
    ?*.*) BASE="${1%.*}"; EXT=".${1##*.}" ;;
    *)    BASE="$1"; EXT="" ;;
  esac
}

# Deixa o nome mais legível. Com "manter", os números de versão "(2)" ficam.
limpar_nome() {
  local n="$1" numeros='s/([[:space:]]*\( ?[0-9]+\)[[:space:]]*)+$//'   # só no final do nome
  [ "$2" = "manter" ] && numeros='s/[[:space:]]+\(/ (/g'
  case "$n" in YTDown.com_*) n="$(echo "$n" | sed -E 's/^YTDown\.com_YouTube_//; s/_Media_.*$//; s/-/ /g')" ;; esac
  n="$(echo "$n" | sed -E "
    s/%20/ /g
    s/_+/ /g
    s/^(Cópia|Copia|cópia|copia) de //
    s/^(Copy|copy) of //
    s/^Microsoft (Word|PowerPoint|Excel) - //
    s/ -- [0-9a-f]{32}//g
    s/ -- Anna.s Archive$//
    s/ ?\(Z-Library\)//
    s/[\/:]/-/g
    $numeros
    s/[[:space:]]+$//
    s/\.(docx|doc|pdf|png|mov)$//
    s/\.(docx|doc)$//
    s/[[:space:]]+(copy|Copy|COPY|copia|Copia|cópia|Cópia)$//
    s/[[:space:]]+-[[:space:]]*$//
    s/[[:space:]]+/ /g")"
  n="$(aparar "$n")"
  [ -n "$n" ] && echo "$n" || echo "$1"
}

destino_livre() {   # dir nome eh_pasta -> caminho que ainda não existe
  local dir="$1" nome="$2" b e k=2
  if [ ! -e "$dir/$nome" ]; then echo "$dir/$nome"; return; fi
  if [ "$3" = 1 ]; then b="$nome"; e=""; else separar "$nome"; b="$BASE"; e="$EXT"; fi
  while [ -e "$dir/$b ($k)$e" ]; do k=$((k + 1)); done
  echo "$dir/$b ($k)$e"
}

iguais() {   # mesmo conteúdo, byte a byte?
  if [ -d "$1" ] && [ -d "$2" ]; then diff -rq "$1" "$2" >/dev/null 2>&1; return; fi
  [ -f "$1" ] && [ -f "$2" ] || return 1
  [ "$(tamanho "$1")" = "$(tamanho "$2")" ] && cmp -s "$1" "$2"
}

data_adicao() {   # data em que o arquivo chegou ao Mac (AAAA-MM-DD)
  local d=""
  command -v mdls >/dev/null 2>&1 && d="$(mdls -raw -name kMDItemDateAdded "$1" 2>/dev/null)"
  case "$d" in [0-9][0-9][0-9][0-9]-*) echo "${d:0:10}"; return ;; esac
  date -r "$1" +%Y-%m-%d 2>/dev/null
}

lista_norm() {   # "a, b c" -> " a | b c |" (palavras normalizadas)
  local out="" p
  IFS=',' read -r -a _l <<< "$1"
  for p in "${_l[@]}"; do p="$(aparar "$(normalizar "$p")")"; [ -n "$p" ] && out="$out$p$SEP"; done
  echo "$out"
}
tem_palavra() {   # texto lista -> verdadeiro se alguma palavra aparece no começo de uma palavra do texto
  local p resto="$2"
  while [ -n "$resto" ]; do
    p="${resto%%"$SEP"*}"; resto="${resto#*"$SEP"}"
    case "$1" in *" $p"*) return 0 ;; esac
  done
  return 1
}

# Decide o clube: pelo nome; se o nome não diz, pela data. Define CLUBE e CLUBE_POR.
KW_AM="$(lista_norm "$PALAVRAS_AMERICA")"; KW_TUB="$(lista_norm "$PALAVRAS_TUBAROES")"
decidir_clube() {
  local texto="$1" item="$2" d
  if tem_palavra "$texto" "$KW_AM"; then CLUBE="$AM"; CLUBE_POR="nome"; return; fi
  if tem_palavra "$texto" "$KW_TUB"; then CLUBE="$TUB"; CLUBE_POR="nome"; return; fi
  d="$(data_adicao "$item")"
  if [ -n "$d" ] && [ "$d" \< "$CHEGADA_AMERICA" ]; then CLUBE="$TUB"; else CLUBE="$AM"; fi
  CLUBE_POR="baixado em $d"
}

# ---------- Lê a configuração ----------
R_DEST=(); R_TIPOS=(); R_CONT=(); R_TEMPAL=()
KW_R=(); KW_T=()          # lista achatada de palavras: regra e texto normalizado
while IFS='|' read -r dest palavras tipos cont; do
  dest="$(aparar "$dest")"; [ -z "$dest" ] && continue
  r=${#R_DEST[@]}
  R_DEST+=("$dest")
  R_TIPOS+=(",$(minusculas "$tipos" | tr -d ' '),")
  R_CONT+=("$(aparar "$cont")")
  R_TEMPAL+=(0)
  IFS=',' read -r -a lista <<< "$palavras"
  for p in "${lista[@]}"; do
    p="$(aparar "$(normalizar "$p")")"; [ -z "$p" ] && continue
    KW_R+=("$r"); KW_T+=("$p"); R_TEMPAL[$r]=1
  done
done <<EOF
$REGRAS
EOF

P_TIPOS=(); P_DEST=()
while IFS='|' read -r tipos dest; do
  dest="$(aparar "$dest")"; [ -z "$dest" ] && continue
  P_TIPOS+=(",$(minusculas "$tipos" | tr -d ' '),"); P_DEST+=("$dest")
done <<EOF
$PADRAO
EOF

# ---------- Escolhe a etapa ----------
echo
echo "Qual etapa você quer fazer agora?"
echo "  1) Limpeza: instaladores, cópias 100% idênticas, zips já extraídos,"
echo "     capturas e gravações de tela (vão para o clube da data em que foram feitas)"
echo "  2) Trabalho: América-PE, Tubarões, AABB e Benfica"
echo "  3) Estudos, TCC, Faculdade, Pessoal, Projetos e o resto"
echo "  4) Tudo de uma vez"
printf "Etapa [1]: "
read -r ETAPA
[ -z "$ETAPA" ] && ETAPA=1
case "$ETAPA" in 1|2|3|4) ;; *) echo "Opção inválida."; exit 1 ;; esac

etapa_de() {   # destino -> 1, 2 ou 3
  case "$1" in
    "$DL/Instaladores (pode apagar)"|"$DUPLICADOS"|"$ZIPS"|*"/Capturas de Tela"|*"/Gravações de Tela") echo 1 ;;
    "$AM"|"$AM/"*|"$ANT"|"$ANT/"*|"$BEN"|"$BEN/"*) echo 2 ;;
    *) echo 3 ;;
  esac
}

# ---------- Monta o plano ----------
# PL_ONFC = nome original na forma "normal" dos acentos (para comparar nomes).
PL_ORIG=(); PL_DIR=(); PL_TIRAR=(); PL_MANTER=(); PL_MOTIVO=(); PL_ONFC=()
planejar() { PL_ORIG+=("$1"); PL_DIR+=("$2"); PL_TIRAR+=("$3"); PL_MANTER+=("$4"); PL_MOTIVO+=("$5"); PL_ONFC+=("${6:-${1##*/}}"); }

# Pastas antigas de Documentos
while IFS='|' read -r antiga nova; do
  antiga="$(aparar "$antiga")"; nova="$(aparar "$nova")"
  [ -z "$antiga" ] && continue
  [ -d "$antiga" ] && [ ! -e "$nova" ] && planejar "$antiga" "${nova%/*}" "${nova##*/}" "${nova##*/}" "pasta antiga reorganizada"
done <<EOF
$MIGRAR
EOF

# Itens soltos
itens=()
for origem in "${ORIGENS[@]}"; do
  [ -d "$origem" ] || continue
  for f in "$origem"/*; do
    [ -e "$f" ] || continue
    nome="${f##*/}"
    case "$nome" in
      "$ESTE_SCRIPT"|organizar_*.sh|DESFAZER_organizacao_*|PLANO_organizacao_*|lista_finder.txt) continue ;;
      "Duplicados (pode apagar)"|"Instaladores (pode apagar)"|"Zips já extraídos (pode apagar)") continue ;;
      *.download|*.crdownload|*.part|"~\$"*) continue ;;   # download em andamento / temporário do Word
      *.csv|*.CSV) continue ;;                              # dados do Scout
    esac
    [ -L "$f" ] && continue
    itens+=("$f")
  done
done

# Conteúdo dos arquivos pelo Spotlight (só nos Downloads, só regras marcadas com "s").
CONT=()
if [ "$ETAPA" = 3 ] || [ "$ETAPA" = 4 ]; then
  if command -v mdfind >/dev/null 2>&1; then
    echo "Lendo o conteúdo dos PDFs pelo Spotlight (1 a 2 minutos)..."
    k=0
    while [ $k -lt ${#KW_T[@]} ]; do
      r=${KW_R[$k]}
      if [ "${R_CONT[$r]}" = "s" ]; then
        achados="$(mdfind -onlyin "$DL" "kMDItemTextContent == \"${KW_T[$k]}*\"cdw" 2>/dev/null \
          | awk -v d="$DL/" 'index($0,d)==1 && index(substr($0,length(d)+1),"/")==0')"
        while IFS= read -r a; do [ -n "$a" ] && CONT[$r]="${CONT[$r]}$SEP$a$SEP"; done <<< "$achados"
      fi
      k=$((k + 1))
    done
  fi
fi

echo "Analisando ${#itens[@]} itens..."
n=0
for item in "${itens[@]}"; do
  n=$((n + 1)); [ $((n % 200)) -eq 0 ] && echo "  ... $n"
  nome="${item##*/}"; dir="${item%/*}"

  if [ -d "$item" ]; then
    case "$nome" in *.app) tipo="app" ;; *) tipo="pasta" ;; esac
    BASE="$nome"; EXT=""
  else
    separar "$nome"; tipo="$(minusculas "${EXT#.}")"
  fi

  # --- Cópias 100% idênticas e zips já extraídos ---
  if [ "$tipo" = "zip" ] && [ -d "$dir/$BASE" ]; then
    planejar "$item" "$ZIPS" "$nome" "$nome" "a pasta \"$BASE\" já tem o conteúdo extraído"; continue
  fi
  sem="$(echo "$BASE" | sed -E 's/[[:space:]]*\( ?[0-9]+\)//g; s/ [0-9]$//; s/[[:space:]]+$//')"
  if [ "$sem" != "$BASE" ] && [ -e "$dir/$sem$EXT" ] && iguais "$item" "$dir/$sem$EXT"; then
    planejar "$item" "$DUPLICADOS" "$nome" "$nome" "idêntico byte a byte a \"$sem$EXT\""; continue
  fi

  base_nfc="$(nfc "$BASE")"
  tirar="$(limpar_nome "$base_nfc")"
  manter="$(limpar_nome "$base_nfc" manter)"
  # Nome sem espaços e comprido (ex.: "8VPm6d5Jqmz3FZd8C8jzVVp") -> título interno do PDF.
  case "$tirar" in
    *" "*) ;;
    *) if [ "$tipo" = "pdf" ] && [ ${#tirar} -ge 15 ] && command -v mdls >/dev/null 2>&1; then
         t="$(mdls -raw -name kMDItemTitle "$item" 2>/dev/null)"
         if [ -n "$t" ] && [ "$t" != "(null)" ] && [ ${#t} -le 90 ]; then
           t="$(limpar_nome "$(nfc "$t")")"; [ ${#t} -ge 6 ] && { tirar="$t"; manter="$t"; }
         fi
       fi ;;
  esac

  # --- Pontuação ---
  texto=" $(normalizar "$nome $tirar") "
  PTS=(); MOT=()
  k=0
  while [ $k -lt ${#KW_T[@]} ]; do
    case "$texto" in *" ${KW_T[$k]}"*) r=${KW_R[$k]}; PTS[$r]=$(( ${PTS[$r]:-0} + 3 )); MOT[$r]="${MOT[$r]} \"${KW_T[$k]}\"" ;; esac
    k=$((k + 1))
  done
  melhor=-1; melhor_pts=0
  r=0
  while [ $r -lt ${#R_DEST[@]} ]; do
    if [ "${R_TIPOS[$r]}" = ",," ] || case "${R_TIPOS[$r]}" in *",$tipo,"*) true ;; *) false ;; esac; then
      p=${PTS[$r]:-0}
      b="${CONT[$r]}"
      if [ -n "$b" ]; then
        resto="${b//"$SEP$item$SEP"/}"
        c=$(( (${#b} - ${#resto}) / (${#item} + 2) ))
        [ $c -gt 0 ] && { p=$((p + 2 * c)); MOT[$r]="${MOT[$r]} (conteúdo)"; }
      fi
      [ "${R_TEMPAL[$r]}" = 0 ] && p=100      # regra só por tipo: sempre ganha
      if [ $p -gt $melhor_pts ]; then melhor=$r; melhor_pts=$p; fi
    fi
    r=$((r + 1))
  done

  if [ $melhor -ge 0 ]; then
    dest="${R_DEST[$melhor]}"; motivo="${MOT[$melhor]:- tipo .$tipo}"
  else
    dest=""; motivo=""
    r=0
    while [ $r -lt ${#P_DEST[@]} ]; do
      case "${P_TIPOS[$r]}" in *",$tipo,"*) dest="${P_DEST[$r]}"; motivo=" nenhuma palavra; padrão para .$tipo"; break ;; esac
      r=$((r + 1))
    done
  fi
  if [ -z "$dest" ]; then planejar "$item" "" "$nome" "$nome" ""; continue; fi   # fica onde está

  case "$dest" in *"{CLUBE}"*)
    decidir_clube "$texto" "$item"
    dest="${dest//\{CLUBE\}/$CLUBE}"
    motivo="$motivo; clube pelo $CLUBE_POR"
  esac
  planejar "$item" "$dest" "$tirar$EXT" "$manter$EXT" "$motivo" "$base_nfc$EXT"
done

# ---------- Nomes: só tira o "(2)" se isso não juntar versões diferentes ----------
# Se dois itens ficariam com o mesmo nome na mesma pasta, os dois mantêm o número.
COLIDE="$(
  i=0
  while [ $i -lt ${#PL_ORIG[@]} ]; do
    [ -n "${PL_DIR[$i]}" ] && printf '%s\n' "${PL_DIR[$i]}/${PL_TIRAR[$i]}"
    i=$((i + 1))
  done | sort | uniq -d | while IFS= read -r l; do printf '%s' "$SEP$l$SEP"; done
)"
PL_NOME=()
i=0
while [ $i -lt ${#PL_ORIG[@]} ]; do
  alvo="${PL_DIR[$i]}/${PL_TIRAR[$i]}"
  nome="${PL_TIRAR[$i]}"
  case "$COLIDE" in *"$SEP$alvo$SEP"*) nome="${PL_MANTER[$i]}" ;; esac
  # Já existe um arquivo DIFERENTE com esse nome no destino? Mantém o número.
  if [ -n "${PL_DIR[$i]}" ] && [ -e "${PL_DIR[$i]}/$nome" ] && ! iguais "${PL_ORIG[$i]}" "${PL_DIR[$i]}/$nome"; then
    nome="${PL_MANTER[$i]}"
  fi
  # Nome que só mudaria o formato do acento continua exatamente igual.
  [ "$nome" = "${PL_ONFC[$i]}" ] && nome="${PL_ORIG[$i]##*/}"
  PL_NOME+=("$nome")
  i=$((i + 1))
done

# ---------- Mostra o plano da etapa ----------
na_etapa() {   # índice -> verdadeiro se pertence à etapa escolhida
  [ "$ETAPA" = 4 ] && return 0
  [ -z "${PL_DIR[$1]}" ] && [ "$ETAPA" = 3 ] && return 0
  [ -n "${PL_DIR[$1]}" ] && [ "$(etapa_de "${PL_DIR[$1]}")" = "$ETAPA" ]
}
{
  echo "PLANO DE ORGANIZAÇÃO — etapa $ETAPA — $DATA"
  echo "Nada foi mudado ainda. Volte ao Terminal para confirmar."
  echo "Entre [colchetes] está o motivo de cada decisão."
  echo
  i=0
  while [ $i -lt ${#PL_ORIG[@]} ]; do
    if na_etapa $i; then
      if [ -n "${PL_DIR[$i]}" ]; then
        o="${PL_ORIG[$i]##*/}"
        if [ "$o" = "${PL_NOME[$i]}" ]; then l="$o"; else l="$o   →   ${PL_NOME[$i]}"; fi
        printf '%s\t%s   [%s ]\n' "$(relativo "${PL_DIR[$i]}")" "$l" "${PL_MOTIVO[$i]# }"
      else
        printf '%s\t%s\n' "~ FICA ONDE ESTÁ (não identifiquei)" "$(relativo "${PL_ORIG[$i]}")"
      fi
    fi
    i=$((i + 1))
  done | sort | awk -F'\t' '$1!=g{g=$1; print "\n=== " g " ==="} {print "   " $2}'
} > "$PLANO"

echo
echo "============ RESUMO DO PLANO (etapa $ETAPA) ============"
total=0
i=0
while [ $i -lt ${#PL_ORIG[@]} ]; do
  if na_etapa $i; then
    [ -n "${PL_DIR[$i]}" ] && echo "$(relativo "${PL_DIR[$i]}")" || echo "~ fica onde está"
  fi
  i=$((i + 1))
done | sort | uniq -c | sort -rn
echo "========================================================"
echo "O plano completo (arquivo por arquivo) está em:"
echo "  $PLANO"
open -e "$PLANO" 2>/dev/null
echo
printf "Aplicar esta etapa? (s = sim / n = não) "
read -r ok
if [ "$ok" != "s" ] && [ "$ok" != "S" ]; then
  echo "Cancelado. Nada foi alterado. (O arquivo do plano pode ser apagado.)"; exit 0
fi

# ---------- Aplica ----------
# O desfazer volta os passos na ORDEM INVERSA (ex.: tira os arquivos de
# "Estudos/Neurociência" antes de devolver a pasta para "NEURO"). Ele é gerado
# no final, ou se o script for interrompido no meio.
PASSOS="$DESFAZER.passos"
: > "$PASSOS"
gerar_desfazer() {
  [ -f "$PASSOS" ] || return
  {
    echo "#!/bin/bash"
    echo "# Desfaz a organização (etapa $ETAPA) feita em $DATA"
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$PASSOS"
  } > "$DESFAZER"
  rm -f "$PASSOS"
}
trap gerar_desfazer EXIT

if [ "$ETAPA" = 2 ] || [ "$ETAPA" = 4 ]; then
  while IFS= read -r p; do p="$(aparar "$p")"; [ -n "$p" ] && mkdir -p "$p"; done <<EOF
$CRIAR
EOF
fi

movidos=0; renomeados=0; duplicados=0; erros=0
i=0
while [ $i -lt ${#PL_ORIG[@]} ]; do
  orig="${PL_ORIG[$i]}"; dest="${PL_DIR[$i]}"; novo="${PL_NOME[$i]}"
  if ! na_etapa $i || [ -z "$dest" ] || [ ! -e "$orig" ]; then i=$((i + 1)); continue; fi
  i=$((i + 1))
  # Já existe um arquivo IDÊNTICO com esse nome no destino? Então é cópia.
  if [ "$dest" != "$DUPLICADOS" ] && [ -e "$dest/$novo" ] && iguais "$orig" "$dest/$novo"; then
    dest="$DUPLICADOS"; novo="${orig##*/}"
  fi
  [ -d "$orig" ] && eh=1 || eh=0
  mkdir -p "$dest"
  alvo="$(destino_livre "$dest" "$novo" "$eh")"
  if mv "$orig" "$alvo"; then
    printf 'mkdir -p %q && mv -n %q %q\n' "${orig%/*}" "$alvo" "$orig" >> "$PASSOS"
    case "$dest" in
      "$DUPLICADOS"|"$ZIPS") duplicados=$((duplicados + 1)) ;;
      *) movidos=$((movidos + 1)); [ "${alvo##*/}" != "${orig##*/}" ] && renomeados=$((renomeados + 1)) ;;
    esac
  else
    erros=$((erros + 1))
  fi
done

# Pastas em destaque: cor no Finder
while IFS='|' read -r pasta cor; do
  pasta="$(aparar "$pasta")"; cor="$(aparar "$cor")"
  [ -d "$pasta" ] || continue
  osascript -e "tell application \"Finder\" to set label index of (POSIX file \"$pasta\" as alias) to $cor" >/dev/null 2>&1
done <<EOF
$DESTAQUES
EOF

echo
echo "Etapa $ETAPA pronta! $movidos itens organizados ($renomeados renomeados) e $duplicados cópias/zips separados."
[ $erros -gt 0 ] && echo "Atenção: $erros itens não puderam ser movidos (veja as mensagens acima)."
[ $duplicados -gt 0 ] && echo "Confira as pastas \"(pode apagar)\" em Downloads antes de jogar no Lixo."
echo "Para voltar esta etapa como estava:"
echo "  bash \"$DESFAZER\""
