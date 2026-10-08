-- =====================================================================
-- Nivvo — schema inicial (MVP)
--
-- Princípios:
--   * Dinheiro em numeric(14,2). Nada de float.
--   * Tabelas financeiras são somente-leitura para o app; toda escrita passa
--     pelas funções RPC abaixo (transação + trava da operação + validação).
--   * Nada financeiro é excluído: encargos e pagamentos são cancelados/estornados.
--   * Status temporal (vence hoje / vencida) é derivado na leitura, não gravado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------
create type public.loan_status as enum ('active', 'paid', 'cancelled');
create type public.record_status as enum ('active', 'cancelled');
create type public.charge_type as enum ('late_interest', 'fine', 'other');
create type public.payment_method as enum ('pix', 'cash', 'transfer', 'other');
create type public.history_action as enum (
  'loan_created',
  'charge_added',
  'charge_cancelled',
  'payment_registered',
  'payment_cancelled',
  'loan_paid',
  'loan_reopened',
  'loan_cancelled'
);
create type public.notification_status as enum ('scheduled', 'sent', 'cancelled', 'failed');

-- ---------------------------------------------------------------------
-- Utilitário: updated_at
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- profiles (1:1 com auth.users)
-- ---------------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  name       text not null default '' check (char_length(name) <= 120),
  email      text,
  phone      text check (phone is null or phone ~ '^[0-9]{10,13}$'),
  timezone   text not null default 'America/Sao_Paulo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Um fuso inválido quebraria o cálculo de "hoje"; valida e protege campos imutáveis.
create or replace function public.profiles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id <> old.id or new.created_at <> old.created_at then
    raise exception 'immutable_field';
  end if;
  if new.timezone is distinct from old.timezone
     and not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'invalid_timezone';
  end if;
  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function public.profiles_guard();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data ->> 'name', ''), 120),
    new.email
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- "Hoje" no fuso do usuário (vencimentos são datas, não instantes).
create or replace function public.user_today()
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (now() at time zone coalesce(
    (select p.timezone from public.profiles p where p.id = auth.uid()),
    'America/Sao_Paulo'
  ))::date;
$$;

-- ---------------------------------------------------------------------
-- clients
-- ---------------------------------------------------------------------
create table public.clients (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 2 and 120),
  phone       text check (phone is null or phone ~ '^[0-9]{10,13}$'),
  cpf         text check (cpf is null or cpf ~ '^[0-9]{11}$'),
  notes       text check (notes is null or char_length(notes) <= 1000),
  created_by  uuid not null default auth.uid() references auth.users (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (id, user_id)
);

create unique index clients_user_cpf_uq on public.clients (user_id, cpf) where cpf is not null;
create index clients_user_name_idx on public.clients (user_id, lower(name));

create trigger clients_updated_at
  before update on public.clients
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- loans (operações)
-- ---------------------------------------------------------------------
create table public.loans (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users (id) on delete cascade,
  client_id            uuid not null,
  principal_amount     numeric(14,2) not null check (principal_amount > 0),
  interest_rate        numeric(6,2)  not null check (interest_rate >= 0 and interest_rate <= 999.99),
  interest_amount      numeric(14,2) not null check (interest_amount >= 0),
  total_initial_amount numeric(14,2) generated always as (principal_amount + interest_amount) stored,
  charges_amount       numeric(14,2) not null default 0 check (charges_amount >= 0),
  paid_amount          numeric(14,2) not null default 0 check (paid_amount >= 0),
  remaining_amount     numeric(14,2) generated always as
                         (principal_amount + interest_amount + charges_amount - paid_amount) stored,
  term_days            integer not null check (term_days between 1 and 3650),
  start_date           date not null,
  due_date             date not null,
  status               public.loan_status not null default 'active',
  notes                text check (notes is null or char_length(notes) <= 1000),
  paid_at              timestamptz,
  cancelled_at         timestamptz,
  cancelled_by         uuid references auth.users (id),
  cancel_reason        text check (cancel_reason is null or char_length(cancel_reason) <= 500),
  created_by           uuid not null references auth.users (id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, user_id),
  foreign key (client_id, user_id) references public.clients (id, user_id) on delete restrict,
  check (due_date = start_date + term_days),
  check (principal_amount + interest_amount + charges_amount - paid_amount >= 0),
  check ((status = 'paid') = (paid_at is not null)),
  check ((status = 'cancelled') = (cancelled_at is not null))
);

