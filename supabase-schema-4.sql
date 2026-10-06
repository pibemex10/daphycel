-- ============================================================
-- Daphycel — numero de producto automatico (DPC-########) y
-- codigo de barras escaneado, como dos campos separados.
-- Correr una sola vez, DESPUES de los schema anteriores.
-- ============================================================

-- Codigo de barras del producto (el que trae de fabrica, se llena
-- escaneando con un lector fisico -- es independiente del sku).
alter table products add column if not exists barcode text;

-- Contador para el numero de producto interno (DPC-00000001, DPC-00000002, ...).
insert into counters (key, value) values ('producto', 0)
on conflict (key) do nothing;
