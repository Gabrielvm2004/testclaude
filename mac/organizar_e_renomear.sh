#!/bin/bash
# Organiza os Downloads nas SUAS pastas (TCC, Trabalho...) e renomeia os arquivos.
#
# - Adivinha o assunto de cada arquivo pelas palavras-chave no NOME e no
#   CONTEÚDO (usa a busca do Spotlight, que lê PDFs, Word, Pages etc.).
# - Sugere uma pasta e um nome mais limpo; você confirma com Enter ou muda.
# - Nunca apaga nada e nunca sobrescreve (renomeia para "nome (2)" se já existir).
# - Cria um script para DESFAZER tudo.
#
# Como usar (no Terminal):  bash ~/Downloads/organizar_e_renomear.sh

# ======================= CONFIGURE AQUI =======================
# Uma pasta por linha:  Nome | caminho da pasta | palavras-chave separadas por vírgula
# As palavras podem ter ou não acento; maiúsculas não importam.
REGRAS="
TCC       | $HOME/Documents/TCC       | tcc, monografia, orientador, orientadora, banca, abnt, metodologia, referencias, bibliografia, artigo, resumo, abstract, capitulo, introducao, conclusao, revisao, pesquisa, questionario, entrevista
Trabalho  | $HOME/Documents/Trabalho  | trabalho, contrato, proposta, reuniao, cliente, relatorio, fatura, orcamento, apresentacao, planejamento, holerite, curriculo, empresa, projeto
Faculdade | $HOME/Documents/Faculdade | aula, prova, lista, exercicio, disciplina, professor, slides, apostila, ementa, matricula, historico, semestre, atividade
Pessoal   | $HOME/Documents/Pessoal   | rg, cpf, cnh, comprovante, boleto, extrato, nota fiscal, recibo, conta, imposto, irpf, saude, exame, receita, passagem, reserva
"
# ==============================================================

# Garante que acentos sejam entendidos (o Terminal do Mac já costuma usar UTF-8).
case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in *UTF-8*|*utf8*) ;; *) export LC_ALL=en_US.UTF-8 ;; esac

PASTA="$HOME/Downloads"
ESTE_SCRIPT="$(basename "$0")"
DATA="$(date +%Y-%m-%d_%H-%M-%S)"
DESFAZER="$PASTA/DESFAZER_organizacao_$DATA.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Texto sem acento, em minúsculas e só com letras/números.
normalizar() {
  # O iconv do Mac escreve "ó" como "'o": as marcas são removidas antes do tr.
  echo "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\"^\`~" \
    | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' ' '
}

aparar() { echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# Deixa o nome mais legível: tira "_", "(1)", "copy", espaços duplos...
limpar_nome() {
  n="$(echo "$1" | sed -E '
    s/%20/ /g
    s/_+/ /g
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
  dir="$1"; nome="$2"
  if [ ! -e "$dir/$nome" ]; then echo "$dir/$nome"; return; fi
  base="${nome%.*}"; ext="${nome##*.}"
  [ "$base" = "$nome" ] && ext="" || ext=".$ext"
  n=2
  while [ -e "$dir/$base ($n)$ext" ]; do n=$((n + 1)); done
  echo "$dir/$base ($n)$ext"
}

# ---------- Lê as regras ----------
NOMES=(); CAMINHOS=(); PALAVRAS=()
while IFS='|' read -r nome caminho palavras; do
  nome="$(aparar "$nome")"
  [ -z "$nome" ] && continue
  NOMES+=("$nome")
  CAMINHOS+=("$(aparar "$caminho")")
  PALAVRAS+=("$palavras")
done <<EOF
$REGRAS
EOF

cd "$PASTA" || { echo "Não encontrei a pasta $PASTA"; exit 1; }

# ---------- Junta os arquivos soltos ----------
arquivos=()
for f in *; do
  [ -f "$f" ] || continue
  [ "$f" = "$ESTE_SCRIPT" ] && continue
  case "$f" in
    DESFAZER_organizacao_*.sh|organizar_*.sh) continue ;;
    *.download|*.crdownload|*.part) continue ;;  # download em andamento
  esac
  arquivos+=("$f")
done

