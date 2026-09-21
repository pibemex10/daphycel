# RefacTel

Tienda de refacciones y accesorios de telefonía. Dos aplicaciones web, cada una un único archivo HTML autocontenido.

## Archivos del proyecto

- **`refactel.html`** — Panel interno del negocio. Requiere login (usuario/contraseña) con 3 roles: `dueno`, `administrador`, `vendedor`, cada uno con permisos distintos. Incluye catálogo, punto de venta (POS) con apertura/cierre de caja, cartera de clientes (crédito/fiado), inventario, panel de estadísticas y gestión de usuarios.
- **`refactel-cliente.html`** — Tienda pública de cara al cliente final, sin login. Incluye catálogo tipo marketplace (con reseñas y calificación por estrellas), consulta de estado de reparaciones por número de orden, y una sección "Mi cuenta" con búsqueda privada por nombre/número de cliente/orden.

## Stack y convenciones técnicas

- **Vanilla HTML/CSS/JS.** Sin framework, sin bundler, sin build step, sin `package.json` para la app en sí. Cada archivo `.html` es autocontenido: su `<style>` y su `<script>` viven en el mismo archivo.
- **Sin backend.** Todos los datos (`products`, `customers`, `sales`, `jobs`/`repairQueue`, `users`) viven en arrays de JavaScript en memoria. Se reinician al recargar la página — no hay `localStorage` ni servidor todavía.
- **Dependencias externas** cargadas por CDN únicamente: Google Fonts (Space Grotesk, IBM Plex Sans, IBM Plex Mono), JsBarcode y qrcodejs vía `cdnjs.cloudflare.com`.
- **Playwright está instalado globalmente en esta máquina** (`npm install -g playwright`, navegador Chromium) exclusivamente como herramienta de testing para el Evaluator del harness. No es una dependencia del proyecto ni implica que la app necesite Node/npm para funcionar — los archivos `.html` se abren directamente en el navegador (`file://`) o se sirven estáticos.
- **Paleta azul rey** en ambos archivos, con variantes distintas: `refactel.html` usa fondo crema (`#f8f6f1`) con acento `#3d6fd6`; `refactel-cliente.html` usa fondo blanco con acento `#2540d6`. Mantener esta identidad visual al agregar features.

## Modelo de datos

Actualmente (antes de la unificación en curso) los dos archivos tienen datasets **independientes y con esquemas distintos** — mismo SKU puede tener campos diferentes entre archivos, los clientes no coinciden, y las reparaciones usan estructuras distintas (`repairQueue` en el panel vs. `jobs` en la tienda cliente). Cualquier trabajo que unifique el modelo de datos debe quedar documentado explícitamente en `SPEC.md` antes de tocar código — no asumir la forma final del esquema compartido sin especificarla primero.

## Reglas para cambios (Generator)

- **Cambios quirúrgicos.** Preferir ediciones puntuales sobre reescribir archivos completos. Mantener el estilo, nombres de variables/funciones y estructura ya existentes en cada archivo.
- **No romper lo que ya funciona.** Antes de modificar una sección compartida entre vistas (ej. `products`, `fmt`, `findProduct`), revisar todos los lugares que la usan dentro del mismo archivo.
- **Commits chicos y frecuentes**, uno por unidad de trabajo lógica, con mensajes descriptivos en español acordes al resto del proyecto.
- **Mantener el idioma español** en toda la UI, comentarios de cara a datos de ejemplo (nombres, productos) y mensajes al usuario.

## Cómo probar

Abrir el archivo `.html` correspondiente directamente en un navegador. No requiere `npm install` ni servidor de desarrollo. Para pruebas automatizadas (Evaluator), Playwright puede abrir el archivo por ruta de archivo local o servirlo con un servidor estático simple si la prueba lo requiere.
