# Nivvo — Análise de arquitetura e decisões do MVP

Este documento registra a revisão da especificação original feita antes da implementação:
os problemas encontrados, como cada um foi resolvido e o que ficou para depois.

---

## 1. Visão geral

```
Flutter (Android)                         Supabase
┌───────────────────────────┐            ┌─────────────────────────────────────┐
│ features/*  (UI + estado) │            │ Auth (e-mail/senha, recuperação)    │
│      │  Riverpod          │            │                                     │
│      ▼                    │   HTTPS    │ PostgREST ── RLS (user_id = uid)    │
│ shared/repositories ──────┼───────────▶│   SELECT  → tabelas e views         │
│      │                    │            │   ESCRITA → funções RPC atômicas    │
│ core/finance (regras)     │            │                                     │
│ core/cache (offline)      │            │ PostgreSQL (fonte da verdade)       │
│ shared/services/notif.    │            └─────────────────────────────────────┘
└───────────────────────────┘
```

- **Fonte da verdade financeira = banco.** Saldos, juros e status de quitação são calculados
  e gravados por funções PostgreSQL dentro de transações. O app só exibe e faz uma
  *prévia* idêntica (mesma regra de arredondamento) para a tela de nova operação.
- **Widgets não contêm regra financeira.** Toda regra está em `lib/core/finance/`
  (Dart puro, testável) e nas funções SQL.

---

## 2. Problemas de modelagem encontrados e correções

| # | Problema na especificação | Risco | Decisão |
|---|---|---|---|
| M1 | `paid_amount` e `remaining_amount` gravados em `loans` e atualizados pelo app | Duas escritas separadas (pagamento + loan) podem divergir; um cliente malicioso pode gravar qualquer saldo | Escritas financeiras **somente via RPC** (`register_payment`, `add_charge`…) que travam a linha (`FOR UPDATE`) e atualizam tudo na mesma transação. `remaining_amount` e `total_initial_amount` são **colunas geradas** pelo banco. O app não tem permissão de INSERT/UPDATE nessas tabelas. |
| M2 | Status "Vence hoje", "Próxima do vencimento" e "Vencida" gravados no banco | Dependem da data atual: ficariam errados no dia seguinte sem um job agendado | O banco guarda apenas o **ciclo de vida** (`active`, `paid`, `cancelled`). O status exibido é **derivado** de (ciclo de vida, saldo, vencimento, hoje) em `LoanStatusRules`. |
| M3 | Status ambíguos: uma operação pode estar "Vencida" **e** com "Pagamento parcial" | Regra de exibição indefinida | Precedência: Cancelada › Paga › Vencida › Vence hoje › Próxima › Pagamento parcial › Pendente. O valor já pago aparece sempre no detalhe. |
| M4 | Faltava o campo **prazo** (`term_days`) | Não dá para reexibir/auditar o prazo original | Adicionado `term_days`; `due_date = start_date + term_days` (08/10 + 30 dias = 07/11, conforme o exemplo). |
| M5 | Não havia como **corrigir um pagamento lançado errado** | Com "nunca apagar", um erro de digitação ficaria permanente | Pagamentos também têm `status` (`active`/`cancelled`) com **estorno** (motivo, usuário, data). Nada é excluído. |
| M6 | Cancelar encargo depois de quitar deixaria saldo negativo | Ex.: total 375 pago, cancela encargo de 30 → saldo −30 | O banco bloqueia (`balance_would_be_negative`). O usuário estorna o pagamento primeiro. |
| M7 | Pagamento maior que o saldo | Saldo negativo | Bloqueado no app e no banco (`amount_exceeds_balance`). O botão "Quitar" preenche o saldo exato. |
| M8 | "Juros recebidos" sem regra de alocação do pagamento | Relatório ambíguo | Alocação em cascata: **encargos → juros → principal**. `juros/encargos recebidos = min(pago, juros + encargos)`. Calculado na leitura, então continua correto após cancelamentos. |
| M9 | Dinheiro em ponto flutuante | Erros de centavos (0,1 + 0,2) | Banco: `numeric(14,2)`. App: **inteiros em centavos** (`Money`). Juros arredondados meio-para-cima em ambos os lados (mesmo resultado). |
| M10 | Tabela `users` própria | Duplicaria o Supabase Auth e tentaria guardar senha | `profiles` (1:1 com `auth.users`, criado por trigger) com nome, telefone e fuso horário. |
| M11 | Fuso horário não definido | "Vence hoje" errado perto da meia-noite (UTC × Brasília) | Datas financeiras são `date` (sem hora). "Hoje" usa o fuso do perfil (padrão `America/Sao_Paulo`). |
| M12 | `loan_history` só com texto livre | Difícil exibir/traduzir/filtrar | Campos estruturados: `action` (enum), `amount`, `event_date`, `metadata` (jsonb) + `description` livre. O texto da linha do tempo é montado no app. |
| M13 | "Operação marcada como vencida" como evento gravado | Exigiria job diário | O evento "Vencimento" é derivado de `due_date` e intercalado na linha do tempo. |
| M14 | Preparação para multiusuário | Reescrever tudo depois | Toda tabela tem `user_id` (dono dos dados) **e** `created_by` (quem fez). No futuro, `user_id` vira `organization_id` + tabela de membros sem mudar o modelo de eventos. |
| M15 | Integridade entre donos | Pagamento de um usuário apontando para operação de outro | FKs compostas `(loan_id, user_id) → loans(id, user_id)` e `(client_id, user_id) → clients(id, user_id)`. É impossível no nível do banco cruzar dados de usuários. |

---

## 3. Segurança

