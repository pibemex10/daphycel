# Daphycel

Tienda de refacciones y accesorios de telefonía. Dos aplicaciones web autocontenidas que
comparten **una sola fuente de verdad** guardada en `localStorage`.

- **`daphycel.html`** — panel interno (login, POS, caja, clientes, inventario, usuarios).
- **`daphycel-cliente.html`** — tienda pública (catálogo, reseñas, carrito, reparaciones, Mi cuenta).

Lo que se registra en cualquiera de las dos se refleja en la otra **al recargarla o navegar hacia ella**.

## Cómo arrancar la app

Abrir el archivo directamente en el navegador. No hay build, backend ni `npm install`.

```powershell
Start-Process .\daphycel.html          # panel interno
Start-Process .\daphycel-cliente.html  # tienda pública
```

Credenciales del panel: `dueno/dueno123`, `admin/admin123`, `vendedor/vendedor123`.

### Sirviendo por HTTP (recomendado para pruebas automatizadas)

`file://` y `http://localhost` son orígenes distintos y **no comparten datos** entre sí.
Para pruebas conviene un origen HTTP estable:

```powershell
python -m http.server 8000
```

Si no hay Python en la máquina, el equivalente con Node (no agrega archivos al proyecto):

```powershell
node --% -e "const h=require('http'),f=require('fs'),p=require('path');h.createServer((q,s)=>{const u=decodeURIComponent(q.url.split('?')[0]),x=p.join(process.cwd(),u==='/'?'/daphycel.html':u);f.readFile(x,(e,d)=>{if(e){s.writeHead(404);return s.end('404')}s.writeHead(200,{'Content-Type':x.endsWith('.html')?'text/html; charset=utf-8':'application/octet-stream'});s.end(d)})}).listen(8000,()=>console.log('http://localhost:8000/daphycel.html'))"
```

Luego abrir `http://localhost:8000/daphycel.html` y `http://localhost:8000/daphycel-cliente.html`.
Con Playwright hay que usar **el mismo `browserContext`** para ambas páginas; de lo contrario no
comparten `localStorage`.

## Persistencia

Todo el estado compartido vive en una sola clave de `localStorage`:

| | |
|---|---|
| Clave | `daphycel_db_v1` |
| Versión | `1` (si `version !== 1` se re-siembra) |
| Colecciones | `products`, `customers`, `sales`, `repairs`, `users`, `counters`, `caja` |

El bloque de persistencia (`seedDB` / `loadDB` / `saveDB` / `reloadFromStore`) es **texto idéntico**
en los dos archivos, así que la app que se abra primero con almacenamiento vacío escribe exactamente
el mismo dataset. Ambos archivos hidratan y reescriben *todas* las colecciones, incluidas las que no
usan, para que ninguna app borre datos de la otra.

- Si el JSON está corrupto o `localStorage` no está disponible, la app arranca con la semilla y no
  lanza excepciones.
- No hay sincronización en vivo entre pestañas abiertas a la vez: gana la última escritura. Al
  navegar entre vistas cada app vuelve a leer el store, para no pisar con un snapshot viejo lo que
  la otra haya escrito.
- El carrito, el ticket del POS y las sesiones **no** se persisten.

### API de depuración

Disponible en ambos archivos desde la consola del navegador:

```js
window.DaphycelDB.KEY      // 'daphycel_db_v1'
window.DaphycelDB.read()   // objeto parseado desde localStorage
window.DaphycelDB.save()   // fuerza un guardado del estado en memoria
window.DaphycelDB.reset()  // reescribe la semilla y recarga la página
```

## Documentación relacionada

- `CLAUDE.md` — convenciones del repo y reglas para cambios.
- `SPEC.md` — especificación de la unificación del modelo de datos y rubric de evaluación.
