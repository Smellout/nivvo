// Teste da migration em Postgres real (PGlite/WASM), com Auth do Supabase simulado.
// Uso: cd supabase/tests && npm install && npm test

import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';

const migration = readFileSync(process.argv[2] ?? new URL('../migrations/20261008000000_init.sql', import.meta.url), 'utf8');
const db = new PGlite();

const U1 = '11111111-1111-1111-1111-111111111111';
const U2 = '22222222-2222-2222-2222-222222222222';

// --- Simulação mínima do ambiente Supabase -------------------------------
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (
    id uuid primary key,
    email text,
    raw_user_meta_data jsonb default '{}'::jsonb
  );
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema auth to anon, authenticated;
  grant execute on function auth.uid() to anon, authenticated;
  grant usage on schema public to anon, authenticated;
  alter default privileges in schema public grant all on tables to anon, authenticated;
  alter default privileges in schema public grant all on functions to anon, authenticated;
`);

await db.exec(migration);

await db.exec(`
  insert into auth.users (id, email, raw_user_meta_data) values
    ('${U1}', 'u1@nivvo.app', '{"name":"Daniel"}'),
    ('${U2}', 'u2@nivvo.app', '{"name":"Intruso"}');
`);

let failures = 0;
let passes = 0;
const ok = (cond, msg) => {
  if (cond) { passes++; console.log('  ✓', msg); }
  else { failures++; console.log('  ✗', msg); }
};

async function as(user, sql, params = []) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${user ?? ''}', false); set role ${user ? 'authenticated' : 'anon'};`);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role;');
  }
}

async function expectError(user, sql, params, expected, msg) {
  try {
    await as(user, sql, params);
    ok(false, `${msg} (esperava erro "${expected}", mas passou)`);
  } catch (e) {
    ok(String(e.message).includes(expected), `${msg} → ${e.message}`);
  }
}

const one = async (user, sql, params) => (await as(user, sql, params)).rows[0];
const today = (await db.query(`select (now() at time zone 'America/Sao_Paulo')::date as d`)).rows[0].d;
const iso = (d) => d.toISOString().slice(0, 10);
const addDays = (d, n) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + n));
const start = addDays(today, -40);

console.log('\nPerfil criado por trigger');
const prof = await one(U1, `select * from profiles`);
ok(prof?.name === 'Daniel', 'profile criado com o nome dos metadados');

console.log('\nCriação de operação (exemplo da especificação)');
const client = await one(U1, `insert into clients (name, phone, cpf) values ('Fulano da Silva', '11987654321', '52998224725') returning *`);
ok(client.user_id === U1 && client.created_by === U1, 'cliente recebe user_id/created_by do usuário logado');

const loan = await one(U1, `select * from create_loan($1, 300, 15, 30, $2)`, [client.id, iso(start)]);
ok(Number(loan.interest_amount) === 45, 'juros = 45,00');
ok(Number(loan.total_initial_amount) === 345, 'total inicial = 345,00');
ok(iso(loan.due_date) === iso(addDays(start, 30)), 'vencimento = início + 30 dias');
ok(loan.status === 'active' && Number(loan.remaining_amount) === 345, 'status ativo, saldo 345');

const odd = await one(U1, `select * from create_loan($1, 333.33, 12.5, 10, $2)`, [client.id, iso(today)]);
ok(Number(odd.interest_amount) === 41.67, 'arredondamento 333,33 × 12,5% = 41,67 (igual ao app)');

console.log('\nEncargos e pagamento parcial');
const d = (n) => iso(addDays(start, n));
const c1 = await one(U1, `select * from add_charge($1, 'late_interest', 20, $2, 'atraso')`, [loan.id, d(31)]);
await as(U1, `select add_charge($1, 'late_interest', 15, $2)`, [loan.id, d(35)]);
await as(U1, `select add_charge($1, 'fine', 25, $2)`, [loan.id, d(38)]);
let l = await one(U1, `select * from loans where id = $1`, [loan.id]);
ok(Number(l.charges_amount) === 60, 'encargos somam 60');
ok(Number(l.remaining_amount) === 405, 'total atualizado 405');