if [ ${#arquivos[@]} -eq 0 ]; then
  echo "Nenhum arquivo solto em Downloads. Já está organizado!"
  exit 0
fi

# ---------- Busca pelo CONTEÚDO com o Spotlight ----------
# Gera, para cada pasta i, o arquivo $TMP/conteudo_i com os arquivos que citam
# alguma das palavras-chave dela.
if command -v mdfind >/dev/null 2>&1; then
  echo "Lendo o conteúdo dos arquivos (pode levar alguns segundos)..."
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    : > "$TMP/conteudo_$i"
    IFS=',' read -r -a lista <<< "${PALAVRAS[$i]}"
    for p in "${lista[@]}"; do
      p="$(aparar "$p")"; [ -z "$p" ] && continue
      mdfind -onlyin "$PASTA" "kMDItemTextContent == \"$p\"cdw" >> "$TMP/conteudo_$i" 2>/dev/null
    done
    i=$((i + 1))
  done
fi

# Escolhe a pasta com mais pontos: palavra no nome = 3, no conteúdo = 1 por palavra.
sugerir_pasta() {
  # $2 = nome sugerido (pode vir do título interno do PDF), também é analisado.
  f="$1"; nome_norm=" $(normalizar "$f $2" | tr -s ' ') "  # compara palavras inteiras
  melhor=-1; melhor_pts=0; MOTIVO=""
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    pts=0; achou=""
    IFS=',' read -r -a lista <<< "${PALAVRAS[$i]}"
    for p in "${lista[@]}"; do
      p="$(aparar "$(normalizar "$p" | tr -s ' ')")"; [ -z "$p" ] && continue
      case "$nome_norm" in *" $p "*) pts=$((pts + 3)); achou="$achou \"$p\"" ;; esac
    done
    if [ -s "$TMP/conteudo_$i" ]; then
      c=$(grep -Fxc "$PASTA/$f" "$TMP/conteudo_$i")
      [ "$c" -gt 0 ] && { pts=$((pts + c)); achou="$achou (+conteúdo do arquivo)"; }
    fi
    if [ $pts -gt $melhor_pts ]; then melhor=$i; melhor_pts=$pts; MOTIVO="$achou"; fi
    i=$((i + 1))
  done
  SUGESTAO=$melhor
}

sugerir_nome() {
  f="$1"
  case "$f" in *.*) base="${f%.*}"; ext=".${f##*.}" ;; *) base="$f"; ext="" ;; esac
  limpo="$(limpar_nome "$base")"
  # Nome sem espaços e comprido (ex.: "a8f9e7d1c2b3d4") -> tenta o título interno do PDF/Word.
  case "$limpo" in
    *" "*) ;;
    *) if [ ${#limpo} -ge 15 ] && command -v mdls >/dev/null 2>&1; then
         t="$(mdls -raw -name kMDItemTitle "$f" 2>/dev/null)"
         if [ -n "$t" ] && [ "$t" != "(null)" ] && [ ${#t} -le 80 ]; then
           t="$(limpar_nome "${t%.*}")"
           [ ${#t} -ge 4 ] && limpo="$t"
         fi
       fi ;;
  esac
  echo "$limpo$ext"
}

mostrar_pastas() {
  i=0
  while [ $i -lt ${#NOMES[@]} ]; do
    echo "      $((i + 1))) ${NOMES[$i]}"
    i=$((i + 1))
  done
  echo "      0) deixar em Downloads"
}

echo "#!/bin/bash" > "$DESFAZER"
echo "# Desfaz a organização feita em $DATA" >> "$DESFAZER"

echo
echo "Encontrei ${#arquivos[@]} arquivos em Downloads. Vou mostrar um por um."
echo "Em cada pergunta, aperte Enter para aceitar a sugestão."
echo "Digite  t  para aceitar TODAS as sugestões que faltam, ou  q  para parar."

movidos=0; renomeados=0; automatico=0; total=${#arquivos[@]}; n=0
for f in "${arquivos[@]}"; do
  n=$((n + 1))
  novo="$(sugerir_nome "$f")"
  sugerir_pasta "$f" "$novo"

  if [ $automatico -eq 1 ]; then
    [ $SUGESTAO -lt 0 ] && continue   # sem sugestão: fica em Downloads
    escolha=$((SUGESTAO + 1))
  else
    echo
    echo "[$n/$total]  $f"
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
           case "$f" in *.*) ext=".${f##*.}" ;; *) ext="" ;; esac
           e1="$(echo "$digitado" | tr '[:upper:]' '[:lower:]')"
           e2="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
           case "$e1" in *"$e2") novo="$digitado" ;; *) novo="$digitado$ext" ;; esac ;;
      esac
    fi
  fi

  if [ "$escolha" -eq 0 ]; then
    destino_dir="$PASTA"
  else
    destino_dir="${CAMINHOS[$((escolha - 1))]}"
    mkdir -p "$destino_dir"
  fi

  [ "$destino_dir" = "$PASTA" ] && [ "$novo" = "$f" ] && continue   # nada muda
  alvo="$(destino_livre "$destino_dir" "$novo")"
  if mv "$f" "$alvo"; then
    printf 'mv -n %q %q\n' "$alvo" "$PASTA/$f" >> "$DESFAZER"
    [ "$destino_dir" != "$PASTA" ] && movidos=$((movidos + 1))
    [ "$(basename "$alvo")" != "$f" ] && renomeados=$((renomeados + 1))
    if [ $automatico -eq 1 ]; then
      [ "$escolha" -eq 0 ] && onde="Downloads" || onde="${NOMES[$((escolha - 1))]}"
      echo "  $f  ->  $onde/$(basename "$alvo")"
    fi
  fi
done

echo
echo "Pronto! $movidos arquivos movidos e $renomeados renomeados."
echo "Se quiser voltar tudo como estava, rode:"
echo "  bash \"$DESFAZER\""
