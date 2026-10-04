# Scout pós-jogo — América FC

Atalhos de teclado que gravam eventos do jogo num CSV, lendo o **tempo do vídeo** (YouTube no Chrome ou QuickTime), e uma página que monta a tabela do jogo.

## Os atalhos

| Atalho | Evento | Quando usar |
|---|---|---|
| ⌃⌥9 | **Novo jogo** | antes de começar (pergunta adversário, data, categoria e mando) |
| ⌃⌥7 | Início do 1º tempo | no apito inicial, no vídeo do 1º tempo |
| ⌃⌥8 | Início do 2º tempo | no apito inicial, no vídeo do 2º tempo |
| ⌃⌥1 | Ganhamos a posse | início de uma posse que você escolheu marcar (jogo inteiro) |
| ⌃⌥2 | Perdemos a posse | fim dessa posse |
| ⌃⌥3 | Finalização nossa | jogo inteiro |
| ⌃⌥4 | Finalização concedida | jogo inteiro |
| ⌃⌥5 | Subida de pressão | jogo inteiro |
| ⌃⌥6 | Corrida para trás da defesa | jogo inteiro |
| ⌃⌥0 | Desfazer último registro | quando errar a tecla |

**Confirmação:** som **"Tink"** + aviso **"Scout ✓"** no canto da tela = gravou. Som grave + aviso **"Scout – nada gravado"** = não gravou (o aviso diz o motivo).

## Como funciona

- Cada atalho é uma **Ação Rápida do Automator** (`~/Library/Services/Scout N - ….workflow`) de uma linha que chama o script central `Documentos/Scout/sistema/scout.applescript`. O instalador coloca tudo no lugar.
- O script vê qual app está na frente:
  - **Chrome:** lê o tempo do vídeo do YouTube da aba ativa. Se estiver passando anúncio, avisa e não grava.
  - **QuickTime:** ignora gravações de tela e vídeos com menos de 5 minutos. Usa o vídeo que estiver tocando; se nenhum estiver tocando, usa o que está mais na frente.
- **1º e 2º tempo em vídeos separados:** cada registro grava se é do 1º ou do 2º tempo (coluna `tempo`), conforme o último ⌃⌥7/⌃⌥8 marcado. Por isso não importa que o tempo do vídeo recomece no 2º tempo.
- **Posses marcadas:** você escolhe quais posses marcar (as principais), em qualquer momento do jogo, depois do ⌃⌥7/⌃⌥8. Marque ⌃⌥1 quando a posse começa e ⌃⌥2 quando termina.
  - Se apertar ⌃⌥1 com uma posse ainda aberta, ou ⌃⌥2 sem posse aberta, grava, mas avisa na hora. A página do resumo ignora a posse com sequência errada.
- **Regras de segurança:**
  - ⌃⌥3 a ⌃⌥6 só gravam depois do ⌃⌥7. Se você esquecer, o aviso lembra.
  - O script não deixa misturar YouTube e QuickTime no mesmo jogo.
  - O ⌃⌥0 apaga a última linha do CSV (nunca o cabeçalho).

### Por que Automator e não o app Atalhos?
No Monterey, o app Atalhos é a primeira versão: em Mac Intel ele demora 1 a 2 s para disparar e às vezes o atalho de teclado não funciona. A Ação Rápida do Automator é mais leve, roda dentro do app que está na frente (Chrome/QuickTime, sem trocar de janela) e é mais madura.

---

## Instalação (passo a passo)

O instalador faz quase tudo sozinho: copia o script, instala as 10 Ações Rápidas e configura os atalhos ⌃⌥0 a ⌃⌥9. Você só baixa, dá duplo clique e reinicia a sessão.

### Passo 1 — Baixar o ZIP
1. No GitHub, abra o repositório e troque para o branch **`claude/vibrant-archimedes-2l7l6r`** (botão com o nome do branch, em cima da lista de arquivos).
2. Clique no botão verde **Code** → **Download ZIP**.
3. Abra a pasta **Transferências** e dê **duplo clique** no ZIP. Aparece uma pasta com o mesmo nome.
4. Entre nessa pasta e depois na pasta **`scout`**.

### Passo 2 — Rodar o instalador
1. Dê **duplo clique** em **`Instalar Scout.command`**.
2. Abre uma janela do **Terminal** (fundo branco ou preto, com texto). Não precisa digitar nada.
3. Em poucos segundos aparece uma janela **"Scout — instalação"** com o que deu certo e o que fazer. Leia e clique **OK**.

