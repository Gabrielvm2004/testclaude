#!/bin/bash
# =====================================================================
# Instalador do Scout — América FC
# Dê duplo clique neste arquivo (ou: botão direito → Abrir).
# Pode rodar quantas vezes quiser: ele sempre deixa tudo atualizado.
# =====================================================================

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCOUT="$HOME/Documents/Scout"
SERVICOS="$HOME/Library/Services"
LISTA="$AQUI/servicos/atalhos.txt"

DEU_CERTO=()
FALTA=()

titulo() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()     { printf '  ✅ %s\n' "$1"; DEU_CERTO+=("$1"); }
falha()  { printf '  ⚠️  %s\n' "$1"; FALTA+=("$1"); }

titulo "Instalador do Scout — América FC"

# ---------- 0. Conferir se os arquivos do ZIP estão aqui ----------
if [ ! -f "$AQUI/sistema/scout.applescript" ] || [ ! -f "$LISTA" ]; then
	echo "Não encontrei os arquivos do Scout ao lado do instalador."
	echo "Rode o instalador de dentro da pasta 'scout' do ZIP, sem mover só ele."
	osascript -e 'display dialog "Não encontrei os arquivos do Scout. Rode o instalador de dentro da pasta \"scout\" do ZIP, sem tirar ele de lá." buttons {"OK"} with title "Scout" with icon caution' >/dev/null 2>&1
	exit 1
fi

# ---------- 1. Tirar o bloqueio de "arquivo baixado da internet" ----------
titulo "1. Liberando os arquivos baixados"
if xattr -dr com.apple.quarantine "$AQUI" 2>/dev/null; then
	ok "Bloqueio de arquivo baixado removido."
else
	ok "Arquivos já estavam liberados."
fi

# ---------- 2. Script central ----------
titulo "2. Script central"
mkdir -p "$SCOUT/sistema"
obs=""
if [ -f "$SCOUT/sistema/scout.applescript" ]; then
	cp "$SCOUT/sistema/scout.applescript" "$SCOUT/sistema/scout.applescript.anterior"
	obs=" (o antigo ficou como scout.applescript.anterior)"
fi
if cp "$AQUI/sistema/scout.applescript" "$SCOUT/sistema/scout.applescript"; then
	ok "scout.applescript copiado para Documentos/Scout/sistema$obs."
else
	falha "Não consegui copiar o scout.applescript para Documentos/Scout/sistema."
fi

# Página de resumo: substitui pela versão nova (a antiga fica como resumo.anterior.html).
obs=""
if [ -f "$SCOUT/resumo.html" ] && ! cmp -s "$AQUI/resumo.html" "$SCOUT/resumo.html"; then
	cp "$SCOUT/resumo.html" "$SCOUT/resumo.anterior.html"
	obs=" (a antiga ficou como resumo.anterior.html)"
fi
cp "$AQUI/resumo.html" "$SCOUT/resumo.html" && ok "resumo.html atualizado em Documentos/Scout$obs."
rm -f "$SCOUT/resumo (nova versao).html"

# Sobra da antiga amostra de 15 min (não é mais usada).
rm -f "$SCOUT/.amostra_avisada"

# ---------- 3. Ações Rápidas ----------
titulo "3. Ações Rápidas (atalhos)"
mkdir -p "$SERVICOS"

# As Ações Rápidas antigas, criadas à mão ("Scout – ..."), vão para o Lixo.
antigas=0
for w in "$SERVICOS"/Scout\ –\ *.workflow "$SERVICOS"/Scout\ -\ *.workflow; do
	[ -e "$w" ] || continue
	mv "$w" "$HOME/.Trash/" 2>/dev/null || rm -rf "$w"
	antigas=$((antigas + 1))
done
[ "$antigas" -gt 0 ] && ok "$antigas Ação(ões) Rápida(s) antiga(s) 'Scout – ...' movida(s) para o Lixo."

# Ações Rápidas de versões anteriores deste instalador que mudaram de nome
# (ex.: "Scout 1 - Ganhamos posse" virou "Scout 1 - Posse nossa") são removidas,
# para não disputarem o mesmo atalho com as novas.
REMOVIDAS=()
for w in "$SERVICOS"/Scout\ [0-9]\ -\ *.workflow; do
	[ -e "$w" ] || continue
	nome="$(basename "$w" .workflow)"
	if ! cut -f2 "$LISTA" | grep -qxF "$nome"; then
		rm -rf "$w"
		REMOVIDAS+=("$nome")
	fi
