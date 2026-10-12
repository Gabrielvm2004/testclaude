#!/bin/bash
# Organiza os Downloads e a Mesa nas suas pastas (América-PE, TCC...) e renomeia.
#
# - Adivinha o assunto de cada arquivo/pasta pelas palavras-chave no NOME e no
#   CONTEÚDO (usa a busca do Spotlight, que lê PDFs, Word, Pages etc.).
# - Sugere uma pasta e um nome mais limpo; você confirma com Enter ou muda.
# - Cópias idênticas de um arquivo vão para "Duplicados (pode apagar)".
# - Nunca apaga nada e nunca sobrescreve (renomeia para "nome (2)" se já existir).
# - Cria um script para DESFAZER tudo.
#
# Como usar (no Terminal):  bash ~/Downloads/organizar_e_renomear.sh

# ======================= CONFIGURE AQUI =======================
# Pastas que serão organizadas:
ORIGENS=("$HOME/Downloads" "$HOME/Desktop")

# Uma regra por linha:
#   Nome | caminho da pasta | palavras-chave (vírgulas) | tipos (opcional)
# - Palavras: com ou sem acento, maiúsculas não importam, comparadas como
#   palavras inteiras ("prova" não pega "comprovante").
# - Tipos: extensões aceitas por essa regra; "pasta" = aceita pastas.
#   Vazio = aceita qualquer arquivo ou pasta.
# - Empate: ganha a regra que aparece primeiro.
AM="$HOME/Documents/América-PE"
REGRAS="
Vídeos de Jogos   | $AM/Vídeos de Jogos | jogo, jogos, amistoso, tempo, retro, sub20, sub 20, sub17, sub 17, sub15, sub 15, profissional, campeonato, copa, rodada, adversario, pressao, bolas paradas, bola parada, c bola, s bola, escanteio, transicao, gol, gols, lances, cortes, compacto, america | mov, mp4, m4v, avi, mkv
Análises          | $AM/Análises        | analise, analises, adversario, scout, retro, sub20, sub 20, sub17, sub 17, pressao, bolas paradas, jogo, amistoso, estatisticas, desempenho | pdf, doc, docx, pages, xls, xlsx, numbers, csv, png, jpg, jpeg, zip, ppt, pptx, key, txt, pasta
Treinos           | $AM/Treinos         | treino, treinos, plano de treino, microciclo, sessao, periodizacao, aquecimento, exercicio, exercicios
Apresentações     | $AM/Apresentações   | slide, slides, deck, apresentacao, principios, modelo de jogo, palestra
Relatórios        | $AM/Relatórios      | relatorio, relatorios, america, america pe, clube
TCC               | $HOME/Documents/TCC | tcc, monografia, orientador, orientadora, banca, abnt, metodologia, referencias, bibliografia
Gravações de Tela | $HOME/Movies/Gravações de Tela  | gravacao de tela
Capturas de Tela  | $HOME/Pictures/Capturas de Tela | captura de tela
Pessoal           | $HOME/Documents/Pessoal | rg, cpf, cnh, comprovante, boleto, extrato, nota fiscal, recibo, imposto, irpf, exame, passagem, reserva
"
# ==============================================================

# Garante que acentos sejam entendidos (o Terminal do Mac já costuma usar UTF-8).
case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in *UTF-8*|*utf8*) ;; *) export LC_ALL=en_US.UTF-8 ;; esac

ESTE_SCRIPT="$(basename "$0")"
DATA="$(date +%Y-%m-%d_%H-%M-%S)"
DESFAZER="$HOME/Downloads/DESFAZER_organizacao_$DATA.sh"
DUPLICADOS="$HOME/Downloads/Duplicados (pode apagar)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Texto sem acento, em minúsculas, só letras/números separados por um espaço.
normalizar() {
  # O iconv do Mac escreve "ó" como "'o": as marcas são removidas antes do tr.
  echo "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\"^\`~" \
    | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' ' ' | tr -s ' '
}