**Se o Mac disser que o arquivo é de "desenvolvedor não identificado"** (ou que "não pode ser aberto"):
1. Clique em **OK** (ou **Cancelar**) nesse aviso.
2. Clique no `Instalar Scout.command` com o **botão direito** (ou Control + clique) → **Abrir**.
3. Aparece o aviso de novo, agora com o botão **Abrir**. Clique em **Abrir**.

Se ainda assim não abrir:
1. Abra **Preferências do Sistema → Segurança e Privacidade → aba Geral**.
2. Embaixo aparece *"O 'Instalar Scout.command' foi bloqueado…"*. Clique em **Abrir Mesmo Assim** e confirme.

**Plano C (sempre funciona):**
1. Abra o **Terminal** (Aplicativos → Utilitários → Terminal).
2. Digite `bash` e **um espaço** (não aperte Enter ainda).
3. Arraste o arquivo `Instalar Scout.command` do Finder para dentro da janela do Terminal.
4. Aperte **Enter**.

> Pode rodar o instalador quantas vezes quiser. Toda vez que eu mandar uma versão nova, é só baixar o ZIP e rodar de novo.

### Passo 3 — Sair e entrar de novo na sessão
Para o Mac reconhecer os atalhos novos: menu  (maçã) → **Encerrar Sessão de Gabriel…** → entre de novo com sua senha. Reiniciar o Mac também serve.

### Passo 4 — Conferir os atalhos
1. Abra **Preferências do Sistema → Teclado → aba Atalhos → Serviços** (na lista da esquerda).
2. Role a lista da direita até a seção **Geral**. Devem estar lá, **marcados**:

| Ação Rápida | Atalho |
|---|---|
| Scout 0 - Desfazer | ^⌥0 |
| Scout 1 - Ganhamos posse | ^⌥1 |
| Scout 2 - Perdemos posse | ^⌥2 |
| Scout 3 - Finalizacao nossa | ^⌥3 |
| Scout 4 - Finalizacao concedida | ^⌥4 |
| Scout 5 - Subida de pressao | ^⌥5 |
| Scout 6 - Corrida para tras | ^⌥6 |
| Scout 7 - Inicio 1o tempo | ^⌥7 |
| Scout 8 - Inicio 2o tempo | ^⌥8 |
| Scout 9 - Novo jogo | ^⌥9 |

3. **Se algum estiver sem atalho:** dê duplo clique em **nenhum** (ou **adicionar atalho**) ao lado do nome e aperte a combinação (ex.: **Control + Option + 1**).
4. **Se algum estiver desmarcado:** marque a caixinha à esquerda do nome.

> **Por que os nomes não têm acento?** O instalador configura os atalhos pelo nome de cada ação. Sem acento, esse nome é sempre o mesmo e não há risco de o atalho não "pegar".

### Passo 5 — Liberar o JavaScript no Chrome (só uma vez; você já fez)
No Chrome: **Visualizar → Desenvolvedor → Permitir JavaScript de Eventos Apple** (deve ficar com ✓).

### Passo 6 — Permitir os avisos na tela (Notificações)
1. Aperte um atalho Scout uma vez com o Chrome na frente (ex.: ⌃⌥9 e depois **Cancelar**).
2. Abra **Preferências do Sistema → Notificações e Foco → aba Notificações**.
3. Na lista da esquerda, procure **Automator**, **Editor de Script**, **WorkflowServiceRunner** ou **Google Chrome** (o que aparecer).
4. Ative **Permitir Notificações** e escolha o estilo **Faixas**.
5. Confira também se o **Foco / Não Perturbe** está desligado (ícone da lua na barra de menus).

> Se mesmo assim nenhum aviso aparecer, o **som** continua confirmando: "Tink" = gravou, som grave = não gravou. Me conte, que trocamos o aviso por outro tipo.

### Passo 7 — Teste completo (5 minutos)
1. Abra um jogo no **YouTube** (Chrome) e deixe tocando.
2. **⌃⌥9** → digite o adversário → **OK** → confira a data → **OK** → escolha a categoria → **OK** → escolha o mando → **OK**. Deve tocar o "Tink" e aparecer "Jogo: América x …".
3. **⌃⌥3** → deve avisar *"Marque antes o início do 1º tempo"* (som grave).
4. **⌃⌥7** → "Tink" + "Início do 1º tempo".
5. **⌃⌥1**, espere uns segundos, **⌃⌥2** → dois "Tink".
6. **⌃⌥5** e depois **⌃⌥0** → "Desfeito: Subida de pressão".
7. Avance o vídeo para qualquer ponto do jogo e aperte **⌃⌥1** duas vezes seguidas → a segunda avisa *"a posse anterior não foi fechada"*. Feche com **⌃⌥2**.
8. Abra `Documentos/Scout/resumo.html` e arraste o CSV do jogo (está em `Documentos/Scout/`).

