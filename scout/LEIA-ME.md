# Scout pós-jogo — América FC

Atalhos de teclado que gravam eventos do jogo num CSV, lendo o **tempo do vídeo** (YouTube no Chrome ou QuickTime), e uma página que monta a tabela do jogo.

## Os atalhos

| Atalho | Evento | Quando usar |
|---|---|---|
| ⌃⌥9 | **Novo jogo** | antes de começar (pergunta adversário, data, categoria e mando) |
| ⌃⌥7 | Início do 1º tempo | no apito inicial, no vídeo do 1º tempo |
| ⌃⌥8 | Início do 2º tempo | no apito inicial, no vídeo do 2º tempo |
| ⌃⌥1 | Ganhamos a posse | só na amostra (0–15' de cada tempo) |
| ⌃⌥2 | Perdemos a posse | só na amostra |
| ⌃⌥3 | Finalização nossa | jogo inteiro |
| ⌃⌥4 | Finalização concedida | jogo inteiro |
| ⌃⌥5 | Subida de pressão | jogo inteiro |
| ⌃⌥6 | Corrida para trás da defesa | jogo inteiro |
| ⌃⌥0 | Desfazer último registro | quando errar a tecla |

**Confirmação:** som **"Tink"** + aviso **"Scout ✓"** no canto da tela = gravou. Som grave + aviso **"Scout – nada gravado"** = não gravou (o aviso diz o motivo).

## Como funciona

- Cada atalho é uma **Ação Rápida do Automator** de uma linha que chama o script central `Documentos/Scout/sistema/scout.applescript`.
- O script vê qual app está na frente:
  - **Chrome:** lê o tempo do vídeo do YouTube da aba ativa. Se estiver passando anúncio, avisa e não grava.
  - **QuickTime:** ignora gravações de tela e vídeos com menos de 5 minutos. Usa o vídeo que estiver tocando; se nenhum estiver tocando, usa o que está mais na frente.
- **1º e 2º tempo em vídeos separados:** cada registro grava se é do 1º ou do 2º tempo (coluna `tempo`), conforme o último ⌃⌥7/⌃⌥8 marcado. Por isso não importa que o tempo do vídeo recomece no 2º tempo.
- **Amostra de posse:** ⌃⌥1 e ⌃⌥2 só gravam entre o início do tempo (⌃⌥7/⌃⌥8) e +15 min **de vídeo**. Fora disso, avisa "Fora da amostra".
  - Exceção: um ⌃⌥2 logo depois da janela é aceito se fecha uma posse que começou dentro dela.
  - No primeiro atalho que você apertar depois da janela, aparece o aviso "Amostra do 1º tempo encerrada" (uma vez por tempo).
- **Regras de segurança:**
  - ⌃⌥3 a ⌃⌥6 só gravam depois do ⌃⌥7. Se você esquecer, o aviso lembra.
  - O script não deixa misturar YouTube e QuickTime no mesmo jogo.
  - O ⌃⌥0 apaga a última linha do CSV (nunca o cabeçalho).

### Por que Automator e não o app Atalhos?
No Monterey, o app Atalhos é a primeira versão: em Mac Intel ele demora 1 a 2 s para disparar e às vezes o atalho de teclado não funciona. A Ação Rápida do Automator é mais leve, roda dentro do app que está na frente (Chrome/QuickTime, sem trocar de janela) e é mais madura.

---

## Instalação (passo a passo)

> **Se você já fez a Etapa 1:** pule os Passos 3 a 5 da primeira instalação. Faça só o **Passo 1** (baixar de novo), o **Passo 2** (substituir o script) e depois o **Passo 6** em diante.

### Passo 1 — Baixar os arquivos
1. No GitHub, abra o repositório, troque para o branch **`claude/vibrant-archimedes-2l7l6r`** e clique em **Code → Download ZIP**.
2. Abra o ZIP (duplo clique) na pasta **Transferências**.

### Passo 2 — Colocar o script no lugar
1. No Finder, abra **Documentos**. Se ainda não existir, crie a pasta **`Scout`** e, dentro dela, a pasta **`sistema`**.
2. Copie o arquivo **`scout/sistema/scout.applescript`** (do ZIP) para **`Documentos/Scout/sistema/`**. Se perguntar, escolha **Substituir**.
3. Copie também **`scout/resumo.html`** para **`Documentos/Scout/`** (é a página do resumo).

### Passo 3 — Criar a primeira Ação Rápida (Finalização nossa)
*(Já feito na Etapa 1? Pule para o Passo 6.)*
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

### Passo 4 — Liberar o JavaScript no Chrome (só uma vez)
1. Abra o **Google Chrome**.
2. Na barra de menus: **Visualizar → Desenvolvedor → Permitir JavaScript de Eventos Apple**.
3. Confirme que ficou com um ✓ ao lado.

### Passo 5 — Atalho da primeira ação
Veja o Passo 7 (é igual para todas as ações).

### Passo 6 — Criar as outras 9 Ações Rápidas (duplicando)
Todas são iguais à primeira; só muda **uma palavra** (o evento entre aspas) e o nome.

1. No Automator, abra **Arquivo → Abrir Recente → Scout – Finalização nossa**.
   (Se não aparecer: **Arquivo → Abrir…**, aperte **⌘⇧G**, digite `~/Library/Services` e abra **Scout – Finalização nossa.workflow**.)
2. **Arquivo → Duplicar** (⌘⇧S). Abre uma cópia.
3. Na cópia, troque **só** o texto entre aspas em `{"finalizacao_nossa"}` pelo evento da tabela abaixo. Mantenha as aspas.
4. Clique no martelo (**Compilar**).
5. **Arquivo → Salvar…** com o nome da tabela. Feche a cópia (⌘W).
6. Repita os itens 2 a 5 para cada linha:

| Nome para salvar | Texto entre aspas | Atalho |
|---|---|---|
| `Scout – Ganhamos a posse` | `ganhamos_posse` | ⌃⌥1 |
| `Scout – Perdemos a posse` | `perdemos_posse` | ⌃⌥2 |
| `Scout – Finalização nossa` *(já existe)* | `finalizacao_nossa` | ⌃⌥3 |
| `Scout – Finalização concedida` | `finalizacao_concedida` | ⌃⌥4 |
| `Scout – Subida de pressão` | `subida_pressao` | ⌃⌥5 |
| `Scout – Corrida para trás` | `corrida_para_tras` | ⌃⌥6 |
| `Scout – Início do 1º tempo` | `inicio_1t` | ⌃⌥7 |
| `Scout – Início do 2º tempo` | `inicio_2t` | ⌃⌥8 |
| `Scout – Novo jogo` | `novo_jogo` | ⌃⌥9 |
| `Scout – Desfazer` | `desfazer` | ⌃⌥0 |

> Digite o texto entre aspas **exatamente** como na tabela: sem acento, com `_`. Se errar, o atalho avisa "Evento desconhecido".

### Passo 7 — Configurar os atalhos de teclado
1. Abra **Preferências do Sistema → Teclado → aba Atalhos**.
2. Na lista da esquerda, clique em **Serviços**.
3. Role a lista da direita até a seção **Geral**: as 10 ações **Scout – …** estão lá.
4. Para cada uma: dê duplo clique em **nenhum** (ou **adicionar atalho**) ao lado do nome e aperte a combinação da tabela (ex.: **Control + Option + 1**). Deve aparecer `^⌥1`.
5. Confira se todas as 10 estão **marcadas** (caixinha à esquerda do nome).
6. Feche as Preferências.

### Passo 8 — Permitir os avisos na tela (Notificações)
Na Etapa 1 não apareceu nenhum aviso. Para garantir que apareçam:
1. Aperte qualquer atalho Scout uma vez com o Chrome na frente (ex.: ⌃⌥9 e depois **Cancelar**).
2. Abra **Preferências do Sistema → Notificações e Foco → aba Notificações**.
3. Na lista da esquerda, procure **Automator**, **Editor de Script**, **WorkflowServiceRunner** ou **Google Chrome** (o que aparecer).
4. Ative **Permitir Notificações** e escolha o estilo **Faixas**.
5. Confira também se o **Foco / Não Perturbe** está desligado (ícone da lua na barra de menus).

> Se mesmo assim nenhum aviso aparecer, o **som** continua confirmando: "Tink" = gravou, som grave = não gravou. Me conte, que trocamos o aviso por outro tipo.

### Passo 9 — Teste completo (5 minutos)
1. Abra um jogo no **YouTube** (Chrome) e deixe tocando.
2. **⌃⌥9** → digite o adversário → **OK** → confira a data → **OK** → escolha a categoria → **OK** → escolha o mando → **OK**. Deve tocar o "Tink" e aparecer "Jogo: América x …".
3. **⌃⌥3** → deve avisar *"Marque antes o início do 1º tempo"* (som grave).
4. **⌃⌥7** → "Tink" + "Início do 1º tempo — Amostra de posse: próximos 15 min de vídeo".
5. **⌃⌥1**, espere uns segundos, **⌃⌥2** → dois "Tink".
6. **⌃⌥5** e depois **⌃⌥0** → "Desfeito: Subida de pressão".
7. Avance o vídeo para **depois** dos 15 min da amostra e aperte **⌃⌥1** → *"Fora da amostra"*.
8. Aperte **⌃⌥3** → grava e avisa *"Amostra do 1º tempo encerrada"*.
9. Abra `Documentos/Scout/resumo.html` e arraste o CSV do jogo (está em `Documentos/Scout/`).

**Teste no QuickTime:** faça um **⌃⌥9** novo (outro adversário, ex.: "Teste QT"), abra um vídeo do jogo no QuickTime, deixe ele na frente e repita os passos 4 a 6. Na primeira vez, aceite o pedido para controlar o **QuickTime Player** → **OK**. Depois, faça uma gravação de tela curta, deixe ela aberta no QuickTime e aperte **⌃⌥3** com o jogo pausado: o tempo gravado deve ser o do jogo, não o da gravação.

---

## Se algo não funcionar

| O que acontece | O que fazer |
|---|---|
| Nada acontece ao apertar um atalho | Teste pelo menu: **Chrome → Serviços → Scout – …**. Se pelo menu funcionar, o problema é o atalho: refaça o Passo 7 ou use **⌃⌥⌘** + número. |
| A ação não aparece em Serviços | No Automator, confira o Passo 3, item 3 ("nenhuma entrada" em "qualquer aplicativo"). |
| "Evento desconhecido" | O texto entre aspas da Ação Rápida está diferente da tabela do Passo 6. |
| "O Chrome bloqueou a leitura do tempo" | Refaça o Passo 4. |
| "Nenhum jogo aberto" | Comece com **⌃⌥9**. |
| As perguntas do ⌃⌥9 não aparecem ou ficam atrás | Clique no ícone do Chrome no Dock e tente de novo; me avise se continuar. |
| Cliquei "Não permitir" sem querer | **Preferências do Sistema → Segurança e Privacidade → Privacidade → Automação**: marque o Chrome / QuickTime sob o app que aparecer na lista. Em **Arquivos e Pastas**, libere **Documentos**. |
| Acentos estranhos nos avisos | Me avise: só muda a forma como o script é carregado. |

## Onde mudar as configurações
No começo do `Documentos/Scout/sistema/scout.applescript`, na seção **CONFIGURAÇÕES**:
- **`JANELA_AMOSTRA_MIN`** (15): duração da amostra de posse. Mude só se for mudar para todos os jogos dali em diante. Cada jogo grava no próprio CSV a janela que usou.
- `AVISO_NA_TELA`: `false` deixa só o som quando grava (os avisos de erro continuam).
- Nome da pasta, duração mínima do vídeo no QuickTime e os sons.

Para editar: clique com o botão direito no arquivo → **Abrir com → Editor de Script**, mude o valor e salve (⌘S). Não precisa mexer no Automator.

---

## Página de resumo (`resumo.html`)

1. Dê duplo clique em **`Documentos/Scout/resumo.html`** (abre no Chrome ou no Safari, funciona sem internet).
2. Arraste o CSV do jogo para a área tracejada (ou clique nela para escolher o arquivo).
3. Confira os campos **Adversário / Data / Categoria / Mando**. Eles vêm do nome do arquivo criado pelo ⌃⌥9 e podem ser corrigidos ali mesmo.
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
O texto fica no topo do `resumo.html`, em **CONFIGURAÇÕES**, entre crases (`` ` ``), em `INSTRUCAO_CLAUDE_DESIGN`. `<janela>` vira automaticamente a duração da amostra (ex.: 15). Ali também ficam o limite de "posse suspeita" (180 s) e o de "registro repetido" (2 s).

Para editar com o **TextEdit** sem estragar o arquivo:
1. Abra o **TextEdit → Preferências → aba Abrir e Salvar** e marque **"Exibir arquivos HTML como código HTML em vez de texto formatado"**. Isso só precisa ser feito uma vez.
2. Clique com o botão direito em `resumo.html` → **Abrir com → TextEdit**.
3. Edite só o texto entre as crases e salve (⌘S).

## Formato do CSV (para referência)

Arquivo: `Documentos/Scout/AAAA-MM-DD_Categoria_Adversário_Mando.csv`

```
evento,segundos_video,tempo,origem,horario
janela_amostra,900,,,2026-10-03 20:00:00
inicio_1t,62.0,1,youtube,2026-10-03 20:01:00
finalizacao_nossa,130.2,1,youtube,2026-10-03 20:02:00
```

| evento | significado |
|---|---|
| `janela_amostra` | duração da amostra em segundos (gravada pelo ⌃⌥9) |
| `inicio_1t` / `inicio_2t` | início do 1º / 2º tempo |
| `ganhamos_posse` / `perdemos_posse` | início / fim de uma posse (só na amostra) |
| `finalizacao_nossa` / `finalizacao_concedida` | finalizações |
| `subida_pressao` | subida de pressão |
| `corrida_para_tras` | corrida para trás da defesa |
