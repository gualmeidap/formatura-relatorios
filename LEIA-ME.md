# Tesouraria da Formatura — relatórios do Keeper

App de página única (`index.html`) que lê a planilha **"Vendas Parcelas Detalhado"** do Keeper e gera relatórios prontos para enviar (WhatsApp, Excel, PDF). Pensado para o iPhone dela, funciona também no PC.

Duas formas de alimentar os dados:

| | Manual | Automática (robô) |
|---|---|---|
| Como | ela baixa a planilha no Keeper e carrega no app | um robô baixa toda noite e o app carrega sozinho ao abrir |
| Precisa de | só o `index.html` publicado (ou aberto no PC) | repositório GitHub + GitHub Actions + GitHub Pages (tudo grátis) |
| Segurança | nada sai do aparelho | planilha publicada **criptografada** (AES-256); o app pede uma senha uma vez |

As duas convivem: mesmo com o robô, o botão **Mais → Carregar planilha manualmente** continua disponível.

---

## 1. Publicar o app + robô (GitHub, ~15 min, uma vez só)

1. Crie um repositório no GitHub (pode ser **privado**; o Pages funciona em repositório privado só em contas pagas — se for conta gratuita, use **público**: o `index.html` não tem dados e o `dados.enc` é criptografado).
2. Suba o conteúdo desta pasta (`index.html`, `sync/`, `.github/`, `.gitignore`, `LEIA-ME.md`). **Não** suba a planilha de exemplo (`.gitignore` já bloqueia `.xlsx` e `.env`).
3. **Settings → Secrets and variables → Actions → New repository secret**, crie três:
   - `KEEPER_EMAIL` — e-mail (ou CPF) de login dela no Keeper
   - `KEEPER_SENHA` — senha do Keeper
   - `DATA_KEY` — uma frase secreta forte que vocês inventam. É a senha que o app vai pedir no iPhone.
4. **Settings → Pages → Source: Deploy from a branch → main / (root)**. Anote a URL (`https://SEU-USUARIO.github.io/NOME-DO-REPO/`).
5. **Actions → "Atualizar dados do Keeper" → Run workflow** para testar. Em ~2 min deve aparecer o commit `dados: …` com o arquivo `dados.enc`.
   - Se falhar, abra o job: há um artefato `sync-erro` com uma captura da tela do Keeper no momento do erro (normalmente é login recusado ou algum popup novo).
6. Depois disso o robô roda sozinho **todo dia às 00:00 (Brasília)**. Para mudar o horário, edite o `cron` em `.github/workflows/sync.yml` (está em UTC; Brasília = UTC−3).

> O login no Keeper por senha gera sessão nova a cada execução; a conta dela continua funcionando normalmente no app do Keeper. As credenciais ficam só nos *secrets* do GitHub (criptografados, ninguém consegue ler depois de salvos).

### Rodar o robô no seu PC em vez do GitHub (opcional)

```bash
pip install -r sync/requirements.txt
playwright install chromium
```

Copie `.env.example` para `.env`, preencha, e rode (`python sync/sync.py` com as variáveis definidas). Ele gera `dados.enc`; aí é você que precisa publicar o arquivo (commit + push). Dá para agendar no Agendador de Tarefas do Windows, mas o PC precisa estar ligado — por isso o GitHub Actions é melhor.

---

## 2. Instalar no iPhone dela

1. Abrir a URL do Pages no **Safari** → Compartilhar → **Adicionar à Tela de Início**.
2. Abrir o ícone "Tesouraria". Na primeira vez ele pede a **senha dos dados** (`DATA_KEY`). Fica salva no aparelho.
3. Pronto: toda vez que abrir, ele busca a atualização da noite anterior. O selo **🤖 automático** e a data "Dados do Keeper: …" mostram de quando são os números. O botão **↻** força uma nova busca.

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
- `.github/workflows/sync.yml` — agendamento noturno no GitHub Actions.
- `.env.example` — modelo de variáveis para rodar o robô localmente.
- `exemplo - Vendas Parcelas Detalhado.xlsx` — export real de 21/09/2026, para testes manuais (não vai para o git).
