-- ============================================================
-- Daphycel — pago pendiente ("paga al entregar equipo") ligado a
-- una orden de reparacion. Correr una sola vez, DESPUES de los
-- schema anteriores.
-- ============================================================

-- A que orden de reparacion queda ligada una venta con pago pendiente
-- (method='entrega' mientras no se cobra; nulo para el resto de ventas).
alter table sales add column if not exists linked_repair_id text references repairs(id);

-- create_sale gana un parametro opcional al final (compatible con el
-- create_sale anterior de 10 parametros, que se reemplaza por este).
drop function if exists create_sale(text,text,text,text,numeric,numeric,numeric,numeric,numeric,jsonb);

create or replace function create_sale(
  p_id text, p_customer_id text, p_method text, p_tipo text,
  p_subtotal numeric, p_iva numeric, p_total numeric, p_cash numeric, p_change numeric,
  p_items jsonb, p_linked_repair_id text default null
) returns void language plpgsql security definer as $$
declare it jsonb; cur_stock integer;
begin
  insert into sales(id, customer_id, method, tipo, subtotal, iva, total, cash, change_amount, linked_repair_id)
    values (p_id, p_customer_id, p_method, p_tipo, p_subtotal, p_iva, p_total, p_cash, p_change, p_linked_repair_id);
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

grant execute on function create_sale(text,text,text,text,numeric,numeric,numeric,numeric,numeric,jsonb,text) to anon;
