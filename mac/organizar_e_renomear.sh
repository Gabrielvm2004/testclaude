#!/bin/bash
# Organiza Downloads, Mesa e Documentos de uma vez, com um PLANO para revisar antes.
#
# 1. Analisa cada item (nome + conteúdo dos PDFs pelo Spotlight) e decide o destino.
# 2. Mostra o plano completo (abre no TextEdit) e só aplica se você confirmar.
# 3. Cópias idênticas vão para "Downloads/Duplicados (pode apagar)".
# 4. Nunca apaga nada, nunca sobrescreve, e cria um script para DESFAZER tudo.
# 5. Não mexe na pasta Scout nem em arquivos .csv (automação do Scout).
#
# Como usar (no Terminal):  bash ~/Downloads/organizar_e_renomear.sh

# ======================= CONFIGURE AQUI =======================
DOC="$HOME/Documents"
AM="$DOC/América-PE"
EST="$DOC/Estudos"
DL="$HOME/Downloads"

# Pastas que serão organizadas (só os itens soltos nelas, não o que já está em subpastas).
ORIGENS=("$DL" "$HOME/Desktop")

# Pastas antigas de Documentos que mudam de lugar:  antiga | nova
MIGRAR="
$DOC/NEURO               | $EST/Neurociência
$DOC/APREND. MOTORA      | $EST/Aprendizagem Motora
$DOC/FUTEBOL             | $EST/Futebol
$DOC/JOGOS CAMERA ABERTA | $AM/Nossa Equipe/Jogos/Câmera Aberta
"

# Regras:  destino | palavras-chave | tipos aceitos (vazio = todos) | ler conteúdo? (s)
# - Palavra no nome = 3 pontos; no conteúdo do PDF = 2. Ganha quem tiver mais pontos;
#   no empate, ganha a regra que aparece primeiro.
# - As palavras pegam o começo das palavras do nome ("neuro" pega "neurociência").
# - "pasta" nos tipos = aceita pastas. Regra sem palavras vale para o tipo inteiro.
REGRAS="
$DL/Instaladores (pode apagar)   | | dmg, pkg, mpkg, exe, app
$HOME/Pictures/Capturas de Tela  | captura de tela, screenshot
$HOME/Movies/Gravações de Tela   | gravacao de tela
$DOC/TCC                         | tcc, monografia, orientador, orientacao voluntaria, termo de aceite, projeto de pesquisa, preprojeto, pre projeto, relatorio de andamento, parecer orientador
$DOC/Outros Trabalhos/Tubarões   | tubaroes, tub, barao, ct lucio, maita, sub 13, sub13, sub 14, sub 15, sub15, u 16
$DOC/Outros Trabalhos/AABB       | aabb
$AM/Nossa Equipe/Jogos           | america, amistoso, 1 tempo, 2 tempo, 1o tempo, primeiro tempo, segundo tempo | mov, mp4, m4v
$AM/Nossa Equipe/Relatórios     | america, autoanalise, elenco, relatorio dados, controle de cartoes, boletim
$AM/Nossa Equipe/Modelo de Jogo  | modelo de jogo america, slide deck, principios para tarefas
$AM/Nossa Equipe/Treinos         | plano de treino, plano treino, planilhas de treino, mini campinho, microciclo, treino diego, diego avelar
$AM/Adversários/Retrô            | retro
$AM/Adversários/Treze            | treze
$AM/Adversários/Náutico          | nautico
$AM/Adversários/Sport            | sport | mov, mp4, m4v, pasta, png, jpg, jpeg
$AM/Adversários/CRB              | crb
$AM/Adversários/Santa Cruz       | santa cruz
$AM/Adversários/Petrolina        | petrolina
$AM/Adversários/Torres           | torres
$AM/Adversários/Santa Fé         | santa fe
$AM/Adversários/Geral            | adversario, adversarios
$AM/Wyscout                      | wyplaylist, wyscout, playlist
$EST/Futebol/Vídeos de Referência | barcelona, city, palmeiras, inter vs, ned v jap, cotinthians, corinthians, tactical cam | mov, mp4, m4v
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
mov, mp4, m4v, avi, mkv            | $AM/Cortes de Vídeo
pdf, epub, doc, docx, pptx, ppt    | $EST/A classificar
png, jpg, jpeg, heic, webp, gif    | $HOME/Pictures/Imagens dos Downloads
html, gs, md, txt                  | $DOC/Projetos Claude
"

# Cores das pastas em destaque (1 laranja, 2 vermelho, 3 amarelo, 4 azul, 5 roxo, 6 verde).
DESTAQUES="
$DOC/TCC | 2
$DOC/Scout | 4
$AM | 6
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
SEP=$'\x1f'
NL=$'\n'

