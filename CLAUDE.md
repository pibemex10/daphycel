# Daphycel

Tienda de refacciones y accesorios de telefonía. Dos aplicaciones web, cada una un único archivo HTML autocontenido.

## Archivos del proyecto

- **`daphycel.html`** — Panel interno del negocio. Requiere login (usuario/contraseña) con 3 roles: `dueno`, `administrador`, `vendedor`, cada uno con permisos distintos. Incluye catálogo, punto de venta (POS) con apertura/cierre de caja, cartera de clientes (crédito/fiado), inventario, panel de estadísticas y gestión de usuarios.
- **`daphycel-cliente.html`** — Tienda pública de cara al cliente final, sin login. Incluye catálogo tipo marketplace (con reseñas y calificación por estrellas), consulta de estado de reparaciones por número de orden, y una sección "Mi cuenta" con búsqueda privada por nombre/número de cliente/orden.

## Stack y convenciones técnicas

- **Vanilla HTML/CSS/JS.** Sin framework, sin bundler, sin build step, sin `package.json` para la app en sí. Cada archivo `.html` es autocontenido: su `<style>` y su `<script>` viven en el mismo archivo.
- **Sin backend, con fuente única en `localStorage`.** Ambos archivos comparten una sola clave (`daphycel_db_v1`) que guarda `products`, `customers`, `sales`, `repairs` (fusión de `repairQueue`/`jobs`), `users`, `counters` y `caja` como JSON. El bloque `seedDB()/loadDB()/saveRaw()/snapshotDB()/saveDB()` es idéntico e inline en ambos archivos (ver detalle completo en `SPEC.md`). Sin sincronización en vivo entre pestañas: los cambios se reflejan al recargar o navegar, última escritura gana. `window.DaphycelDB` expone `read()/save()/reset()` para pruebas.
- **Dependencias externas** cargadas por CDN únicamente: Google Fonts (Space Grotesk, IBM Plex Sans, IBM Plex Mono), JsBarcode y qrcodejs vía `cdnjs.cloudflare.com`.
- **Playwright está instalado globalmente en esta máquina** (`npm install -g playwright`, navegador Chromium) exclusivamente como herramienta de testing para el Evaluator del harness. No es una dependencia del proyecto ni implica que la app necesite Node/npm para funcionar — los archivos `.html` se abren directamente en el navegador (`file://`) o se sirven estáticos.
- **Paleta azul rey** en ambos archivos, con variantes distintas: `daphycel.html` usa fondo crema (`#f8f6f1`) con acento `#3d6fd6`; `daphycel-cliente.html` usa fondo blanco con acento `#2540d6`. Mantener esta identidad visual al agregar features.

## Modelo de datos

Unificado desde septiembre 2026 (ver `SPEC.md` para el esquema completo y `FINDINGS.md` para su verificación). El catálogo maestro es el de la tienda (20 SKUs, con `desc`/`subcat`/`reviews`); las reparaciones tienen doble identificador (`id` interno `EQ-###` para el panel, `order` público `OR-####` que consulta el cliente). El checkout de la tienda genera una venta real (`method:'online'`, sin IVA, fuera de los cortes de caja). Cualquier cambio futuro al esquema compartido debe documentarse en un nuevo `SPEC.md` (o una sección nueva) antes de tocar código, igual que se hizo para esta unificación.

**Campo `notifyEmail`** (octubre 2026, string, `''` por defecto): correo al que se avisa cuando se cambia la contraseña de cualquier cuenta. Solo se edita desde la vista Usuarios del panel (ya restringida al rol `dueno`); la tienda lo hidrata y lo reescribe sin usarlo, igual que con `users`/`caja`/`counters`. Como la app no tiene backend ni servicio de correo, el aviso se envía abriendo un enlace `mailto:` con el mensaje redactado — no hay envío automático real ni se expone ninguna credencial de proveedor de email en el código.

## Reglas para cambios (Generator)

- **Cambios quirúrgicos.** Preferir ediciones puntuales sobre reescribir archivos completos. Mantener el estilo, nombres de variables/funciones y estructura ya existentes en cada archivo.
- **No romper lo que ya funciona.** Antes de modificar una sección compartida entre vistas (ej. `products`, `fmt`, `findProduct`), revisar todos los lugares que la usan dentro del mismo archivo.
- **Commits chicos y frecuentes**, uno por unidad de trabajo lógica, con mensajes descriptivos en español acordes al resto del proyecto.
- **Mantener el idioma español** en toda la UI, comentarios de cara a datos de ejemplo (nombres, productos) y mensajes al usuario.

## Cómo probar

Abrir el archivo `.html` correspondiente directamente en un navegador. No requiere `npm install` ni servidor de desarrollo. Para pruebas automatizadas (Evaluator), Playwright puede abrir el archivo por ruta de archivo local o servirlo con un servidor estático simple si la prueba lo requiere.