aparar() { echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

minusculas() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# Separa um nome de arquivo em BASE e EXT ("foto.jpg" -> "foto" e ".jpg").
separar() {
  case "$1" in
    ?*.*) BASE="${1%.*}"; EXT=".${1##*.}" ;;
    *)    BASE="$1"; EXT="" ;;
  esac
}

# Deixa o nome mais legível: tira "_", "(1)", "Cópia de", "copy", espaços duplos...
limpar_nome() {
  n="$(echo "$1" | sed -E '
    s/%20/ /g
    s/_+/ /g
    s/^(Cópia|Copia|cópia|copia) de //
    s/^(Copy|copy) of //
    s/^Microsoft (Word|PowerPoint|Excel) - //
    s/[\/:]/-/g
    s/[[:space:]]*\([0-9]+\)$//
    s/[[:space:]]+(copy|Copy|COPY|copia|Copia|cópia|Cópia)$//
    s/[[:space:]]*\([0-9]+\)$//
    s/[[:space:]]+-[[:space:]]*$//
    s/[[:space:]]+/ /g')"
  n="$(aparar "$n")"
  [ -n "$n" ] && echo "$n" || echo "$1"
}

# Caminho livre: "foto.jpg", "foto (2).jpg", "foto (3).jpg"...
destino_livre() {
  dir="$1"; nome="$2"; eh_pasta="$3"
  if [ ! -e "$dir/$nome" ]; then echo "$dir/$nome"; return; fi
  if [ "$eh_pasta" = 1 ]; then b="$nome"; e=""; else separar "$nome"; b="$BASE"; e="$EXT"; fi
  k=2
  while [ -e "$dir/$b ($k)$e" ]; do k=$((k + 1)); done
  echo "$dir/$b ($k)$e"
}

# ---------- Lê as regras ----------
NOMES=(); CAMINHOS=(); PALAVRAS=(); TIPOS=()
while IFS='|' read -r nome caminho palavras tipos; do
  nome="$(aparar "$nome")"
  [ -z "$nome" ] && continue
  NOMES+=("$nome")
  CAMINHOS+=("$(aparar "$caminho")")
  PALAVRAS+=("$palavras")
  TIPOS+=(",$(minusculas "$tipos" | tr -d ' '),")
done <<EOF
$REGRAS
EOF