const p1 = await one(U1, `select * from register_payment($1, 100, 'pix', $2, 'parcial')`, [loan.id, d(35)]);
l = await one(U1, `select * from loan_overview where id = $1`, [loan.id]);
ok(Number(l.remaining_amount) === 305 && l.status === 'active', 'pagamento parcial de 100 → saldo 305, ativa');
ok(Number(l.earnings_received) === 100, 'alocação: 100 recebidos contam como encargos/juros');

await expectError(U1, `select register_payment($1, 305.01, 'pix', $2)`, [loan.id, d(36)], 'amount_exceeds_balance', 'pagamento acima do saldo é bloqueado');
await expectError(U1, `select register_payment($1, 10.005, 'pix', $2)`, [loan.id, d(36)], 'invalid_amount', 'mais de 2 casas decimais é bloqueado');
await expectError(U1, `select register_payment($1, 10, 'pix', $2)`, [loan.id, iso(addDays(today, 5))], 'invalid_date', 'pagamento com data futura é bloqueado');
await expectError(U1, `select register_payment($1, 10, 'pix', $2)`, [loan.id, d(-1)], 'invalid_date', 'pagamento antes do início é bloqueado');

console.log('\nCancelamento de encargo (lógico, com motivo)');
await expectError(U1, `select cancel_charge($1, '')`, [c1.id], 'reason_required', 'motivo obrigatório');
await as(U1, `select cancel_charge($1, 'lançado errado')`, [c1.id]);
const cc = await one(U1, `select * from loan_charges where id = $1`, [c1.id]);
ok(cc.status === 'cancelled' && cc.cancelled_by === U1 && cc.cancel_reason === 'lançado errado', 'encargo cancelado com usuário e motivo (não excluído)');
l = await one(U1, `select * from loans where id = $1`, [loan.id]);
ok(Number(l.remaining_amount) === 285, 'saldo recalculado para 285');
await expectError(U1, `select cancel_charge($1, 'de novo')`, [c1.id], 'already_cancelled', 'não cancela duas vezes');

console.log('\nQuitação e estorno');
await as(U1, `select register_payment($1, 285, 'cash', $2)`, [loan.id, d(39)]);
l = await one(U1, `select * from loans where id = $1`, [loan.id]);
ok(l.status === 'paid' && Number(l.remaining_amount) === 0 && l.paid_at !== null, 'saldo zero → Paga');
await expectError(U1, `select register_payment($1, 1, 'pix', $2)`, [loan.id, d(39)], 'loan_already_paid', 'não aceita pagamento em operação quitada');
const fine = await one(U1, `select id from loan_charges where loan_id = $1 and type = 'fine'`, [loan.id]);
await expectError(U1, `select cancel_charge($1, 'tentativa')`, [fine.id], 'balance_would_be_negative', 'cancelar encargo de operação quitada é bloqueado (saldo ficaria negativo)');
await as(U1, `select cancel_payment($1, 'valor digitado errado')`, [p1.id]);
l = await one(U1, `select * from loans where id = $1`, [loan.id]);
ok(l.status === 'active' && Number(l.remaining_amount) === 100 && l.paid_at === null, 'estorno reabre a operação (saldo 100)');
await expectError(U1, `select cancel_loan($1, 'engano')`, [loan.id], 'loan_has_payments', 'não cancela operação com pagamentos');

const hist = (await as(U1, `select action from loan_history where loan_id = $1 order by created_at, id`, [loan.id])).rows.map((r) => r.action);
ok(['loan_created', 'charge_added', 'payment_registered', 'charge_cancelled', 'loan_paid', 'payment_cancelled', 'loan_reopened'].every((a) => hist.includes(a)), `histórico completo: ${hist.join(', ')}`);

console.log('\nImutabilidade do histórico financeiro');
await expectError(U1, `update loans set paid_amount = 999 where id = $1`, [loan.id], 'permission denied', 'app não altera saldo diretamente');
await expectError(U1, `insert into payments (loan_id, user_id, amount, payment_method, payment_date, created_by) values ($1, $2, 10, 'pix', current_date, $2)`, [loan.id, U1], 'permission denied', 'app não insere pagamento fora da RPC');
await expectError(U1, `delete from payments where id = $1`, [p1.id], 'permission denied', 'pagamentos não podem ser excluídos');
await expectError(U1, `delete from loan_history`, [], 'permission denied', 'histórico não pode ser excluído');
await expectError(U1, `delete from clients where id = $1`, [client.id], 'violates foreign key', 'cliente com operações não pode ser excluído');