create index loans_user_status_due_idx on public.loans (user_id, status, due_date);
create index loans_user_created_idx on public.loans (user_id, created_at desc);
create index loans_client_idx on public.loans (client_id);

create trigger loans_updated_at
  before update on public.loans
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- loan_charges (encargos manuais)
-- ---------------------------------------------------------------------
create table public.loan_charges (
  id            uuid primary key default gen_random_uuid(),
  loan_id       uuid not null,
  user_id       uuid not null references auth.users (id) on delete cascade,
  type          public.charge_type not null,
  amount        numeric(14,2) not null check (amount > 0),
  description   text check (description is null or char_length(description) <= 500),
  charge_date   date not null,
  status        public.record_status not null default 'active',
  cancelled_at  timestamptz,
  cancelled_by  uuid references auth.users (id),
  cancel_reason text check (cancel_reason is null or char_length(cancel_reason) <= 500),
  created_by    uuid not null references auth.users (id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  foreign key (loan_id, user_id) references public.loans (id, user_id) on delete restrict,
  check ((status = 'cancelled') = (cancelled_at is not null))
);

create index loan_charges_loan_idx on public.loan_charges (loan_id, charge_date);
create index loan_charges_user_date_idx on public.loan_charges (user_id, charge_date) where status = 'active';

create trigger loan_charges_updated_at
  before update on public.loan_charges
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- payments (recebimentos registrados — o dinheiro circula fora do app)
-- ---------------------------------------------------------------------
create table public.payments (
  id             uuid primary key default gen_random_uuid(),
  loan_id        uuid not null,
  user_id        uuid not null references auth.users (id) on delete cascade,
  amount         numeric(14,2) not null check (amount > 0),
  payment_method public.payment_method not null,
  payment_date   date not null,
  notes          text check (notes is null or char_length(notes) <= 500),
  status         public.record_status not null default 'active',
  cancelled_at   timestamptz,
  cancelled_by   uuid references auth.users (id),
  cancel_reason  text check (cancel_reason is null or char_length(cancel_reason) <= 500),
  created_by     uuid not null references auth.users (id),
  created_at     timestamptz not null default now(),
  foreign key (loan_id, user_id) references public.loans (id, user_id) on delete restrict,
  check ((status = 'cancelled') = (cancelled_at is not null))
);

create index payments_loan_idx on public.payments (loan_id, payment_date);
create index payments_user_date_idx on public.payments (user_id, payment_date) where status = 'active';

-- ---------------------------------------------------------------------
-- loan_history (append-only)
-- ---------------------------------------------------------------------
create table public.loan_history (
  id          uuid primary key default gen_random_uuid(),
  loan_id     uuid not null,
  user_id     uuid not null references auth.users (id) on delete cascade,
  action      public.history_action not null,
  amount      numeric(14,2),
  event_date  date not null,
  description text,
  metadata    jsonb not null default '{}'::jsonb,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now(),
  foreign key (loan_id, user_id) references public.loans (id, user_id) on delete restrict
);

create index loan_history_loan_idx on public.loan_history (loan_id, created_at);

-- ---------------------------------------------------------------------
-- notifications (fase 2: push remoto via FCM; o MVP usa notificações locais)
-- ---------------------------------------------------------------------
create table public.notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  loan_id       uuid not null,
  type          text not null check (type in ('due_in_7', 'due_in_3', 'due_in_1', 'due_today', 'overdue')),
  scheduled_for timestamptz not null,
  sent_at       timestamptz,
  status        public.notification_status not null default 'scheduled',
  created_at    timestamptz not null default now(),
  foreign key (loan_id, user_id) references public.loans (id, user_id) on delete cascade,
  unique (loan_id, type)
);