**Teste no QuickTime:** faça um **⌃⌥9** novo (outro adversário, ex.: "Teste QT"), abra um vídeo do jogo no QuickTime, deixe ele na frente e repita os passos 4 a 6. Na primeira vez, aceite o pedido para controlar o **QuickTime Player** → **OK**. Depois, faça uma gravação de tela curta, deixe ela aberta no QuickTime e aperte **⌃⌥3** com o jogo pausado: o tempo gravado deve ser o do jogo, não o da gravação.

---

## Se algo não funcionar

| O que acontece | O que fazer |
|---|---|
| Nada acontece ao apertar um atalho | Encerre a sessão e entre de novo (Passo 3). Depois teste pelo menu: **Chrome → Serviços → Scout 3 - …**. Se pelo menu funcionar, o problema é o atalho: confira o Passo 4. |
| As ações não aparecem em Serviços | Rode o instalador de novo e encerre a sessão. Se continuar, me mande a mensagem final do instalador. |
| "O Chrome bloqueou a leitura do tempo" | Refaça o Passo 4. |
| "Nenhum jogo aberto" | Comece com **⌃⌥9**. |
| As perguntas do ⌃⌥9 não aparecem ou ficam atrás | Clique no ícone do Chrome no Dock e tente de novo; me avise se continuar. |
| Cliquei "Não permitir" sem querer | **Preferências do Sistema → Segurança e Privacidade → Privacidade → Automação**: marque o Chrome / QuickTime sob o app que aparecer na lista. Em **Arquivos e Pastas**, libere **Documentos**. |
| Acentos estranhos nos avisos | Me avise: só muda a forma como o script é carregado. |

## Onde mudar as configurações
No começo do `Documentos/Scout/sistema/scout.applescript`, na seção **CONFIGURAÇÕES**:
- `AVISO_NA_TELA`: `false` deixa só o som quando grava (os avisos de erro continuam).
- Nome da pasta, duração mínima do vídeo no QuickTime e os sons.

Para editar: clique com o botão direito no arquivo → **Abrir com → Editor de Script**, mude o valor e salve (⌘S). Não precisa mexer no Automator.

> Atenção: rodar o instalador de novo substitui o script pela versão do ZIP (a sua fica salva como `scout.applescript.anterior`). Se mudar alguma configuração, me avise para eu deixar igual na próxima versão.

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
O texto fica no topo do `resumo.html`, em **CONFIGURAÇÕES**, entre crases (`` ` ``), em `INSTRUCAO_CLAUDE_DESIGN`. `<posses>` vira automaticamente o número de posses marcadas. Ali também ficam o limite de "posse suspeita" (180 s) e o de "registro repetido" (2 s).

Para editar com o **TextEdit** sem estragar o arquivo:
1. Abra o **TextEdit → Preferências → aba Abrir e Salvar** e marque **"Exibir arquivos HTML como código HTML em vez de texto formatado"**. Isso só precisa ser feito uma vez.
2. Clique com o botão direito em `resumo.html` → **Abrir com → TextEdit**.
3. Edite só o texto entre as crases e salve (⌘S).

## Formato do CSV (para referência)

Arquivo: `Documentos/Scout/AAAA-MM-DD_Categoria_Adversário_Mando.csv`

```
evento,segundos_video,tempo,origem,horario
inicio_1t,62.0,1,youtube,2026-10-03 20:01:00
finalizacao_nossa,130.2,1,youtube,2026-10-03 20:02:00
```

| evento | significado |
|---|---|
| `janela_amostra` | só em jogos antigos (época da amostra de 15 min); é ignorada |
| `inicio_1t` / `inicio_2t` | início do 1º / 2º tempo |
| `ganhamos_posse` / `perdemos_posse` | início / fim de uma posse marcada |
| `finalizacao_nossa` / `finalizacao_concedida` | finalizações |
| `subida_pressao` | subida de pressão |
| `corrida_para_tras` | corrida para trás da defesa |

## Para quem for mexer no código

- `sistema/scout.applescript`: toda a lógica dos atalhos.
- `servicos/`: as 10 Ações Rápidas. Elas são **geradas** por `ferramentas/gerar_workflows.py` (`python3 scout/ferramentas/gerar_workflows.py`). Para mudar nomes ou atalhos, edite a lista `ATALHOS` lá e gere de novo.
- `Instalar Scout.command`: o instalador.
- `resumo.html`: a página do resumo.
