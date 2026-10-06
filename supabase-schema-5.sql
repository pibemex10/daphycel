-- ============================================================
-- Daphycel — permisos configurables por rol (administrador/vendedor).
-- Correr una sola vez, DESPUES de los schema anteriores.
-- ============================================================

-- Se reutiliza la tabla settings (key/value de texto) que ya existe.
-- El valor es un JSON con el permiso de cada rol; el dueño siempre
-- tiene acceso a todo y no depende de este ajuste.
insert into settings (key, value) values (
  'role_permissions',
  '{"administrador":{"inventario":true,"panel":false,"cancelaciones":true},"vendedor":{"inventario":false,"panel":false,"cancelaciones":false}}'
)
on conflict (key) do nothing;
