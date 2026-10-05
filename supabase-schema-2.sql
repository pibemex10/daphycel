-- ============================================================
-- Daphycel — funciones adicionales para operaciones atomicas
-- Correr una sola vez, DESPUES de supabase-schema.sql
-- ============================================================

alter table product_reviews drop constraint product_reviews_sku_fkey;
alter table product_reviews add constraint product_reviews_sku_fkey
  foreign key (sku) references products(sku) on delete cascade on update cascade;

create or replace function increment_counter(p_key text)
returns integer language plpgsql security definer as $$
declare v integer;
begin
  update counters set value = value + 1 where key = p_key returning value into v;
  return v;
end; $$;

create or replace function create_sale(
  p_id text, p_customer_id text, p_method text, p_tipo text,
  p_subtotal numeric, p_iva numeric, p_total numeric, p_cash numeric, p_change numeric,
  p_items jsonb
) returns void language plpgsql security definer as $$
declare it jsonb; cur_stock integer;
begin
  insert into sales(id, customer_id, method, tipo, subtotal, iva, total, cash, change_amount)
    values (p_id, p_customer_id, p_method, p_tipo, p_subtotal, p_iva, p_total, p_cash, p_change);
  for it in select * from jsonb_array_elements(p_items) loop
    insert into sale_items(sale_id, sku, name, qty, price)
      values (p_id, it->>'sku', it->>'name', (it->>'qty')::int, (it->>'price')::numeric);
    if (it->>'sku') is not null then
      update products set stock = stock - (it->>'qty')::int where sku = it->>'sku'
        returning stock into cur_stock;
      if cur_stock < 0 then
        raise exception 'Stock insuficiente para %', it->>'name';
      end if;
    end if;
  end loop;
  if p_customer_id is not null and p_method = 'credito' then
    update customers set balance = balance + p_total where id = p_customer_id;
  end if;
end; $$;

create or replace function cancel_sale(p_sale_id text)
returns void language plpgsql security definer as $$
declare s record; it record;
begin
  select * into s from sales where id = p_sale_id and cancelled = false;
  if not found then raise exception 'Venta no encontrada o ya cancelada'; end if;
  for it in select * from sale_items where sale_id = p_sale_id loop
    if it.sku is not null then
      update products set stock = stock + it.qty where sku = it.sku;
    end if;
  end loop;
  if s.customer_id is not null and s.method = 'credito' then
    update customers set balance = greatest(0, balance - s.total) where id = s.customer_id;
  end if;
  update sales set cancelled = true where id = p_sale_id;
end; $$;

create or replace function abonar(p_customer_id text, p_amount numeric)
returns void language plpgsql security definer as $$
begin
  update customers set balance = greatest(0, balance - p_amount) where id = p_customer_id;
end; $$;

grant execute on function increment_counter(text) to anon;
grant execute on function create_sale(text,text,text,text,numeric,numeric,numeric,numeric,numeric,jsonb) to anon;
grant execute on function cancel_sale(text) to anon;
grant execute on function abonar(text,numeric) to anon;