create index notifications_due_idx on public.notifications (scheduled_for) where status = 'scheduled';

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table public.profiles      enable row level security;
alter table public.clients       enable row level security;
alter table public.loans         enable row level security;
alter table public.loan_charges  enable row level security;
alter table public.payments      enable row level security;
alter table public.loan_history  enable row level security;
alter table public.notifications enable row level security;

-- Ninguém anônimo acessa nada.
revoke all on public.profiles, public.clients, public.loans, public.loan_charges,
              public.payments, public.loan_history, public.notifications from anon;

-- Tabelas financeiras: somente leitura para o app. Escrita apenas via RPC.
revoke insert, update, delete, truncate on public.loans, public.loan_charges,
       public.payments, public.loan_history from authenticated;
revoke delete, truncate on public.profiles from authenticated;
revoke truncate on public.clients, public.notifications from authenticated;

create policy profiles_select on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_update on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy clients_select on public.clients
  for select to authenticated using (user_id = (select auth.uid()));
create policy clients_insert on public.clients
  for insert to authenticated
  with check (user_id = (select auth.uid()) and created_by = (select auth.uid()));
create policy clients_update on public.clients
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Exclusão só funciona para cliente sem operações (FK restrict).
create policy clients_delete on public.clients
  for delete to authenticated using (user_id = (select auth.uid()));

create policy loans_select on public.loans
  for select to authenticated using (user_id = (select auth.uid()));
create policy loan_charges_select on public.loan_charges
  for select to authenticated using (user_id = (select auth.uid()));
create policy payments_select on public.payments
  for select to authenticated using (user_id = (select auth.uid()));
create policy loan_history_select on public.loan_history
  for select to authenticated using (user_id = (select auth.uid()));

create policy notifications_all on public.notifications
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Impede que o dono/autor de um cliente seja trocado por UPDATE.
create or replace function public.clients_guard_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id <> old.user_id or new.created_by <> old.created_by or new.created_at <> old.created_at then
    raise exception 'immutable_field';
  end if;
  return new;
end;
$$;

create trigger clients_guard_owner
  before update on public.clients
  for each row execute function public.clients_guard_owner();

-- =====================================================================
-- Views (security_invoker: respeitam a RLS de quem consulta)
-- =====================================================================
create view public.loan_overview
with (security_invoker = true) as
select
  l.id,
  l.user_id,
  l.client_id,
  c.name  as client_name,
  c.phone as client_phone,
  c.cpf   as client_cpf,
  l.principal_amount,
  l.interest_rate,
  l.interest_amount,
  l.total_initial_amount,
  l.charges_amount,
  l.paid_amount,
  l.remaining_amount,
  l.term_days,
  l.start_date,
  l.due_date,
  l.status,
  l.notes,
  l.paid_at,
  l.cancelled_at,
  l.cancel_reason,
  l.created_at,
  -- Alocação em cascata: encargos -> juros -> principal.
  least(l.paid_amount, l.interest_amount + l.charges_amount) as earnings_received
from public.loans l
join public.clients c on c.id = l.client_id and c.user_id = l.user_id;

create view public.client_summary
with (security_invoker = true) as
select
  c.id,
  c.user_id,
  c.name,
  c.phone,
  c.cpf,
  c.notes,
  c.created_at,
  c.updated_at,
  coalesce(sum(l.principal_amount) filter (where l.status <> 'cancelled'), 0) as total_lent,
  coalesce(sum(l.paid_amount)      filter (where l.status <> 'cancelled'), 0) as total_received,
  coalesce(sum(l.remaining_amount) filter (where l.status = 'active'), 0)     as balance,
  count(l.id) filter (where l.status <> 'cancelled')                          as loans_count,
  count(l.id) filter (where l.status = 'active' and l.due_date < public.user_today()) as overdue_count
from public.clients c
left join public.loans l on l.client_id = c.id and l.user_id = c.user_id
group by c.id;

