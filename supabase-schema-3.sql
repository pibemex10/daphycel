-- ============================================================
-- Daphycel — fotos de producto (Supabase Storage)
-- Correr una sola vez, DESPUES de supabase-schema.sql y supabase-schema-2.sql
-- ============================================================

-- Columna nueva en products para guardar el link publico de la foto
alter table products add column if not exists image_url text;

-- Bucket publico donde se guardan las fotos subidas desde el panel
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- Lectura publica (para que la tienda cliente pueda mostrar las fotos)
create policy "public read product-images"
on storage.objects for select
using (bucket_id = 'product-images');

-- Subida y reemplazo publicos (misma logica de seguridad que el resto de la app:
-- la clave anon puede escribir, sin distincion de rol a nivel de base de datos --
-- ver FINDINGS.md F-02).
create policy "public insert product-images"
on storage.objects for insert
with check (bucket_id = 'product-images');

create policy "public update product-images"
on storage.objects for update
using (bucket_id = 'product-images');