normalizar() {
  # O iconv do Mac escreve "ó" como "'o": as marcas são removidas antes do tr.
  echo "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\"^\`~" \
    | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' ' ' | tr -s ' '
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

# Deixa o nome mais legível.
limpar_nome() {
  local n="$1"
  case "$n" in YTDown.com_*) n="$(echo "$n" | sed -E 's/^YTDown\.com_YouTube_//; s/_Media_.*$//; s/-/ /g')" ;; esac
  n="$(echo "$n" | sed -E '
    s/%20/ /g
    s/_+/ /g
    s/^(Cópia|Copia|cópia|copia) de //
    s/^(Copy|copy) of //
    s/^Microsoft (Word|PowerPoint|Excel) - //
    s/ -- [0-9a-f]{32}//g
    s/ -- Anna.s Archive$//
    s/ ?\(Z-Library\)//
    s/[\/:]/-/g
    s/[[:space:]]*\( ?[0-9]+\)//g
    s/[[:space:]]+$//
    s/\.(docx|doc|pdf|png|mov)$//
    s/\.(docx|doc)$//
    s/[[:space:]]+(copy|Copy|COPY|copia|Copia|cópia|Cópia)$//
    s/[[:space:]]+-[[:space:]]*$//
    s/[[:space:]]+/ /g')"
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

iguais() {   # dois arquivos (ou pastas) com o mesmo conteúdo?
  if [ -d "$1" ] && [ -d "$2" ]; then diff -rq "$1" "$2" >/dev/null 2>&1; return; fi
  [ -f "$1" ] && [ -f "$2" ] || return 1
  [ "$(tamanho "$1")" = "$(tamanho "$2")" ] && cmp -s "$1" "$2"
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

# ---------- Monta o plano ----------
PL_ORIG=(); PL_DIR=(); PL_NOME=(); PL_MOTIVO=()
planejar() { PL_ORIG+=("$1"); PL_DIR+=("$2"); PL_NOME+=("$3"); PL_MOTIVO+=("$4"); }

# 1) Pastas antigas de Documentos
while IFS='|' read -r antiga nova; do
  antiga="$(aparar "$antiga")"; nova="$(aparar "$nova")"
  [ -z "$antiga" ] && continue
  [ -d "$antiga" ] && [ ! -e "$nova" ] && planejar "$antiga" "${nova%/*}" "${nova##*/}" "pasta antiga reorganizada"
done <<EOF
$MIGRAR
EOF

# 2) Itens soltos
itens=()
for origem in "${ORIGENS[@]}"; do
  [ -d "$origem" ] || continue
  for f in "$origem"/*; do
    [ -e "$f" ] || continue
    nome="${f##*/}"
    case "$nome" in
      "$ESTE_SCRIPT"|organizar_*.sh|DESFAZER_organizacao_*|PLANO_organizacao_*|lista_finder.txt) continue ;;
      "Duplicados (pode apagar)"|"Instaladores (pode apagar)") continue ;;
      *.download|*.crdownload|*.part|"~\$"*) continue ;;   # download em andamento / arquivo temporário do Word
      *.csv|*.CSV) continue ;;                              # dados do Scout
    esac
    [ -L "$f" ] && continue
    itens+=("$f")
  done
done

