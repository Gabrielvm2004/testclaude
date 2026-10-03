# Scout pós-jogo — América FC

Atalhos de teclado que gravam eventos do jogo num CSV, lendo o **tempo do vídeo** (YouTube no Chrome ou QuickTime).

> **Pronto:** atalho **⌃⌥3 – Finalização nossa** (Etapa 1) e a **página de resumo** (`resumo.html`).
> **Falta:** os outros atalhos, a amostra de posse e o "Novo jogo" (Etapa 2).

## Como funciona

- Cada atalho é uma **Ação Rápida do Automator** de uma linha que chama o script central `sistema/scout.applescript`.
- O script vê qual app está na frente:
  - **Chrome:** lê o tempo do vídeo do YouTube da aba ativa. Se estiver passando anúncio, avisa e não grava.
  - **QuickTime:** ignora gravações de tela e vídeos com menos de 5 minutos. Usa o vídeo que estiver tocando; se nenhum estiver tocando, usa o que está mais na frente.
- Grava uma linha em `Documentos/Scout/<jogo>.csv`:

  ```
  evento,segundos_video,tempo,origem,horario
  finalizacao_nossa,1234.5,1,youtube,2026-10-03 20:15:02
  ```

  `tempo` é 1 ou 2, conforme o último início de tempo marcado (⌃⌥7/⌃⌥8, na Etapa 2). Por isso funciona com o 1º e o 2º tempo em **vídeos separados**.
- **Som "Tink"** = gravou. **Som grave + notificação** = **não** gravou (a notificação diz o motivo).

### Por que Automator e não o app Atalhos?
No Monterey, o app Atalhos é a primeira versão: em Mac Intel ele demora 1 a 2 s para disparar e às vezes o atalho de teclado não funciona. A Ação Rápida do Automator é mais leve, roda dentro do app que está na frente (Chrome/QuickTime, sem trocar de janela) e é mais madura.

---

## Instalação — Etapa 1 (passo a passo)

### Passo 1 — Baixar os arquivos
1. No GitHub, abra o repositório, troque para o branch **`claude/vibrant-archimedes-2l7l6r`** e clique em **Code → Download ZIP**.
2. Abra o ZIP (duplo clique) na pasta **Transferências**.

### Passo 2 — Colocar o script no lugar
1. No Finder, abra **Documentos** e crie uma pasta chamada **`Scout`** (com S maiúsculo).
2. Dentro de `Scout`, crie uma pasta chamada **`sistema`**.
3. Copie o arquivo **`scout/sistema/scout.applescript`** (do ZIP) para **`Documentos/Scout/sistema/`**.

O caminho final deve ser: `Documentos/Scout/sistema/scout.applescript`.

### Passo 3 — Criar a Ação Rápida "Scout – Finalização nossa"
1. Abra o **Automator** (Aplicativos → Automator).
2. Clique em **Novo Documento** → escolha **Ação Rápida** → **Escolher**.
3. No topo da área da direita, ajuste:
   - **Fluxo de trabalho recebe:** `nenhuma entrada`
   - **em:** `qualquer aplicativo`
4. Na coluna da esquerda, na busca, digite **`AppleScript`** e arraste **Executar AppleScript** para a área da direita.
5. Apague todo o texto que aparece na caixa e cole exatamente isto:

   ```applescript
   on run {input, parameters}
   	set scout to (POSIX path of (path to documents folder)) & "Scout/sistema/scout.applescript"
   	run script ((POSIX file scout) as alias) with parameters {"finalizacao_nossa"}
   	return input
   end run
   ```

6. Clique no martelo (**Compilar**). O texto deve ficar colorido, sem erro.
7. **Arquivo → Salvar…** com o nome **`Scout – Finalização nossa`**.
8. Feche o Automator.

### Passo 4 — Liberar o JavaScript no Chrome (só uma vez)
1. Abra o **Google Chrome**.
2. Na barra de menus: **Visualizar → Desenvolvedor → Permitir JavaScript de Eventos Apple**.
3. Confirme que ficou com um ✓ ao lado.

### Passo 5 — Configurar o atalho ⌃⌥3
1. Abra **Preferências do Sistema → Teclado → aba Atalhos**.
2. Na lista da esquerda, clique em **Serviços**.
3. Role a lista da direita até a seção **Geral** e encontre **Scout – Finalização nossa**.
4. Dê duplo clique em **nenhum** (ou em **adicionar atalho**) ao lado do nome.
5. Aperte **Control + Option + 3** (⌃⌥3). Deve aparecer `^⌥3`.
6. Feche as Preferências.

### Passo 6 — Primeiro teste e permissões
As permissões aparecem **na primeira vez** que o atalho roda. Clique **OK / Permitir** em todas.

**Teste no YouTube:**
1. Abra um jogo no YouTube, no Chrome, e deixe tocando (sem anúncio).
2. Com o Chrome na frente, aperte **⌃⌥3**.
3. Se aparecer *"… deseja controlar o Google Chrome"* → **OK**. Se aparecer pedido de acesso à pasta **Documentos** → **OK**.
4. Aperte **⌃⌥3** de novo. Deve tocar o **"Tink"**.