console.log('\nIsolamento entre usuários (RLS)');
ok((await as(U2, `select * from loans`)).rows.length === 0, 'U2 não vê operações de U1');
ok((await as(U2, `select * from clients`)).rows.length === 0, 'U2 não vê clientes de U1');
ok((await as(U2, `select * from loan_overview`)).rows.length === 0, 'U2 não vê a view de operações de U1');
ok((await as(U2, `select * from client_summary`)).rows.length === 0, 'U2 não vê a view de clientes de U1');
ok((await as(U2, `select * from payments`)).rows.length === 0, 'U2 não vê pagamentos de U1');
await expectError(U2, `select register_payment($1, 10, 'pix', current_date)`, [loan.id], 'loan_not_found', 'U2 não registra pagamento na operação de U1');
await expectError(U2, `select add_charge($1, 'fine', 10, current_date)`, [loan.id], 'loan_not_found', 'U2 não lança encargo na operação de U1');
await expectError(U2, `select cancel_payment($1, 'hack')`, [p1.id], 'payment_not_found', 'U2 não estorna pagamento de U1');
await expectError(U2, `select create_loan($1, 100, 10, 10, current_date)`, [client.id], 'client_not_found', 'U2 não cria operação para cliente de U1');
await expectError(U2, `insert into clients (name, user_id) values ('Falso', $1)`, [U1], 'row-level security', 'U2 não cria cliente em nome de U1');
const upd = await as(U2, `update clients set name = 'hack' where id = $1`, [client.id]);
ok(upd.affectedRows === 0, 'U2 não edita cliente de U1');
await expectError(U1, `update clients set user_id = $1 where id = $2`, [U2, client.id], 'immutable_field', 'U1 não transfere cliente para outro usuário');
await expectError(null, `select * from clients`, [], 'permission denied', 'anônimo não acessa nada');
await expectError(null, `select create_loan($1, 100, 10, 10, current_date)`, [client.id], 'permission denied', 'anônimo não executa RPC');

console.log('\nResumos');
const dash = (await one(U1, `select dashboard_summary() as s`)).s;
ok(Number(dash.to_receive) === 100 + 375.00, `dashboard: a receber ${dash.to_receive}`);
ok(dash.active_count === 2 && dash.overdue_count === 1, `dashboard: ${dash.active_count} ativas, ${dash.overdue_count} vencida`);
ok(Number(dash.principal_outstanding) + 0 >= 0, `dashboard: principal em aberto ${dash.principal_outstanding}`);
const rep = (await one(U1, `select report_summary($1, $2) as r`, [iso(start), iso(today)])).r;
ok(Number(rep.total_received) === 285 && rep.payments_count === 1, `relatório: recebido ${rep.total_received} (estorno não conta)`);
ok(Number(rep.total_lent) === 633.33 && rep.loans_count === 2, `relatório: emprestado ${rep.total_lent}`);
ok(Number(rep.total_charges) === 40, `relatório: encargos ativos ${rep.total_charges}`);
ok(Array.isArray(rep.series), 'relatório: série diária');
const cs = await one(U1, `select * from client_summary where id = $1`, [client.id]);
ok(Number(cs.balance) === 475 && Number(cs.loans_count) === 2 && Number(cs.overdue_count) === 1, `client_summary: saldo ${cs.balance}, ${cs.loans_count} operações, ${cs.overdue_count} vencida`);
const dash2 = (await one(U2, `select dashboard_summary() as s`)).s;
ok(Number(dash2.to_receive) === 0 && dash2.active_count === 0, 'dashboard de U2 vazio (sem vazamento)');

console.log('\nCancelamento de operação');
const l3 = await one(U1, `select * from create_loan($1, 50, 0, 7, current_date)`, [client.id]);
await as(U1, `select cancel_loan($1, 'cadastro duplicado')`, [l3.id]);
const l3b = await one(U1, `select * from loans where id = $1`, [l3.id]);
ok(l3b.status === 'cancelled' && l3b.cancelled_by === U1, 'operação sem pagamentos pode ser cancelada');
await expectError(U1, `select register_payment($1, 10, 'pix', current_date)`, [l3.id], 'loan_cancelled', 'operação cancelada não recebe pagamento');

console.log(`\n${passes} ok, ${failures} falha(s)`);
process.exit(failures ? 1 : 0);