- **RLS em todas as tabelas**, política `user_id = auth.uid()`.
- Tabelas financeiras (`loans`, `payments`, `loan_charges`, `loan_history`): o app só tem
  **SELECT**. Escrita exclusivamente pelas funções `SECURITY DEFINER` com
  `search_path = ''`, que validam dono, valores, datas e estado.
- Histórico é **append-only**: não existe função nem permissão de UPDATE/DELETE.
- Apenas a chave `anon` vai no app (pública por design; quem protege é a RLS).
  A `service_role` **nunca** entra no app.
- Validação de entrada em duas camadas: formulário (UX) + `CHECK` constraints e funções (garantia).
- CPF validado por dígito verificador; único por usuário. CPF e telefone são dados pessoais (LGPD):
  ficam opcionais, isolados por usuário e não aparecem em notificações.
- Proteção de rotas: `GoRouter.redirect` com base na sessão; sessão persistente e
  renovação de token pelo `supabase_flutter`.
- Notificações mostram nome e valor na tela de bloqueio — há opção para ocultar valores
  (Configurações).
- Cache offline é limpo ao sair da conta e separado por usuário.

**Ponto de atenção (não técnico):** cobrança de juros em empréstimos entre particulares tem
limites legais no Brasil. O Nivvo é uma ferramenta de registro e não valida taxas;
vale confirmar com um advogado/contador o enquadramento do negócio antes de oferecer o app
como SaaS.

---

## 4. Regras financeiras validadas

```
juros            = arred(principal × taxa%, 2)        // meio para cima
total inicial    = principal + juros
encargos         = Σ encargos ativos (cancelados não somam)
pago             = Σ pagamentos ativos (estornados não somam)
saldo atual      = principal + juros + encargos − pago   (nunca < 0)
vencimento       = data inicial + prazo (dias)
```

Exemplos da especificação conferidos (testes em `test/core/`):

- 300 × 15% = 45 → total 345, vencimento 07/11/2026 ✔
- 300 + 45 + 60 (20 + 15 + 25) − 100 = **305** ✔
- 300 + 45 + 30 − 100 = **275** ✔

## 5. Pagamento parcial e baixa

1. App mostra total atualizado, pago e saldo; valor sugerido = saldo ("Quitar").
2. `register_payment` trava a operação, valida `0 < valor ≤ saldo` e data, grava pagamento,
   soma em `paid_amount`, grava histórico.
3. Se o saldo chega a 0 → `status = paid`, `paid_at = now()` e evento "Operação quitada".
4. Estorno (`cancel_payment`) reabre a operação se ela estava quitada.

## 6. Encargos

- Lançamento manual (`late_interest`, `fine`, `other`), valor > 0, data e descrição.
  O app **nunca** calcula atraso automaticamente.
- Vários encargos por operação; nada é sobrescrito.
- Permitido também antes do vencimento (casos raros), mas o botão ganha destaque quando vencida.
- Cancelamento lógico com motivo, usuário e data.

## 7. Notificações — decisão do MVP

A especificação pede FCM. Push remoto exige: tabela de tokens, job agendado (pg_cron),
Edge Function com credencial do Firebase e projeto Firebase configurado — muita infraestrutura
para o MVP e com pontos de falha.

**MVP: notificações locais agendadas no aparelho** (`flutter_local_notifications`):

- Funcionam offline e sem servidor.
- A cada abertura do app e após qualquer alteração, o agendamento é **refeito do zero** a partir
  das operações ativas → quando a operação é quitada, os lembretes somem automaticamente.
- Lembretes às 09:00: 7 dias antes, 3 dias antes, 1 dia antes, no dia e 1 dia após vencer.
- Limite de 400 lembretes (o Android limita alarmes por app), priorizando os mais próximos.
- Agendamento **inexato** (`inexactAllowWhileIdle`): não exige a permissão restrita de alarme
  exato do Android 14.
- A tabela `notifications` já existe no banco para a fase 2 (FCM + Edge Function), quando
  houver múltiplos aparelhos/funcionários.

## 8. Offline

- Leituras guardam o último JSON recebido (por usuário) em armazenamento local.
- Sem conexão: telas mostram os dados salvos com um aviso "Offline".
- **Escritas financeiras exigem conexão** no MVP. Fila offline de pagamentos criaria
  conflitos (dois aparelhos quitando a mesma operação). Fica para uma fase futura com
  idempotência por `client_request_id`.

## 9. UX — decisões

- **Nova operação em uma única tela** (em vez de wizard de 4 passos): cliente → valor → juros →
  prazo, com foco avançando sozinho, prévia ao vivo e botão fixo "Confirmar".
  A última taxa e o último prazo usados vêm preenchidos; prazos rápidos (7/15/30 dias).
  Meta de ~30s alcançável com ~6 toques.
- "Novo cliente" inline no seletor (nome obrigatório, telefone opcional) — sem sair do fluxo.
- Valores digitados como em apps bancários (dígitos entram pelos centavos).
- Botão "+" de nova operação visível em todas as abas.
- Card de alerta "Vencidas" no Início, que abre Operações já filtrada.

## 10. Preparado para o futuro (não implementado)

| Futuro | Onde encaixa |
|---|---|
| Funcionários/permissões/empresas | `created_by` já existe; trocar `user_id` por `organization_id` + `members` e ajustar políticas RLS |
| Parcelas / modalidades de juros | Nova tabela `loan_installments`; `LoanCalculator` é isolado |
| Renegociação | Novo `history_action` + operação filha com `parent_loan_id` |
| Exportação / PDF / dashboard web | Funções `report_summary` e views já servem qualquer cliente |
| WhatsApp / lembretes ao cliente | Telefone já normalizado (somente dígitos) |
| Comprovantes / anexos | Supabase Storage com bucket por usuário |
| Push (FCM) | Tabela `notifications` |
