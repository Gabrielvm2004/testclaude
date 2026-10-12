#!/bin/bash
# Lê os PDFs de Estudos e anota título, autor e o começo da 1ª página de cada um,
# para depois sugerir nomes melhores (TÍTULO - Autor (Ano)).
#
# NÃO MUDA NADA: só cria o arquivo "artigos_info.tsv" na Mesa.
#
# Como usar (no Terminal):  bash ~/Downloads/extrair_artigos.sh
# Outra pasta (opcional):    bash ~/Downloads/extrair_artigos.sh ~/Documents/TCC

PASTA="${1:-$HOME/Documents/Estudos}"
SAIDA="$HOME/Desktop/artigos_info.tsv"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

find "$PASTA" -type f -iname '*.pdf' -not -path '*/.*' | sort > "$TMPD/lista"
total=$(wc -l < "$TMPD/lista" | tr -d ' ')
if [ "$total" = 0 ]; then echo "Nenhum PDF em $PASTA"; exit 1; fi
echo "Lendo $total PDFs em $PASTA (leva alguns minutos)..."

# O Mac já vem com o PDFKit; o JavaScript do osascript usa ele para ler os PDFs.
cat > "$TMPD/ler.js" <<'JXA'
ObjC.import('Foundation');
ObjC.import('PDFKit');

function texto(obj) {
  if (!obj || obj.isNil()) return '';
  try { return String(ObjC.unwrap(obj)); } catch (e) { return ''; }
}
function limpa(s) {
  return String(s || '').replace(/[\t\r\n  ]+/g, ' | ').replace(/\s+/g, ' ').trim();
}

function run(argv) {
  var lista = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null));
  var casa = argv[2] + '/';
  var arquivos = lista.split('\n').filter(function (p) { return p.length > 0; });
  var linhas = ['n\tarquivo\ttitulo_pdf\tautor_pdf\tdata_pdf\tpaginas\ttexto_inicio'];

  for (var i = 0; i < arquivos.length; i++) {
    var p = arquivos[i], tit = '', aut = '', dat = '', pags = '', txt = '';
    try {
      var doc = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(p));
      if (doc && !doc.isNil()) {
        var a = doc.documentAttributes;
        if (a && !a.isNil()) {
          tit = texto(a.objectForKey('Title'));
          aut = texto(a.objectForKey('Author'));
          var d = a.objectForKey('CreationDate');
          if (d && !d.isNil()) dat = texto(d.description);
        }
        pags = doc.pageCount;
        for (var k = 0; k < Math.min(2, pags) && txt.length < 900; k++) {
          var pg = doc.pageAtIndex(k);
          if (pg && !pg.isNil()) txt += ' ' + texto(pg.string);
        }
      } else {
        txt = '(não abriu)';
      }
    } catch (e) {
      txt = '(erro: ' + e + ')';
    }
    linhas.push([i + 1, p.replace(casa, ''), limpa(tit), limpa(aut), limpa(dat), pags,
                 limpa(txt).slice(0, 900)].join('\t'));
    if ((i + 1) % 50 === 0) console.log('  ... ' + (i + 1) + ' de ' + arquivos.length);
  }

  $(linhas.join('\n') + '\n').writeToFileAtomicallyEncodingError(argv[1], true, $.NSUTF8StringEncoding, null);
  return 'Pronto! ' + arquivos.length + ' PDFs lidos. Arquivo criado na Mesa: artigos_info.tsv';
}
JXA

osascript -l JavaScript "$TMPD/ler.js" "$TMPD/lista" "$SAIDA" "$HOME"
[ -s "$SAIDA" ] && open -R "$SAIDA"
