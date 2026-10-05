# Daphycel

Tienda de refacciones y accesorios de telefonía. Dos aplicaciones web, cada una un único archivo HTML autocontenido.

## Archivos del proyecto

- **`daphycel.html`** — Panel interno del negocio. Requiere login (usuario/contraseña) con 3 roles: `dueno`, `administrador`, `vendedor`, cada uno con permisos distintos. Incluye catálogo, punto de venta (POS) con apertura/cierre de caja, cartera de clientes (crédito/fiado), inventario, panel de estadísticas y gestión de usuarios.
- **`daphycel-cliente.html`** — Tienda pública de cara al cliente final, sin login. Incluye catálogo tipo marketplace (con reseñas y calificación por estrellas), consulta de estado de reparaciones por número de orden, y una sección "Mi cuenta" con búsqueda privada por nombre/número de cliente/orden.

## Stack y convenciones técnicas

- **Vanilla HTML/CSS/JS en el frontend.** Sin framework, sin bundler, sin build step. Cada archivo `.html` es autocontenido: su `<style>` y su `<script>` viven en el mismo archivo. Única dependencia de runtime: el cliente JS de Supabase vía CDN (`@supabase/supabase-js@2`).
- **Backend real: Supabase (Postgres + PostgREST + RPC).** Desde octubre 2026 la fuente de verdad **ya no es `localStorage`**, es una base de datos Postgres alojada en Supabase, compartida de verdad entre cualquier dispositivo que abra cualquiera de los dos archivos (antes la "fuente única" solo sincronizaba entre pestañas del mismo navegador). Ver `supabase-schema.sql` y `supabase-schema-2.sql` para el esquema completo (tablas, políticas de RLS y funciones RPC) — hay que correr ambos, en ese orden, en el SQL Editor de un proyecto de Supabase nuevo para poder usar la app desde cero.
  - **Conexión:** `SUPABASE_URL` y `SUPABASE_KEY` (la clave pública `anon`/`publishable`, segura para el navegador) están hardcodeadas al inicio del bloque `PERSISTENCIA` de ambos archivos — es intencional, esa clave está diseñada para ser pública.
  - **Operaciones atómicas vía RPC** (evitan condiciones de carrera reales entre dispositivos, algo que `localStorage` nunca tuvo que resolver): `increment_counter`, `create_sale` (usada tanto por `cobrar()` del panel como por `checkoutOnline()` de la tienda — valida stock servidor y revierte la transacción si no alcanza), `cancel_sale`, `abonar`.
  - **Contraseñas nunca viajan al cliente.** La tabla `users` no tiene política pública de lectura/escritura; todo pasa por funciones `SECURITY DEFINER` (`login_check`, `create_user`, `change_password`, `delete_user`) que jamás devuelven la columna `password`. El resto de las tablas (`products`, `customers`, `sales`, `repairs`, `caja`, `settings`, etc.) sí tienen política pública de lectura/escritura con la clave `anon` — no hay reglas por rol a nivel de base de datos, los roles (`dueno`/`administrador`/`vendedor`) son solo gating de UI. Si en algún momento se necesita seguridad real por rol a nivel de datos, hay que migrar a Supabase Auth con RLS por usuario — no está hecho todavía.
  - **Semilla y reseteo:** `window.DaphycelDB.reset()` ya no reinicia nada (antes borraba `localStorage`); ahora solo informa que el catálogo vive en Supabase. Si hace falta reiniciar datos de prueba, usar `seed-supabase.js`/`reset-supabase.js` (en el scratchpad de la sesión que hizo la migración, no están en el repo) o hacerlo directo en el SQL Editor.
- **Dependencias externas** cargadas por CDN únicamente: Google Fonts (Space Grotesk, IBM Plex Sans, IBM Plex Mono), JsBarcode y qrcodejs vía `cdnjs.cloudflare.com`, `@supabase/supabase-js` vía `cdn.jsdelivr.net`.
- **Playwright está instalado globalmente en esta máquina** (`npm install -g playwright`, navegador Chromium) exclusivamente como herramienta de testing. No es una dependencia del proyecto ni implica que la app necesite Node/npm para funcionar — los archivos `.html` se abren directamente en el navegador o se sirven estáticos; lo único que requiere Supabase es tener internet.
- **Paleta azul rey** en ambos archivos, con variantes distintas: `daphycel.html` usa fondo crema (`#f8f6f1`) con acento `#3d6fd6`; `daphycel-cliente.html` usa fondo beige cálido (`#f7f2e8`) con acento `#2540d6`. Mantener esta identidad visual al agregar features.

## Modelo de datos

El esquema relacional vive en Supabase (`supabase-schema.sql` + `supabase-schema-2.sql`) — ya no es un blob JSON único como en la primera versión con `localStorage` (documentada, ya superada, en `SPEC.md`/`FINDINGS.md`). Tablas: `products` (+ `product_reviews` en tabla aparte), `customers`, `sales` (+ `sale_items`), `repairs` (doble identificador: `id` interno `EQ-###` para el panel, `order_no` público `OR-####` que consulta el cliente), `users` (sin acceso público directo), `counters`, `caja` (+ `caja_cortes`), `settings`. El catálogo maestro son los 20 SKUs originales de la tienda (con `description`/`subcat`/reseñas). El checkout de la tienda genera una venta real (`method:'online'`, sin IVA, fuera de los cortes de caja) a través de la misma función `create_sale` que usa el panel. Cualquier cambio futuro al esquema debe ir en un nuevo archivo `.sql` versionado (no editar los dos existentes retroactivamente) y documentarse aquí antes de tocar código de la app.

**Campo `notifyEmail`** (tabla `settings`, clave `notify_email`): correo al que se avisa cuando se cambia la contraseña de cualquier cuenta. Solo se edita desde la vista Usuarios del panel (restringida al rol `dueno` en la UI). Sin servicio de correo propio, el aviso se envía abriendo un enlace `mailto:` con el mensaje redactado — no hay envío automático real ni se expone ninguna credencial de proveedor de email en el código.

## Reglas para cambios (Generator)

- **Cambios quirúrgicos.** Preferir ediciones puntuales sobre reescribir archivos completos. Mantener el estilo, nombres de variables/funciones y estructura ya existentes en cada archivo.
- **No romper lo que ya funciona.** Antes de modificar una sección compartida entre vistas (ej. `products`, `fmt`, `findProduct`), revisar todos los lugares que la usan dentro del mismo archivo.
- **Commits chicos y frecuentes**, uno por unidad de trabajo lógica, con mensajes descriptivos en español acordes al resto del proyecto.
- **Mantener el idioma español** en toda la UI, comentarios de cara a datos de ejemplo (nombres, productos) y mensajes al usuario.

## Cómo probar

Abrir el archivo `.html` correspondiente directamente en un navegador (con internet, para llegar a Supabase) — sigue sin requerir `npm install` ni servidor de desarrollo propio. Para pruebas automatizadas, Playwright con dos `browserContext` **independientes** (sin compartir cookies/storage) es la forma correcta de probar que los datos realmente se comparten entre "dispositivos" distintos, no solo entre pestañas — así quedó verificada esta migración (ver commits de octubre 2026). `window.DaphycelDB.read()` devuelve el estado completo desde Supabase para inspección en consola.