done
[ ${#REMOVIDAS[@]} -gt 0 ] && ok "Removidas as ações de nome antigo: ${REMOVIDAS[*]}."

instaladas=0
while IFS=$'\t' read -r tecla nome; do
	[ -n "$nome" ] || continue
	origem="$AQUI/servicos/$nome.workflow"
	destino="$SERVICOS/$nome.workflow"
	if ! plutil -lint -s "$origem/Contents/Info.plist" "$origem/Contents/document.wflow" >/dev/null 2>&1; then
		falha "Arquivo com defeito: $nome (não instalado)."
		continue
	fi
	rm -rf "$destino"
	if cp -R "$origem" "$destino"; then
		xattr -dr com.apple.quarantine "$destino" 2>/dev/null
		instaladas=$((instaladas + 1))
	else
		falha "Não consegui copiar: $nome."
	fi
done < "$LISTA"
[ "$instaladas" -gt 0 ] && ok "$instaladas Ações Rápidas instaladas em ~/Library/Services."

# ---------- 4. Atalhos de teclado (⌃⌥0 a ⌃⌥9) ----------
# Grava os atalhos nas preferências de Serviços do Mac ("pbs").
# É o mesmo lugar onde Preferências do Sistema → Teclado → Atalhos → Serviços grava.
titulo "4. Atalhos de teclado"
PASTA_TMP="$(mktemp -d)"
TMP="$PASTA_TMP/pbs.plist"
if ! defaults export pbs "$TMP" 2>/dev/null || ! plutil -lint -s "$TMP" >/dev/null 2>&1; then
	cat > "$TMP" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
fi
plutil -insert NSServicesStatus -json '{}' "$TMP" 2>/dev/null

# Tira os atalhos das ações de nome antigo.
for nome in "${REMOVIDAS[@]}"; do
	plutil -remove "NSServicesStatus.(null) - $nome - runWorkflowAsService" "$TMP" >/dev/null 2>&1
done

atalhos_ok=1
while IFS=$'\t' read -r tecla nome; do
	[ -n "$nome" ] || continue
	chave="NSServicesStatus.(null) - $nome - runWorkflowAsService"
	valor='{"enabled_context_menu":true,"enabled_services_menu":true,"key_equivalent":"^~'"$tecla"'","presentation_modes":{"ContextMenu":true,"ServicesMenu":true}}'
	plutil -remove "$chave" "$TMP" >/dev/null 2>&1
	plutil -insert "$chave" -json "$valor" "$TMP" >/dev/null 2>&1 || atalhos_ok=0
done < "$LISTA"

if [ "$atalhos_ok" = 1 ] && defaults import pbs "$TMP" 2>/dev/null; then
	# Conferência: os atalhos estão gravados?
	gravados=$(defaults read pbs NSServicesStatus 2>/dev/null | grep -cE 'key_equivalent"? = "\^~[0-9]"')
	if [ "$gravados" -ge 10 ]; then
		ok "Atalhos ⌃⌥0 a ⌃⌥9 gravados."
	else
		atalhos_ok=0
	fi
else
	atalhos_ok=0
fi
rm -rf "$PASTA_TMP"
[ "$atalhos_ok" = 1 ] || falha "Não consegui gravar os atalhos sozinho: configure à mão (veja o LEIA-ME, Passo 4)."

# Avisa o Mac para recarregar a lista de Serviços.
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1
/System/Library/CoreServices/pbs -update >/dev/null 2>&1

# ---------- 5. Resumo final ----------
titulo "Pronto!"
mensagem="DEU CERTO:"
for item in "${DEU_CERTO[@]}"; do mensagem+=$'\n'"• $item"; done
if [ ${#FALTA[@]} -gt 0 ]; then
	mensagem+=$'\n\n'"PRECISA DE ATENÇÃO:"
	for item in "${FALTA[@]}"; do mensagem+=$'\n'"• $item"; done
fi
mensagem+=$'\n\n'"O QUE FAZER AGORA:"
mensagem+=$'\n'"1. Saia e entre de novo na sua conta do Mac (menu  → Encerrar Sessão), para os atalhos passarem a valer."
mensagem+=$'\n'"2. Confira em Preferências do Sistema → Teclado → Atalhos → Serviços: os 10 'Scout 0' a 'Scout 9' devem estar marcados, com ^⌥0 a ^⌥9."
mensagem+=$'\n'"3. Na primeira vez que usar cada app (Chrome e QuickTime), aceite os pedidos de permissão (OK)."

echo "$mensagem"

# Janela com o resumo (o texto vai por arquivo, para os acentos saírem certos).
ARQ_MSG="$(mktemp -d)/mensagem.txt"
printf '%s' "$mensagem" > "$ARQ_MSG"
resposta=$(SCOUT_ARQ="$ARQ_MSG" osascript \
	-e 'set m to read (POSIX file (system attribute "SCOUT_ARQ")) as «class utf8»' \
	-e 'button returned of (display dialog m buttons {"Abrir Atalhos do Teclado", "OK"} default button "OK" with title "Scout — instalação")' 2>/dev/null)
if [ "$resposta" = "Abrir Atalhos do Teclado" ]; then
	open "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
fi

echo
echo "Pode fechar esta janela do Terminal."