if [ ${#itens[@]} -eq 0 ] && [ ${#PL_ORIG[@]} -eq 0 ]; then
  echo "Nada solto para organizar. Já está tudo em ordem!"; exit 0
fi

# Conteúdo dos arquivos pelo Spotlight (só nos Downloads, só regras marcadas com "s").
CONT=()
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

echo "Analisando ${#itens[@]} itens..."
n=0
for item in "${itens[@]}"; do
  n=$((n + 1)); [ $((n % 100)) -eq 0 ] && echo "  ... $n"
  nome="${item##*/}"; dir="${item%/*}"

  if [ -d "$item" ]; then
    case "$nome" in *.app) tipo="app" ;; *) tipo="pasta" ;; esac
    BASE="$nome"; EXT=""
  else
    separar "$nome"; tipo="$(minusculas "${EXT#.}")"
  fi

  # --- Duplicados ---
  dup=""
  if [ "$tipo" = "zip" ] && [ -d "$dir/$BASE" ]; then
    dup="zip já extraído (a pasta \"$BASE\" existe)"
  else
    sem="$(echo "$BASE" | sed -E 's/[[:space:]]*\( ?[0-9]+\)//g; s/ [0-9]$//; s/[[:space:]]+$//')"
    if [ "$sem" != "$BASE" ] && [ -e "$dir/$sem$EXT" ] && iguais "$item" "$dir/$sem$EXT"; then
      dup="cópia idêntica de \"$sem$EXT\""
    fi
  fi
  if [ -n "$dup" ]; then planejar "$item" "$DUPLICADOS" "$nome" "$dup"; continue; fi

  novo_base="$(limpar_nome "$BASE")"
  # Nome sem espaços e comprido (ex.: "8VPm6d5Jqmz3FZd8C8jzVVp") -> título interno do PDF.
  case "$novo_base" in
    *" "*) ;;
    *) if [ "$tipo" = "pdf" ] && [ ${#novo_base} -ge 15 ] && command -v mdls >/dev/null 2>&1; then
         t="$(mdls -raw -name kMDItemTitle "$item" 2>/dev/null)"
         if [ -n "$t" ] && [ "$t" != "(null)" ] && [ ${#t} -le 90 ]; then
           t="$(limpar_nome "$t")"; [ ${#t} -ge 6 ] && novo_base="$t"
         fi
       fi ;;
  esac
  novo="$novo_base$EXT"

  # --- Pontuação ---
  texto=" $(normalizar "$nome $novo_base") "
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
    planejar "$item" "${R_DEST[$melhor]}" "$novo" "${MOT[$melhor]:- tipo .$tipo}"
    continue
  fi
  # Nenhuma regra: destino padrão pelo tipo
  achou=0; r=0
  while [ $r -lt ${#P_DEST[@]} ]; do
    case "${P_TIPOS[$r]}" in *",$tipo,"*)
      planejar "$item" "${P_DEST[$r]}" "$novo" " padrão para .$tipo"; achou=1; break ;;
    esac
    r=$((r + 1))
  done
  [ $achou = 0 ] && planejar "$item" "" "$nome" ""   # fica onde está
done

# ---------- Mostra o plano ----------
{
  echo "PLANO DE ORGANIZAÇÃO — $DATA"
  echo "Nada foi mudado ainda. Volte ao Terminal para confirmar."
  echo
  i=0
  while [ $i -lt ${#PL_ORIG[@]} ]; do
    if [ -n "${PL_DIR[$i]}" ]; then
      d="$(relativo "${PL_DIR[$i]}")"; o="${PL_ORIG[$i]##*/}"
      if [ "$o" = "${PL_NOME[$i]}" ]; then l="$o"; else l="$o   →   ${PL_NOME[$i]}"; fi
      printf '%s\t%s   [%s ]\n' "$d" "$l" "${PL_MOTIVO[$i]# }"
    else
      printf '%s\t%s\n' "~ FICA ONDE ESTÁ (não identifiquei)" "$(relativo "${PL_ORIG[$i]}")"
    fi
    i=$((i + 1))
  done | sort | awk -F'\t' '$1!=g{g=$1; print "\n=== " g " ==="} {print "   " $2}'
} > "$PLANO"

echo
echo "================ RESUMO DO PLANO ================"
i=0
while [ $i -lt ${#PL_ORIG[@]} ]; do
  [ -n "${PL_DIR[$i]}" ] && echo "$(relativo "${PL_DIR[$i]}")" || echo "~ fica onde está"
  i=$((i + 1))
done | sort | uniq -c | sort -rn
echo "================================================="
echo "O plano completo (arquivo por arquivo) está em:"
echo "  $PLANO"
open -e "$PLANO" 2>/dev/null
echo
printf "Aplicar o plano? (s = sim / n = não) "
read -r ok
if [ "$ok" != "s" ] && [ "$ok" != "S" ]; then
  echo "Cancelado. Nada foi alterado. (O arquivo do plano pode ser apagado.)"; exit 0
fi

# ---------- Aplica ----------
# O desfazer precisa voltar os passos na ORDEM INVERSA (ex.: tirar os arquivos de
# "Estudos/Neurociência" antes de devolver a pasta para "NEURO"). Ele é gerado
# no final, ou se o script for interrompido no meio.
PASSOS="$DESFAZER.passos"
: > "$PASSOS"
gerar_desfazer() {
  [ -f "$PASSOS" ] || return
  {
    echo "#!/bin/bash"
    echo "# Desfaz a organização feita em $DATA"
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$PASSOS"
  } > "$DESFAZER"
  rm -f "$PASSOS"
}
trap gerar_desfazer EXIT
movidos=0; renomeados=0; duplicados=0; erros=0
i=0
while [ $i -lt ${#PL_ORIG[@]} ]; do
  orig="${PL_ORIG[$i]}"; dest="${PL_DIR[$i]}"; novo="${PL_NOME[$i]}"
  i=$((i + 1))
  [ -z "$dest" ] && continue
  [ -e "$orig" ] || continue
  # Já existe um arquivo idêntico com esse nome no destino? Então é duplicado.
  if [ "$dest" != "$DUPLICADOS" ] && [ -e "$dest/$novo" ] && iguais "$orig" "$dest/$novo"; then
    dest="$DUPLICADOS"; novo="${orig##*/}"
  fi
  [ -d "$orig" ] && eh=1 || eh=0
  mkdir -p "$dest"
  alvo="$(destino_livre "$dest" "$novo" "$eh")"
  if mv "$orig" "$alvo"; then
    printf 'mkdir -p %q && mv -n %q %q\n' "${orig%/*}" "$alvo" "$orig" >> "$PASSOS"
    if [ "$dest" = "$DUPLICADOS" ]; then duplicados=$((duplicados + 1))
    else
      movidos=$((movidos + 1))
      [ "${alvo##*/}" != "${orig##*/}" ] && renomeados=$((renomeados + 1))
    fi
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
echo "Pronto! $movidos itens organizados ($renomeados renomeados) e $duplicados duplicados separados."
[ $erros -gt 0 ] && echo "Atenção: $erros itens não puderam ser movidos (veja as mensagens acima)."
[ $duplicados -gt 0 ] && echo "Confira \"Downloads/Duplicados (pode apagar)\" e jogue no Lixo se estiver tudo certo."
echo "Para voltar tudo como estava:"
echo "  bash \"$DESFAZER\""
open "$DOC" 2>/dev/null