# ---------- Junta os itens soltos de cada origem ----------
itens=()
for origem in "${ORIGENS[@]}"; do
  [ -d "$origem" ] || continue
  for f in "$origem"/*; do
    [ -e "$f" ] || continue
    nome="$(basename "$f")"
    [ "$nome" = "$ESTE_SCRIPT" ] && continue
    [ "$f" = "$DUPLICADOS" ] && continue
    case "$nome" in
      DESFAZER_organizacao_*.sh|organizar_*.sh) continue ;;
      *.download|*.crdownload|*.part) continue ;;   # download em andamento
      *.app) continue ;;                            # programas
    esac
    [ -L "$f" ] && continue                         # atalhos ficam onde estão
    [ -f "$f" ] || [ -d "$f" ] || continue
    itens+=("$f")
  done
done

if [ ${#itens[@]} -eq 0 ]; then
  echo "Nada solto para organizar. Já está tudo em ordem!"
  exit 0
fi

# ---------- Busca pelo CONTEÚDO com o Spotlight ----------
if command -v mdfind >/dev/null 2>&1; then
  echo "Lendo o conteúdo dos arquivos (pode levar alguns segundos)..."
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    : > "$TMP/conteudo_$i"
    IFS=',' read -r -a lista <<< "${PALAVRAS[$i]}"
    for p in "${lista[@]}"; do
      p="$(aparar "$p")"; [ -z "$p" ] && continue
      for origem in "${ORIGENS[@]}"; do
        [ -d "$origem" ] || continue
        mdfind -onlyin "$origem" "kMDItemTextContent == \"$p\"cdw" >> "$TMP/conteudo_$i" 2>/dev/null
      done
    done
    i=$((i + 1))
  done
fi

# Escolhe a regra com mais pontos: palavra no nome = 3, no conteúdo = 1.
# $1 = caminho do item, $2 = nome sugerido (pode vir do título interno do PDF).
sugerir_pasta() {
  item="$1"; nome="$(basename "$item")"
  nome_norm=" $(normalizar "$nome $2") "
  if [ -d "$item" ]; then tipo="pasta"; else separar "$nome"; tipo="$(minusculas "${EXT#.}")"; fi
  SUGESTAO=-1; melhor_pts=0; MOTIVO=""
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    if [ "${TIPOS[$i]}" != ",," ]; then
      case "${TIPOS[$i]}" in *",$tipo,"*) ;; *) i=$((i + 1)); continue ;; esac
    fi
    pts=0; achou=""
    IFS=',' read -r -a lista <<< "${PALAVRAS[$i]}"
    for p in "${lista[@]}"; do
      p="$(aparar "$(normalizar "$p")")"; [ -z "$p" ] && continue
      case "$nome_norm" in *" $p "*) pts=$((pts + 3)); achou="$achou \"$p\"" ;; esac
    done
    if [ -s "$TMP/conteudo_$i" ]; then
      c=$(grep -Fxc "$item" "$TMP/conteudo_$i")
      [ "$c" -gt 0 ] && { pts=$((pts + c)); achou="$achou (+conteúdo do arquivo)"; }
    fi
    if [ $pts -gt $melhor_pts ]; then SUGESTAO=$i; melhor_pts=$pts; MOTIVO="$achou"; fi
    i=$((i + 1))
  done
}

sugerir_nome() {
  item="$1"; nome="$(basename "$item")"
  if [ -d "$item" ]; then BASE="$nome"; EXT=""; else separar "$nome"; fi
  limpo="$(limpar_nome "$BASE")"
  # Nome sem espaços e comprido (ex.: "a8f9e7d1c2b3d4") -> tenta o título interno do PDF/Word.
  case "$limpo" in
    *" "*) ;;
    *) if [ ! -d "$item" ] && [ ${#limpo} -ge 15 ] && command -v mdls >/dev/null 2>&1; then
         t="$(mdls -raw -name kMDItemTitle "$item" 2>/dev/null)"
         if [ -n "$t" ] && [ "$t" != "(null)" ] && [ ${#t} -le 80 ]; then
           t="$(limpar_nome "${t%.*}")"
           [ ${#t} -ge 4 ] && limpo="$t"
         fi
       fi ;;
  esac
  echo "$limpo$EXT"
}

mostrar_pastas() {
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    echo "      $((i + 1))) ${NOMES[$i]}"
    i=$((i + 1))
  done
  echo "      0) deixar onde está"
}

# Move registrando no script de desfazer. Se já existe um arquivo IDÊNTICO no
# destino com o mesmo nome, manda para "Duplicados (pode apagar)".
mover() {
  origem_item="$1"; destino_dir="$2"; novo="$3"
  DUPLICADO=0
  if [ -f "$origem_item" ] && [ -f "$destino_dir/$novo" ] && cmp -s "$origem_item" "$destino_dir/$novo"; then
    destino_dir="$DUPLICADOS"; DUPLICADO=1
  fi
  [ -d "$origem_item" ] && eh_pasta=1 || eh_pasta=0
  mkdir -p "$destino_dir"
  ALVO="$(destino_livre "$destino_dir" "$novo" "$eh_pasta")"
  mv "$origem_item" "$ALVO" || return 1
  printf 'mv -n %q %q\n' "$ALVO" "$origem_item" >> "$DESFAZER"
}

echo "#!/bin/bash" > "$DESFAZER"
echo "# Desfaz a organização feita em $DATA" >> "$DESFAZER"

echo
echo "Encontrei ${#itens[@]} itens soltos. Vou mostrar um por um."
echo "Em cada pergunta, aperte Enter para aceitar a sugestão."
echo "Digite  t  para aceitar TODAS as sugestões que faltam, ou  q  para parar."

movidos=0; renomeados=0; duplicados=0; automatico=0; total=${#itens[@]}; num=0
for item in "${itens[@]}"; do
  num=$((num + 1))
  [ -e "$item" ] || continue
  atual="$(basename "$item")"; dir_atual="$(dirname "$item")"
  novo="$(sugerir_nome "$item")"
  sugerir_pasta "$item" "$novo"

  if [ $automatico -eq 1 ]; then
    [ $SUGESTAO -lt 0 ] && continue   # sem sugestão: fica onde está
    escolha=$((SUGESTAO + 1))
  else
    echo
    [ -d "$item" ] && tipo_txt="pasta" || tipo_txt="arquivo"
    echo "[$num/$total]  $atual   ($tipo_txt em $(basename "$dir_atual"))"
    if [ $SUGESTAO -ge 0 ]; then
      echo "   Parece ser: ${NOMES[$SUGESTAO]}   (achei:$MOTIVO)"
      padrao=$((SUGESTAO + 1))
    else
      echo "   Não consegui identificar o assunto."
      padrao=0
    fi
    mostrar_pastas
    read -r -p "   Pasta [$padrao]: " escolha
    case "$escolha" in
      q|Q) break ;;
      t|T) automatico=1; escolha=$padrao ;;
      "")  escolha=$padrao ;;
    esac
    case "$escolha" in *[!0-9]*) echo "   Opção inválida, pulei."; continue ;; esac
    if [ "$escolha" -gt ${#NOMES[@]} ]; then echo "   Opção inválida, pulei."; continue; fi

    if [ $automatico -eq 0 ]; then
      read -r -p "   Nome [$novo]: " digitado
      case "$digitado" in
        q|Q) break ;;
        "") ;;
        *) digitado="$(echo "$digitado" | sed 's/[\/:]/-/g')"
           if [ -d "$item" ]; then novo="$digitado"
           else
             separar "$atual"
             case "$(minusculas "$digitado")" in
               *"$(minusculas "$EXT")") novo="$digitado" ;;
               *) novo="$digitado$EXT" ;;
             esac
           fi ;;
      esac
    fi
  fi

  if [ "$escolha" -eq 0 ]; then destino_dir="$dir_atual"; else destino_dir="${CAMINHOS[$((escolha - 1))]}"; fi
  [ "$destino_dir" = "$dir_atual" ] && [ "$novo" = "$atual" ] && continue   # nada muda

  if mover "$item" "$destino_dir" "$novo"; then
    if [ $DUPLICADO -eq 1 ]; then
      duplicados=$((duplicados + 1)); onde="Duplicados (pode apagar)"
      [ $automatico -eq 0 ] && echo "   Já existe uma cópia idêntica lá -> foi para Duplicados (pode apagar)"
    else
      [ "$destino_dir" != "$dir_atual" ] && movidos=$((movidos + 1))
      [ "$(basename "$ALVO")" != "$atual" ] && renomeados=$((renomeados + 1))
      [ "$escolha" -eq 0 ] && onde="$(basename "$dir_atual")" || onde="${NOMES[$((escolha - 1))]}"
    fi
    [ $automatico -eq 1 ] && echo "  $atual  ->  $onde/$(basename "$ALVO")"
  fi
done

echo
echo "Pronto! $movidos itens movidos, $renomeados renomeados e $duplicados cópias repetidas separadas."
[ $duplicados -gt 0 ] && echo "Confira a pasta \"Duplicados (pode apagar)\" em Downloads e jogue no Lixo se estiver tudo certo."
echo "Se quiser voltar tudo como estava, rode:"
echo "  bash \"$DESFAZER\""