grant select on public.loan_overview, public.client_summary to authenticated;
revoke all on public.loan_overview, public.client_summary from anon;

-- =====================================================================
-- Funções de escrita (RPC)
-- Todas: SECURITY DEFINER + search_path vazio + checagem explícita de dono.
-- Mensagens de erro são códigos estáveis traduzidos no app.
-- =====================================================================

create or replace function public.create_loan(
  p_client_id     uuid,
  p_principal     numeric,
  p_interest_rate numeric,
  p_term_days     integer,
  p_start_date    date,
  p_notes         text default null
)
returns public.loans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_loan public.loans;
  v_principal numeric(14,2);
  v_rate numeric(6,2);
  v_interest numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  perform 1 from public.clients where id = p_client_id and user_id = v_uid;
  if not found then raise exception 'client_not_found'; end if;

  if p_principal is null or p_principal <= 0 or p_principal <> round(p_principal, 2) then
    raise exception 'invalid_amount';
  end if;
  if p_interest_rate is null or p_interest_rate < 0 or p_interest_rate > 999.99
     or p_interest_rate <> round(p_interest_rate, 2) then
    raise exception 'invalid_rate';
  end if;
  if p_term_days is null or p_term_days < 1 or p_term_days > 3650 then
    raise exception 'invalid_term';
  end if;
  if p_start_date is null
     or p_start_date > public.user_today() + 1
     or p_start_date < public.user_today() - 3650 then
    raise exception 'invalid_date';
  end if;

  v_principal := p_principal;
  v_rate := p_interest_rate;
  -- numeric round() arredonda 0,5 para longe do zero (meio para cima em positivos).
  v_interest := round(v_principal * v_rate / 100, 2);

  insert into public.loans (
    user_id, client_id, principal_amount, interest_rate, interest_amount,
    term_days, start_date, due_date, notes, created_by
  ) values (
    v_uid, p_client_id, v_principal, v_rate, v_interest,
    p_term_days, p_start_date, p_start_date + p_term_days, nullif(btrim(p_notes), ''), v_uid
  )
  returning * into v_loan;

  insert into public.loan_history (loan_id, user_id, action, amount, event_date, metadata, created_by)
  values (
    v_loan.id, v_uid, 'loan_created', v_principal, p_start_date,
    jsonb_build_object(
      'interest_rate', v_rate,
      'interest_amount', v_interest,
      'term_days', p_term_days,
      'due_date', v_loan.due_date
    ),
    v_uid
  );

  return v_loan;
end;
$$;

create or replace function public.add_charge(
  p_loan_id     uuid,
  p_type        public.charge_type,
  p_amount      numeric,
  p_charge_date date,
  p_description text default null
)
returns public.loan_charges
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_loan   public.loans;
  v_charge public.loan_charges;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_loan from public.loans
   where id = p_loan_id and user_id = v_uid
   for update;
  if not found then raise exception 'loan_not_found'; end if;
  if v_loan.status = 'cancelled' then raise exception 'loan_cancelled'; end if;
  if v_loan.status = 'paid' then raise exception 'loan_already_paid'; end if;

  if p_type is null then raise exception 'invalid_type'; end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'invalid_amount';
  end if;
  if p_charge_date is null or p_charge_date < v_loan.start_date
     or p_charge_date > public.user_today() + 1 then
    raise exception 'invalid_date';
  end if;

  insert into public.loan_charges (loan_id, user_id, type, amount, description, charge_date, created_by)
  values (p_loan_id, v_uid, p_type, p_amount, nullif(btrim(p_description), ''), p_charge_date, v_uid)
  returning * into v_charge;

  update public.loans set charges_amount = charges_amount + p_amount where id = p_loan_id;

  insert into public.loan_history (loan_id, user_id, action, amount, event_date, description, metadata, created_by)
  values (
    p_loan_id, v_uid, 'charge_added', p_amount, p_charge_date, v_charge.description,
    jsonb_build_object('charge_id', v_charge.id, 'type', p_type),
    v_uid
  );

  return v_charge;