**Teste no QuickTime** (antes, troque de jogo como explicado em "Trocar de jogo" abaixo, porque não dá para misturar YouTube e QuickTime no mesmo jogo):
1. Abra o vídeo no QuickTime e, com ele na frente, aperte **⌃⌥3**.
2. Aceite o pedido para controlar o **QuickTime Player** → **OK**.

**Conferir o resultado:** abra `Documentos/Scout/teste_<data>.csv` no TextEdit ou no Numbers. Deve haver uma linha `finalizacao_nossa` com o tempo do vídeo em segundos.

> Na Etapa 1, como ainda não existe a ação "Novo jogo", o primeiro registro cria sozinho o arquivo `teste_<data>.csv`. A coluna `tempo` fica vazia até a Etapa 2 (⌃⌥7/⌃⌥8).

### Trocar de jogo (só na Etapa 1)
Renomeie (ou apague) o arquivo `Documentos/Scout/teste_<data>.csv`, por exemplo para `teste_youtube.csv`. O próximo registro cria um `teste_<data>.csv` novo. Na Etapa 2 isso vira o atalho **⌃⌥9 – Novo jogo**.

---

## Se algo não funcionar

| O que acontece | O que fazer |
|---|---|
| Nada acontece ao apertar ⌃⌥3 | Teste pelo menu: **Chrome → Serviços → Scout – Finalização nossa**. Se pelo menu funcionar, o problema é o atalho: refaça o Passo 5 ou use **⌃⌥⌘3**. |
| O item não aparece em Serviços | No Automator, confira o Passo 3, item 3 ("nenhuma entrada" em "qualquer aplicativo"). |
| Notificação "O Chrome bloqueou a leitura do tempo" | Refaça o Passo 4. |
| Som grave sem notificação | Libere as notificações: **Preferências do Sistema → Notificações**, procure **Automator** / **Editor de Script** / **WorkflowServiceRunner** e permita. |
| Cliquei "Não permitir" sem querer | **Preferências do Sistema → Segurança e Privacidade → Privacidade → Automação**: marque o Chrome / QuickTime / Eventos do Sistema sob o app que aparecer na lista. Em **Arquivos e Pastas**, libere **Documentos**. |
| Acentos estranhos nas notificações | Me avise: só muda a forma como o script é carregado. |

## Onde mudar as configurações
No começo do `scout.applescript`, na seção **CONFIGURAÇÕES**: nome da pasta, duração mínima do vídeo no QuickTime e os sons. Depois de editar, não precisa mexer no Automator.

---

## Página de resumo (`resumo.html`)

1. Dê duplo clique em **`scout/resumo.html`** (abre no Chrome ou no Safari, funciona sem internet). Se quiser, copie o arquivo para `Documentos/Scout/`.
2. Arraste o CSV do jogo para a área tracejada (ou clique nela para escolher o arquivo).
3. Confira os campos **Adversário / Data / Categoria / Mando**. Eles vêm do nome do arquivo (`AAAA-MM-DD_Categoria_Adversário_Mando.csv`) e podem ser corrigidos ali mesmo.
4. Leia a caixa laranja **"Confira antes de usar os números"**, se aparecer. Ela avisa sobre:
   - dois "ganhamos" seguidos, ou "perdemos" sem "ganhamos" (a posse errada é ignorada);
   - posse com mais de 3 min (entra no cálculo, mas é sinalizada);
   - o mesmo evento marcado duas vezes quase no mesmo lance;
   - mistura de YouTube e QuickTime, ou falta de ⌃⌥7/⌃⌥8.
5. Botões:
   - **Copiar para o Claude Design:** copia o texto pronto (instrução fixa do card + dados do jogo). Abra o Claude Design e cole com **⌘V**.
   - **Baixar CSV de resumo (Google Sheets):** baixa uma linha por jogo. No Sheets: **Arquivo → Importar → Fazer upload** → escolha **Anexar à planilha atual**. Assim cada jogo vira uma linha e dá para comparar.

Para testar sem jogo real, use o exemplo `scout/exemplo/2026-10-03_Profissional_Santa Cruz_Casa.csv`.

### Mudar o padrão do card do Claude Design
Abra `resumo.html` no **TextEdit**. No topo, em **CONFIGURAÇÕES**, edite o texto entre crases (`` ` ``) de `INSTRUCAO_CLAUDE_DESIGN`. `<janela>` vira automaticamente a duração da amostra (ex.: 15). Ali também ficam o limite de "posse suspeita" (180 s) e o de "registro repetido" (2 s).

> No TextEdit, use **Formatar → Converter em Texto Simples** se aparecer formatação, e salve sem mudar a extensão `.html`.

## Formato do CSV (para referência)

| evento | significado |
|---|---|
| `janela_amostra` | duração da amostra em segundos (gravada pelo "Novo jogo") |
| `inicio_1t` / `inicio_2t` | início do 1º / 2º tempo |
| `ganhamos_posse` / `perdemos_posse` | início / fim de uma posse (só na amostra) |
| `finalizacao_nossa` / `finalizacao_concedida` | finalizações |
| `subida_pressao` | subida de pressão |
| `corrida_para_tras` | corrida para trás da defesa |
