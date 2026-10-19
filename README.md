# Daphycel

Tienda de refacciones y accesorios de telefonía. Dos aplicaciones web autocontenidas que
comparten **una sola fuente de verdad real**: una base de datos Postgres en [Supabase](https://supabase.com),
accesible desde cualquier dispositivo — ya no `localStorage` (eso solo sincronizaba entre pestañas
del mismo navegador; ver el historial de octubre 2026 para la migración).

- **`daphycel.html`** — panel interno (login, POS, caja, clientes, inventario, usuarios).
- **`daphycel-cliente.html`** — tienda pública (catálogo, reseñas, carrito, reparaciones, Mi cuenta).

Lo que se registra en cualquiera de las dos, **desde cualquier dispositivo**, se refleja en la otra
al recargarla o navegar hacia ella.

## Cómo arrancar la app

Abrir el archivo directamente en el navegador (con conexión a internet, para llegar a Supabase).
Sigue sin build ni `npm install` propio del frontend.

```powershell
Start-Process .\daphycel.html          # panel interno
Start-Process .\daphycel-cliente.html  # tienda pública
```

Credenciales del panel: `dueno/dueno123`, `admin/admin123`, `vendedor/vendedor123`.

`file://` y `http://` ya no importan para compartir datos (a diferencia de la versión con
`localStorage`): como la fuente de verdad es Supabase, dos dispositivos cualquiera —abiertos como
sea— ven los mismos datos. Servir por HTTP sigue siendo útil solo para pruebas automatizadas con
Playwright, por comodidad de navegación, no por requisito de origen.

## Primer arranque desde cero (proyecto nuevo de Supabase)

1. Crear un proyecto gratis en [supabase.com](https://supabase.com).
2. Correr, en este orden, en el **SQL Editor** del proyecto:
   - `supabase-schema.sql` — tablas, seguridad (RLS) y funciones de usuarios/login.
   - `supabase-schema-2.sql` — funciones atómicas (`create_sale`, `cancel_sale`, `abonar`, `increment_counter`).
   - `supabase-schema-3.sql` — columna `products.image_url` y bucket público `product-images` (fotos de producto).
   - `supabase-schema-4.sql` — columna `products.barcode` y el contador `producto` (número de producto automático `DPC-########`).
   - `supabase-schema-5.sql` — fila `role_permissions` en `settings` (permisos configurables para administrador/vendedor).
   - `supabase-schema-6.sql` — columna `sales.linked_repair_id` y nueva versión de `create_sale` (pago pendiente "paga al entregar equipo"). **Correrlo antes de desplegar** la versión del panel que lo usa.
   - `supabase-schema-7.sql` — quita el `unique` de `repairs.order_no`, para que varios equipos registrados juntos ("varios equipos") puedan compartir un solo número de orden/ticket.
3. Copiar el **Project URL** y la clave **`anon` / `publishable`** (nunca la `service_role`) a las
   constantes `SUPABASE_URL` / `SUPABASE_KEY` al inicio del bloque `PERSISTENCIA` de **ambos** archivos.
4. Sembrar el catálogo/clientes/ventas/reparaciones de ejemplo (no hay script en el repo; se hizo con
   un script Node de un solo uso contra la REST API — replicar el contenido de `seedDB()`/`FINDINGS.md`
   si hace falta reconstruirlo).

## Persistencia

Ya no es un blob JSON único: es un esquema relacional normal en Postgres.

| Tabla | Para qué |
|---|---|
| `products` + `product_reviews` | Catálogo y reseñas (tabla aparte, no array embebido) |
| `customers` | Cartera de clientes (saldo/crédito) |
| `sales` + `sale_items` | Ventas (POS, online, cobros de reparación) y sus líneas |
| `repairs` | Equipos en reparación — `id` interno (`EQ-###`) + `order_no` público (`OR-####`) |
| `users` | Login — **sin política pública**, solo accesible vía funciones RPC |
| `counters` | Folios consecutivos (`sale`, `client`, `repair`, `order`), incrementados atómicamente |
| `caja` + `caja_cortes` | Apertura/cierre de caja y su historial de cortes |
| `settings` | Ajustes sueltos (hoy solo `notify_email`) |

- **Contraseñas nunca se leen desde el navegador.** `users` no tiene `select`/`insert`/`update` público;
  todo pasa por `login_check`, `create_user`, `change_password`, `delete_user` (funciones
  `SECURITY DEFINER` que nunca devuelven la columna `password`).
- **Operaciones de dinero son atómicas** vía RPC (`create_sale`, `cancel_sale`, `abonar`,
  `increment_counter`) — resuelven condiciones de carrera reales entre dispositivos, algo que la
  versión anterior con `localStorage` no necesitaba (ahí solo había "última escritura gana" entre
  pestañas del mismo navegador).
- El resto de las tablas tiene política pública de lectura/escritura con la clave `anon`: los roles
  (`dueno`/`administrador`/`vendedor`) son **solo gating de interfaz**, no reglas de base de datos.
  Migrar a Supabase Auth con RLS por usuario sería el siguiente paso si se necesita seguridad real
  por rol a nivel de datos.
- El carrito, el ticket del POS y las sesiones de login **no** se persisten (siguen siendo estado
  efímero en memoria, como antes).

### API de depuración

Disponible en ambos archivos desde la consola del navegador:

```js
window.DaphycelDB.read()   // trae el estado completo desde Supabase (products, customers, sales...)
window.DaphycelDB.reset()  // ya no reinicia nada; solo explica que los datos viven en Supabase
```

## Publicado en internet (GitHub Pages)

- **Tienda pública:** https://pibemex10.github.io/daphycel/daphycel-cliente.html
- **Panel interno:** https://pibemex10.github.io/daphycel/daphycel.html

Repo público (`github.com/pibemex10/daphycel`) — necesario para que GitHub Pages sea gratis. Lo que
se ve públicamente como sitio es solo `daphycel.html`, `daphycel-cliente.html` e `index.html` (redirige
a la tienda); el resto del repo (docs, `.sql`) es visible como código fuente en GitHub pero no se sirve
como parte del sitio. **No hace falta ningún paso manual para publicar**: `.github/workflows/pages.yml`
reconstruye y publica el sitio automáticamente en cada `git push` a `master` que toque esos 3 archivos
(usa `actions/deploy-pages`, ver el repo en GitHub → pestaña **Actions** para el estado de cada corrida).

`.github/workflows/supabase-ping.yml` pega un `GET` a la API de Supabase cada 3 días (cron) con la
clave `anon` — el plan gratis de Supabase pausa el proyecto tras 7 días sin actividad, así que este
ping lo evita. **Esto es solo preventivo**: si el proyecto ya está pausado, el ping no lo reactiva —
hay que entrar al dashboard de Supabase y darle "Resume project" a mano.

### Histórico: Netlify

El sitio vivió antes en Netlify (`scintillating-selkie-c94035.netlify.app`) — se dejó de usar porque
el despliegue se bloqueó por crédito agotado de la cuenta. El flujo seguía siendo el mismo (`deploy/`
local + `npx netlify-cli deploy --dir=.\deploy --prod`) si en algún momento se quiere volver a esa
plataforma; la carpeta `deploy/` sigue existiendo localmente (en `.gitignore`, nunca se subió a git)
por si hace falta reconstruirla.

## Documentación relacionada

- `CLAUDE.md` — convenciones del repo y reglas para cambios, incluida la arquitectura con Supabase.
- `SPEC.md` / `FINDINGS.md` — especificación y verificación de la **primera** versión del modelo de
  datos unificado sobre `localStorage` (septiembre 2026) — contexto histórico, ya superado por la
  migración a Supabase de octubre 2026.
- `supabase-schema.sql`, `supabase-schema-2.sql`, `supabase-schema-3.sql`, `supabase-schema-4.sql`, `supabase-schema-5.sql`, `supabase-schema-6.sql`, `supabase-schema-7.sql` — esquema completo de la base de datos.
