#!/bin/bash
# Organiza a pasta Downloads do Mac em subpastas por tipo de arquivo.
# - Primeiro mostra o que vai fazer e pede confirmação.
# - Nunca apaga nada e nunca sobrescreve arquivos (renomeia se já existir).
# - Cria um script para DESFAZER tudo, caso você não goste do resultado.
#
# Como usar (no Terminal):  bash ~/Downloads/organizar_downloads.sh

PASTA="$HOME/Downloads"
ESTE_SCRIPT="$(basename "$0")"
DATA="$(date +%Y-%m-%d_%H-%M-%S)"
DESFAZER="$PASTA/DESFAZER_organizacao_$DATA.sh"

categoria() {
  ext="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    pdf)                                         echo "PDFs" ;;
    jpg|jpeg|png|gif|heic|webp|tif|tiff|bmp|svg) echo "Imagens" ;;
    doc|docx|pages|txt|rtf|odt|md)               echo "Documentos de Texto" ;;
    xls|xlsx|numbers|csv|ods)                    echo "Planilhas" ;;
    ppt|pptx|key|odp)                            echo "Apresentacoes" ;;
    mp4|mov|avi|mkv|m4v|wmv|webm)                echo "Videos" ;;
    mp3|wav|m4a|aac|flac|ogg)                    echo "Audios" ;;
    zip|rar|7z|tar|gz|tgz)                       echo "Compactados" ;;
    dmg|pkg|mpkg)                                echo "Instaladores (pode apagar)" ;;
    *)                                           echo "Outros" ;;
  esac
}

# Devolve um caminho livre: "foto.jpg", "foto (2).jpg", "foto (3).jpg"...
destino_livre() {
  dir="$1"; nome="$2"
  if [ ! -e "$dir/$nome" ]; then echo "$dir/$nome"; return; fi
  base="${nome%.*}"; ext="${nome##*.}"
  [ "$base" = "$nome" ] && ext="" || ext=".$ext"
  n=2
  while [ -e "$dir/$base ($n)$ext" ]; do n=$((n + 1)); done
  echo "$dir/$base ($n)$ext"
}

cd "$PASTA" || { echo "Não encontrei a pasta $PASTA"; exit 1; }

# Junta só os ARQUIVOS soltos (pastas e arquivos ocultos ficam onde estão).
arquivos=()
for f in *; do
  [ -f "$f" ] || continue
  [ "$f" = "$ESTE_SCRIPT" ] && continue
  case "$f" in DESFAZER_organizacao_*.sh) continue ;; esac
  case "$f" in *.download|*.crdownload|*.part) continue ;; esac  # download em andamento
  arquivos+=("$f")
done

if [ ${#arquivos[@]} -eq 0 ]; then
  echo "Nenhum arquivo solto em Downloads. Já está organizado!"
  exit 0
fi

echo "=== PRÉVIA: ${#arquivos[@]} arquivos serão movidos dentro de Downloads ==="
echo
for f in "${arquivos[@]}"; do
  case "$f" in *.*) ext="${f##*.}" ;; *) ext="" ;; esac
  echo "$(categoria "$ext")"
done | sort | uniq -c | sort -rn
echo
printf "Quer ver a lista completa de arquivos? (s/n) "
read -r ver
if [ "$ver" = "s" ] || [ "$ver" = "S" ]; then
  for f in "${arquivos[@]}"; do
    case "$f" in *.*) ext="${f##*.}" ;; *) ext="" ;; esac
    echo "  $f  ->  $(categoria "$ext")/"
  done
  echo
fi

printf "Pode organizar? (s/n) "
read -r ok
if [ "$ok" != "s" ] && [ "$ok" != "S" ]; then
  echo "Cancelado. Nada foi alterado."
  exit 0
fi

echo "#!/bin/bash" > "$DESFAZER"
echo "# Desfaz a organização feita em $DATA" >> "$DESFAZER"

movidos=0
for f in "${arquivos[@]}"; do
  case "$f" in *.*) ext="${f##*.}" ;; *) ext="" ;; esac
  cat_dir="$PASTA/$(categoria "$ext")"
  mkdir -p "$cat_dir"
  alvo="$(destino_livre "$cat_dir" "$f")"
  if mv "$f" "$alvo"; then
    printf 'mv -n %q %q\n' "$alvo" "$PASTA/$f" >> "$DESFAZER"
    movidos=$((movidos + 1))
  fi
done

echo
echo "Pronto! $movidos arquivos organizados."
echo "Se quiser voltar tudo como estava, rode:"
echo "  bash \"$DESFAZER\""
open "$PASTA" 2>/dev/null
