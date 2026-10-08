# Nivvo

**Controle financeiro simplificado.** App Android (Flutter) para registrar e acompanhar operações de
empréstimo: clientes, juros, vencimentos, encargos, pagamentos parciais, histórico e lembretes.
O dinheiro circula fora do app — o Nivvo é a camada de controle.

<p>
  <img src="docs/telas/dashboard_dark.png" width="200">
  <img src="docs/telas/new_loan_filled.png" width="200">
  <img src="docs/telas/loan_detail.png" width="200">
  <img src="docs/telas/dashboard_light.png" width="200">
</p>

> As prévias foram geradas em ambiente de teste: rótulos de botões aparecem como blocos por falta da
> fonte do sistema. No aparelho o texto é renderizado normalmente.

Decisões de arquitetura, segurança e regras financeiras: [docs/ARQUITETURA.md](docs/ARQUITETURA.md).

## Stack

Flutter 3.47 · Dart 3.13 · Material 3 (`material_ui`) · Riverpod 3 · go_router 18 · Supabase (Auth + PostgreSQL + RLS) ·
notificações locais agendadas.

## Como rodar

### 1. Supabase

1. Crie um projeto em [supabase.com](https://supabase.com).
2. Rode a migration [supabase/migrations/20261008000000_init.sql](supabase/migrations/20261008000000_init.sql):
   - pelo **SQL Editor** do painel (cole o arquivo inteiro e execute), ou
   - pela CLI: `supabase link --project-ref <ref>` e `supabase db push`.
3. Em **Authentication → URL Configuration → Redirect URLs**, adicione:
   `com.nivvo.app://auth-callback`
   (usado pela confirmação de e-mail e pela recuperação de senha).
4. Em **Project Settings → API Keys**, copie a URL e a chave **publishable** (ou `anon`).
   **Nunca** use a chave `service_role`/secret no app.

### 2. App

```bash
cp env.example.json env.json        # preencha URL e chave
flutter pub get
flutter run --dart-define-from-file=env.json
```

Build de release: `flutter build apk --release --dart-define-from-file=env.json`
(configure antes uma chave de assinatura própria em `android/app/build.gradle.kts`).

## Testes

```bash
flutter test                          # regras financeiras, extrato, linha do tempo, lembretes
cd supabase/tests && npm install && npm test   # migration em Postgres real (PGlite): RLS, RPCs, isolamento
```

## Estrutura

```
lib/
  core/            regras puras: finance/ (juros, saldo, status), money/, utils/, cache/, errors/, config/
  features/        auth, dashboard, loans, clients, payments, charges, reports, settings, notifications
  shared/          models/, repositories/ (acesso ao Supabase), services/ (providers base), widgets/
  routing/         go_router + shell com navegação inferior
  theme/           paleta, tema claro/escuro
supabase/
  migrations/      schema, RLS, funções RPC atômicas
  tests/           teste da migration
docs/              arquitetura e prévias das telas
```

Regras de dinheiro: valores sempre em **centavos inteiros** no app e `numeric(14,2)` no banco.
Toda escrita financeira passa por funções SQL transacionais — o app não tem permissão de alterar
saldos diretamente.

## Próximos passos sugeridos

- Ícone do launcher em PNG para Android < 8 (o ícone adaptativo vetorial já cobre Android 8+).
- Push remoto (FCM + Edge Function) usando a tabela `notifications`, quando houver vários aparelhos.
- Exportação PDF/Excel, renegociação e parcelas (a arquitetura já prevê — ver `docs/ARQUITETURA.md`).