end;
$$;

create or replace function public.cancel_charge(p_charge_id uuid, p_reason text)
returns public.loan_charges
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_charge public.loan_charges;
  v_loan   public.loans;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_reason is null or char_length(btrim(p_reason)) < 3 then raise exception 'reason_required'; end if;

  select * into v_charge from public.loan_charges where id = p_charge_id and user_id = v_uid;
  if not found then raise exception 'charge_not_found'; end if;

  -- Trava a operação antes de mexer em valores (mesma ordem de travas das outras funções).
  select * into v_loan from public.loans where id = v_charge.loan_id and user_id = v_uid for update;
  select * into v_charge from public.loan_charges where id = p_charge_id for update;

  if v_charge.status = 'cancelled' then raise exception 'already_cancelled'; end if;
  if v_loan.status = 'cancelled' then raise exception 'loan_cancelled'; end if;
  if v_loan.remaining_amount - v_charge.amount < 0 then
    raise exception 'balance_would_be_negative';
  end if;

  update public.loan_charges
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, cancel_reason = btrim(p_reason)
   where id = p_charge_id
   returning * into v_charge;

  update public.loans
     set charges_amount = charges_amount - v_charge.amount,
         status  = case when remaining_amount - v_charge.amount = 0 then 'paid'::public.loan_status else status end,
         paid_at = case when remaining_amount - v_charge.amount = 0 then coalesce(paid_at, now()) else paid_at end
   where id = v_loan.id;

  insert into public.loan_history (loan_id, user_id, action, amount, event_date, description, metadata, created_by)
  values (
    v_loan.id, v_uid, 'charge_cancelled', v_charge.amount, public.user_today(), btrim(p_reason),
    jsonb_build_object('charge_id', v_charge.id, 'type', v_charge.type),
    v_uid
  );

  if v_loan.status = 'active' and v_loan.remaining_amount - v_charge.amount = 0 then
    insert into public.loan_history (loan_id, user_id, action, event_date, created_by)
    values (v_loan.id, v_uid, 'loan_paid', public.user_today(), v_uid);
  end if;

  return v_charge;
end;
$$;

create or replace function public.register_payment(
  p_loan_id      uuid,
  p_amount       numeric,
  p_method       public.payment_method,
  p_payment_date date,
  p_notes        text default null
)
returns public.payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_loan    public.loans;
  v_payment public.payments;
  v_settles boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_loan from public.loans
   where id = p_loan_id and user_id = v_uid
   for update;
  if not found then raise exception 'loan_not_found'; end if;
  if v_loan.status = 'cancelled' then raise exception 'loan_cancelled'; end if;
  if v_loan.status = 'paid' then raise exception 'loan_already_paid'; end if;

  if p_method is null then raise exception 'invalid_method'; end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'invalid_amount';
  end if;
  if p_amount > v_loan.remaining_amount then raise exception 'amount_exceeds_balance'; end if;
  if p_payment_date is null or p_payment_date < v_loan.start_date
     or p_payment_date > public.user_today() + 1 then
    raise exception 'invalid_date';
  end if;

  v_settles := (v_loan.remaining_amount - p_amount = 0);

  insert into public.payments (loan_id, user_id, amount, payment_method, payment_date, notes, created_by)
  values (p_loan_id, v_uid, p_amount, p_method, p_payment_date, nullif(btrim(p_notes), ''), v_uid)
  returning * into v_payment;

  update public.loans
     set paid_amount = paid_amount + p_amount,
         status  = case when v_settles then 'paid'::public.loan_status else 'active'::public.loan_status end,
         paid_at = case when v_settles then now() else null end
   where id = p_loan_id;

  insert into public.loan_history (loan_id, user_id, action, amount, event_date, description, metadata, created_by)
  values (
    p_loan_id, v_uid, 'payment_registered', p_amount, p_payment_date, v_payment.notes,
    jsonb_build_object('payment_id', v_payment.id, 'method', p_method, 'settled', v_settles),
    v_uid
  );

  if v_settles then
    insert into public.loan_history (loan_id, user_id, action, event_date, created_by)
    values (p_loan_id, v_uid, 'loan_paid', p_payment_date, v_uid);
  end if;

  return v_payment;
