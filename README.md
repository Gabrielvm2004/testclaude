# Controle de Treinos

Gera automaticamente um PDF por atleta com:

1. **Capa** — atleta, fase e as sessões da semana
2. **Uma página por sessão** — mobilidade, ativação, trabalho principal (com pares combinados), cardio/finalização e objetivo da sessão. Exercícios com imagem de referência e **QR code do vídeo**, quando cadastrados.
3. **Controle semanal** — tabela semana × sessão para o atleta marcar o que fez e anotar o esforço (PSE). O que já foi registrado aparece marcado.
4. **Histórico e evolução** — sessões por mês, foco das sessões, esforço percebido, evolução de carga por exercício e linha do tempo das últimas sessões.

O PDF é pensado para ser enviado pelo WhatsApp.

## Como usar

### Pelo Claude (mais prático)

Peça em linguagem natural, por exemplo:

- "Registra que o Diego fez o Dia 1 hoje, PSE 7, agachamento cálice com 16 kg."
- "Troca a ponte isométrica do Dia 1 por crucifixo iso 3 × 30"."
- "Cria a ficha de um atleta novo, João, goleiro, 16 anos, com base no treino do Diego."
- "Gera o PDF do Diego e sobe no meu Drive."

O Claude atualiza o arquivo do atleta, gera o PDF e envia o link.

### Manualmente

```bash
pip install -r requirements.txt
python -m playwright install chromium
python gerador/gerar.py                # todos os atletas
python gerador/gerar.py diego-avelar   # só um
```

O PDF sai em `saida/<atleta>/AAAA-MM-DD-treino-<atleta>.pdf`.

### Automático (GitHub Actions)

Toda alteração em `dados/`, `midia/`, `modelos/` ou `design-system/` gera os PDFs de novo no GitHub.
Para baixar: aba **Actions** → execução mais recente → **pdfs-treino**.
Dá também para rodar na hora em **Actions → Gerar PDFs de treino → Run workflow**.

## Onde fica cada coisa

| Pasta / arquivo | O que é |
| --- | --- |
| `dados/atletas/<atleta>.yaml` | Ficha do atleta: plano atual (fase, sessões, exercícios) e histórico de treinos feitos |
| `dados/exercicios.yaml` | Biblioteca de exercícios: imagem, vídeo e dica de execução de cada um |
| `midia/exercicios/` | Fotos e ilustrações dos exercícios |
| `design-system/` | Cores, fontes e componentes visuais do PDF (sincronizável com o Claude Design) |
| `modelos/treino.html.j2` | Estrutura das páginas do PDF |
| `gerador/gerar.py` | Script que monta o PDF |

### Registrar um treino feito

No fim da ficha do atleta, em `historico:`:

```yaml
  - data: 2026-09-22
    titulo: Dia 1 — Inferiores + Core
    foco: Força + core
    sessao: 1          # marca o check na tabela de controle
    pse: 7             # esforço percebido (0–10)
    cargas:            # kg por exercício → gráfico de evolução
      Agachamento cálice: 16
      Hip thrust c/ potência: 40
```

### Adicionar imagem ou vídeo a um exercício

Coloque a imagem em `midia/exercicios/` e cadastre em `dados/exercicios.yaml`:

```yaml
Agachamento cálice:
  imagem: agachamento-calice.jpg
  video: https://www.youtube.com/watch?v=...
  dica: Halter junto ao peito, joelhos acompanham a ponta dos pés.
```

Vale para todos os atletas que tiverem esse exercício na ficha.

## Design e Claude Design

Todo o visual do PDF vem de dois arquivos:

- `design-system/tokens.css` — cores, fontes, tamanhos e espaçamentos
- `design-system/componentes.css` — os componentes (card de exercício, par combinado, tabela de controle, gráficos…)

Em `design-system/previews/` há uma página de preview para cada grupo de componentes, já marcada com
`<!-- @dsCard group="…" -->`. Isso permite sincronizar a pasta com um projeto de design system no
[Claude Design](https://claude.ai/design) usando o comando `/design-sync` do Claude Code: você ajusta o visual lá,
traz de volta para cá e os próximos PDFs já saem com o design novo.
