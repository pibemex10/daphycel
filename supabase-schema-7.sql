-- ============================================================
-- Daphycel — permitir que varios equipos registrados juntos (un
-- mismo cliente, modo "Varios equipos") compartan un solo numero
-- de orden, para poder mandarle al cliente un solo ticket/link en
-- vez de uno distinto por cada equipo.
-- Correr una sola vez, DESPUES de los schema anteriores.
-- ============================================================

alter table repairs drop constraint if exists repairs_order_no_key;