end;
$$;

create or replace function public.cancel_payment(p_payment_id uuid, p_reason text)
returns public.payments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_payment public.payments;
  v_loan    public.loans;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_reason is null or char_length(btrim(p_reason)) < 3 then raise exception 'reason_required'; end if;

  select * into v_payment from public.payments where id = p_payment_id and user_id = v_uid;
  if not found then raise exception 'payment_not_found'; end if;

  select * into v_loan from public.loans where id = v_payment.loan_id and user_id = v_uid for update;
  select * into v_payment from public.payments where id = p_payment_id for update;

  if v_payment.status = 'cancelled' then raise exception 'already_cancelled'; end if;
  if v_loan.status = 'cancelled' then raise exception 'loan_cancelled'; end if;

  update public.payments
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, cancel_reason = btrim(p_reason)
   where id = p_payment_id
   returning * into v_payment;

  update public.loans
     set paid_amount = paid_amount - v_payment.amount,
         status  = 'active',
         paid_at = null
   where id = v_loan.id;

  insert into public.loan_history (loan_id, user_id, action, amount, event_date, description, metadata, created_by)
  values (
    v_loan.id, v_uid, 'payment_cancelled', v_payment.amount, public.user_today(), btrim(p_reason),
    jsonb_build_object('payment_id', v_payment.id, 'method', v_payment.payment_method),
    v_uid
  );

  if v_loan.status = 'paid' then
    insert into public.loan_history (loan_id, user_id, action, event_date, created_by)
    values (v_loan.id, v_uid, 'loan_reopened', public.user_today(), v_uid);
  end if;

  return v_payment;
end;
$$;

-- Cancelar operação só é permitido sem pagamentos ativos (lançada por engano).
create or replace function public.cancel_loan(p_loan_id uuid, p_reason text)
returns public.loans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_loan public.loans;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_reason is null or char_length(btrim(p_reason)) < 3 then raise exception 'reason_required'; end if;

  select * into v_loan from public.loans where id = p_loan_id and user_id = v_uid for update;
  if not found then raise exception 'loan_not_found'; end if;
  if v_loan.status = 'cancelled' then raise exception 'already_cancelled'; end if;
  if v_loan.paid_amount > 0 then raise exception 'loan_has_payments'; end if;

  update public.loans
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, cancel_reason = btrim(p_reason)
   where id = p_loan_id
   returning * into v_loan;

  insert into public.loan_history (loan_id, user_id, action, event_date, description, created_by)
  values (p_loan_id, v_uid, 'loan_cancelled', public.user_today(), btrim(p_reason), v_uid);

  return v_loan;
end;
$$;

-- =====================================================================
-- Funções de leitura agregada (security invoker: a RLS filtra os dados)
-- =====================================================================

create or replace function public.dashboard_summary(p_due_soon_days integer default 3)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with t as (
    select public.user_today() as today
  ),
  l as (
    select
      x.*,
      greatest(x.paid_amount - x.interest_amount - x.charges_amount, 0) as principal_paid
    from public.loans x
    where x.user_id = auth.uid()
  )
  select jsonb_build_object(
    'today',                 t.today,
    'to_receive',            coalesce(sum(l.remaining_amount) filter (where l.status = 'active'), 0),
    'principal_outstanding', coalesce(sum(l.principal_amount - l.principal_paid) filter (where l.status = 'active'), 0),
    'active_count',          count(l.id) filter (where l.status = 'active'),
    'overdue_count',         count(l.id) filter (where l.status = 'active' and l.due_date < t.today),
    'overdue_amount',        coalesce(sum(l.remaining_amount) filter (where l.status = 'active' and l.due_date < t.today), 0),
    'due_today_count',       count(l.id) filter (where l.status = 'active' and l.due_date = t.today),
    'due_soon_count',        count(l.id) filter (where l.status = 'active' and l.due_date > t.today
                                                   and l.due_date <= t.today + p_due_soon_days),
    'total_lent',            coalesce(sum(l.principal_amount) filter (where l.status <> 'cancelled'), 0),
    'total_received',        coalesce(sum(l.paid_amount) filter (where l.status <> 'cancelled'), 0),
    'earnings_received',     coalesce(sum(least(l.paid_amount, l.interest_amount + l.charges_amount))
                                        filter (where l.status <> 'cancelled'), 0),
    'received_this_month',   (select coalesce(sum(p.amount), 0)
                                from public.payments p
                               where p.user_id = auth.uid()
                                 and p.status = 'active'
                                 and p.payment_date >= date_trunc('month', t.today)::date
                                 and p.payment_date <= t.today)
  )
  from t
  left join l on true
  group by t.today;
