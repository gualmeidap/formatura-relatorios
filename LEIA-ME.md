# Tesouraria da Formatura — relatórios do Keeper

App de página única (`index.html`) que lê a planilha **"Vendas Parcelas Detalhado"** do Keeper e gera relatórios prontos para enviar (WhatsApp, Excel, PDF). Pensado para o iPhone dela, funciona também no PC.

Duas formas de alimentar os dados:

| | Manual | Automática (robô) |
|---|---|---|
| Como | ela baixa a planilha no Keeper e carrega no app | o robô baixa toda noite e o app carrega sozinho ao abrir |
| Precisa de | só o `index.html` publicado (ou aberto no PC) | robô agendado no PC do Gustavo + GitHub Pages (grátis) |
| Segurança | nada sai do aparelho | planilha publicada **criptografada** (AES-256); o app pede uma senha uma vez |

As duas convivem: mesmo com o robô, o botão **Mais → Carregar planilha manualmente** continua disponível.

---

## 1. Como está montado (produção)

- **Site**: GitHub Pages deste repositório → `https://gualmeidap.github.io/formatura-relatorios/` (é o `index.html`; não contém dados).
- **Dados**: `dados.enc` no mesmo repositório, criptografado (AES-256-GCM) com a `DATA_KEY` do `.env`. O app pede essa senha uma vez no aparelho e depois carrega sozinho a cada abertura.
- **Robô** (`sync/sync.py` + `sync/rodar.ps1`): roda **no PC do Gustavo**, entra no Keeper com a conta dela, baixa a planilha, criptografa e faz `git push`. Em ~1 min o Pages publica.

> Por que no PC e não na nuvem: a API do Keeper recusa conexões vindas de servidores do GitHub Actions (testado — `net::ERR_FAILED` no login). De um computador doméstico funciona.

### Rodar o robô agora (manual)

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File sync/rodar.ps1
```

Pré-requisitos (já feitos neste PC): ambiente virtual em `.venv` (`python -m venv .venv` + `.venv\Scripts\pip install -r sync/requirements.txt`), Chromium do Playwright em `D:\sistemas\ms-playwright` (variável de usuário `PLAYWRIGHT_BROWSERS_PATH`; para reinstalar: `.venv\Scripts\python -m playwright install chromium`); `.env` preenchido (modelo em `.env.example`). O log fica em `sync/ultimo-log.txt`; se der erro no Keeper, ele salva `sync-erro.png` com a tela.

### Agendar toda noite (Agendador de Tarefas do Windows)

```bash
schtasks /create /tn "Formatura - sync Keeper" /sc daily /st 23:30 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File D:\sistemas\formatura-relatorios\sync\rodar.ps1" /f
```

O PC precisa estar ligado (pode estar bloqueado) às 23:30. Para rodar também sempre que você fizer login no Windows (cobre dias em que o PC ficou desligado), crie uma segunda tarefa trocando `/sc daily /st 23:30` por `/sc onlogon`. Para remover: `schtasks /delete /tn "Formatura - sync Keeper" /f`.

---

## 2. Instalar no iPhone dela

1. Abrir `https://gualmeidap.github.io/formatura-relatorios/` no **Safari** → Compartilhar → **Adicionar à Tela de Início**.
2. Abrir o ícone "Tesouraria". Na primeira vez ele pede a **senha dos dados** (a `DATA_KEY` do `.env`). Fica salva no aparelho.
3. Pronto: toda vez que abrir, ele busca a atualização mais recente publicada pelo robô. O selo **🤖 automático** e a data "Dados do Keeper: …" mostram de quando são os números. O botão **↻** força uma nova busca.

Se ela precisar de um número *de agora* (antes da atualização da noite): Keeper → Vendas → Vendas Parcelas Detalhado → Baixar → no app, **Mais → Carregar planilha manualmente**.

---

## 3. O que o app oferece

| Aba | Conteúdo |
|---|---|
| **Início** | anel de progresso, KPIs, 7 respostas prontas (arrecadado, falta, atrasados, este mês, mês que vem, por lote, taxas), relatório completo editável, por lote, gráfico |
| **Mensal** | previsão mês a mês (por vencimento) + o que efetivamente entrou (por data de pagamento) |
| **Atrasos** | inadimplentes com contato, dias de atraso, texto pronto para WhatsApp |
| **Formandos** | situação individual; toque abre o extrato com Copiar / Enviar / Excel |
| **Parcelas** | todas as parcelas, colunas configuráveis, Excel |
| **Mais** | taxas e custos, glossário, atualizar, carregar manualmente, imprimir/PDF, apagar dados |

**Filtros** (ícone ≡): período (vencimento ou pagamento, com atalhos), lote, situação, forma de pagamento, busca. Tudo — inclusive os textos prontos — respeita o filtro ativo. **Copiar** põe o texto na área de transferência; **Enviar** abre o compartilhamento do iOS (WhatsApp, e-mail…).

## 4. Definições (conferidas contra o painel do Keeper)

- **Líquido previsto** = valor da parcela − tarifa de cobrança − taxa Keeper = o que cai na conta da turma.
- **Creditado** = pago e conciliado (bate com "Total pago líquido" do Keeper).
- **Aguardando repasse** = pago no cartão/assinatura, ainda não repassado (bate com "A receber" do Keeper).
- **Atrasado** = vencido e não pago (inclui "Falha no pagamento" de Pix/assinatura; por isso pode contar 1–2 casos a mais que o painel, que só mostra boletos vencidos).
- **Canceladas** ficam fora de todos os totais (marque no filtro para ver).

## 5. Arquivos

- `index.html` — o app (arquivo único; usa SheetJS via CDN, precisa de internet para abrir).
- `sync/sync.py` — robô: login no Keeper (Playwright), download da planilha pela API interna, criptografia.
- `sync/rodar.ps1` — roda o robô lendo o `.env` e publica o `dados.enc` no GitHub.
- `.env` (não vai para o git) — `KEEPER_EMAIL`, `KEEPER_SENHA`, `DATA_KEY`; modelo em `.env.example`.
- `dados.enc` — planilha criptografada publicada pelo robô.
- `exemplo - Vendas Parcelas Detalhado.xlsx` — export real de 21/09/2026, para testes manuais (não vai para o git).
