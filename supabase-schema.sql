-- ============================================================
-- Daphycel — esquema compartido en Supabase (Postgres)
-- Pegar completo en SQL Editor > New query > Run.
-- ============================================================

-- ---------- productos ----------
create table products (
  sku text primary key,
  name text not null,
  cat text not null,
  subcat text,
  price numeric not null default 0,
  stock integer not null default 0,
  description text default ''
);

create table product_reviews (
  id bigint generated always as identity primary key,
  sku text not null references products(sku) on delete cascade,
  author text not null,
  rating integer not null check (rating between 1 and 5),
  comment text not null,
  created_at timestamptz not null default now()
);

-- ---------- clientes ----------
create table customers (
  id text primary key,
  name text not null,
  phone text default '',
  notes text default '',
  since date not null default current_date,
  balance numeric not null default 0
);

-- ---------- ventas ----------
create table sales (
  id text primary key,
  subtotal numeric not null default 0,
  iva numeric not null default 0,
  total numeric not null default 0,
  cash numeric not null default 0,
  change_amount numeric not null default 0,
  ts timestamptz not null default now(),
  customer_id text references customers(id),
  method text not null,
  tipo text not null,
  cancelled boolean not null default false
);

create table sale_items (
  id bigint generated always as identity primary key,
  sale_id text not null references sales(id) on delete cascade,
  sku text,
  name text not null,
  qty integer not null,
  price numeric not null
);

-- ---------- reparaciones ----------
create table repairs (
  id text primary key,
  order_no text unique not null,
  customer text not null,
  customer_id text references customers(id),
  brand text,
  model text,
  device text,
  details text default '',
  work text,
  accessories text default 'Ninguno',
  pass text default 'Sin contraseña',
  received date not null default current_date,
  status text not null default 'Recibido',
  type text not null default 'reparacion',
  cost numeric not null default 0,
  charged boolean not null default false
);

-- ---------- usuarios (password NUNCA se expone via API publica) ----------
create table users (
  username text primary key,
  name text not null,
  password text not null,
  role text not null check (role in ('dueno','administrador','vendedor'))
);

create view users_public as
  select username, name, role from users;

-- ---------- contadores (incremento atomico, sin condiciones de carrera) ----------
create table counters (
  key text primary key,
  value integer not null
);

-- ---------- caja ----------
create table caja (
  id int primary key default 1 check (id = 1),
  abierta boolean not null default false,
  monto_inicial numeric not null default 0,
  apertura_hora text,
  apertura_ts timestamptz
);

create table caja_cortes (
  id bigint generated always as identity primary key,
  categoria text not null,
  tipo text not null,
  hora text not null,
  efectivo numeric not null default 0,
  tarjeta numeric not null default 0,
  transferencia numeric not null default 0,
  total_corte numeric not null default 0,
  esperado numeric not null default 0,
  contado numeric,
  created_at timestamptz not null default now()
);

-- ---------- ajustes (correo de notificaciones, etc.) ----------
create table settings (
  key text primary key,
  value text
);

-- ============================================================
-- Seguridad (RLS)
-- ============================================================
alter table products enable row level security;
alter table product_reviews enable row level security;
alter table customers enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table repairs enable row level security;
alter table users enable row level security;
alter table counters enable row level security;
alter table caja enable row level security;
alter table caja_cortes enable row level security;
alter table settings enable row level security;

create policy "public all products" on products for all using (true) with check (true);
create policy "public all product_reviews" on product_reviews for all using (true) with check (true);
create policy "public all customers" on customers for all using (true) with check (true);
create policy "public all sales" on sales for all using (true) with check (true);
create policy "public all sale_items" on sale_items for all using (true) with check (true);
create policy "public all repairs" on repairs for all using (true) with check (true);
create policy "public all counters" on counters for all using (true) with check (true);
create policy "public all caja" on caja for all using (true) with check (true);
create policy "public all caja_cortes" on caja_cortes for all using (true) with check (true);
create policy "public all settings" on settings for all using (true) with check (true);

-- "users" se queda SIN politica publica: nadie puede leerla ni escribirla
-- directo con la clave anonima. Solo se toca a traves de estas funciones:

grant select on users_public to anon;

create or replace function login_check(p_username text, p_password text)
returns table(username text, name text, role text)
language sql security definer
as $$
  select username, name, role from users
  where lower(username) = lower(p_username) and password = p_password;
$$;

create or replace function create_user(p_name text, p_username text, p_password text, p_role text)
returns void language sql security definer as $$
  insert into users(username, name, password, role) values (p_username, p_name, p_password, p_role);
$$;

create or replace function change_password(p_username text, p_new_password text)
returns void language sql security definer as $$
  update users set password = p_new_password where username = p_username;
$$;

create or replace function delete_user(p_username text)
returns void language sql security definer as $$
  delete from users where username = p_username and role <> 'dueno';
$$;

grant execute on function login_check(text,text) to anon;
grant execute on function create_user(text,text,text,text) to anon;
grant execute on function change_password(text,text) to anon;
grant execute on function delete_user(text) to anon;

-- ============================================================
-- Datos iniciales minimos (usuarios, contadores, caja, ajustes).
-- El catalogo/clientes/ventas/reparaciones de ejemplo los carga
-- un script aparte para no transcribirlos a mano aqui.
-- ============================================================
insert into users(username,name,password,role) values
  ('dueno','Dueño','dueno123','dueno'),
  ('vendedor','Karla Méndez','vendedor123','vendedor'),
  ('admin','Luis Fernández','admin123','administrador');

insert into counters(key,value) values
  ('sale',1005),('client',5),('repair',12),('order',1012);

insert into caja(id,abierta,monto_inicial) values (1,false,0);

insert into settings(key,value) values ('notify_email','');