$$;

create or replace function public.report_summary(p_from date, p_to date)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with t as (select public.user_today() as today)
  select jsonb_build_object(
    'from', p_from,
    'to',   p_to,
    -- Movimento do período
    'total_lent',     (select coalesce(sum(principal_amount), 0) from public.loans
                        where user_id = auth.uid() and status <> 'cancelled'
                          and start_date between p_from and p_to),
    'total_interest', (select coalesce(sum(interest_amount), 0) from public.loans
                        where user_id = auth.uid() and status <> 'cancelled'
                          and start_date between p_from and p_to),
    'loans_count',    (select count(*) from public.loans
                        where user_id = auth.uid() and status <> 'cancelled'
                          and start_date between p_from and p_to),
    'total_charges',  (select coalesce(sum(amount), 0) from public.loan_charges
                        where user_id = auth.uid() and status = 'active'
                          and charge_date between p_from and p_to),
    'total_received', (select coalesce(sum(amount), 0) from public.payments
                        where user_id = auth.uid() and status = 'active'
                          and payment_date between p_from and p_to),
    'payments_count', (select count(*) from public.payments
                        where user_id = auth.uid() and status = 'active'
                          and payment_date between p_from and p_to),
    -- Fotografia atual da carteira
    'total_pending',  (select coalesce(sum(remaining_amount), 0) from public.loans
                        where user_id = auth.uid() and status = 'active'),
    'total_overdue',  (select coalesce(sum(remaining_amount), 0) from public.loans
                        where user_id = auth.uid() and status = 'active' and due_date < t.today),
    'series',         (select coalesce(jsonb_agg(jsonb_build_object('date', s.d, 'received', s.r) order by s.d), '[]'::jsonb)
                         from (select payment_date as d, sum(amount) as r
                                 from public.payments
                                where user_id = auth.uid() and status = 'active'
                                  and payment_date between p_from and p_to
                                group by payment_date) s)
  )
  from t;
$$;

-- Permissões de execução: apenas usuários autenticados.
revoke execute on function
  public.create_loan(uuid, numeric, numeric, integer, date, text),
  public.add_charge(uuid, public.charge_type, numeric, date, text),
  public.cancel_charge(uuid, text),
  public.register_payment(uuid, numeric, public.payment_method, date, text),
  public.cancel_payment(uuid, text),
  public.cancel_loan(uuid, text),
  public.dashboard_summary(integer),
  public.report_summary(date, date),
  public.user_today(),
  public.handle_new_user(),
  public.profiles_guard(),
  public.clients_guard_owner(),
  public.set_updated_at()
from public, anon;

grant execute on function
  public.create_loan(uuid, numeric, numeric, integer, date, text),
  public.add_charge(uuid, public.charge_type, numeric, date, text),
  public.cancel_charge(uuid, text),
  public.register_payment(uuid, numeric, public.payment_method, date, text),
  public.cancel_payment(uuid, text),
  public.cancel_loan(uuid, text),
  public.dashboard_summary(integer),
  public.report_summary(date, date),
  public.user_today()
to authenticated;
