# SPEC — Unificación del modelo de datos de RefacTel (fuente única en el navegador)

## 1. Objetivo

Unificar `refactel.html` (panel interno) y `refactel-cliente.html` (tienda pública) sobre **una sola fuente de verdad persistida en `localStorage`**, de modo que ventas, cobros de reparación, movimientos de inventario, abonos de clientes y reseñas registrados en cualquiera de las dos apps se reflejen en la otra al recargarla o navegar hacia ella, conservando ambos archivos separados y todas sus funcionalidades actuales.

---

## 2. Scope

### SÍ incluye

1. Capa de persistencia `localStorage` con **una sola clave** (`refactel_db_v1`) que guarda todo el estado compartido en JSON.
2. **Esquema unificado** de `products`, `customers`, `sales`, `repairs` (fusión de `repairQueue` del panel + `jobs` de la tienda), `users`, `counters` y `caja`.
3. **Semilla (seed) idéntica byte a byte** en ambos archivos: la app que se abra primero con almacenamiento vacío escribe exactamente el mismo dataset.
4. Hidratación al cargar (`loadDB()`) y guardado en **todos** los puntos de mutación (`saveDB()`), listados en §7.3.
5. Fusión de reparaciones: cada reparación tiene a la vez `id` interno (`EQ-###`) y número de orden público (`OR-####`), consultable desde la tienda.
6. Cobro de reparación en el panel → visible en la tienda (estado/monto) y en el corte de caja.
7. Checkout del carrito de la tienda → **registra una venta real** (`method:'online'`) que descuenta stock y aparece en el panel.
8. Reseñas publicadas en la tienda → persisten dentro del producto y **no se pierden** al editar ese producto desde el panel.
9. Campo `desc` (descripción de tienda) editable desde el formulario de alta y el modal de edición de inventario del panel.
10. Caja: `abierta`, `montoInicial`, hora/`ts` de apertura e historial de cortes persistidos; los cortes cuentan **solo** las ventas del turno abierto (filtro por `ts`).
11. API global de depuración/pruebas `window.RefacTelDB` en ambos archivos (§7.2).
12. Tolerancia a fallos: JSON corrupto o `localStorage` no disponible ⇒ la app arranca con el seed en memoria, sin excepciones no capturadas.

### NO incluye

- Fusionar los dos HTML en uno solo, ni extraer JS/CSS a archivos externos (siguen siendo 2 archivos autocontenidos).
- Backend, API, base de datos, Node, bundler o `package.json`.
- Sincronización en vivo entre pestañas abiertas simultáneamente (listener `storage`, BroadcastChannel, polling). El requisito es reflejar los cambios **al recargar o navegar**. Última escritura gana.
- Login/autenticación real en la tienda cliente (sigue siendo búsqueda privada por nombre/número).
- Migraciones de versiones de esquema (solo existe `version: 1`; si `version !== 1` se re-siembra).
- Persistir el carrito de la tienda, el ticket del POS, la sesión del usuario logueado o el cliente logueado (siguen siendo estado efímero en memoria).
- Cambios de rediseño visual, nuevas vistas o nuevos roles.
- IVA en las ventas online de la tienda (se factura sin IVA; ver Assumptions).

---

## 3. User flows

Credenciales del panel (sin cambio): `dueno/dueno123` (dueño), `admin/admin123` (administrador), `vendedor/vendedor123` (vendedor).

### 3.1 Arranque / siembra (ambas apps)

- **Input:** carga del documento.
- **Proceso:** `loadDB()` lee `localStorage['refactel_db_v1']`. Si no existe, no parsea, o `version !== 1` ⇒ genera `seedDB()`, lo escribe y lo usa. Hidrata las variables globales `products`, `customers`, `sales`, `repairs`, `users`, `counters`, `caja`.
- **Output:** la clave existe en `localStorage` con las 7 colecciones; la UI renderiza los datos del store.

### 3.2 Panel — Venta en POS (`refactel.html` → pestaña "Punto de venta")

- **Input:** productos en el ticket, método de pago (`efectivo|tarjeta|transferencia|credito`), cliente opcional, efectivo recibido.
- **Proceso:** valida igual que hoy (crédito exige cliente; efectivo exige `cash >= total`), descuenta stock, crea `sale` con `id:'V-'+(++counters.sale)`, `tipo:'venta'`, `ts:Date.now()`, IVA 16 %; si es crédito suma `total` al `balance` del cliente. Llama `saveDB()`.
- **Output:** modal de ticket/recibo con folio; stock, venta y saldo persistidos.
- **Efecto cruzado:** al recargar la tienda, el producto muestra el nuevo stock; "Mi cuenta" del cliente muestra la compra y el saldo actualizado.

### 3.3 Panel — Cancelación de venta (POS → submenú "Cancelaciones", solo dueño/administrador)

- **Input:** clic en "Cancelar" de una venta.
- **Proceso:** repone stock de cada ítem, revierte saldo si fue a crédito, marca `cancelled:true`, `saveDB()`.
- **Output:** fila marcada como cancelada; tienda muestra el stock repuesto al recargar.

### 3.4 Panel — Equipos para reparar (POS → submenú "Equipos para reparar")

- **Alta.** Input: nombre de cliente + 1..N bloques (marca, modelo, detalles, trabajo, accesorios, contraseña). Proceso: por cada bloque incrementa `counters.repair` y `counters.order`, crea la reparación con `id:'EQ-'+pad3`, `order:'OR-'+counters.order`, `status:'Recibido'`, `type:'reparacion'`, `cost:0`, `charged:false`, `received` = fecha local `dd/mm/aaaa`, `customerId` = cliente con nombre idéntico (case-insensitive) o `null`. `saveDB()`. Output: filas nuevas en la tabla, con la columna **Orden** visible.
- **Cambio de estado.** Input: `<select>` con `Recibido | En reparación | Listo para entrega | Entregado`. Output: estado persistido (`saveDB()`).
- **Cobro.** Input: botón "Cobrar" → modal con monto y método (`efectivo|tarjeta|transferencia`). Proceso: valida monto > 0; crea venta `id:'R-'+(++counters.sale)`, `tipo:'reparacion'`, `items:[{sku:null, name: device+' — '+work, qty:1, price:monto}]`, `subtotal=total=monto`, `iva:0`, `ts:Date.now()`; marca `charged:true` y `cost:monto`. `saveDB()`. Output: alerta de confirmación y etiqueta "Cobrado $X" en la fila.
- **Detalle.** Output: modal con orden, id, cliente, fecha, detalles, trabajo, accesorios y contraseña.

### 3.5 Panel — Inventario

- **Agregar** (dueño/administrador): inputs nombre, SKU, categoría, **descripción (opcional, se muestra en la tienda)**, precio, stock. Valida SKU único. Crea `{sku, name, cat, subcat:null, price, stock, desc, reviews:[]}`. `saveDB()`.
- **Editar**: modal con nombre, SKU, categoría, **descripción**, precio, stock. **Debe preservar `subcat` y `reviews` del producto.** `saveDB()`.
- **Eliminar**: quita el producto del array. `saveDB()`.
- **Efecto cruzado:** la tienda refleja alta/edición/baja al recargar.

### 3.6 Panel — Clientes (cartera)

- **Alta**: nombre (obligatorio), teléfono, notas ⇒ `id:'C-'+pad3(++counters.client)`, `since` = fecha local, `balance:0`. `saveDB()`.
- **Abono**: monto > 0 ⇒ `balance = max(0, balance - monto)`. `saveDB()`.
- **Efecto cruzado:** "Mi cuenta" en la tienda muestra el saldo nuevo al recargar.

### 3.7 Panel — Usuarios (solo dueño) y Caja

- Crear/eliminar usuario ⇒ `saveDB()`; tras recargar, el usuario nuevo puede iniciar sesión.
- **Abrir caja**: monto inicial ⇒ `caja = {abierta:true, montoInicial, aperturaHora:'HH:MM', aperturaTs:Date.now(), cortes:[]}`. `saveDB()`. El botón del quickbar queda en "Cerrar caja" **incluso tras recargar**.
- **Corte parcial (Ventas / Reparaciones)**: suma por método **solo** las ventas no canceladas del `tipo` correspondiente con `ts >= caja.aperturaTs`; empuja el registro a `caja.cortes`. `saveDB()`.
- **Corte final**: empuja los dos cortes (venta + reparación), pone `caja.abierta=false`, `montoInicial=0`, `aperturaHora=null`, `aperturaTs=null`. `saveDB()`.

### 3.8 Tienda — Catálogo y reseñas (`refactel-cliente.html`)

- **Catálogo**: lee `products` del store; grupos y submenús actuales sin cambio.
- **Ficha de producto**: muestra `desc`, stock, precio, promedio de estrellas y reseñas.
- **Publicar reseña**: inputs nombre, estrellas (1-5), comentario. Valida los tres. Inserta `{author, rating, comment, date:'justo ahora'}` al inicio de `product.reviews`. `saveDB()`.
- **Efecto cruzado:** la reseña sobrevive a recargas y a ediciones del producto desde el panel.

### 3.9 Tienda — Carrito y checkout

- **Input:** carrito con ≥1 producto, botón "Confirmar pedido".
- **Proceso:** si algún ítem excede el stock ⇒ `alert('No hay suficiente stock de <nombre>.')` y aborta. Si no: descuenta stock, crea `sale` con `id:'V-'+(++counters.sale)`, `method:'online'`, `tipo:'venta'`, `iva:0`, `subtotal=total`=suma del carrito, `cash:0`, `change:0`, `customerId` = cliente logueado en "Mi cuenta" o `null`, `ts:Date.now()`. `saveDB()`. Vacía el carrito y cierra el drawer.
- **Output:** `alert('¡Pedido confirmado! Folio <V-xxxx>. Te avisaremos cuando esté listo para recoger o enviar.')`.
- **Efecto cruzado:** al recargar el panel, la venta aparece en el panel de estadísticas y el stock bajó en inventario.

### 3.10 Tienda — Reparaciones por número de orden

- **Input:** número de orden (`OR-####`), botón/Enter.
- **Proceso:** busca en `repairs` por `order` (case-insensitive, `trim`).
- **Output:** tarjeta con `status`, `device`, `work`, `order`, `received` y `fmt(cost)`. Si no hay coincidencia: "No encontramos ninguna orden con ese número. Verifica e intenta de nuevo."

### 3.11 Tienda — Mi cuenta

- **Input:** nombre, número de cliente (`C-00X`) o número de orden (`OR-####`).
- **Proceso:** búsqueda igual que hoy, pero sobre `repairs` (campo `order`/`customer`) en lugar de `jobs`.
- **Output:** nombre, "cliente desde", total de compras, saldo y lista de ventas con `customerId` coincidente. La etiqueta de método usa `methodLabel()` unificado (`Efectivo | Pago con tarjeta | Transferencia | Crédito (fiado) | Pedido en línea`).

---

## 4. Modelo de datos

Clave única: **`refactel_db_v1`**. Valor: un JSON con esta forma exacta.

```jsonc
{
  "version": 1,
  "products": [], "customers": [], "sales": [], "repairs": [], "users": [],
  "counters": { "sale": 1005, "client": 5, "repair": 12, "order": 1012 },
  "caja": { "abierta": false, "montoInicial": 0, "aperturaHora": null, "aperturaTs": null, "cortes": [] }
}
```

### 4.1 `products[]`

| campo | tipo | notas |
|---|---|---|
| `sku` | string | PK, único (comparación case-insensitive) |
| `name` | string | |
| `cat` | string | uno de `CATS`: `pantallas, tabletas, flexores, baterias, tapas, herramientas, insumos, camaras` |
| `subcat` | string\|null | solo para `insumos`: `glass, liquidos, hilos, otros`. `null` en el resto |
| `price` | number | MXN |
| `stock` | number | entero ≥ 0 |
| `desc` | string | descripción de tienda (puede ser `''`) |
| `reviews` | array | `[{author, rating:1..5, comment, date}]`, más recientes primero |

Seed: los **20 productos** de `refactel-cliente.html` (líneas 326-347 del archivo actual), tal cual, agregando `subcat:null` a los que no lo tienen. Es superconjunto del catálogo del panel.

### 4.2 `customers[]`

| campo | tipo | notas |
|---|---|---|
| `id` | string | `C-001`… |
| `name` | string | |
| `phone` | string | |
| `notes` | string | puede ser `''` |
| `since` | string | `dd/mm/aaaa` |
| `balance` | number | saldo pendiente (fiado) tras abonos |

Seed (5):

```js
{id:'C-001', name:'José Martínez',            phone:'55 1234 5678', notes:'Taller frecuente, paga cada quincena', since:'12/01/2026', balance:340},
{id:'C-002', name:'Talleres Ruiz S.A.',       phone:'55 8765 4321', notes:'Compra al mayoreo',                    since:'03/03/2026', balance:0},
{id:'C-003', name:'Karen Sánchez',            phone:'56 2211 9080', notes:'',                                     since:'20/05/2026', balance:120},
{id:'C-004', name:'Miguel Ángel Torres',      phone:'55 3344 2210', notes:'',                                     since:'02/06/2026', balance:0},
{id:'C-005', name:'CelExpress Reparaciones',  phone:'55 9081 7766', notes:'Mayoreo, recoge los viernes',          since:'18/07/2026', balance:275},
```

### 4.3 `sales[]` (más recientes primero; se insertan con `unshift`)

| campo | tipo | notas |
|---|---|---|
| `id` | string | `V-####` ventas, `R-####` cobros de reparación |
| `items` | array | `[{sku:string\|null, name, qty, price}]` |
| `subtotal`, `iva`, `total` | number | |
| `cash`, `change` | number | 0 si no aplica |
| `time` | string | `HH:MM` local (legible) |
| `ts` | number | epoch ms; **obligatorio**, base del filtro de turno de caja |
| `customerId` | string\|null | |
| `method` | string | `efectivo \| tarjeta \| transferencia \| credito \| online` |
| `tipo` | string | `venta \| reparacion` |
| `cancelled` | boolean | |

Seed (5, sin IVA por ser históricas; `cancelled:false`, `tipo:'venta'`, `cash:0`, `change:0`):

```js
{id:'V-1001', customerId:'C-001', method:'credito',  total:890, subtotal:890, iva:0, time:'10:12', ts:Date.parse('2026-09-18T10:12:00'), items:[{sku:'PANT-001', name:'Pantalla iPhone 11 OLED', qty:1, price:890}]},
{id:'V-1002', customerId:'C-003', method:'credito',  total:290, subtotal:290, iva:0, time:'09:40', ts:Date.parse('2026-09-18T09:40:00'), items:[{sku:'BAT-002', name:'Batería Samsung A21s', qty:1, price:290}]},
{id:'V-1003', customerId:'C-001', method:'efectivo', total:180, subtotal:180, iva:0, time:'16:20', ts:Date.parse('2026-09-17T16:20:00'), items:[{sku:'TAB-001', name:'Tableta de carga iPhone 12', qty:1, price:180}]},
{id:'V-1004', customerId:'C-004', method:'efectivo', total:220, subtotal:220, iva:0, time:'12:05', ts:Date.parse('2026-09-17T12:05:00'), items:[{sku:'TAP-001', name:'Tapa trasera iPhone 12 Pro', qty:1, price:220}]},
{id:'V-1005', customerId:'C-005', method:'credito',  total:215, subtotal:215, iva:0, time:'13:45', ts:Date.parse('2026-09-16T13:45:00'), items:[{sku:'FLEX-001', name:'Flexor de encendido iPhone X', qty:1, price:120},{sku:'INS-001', name:'Pegamento OCA UV 50ml', qty:1, price:95}]},
```

`counters.sale` arranca en **1005**.

### 4.4 `repairs[]` (reemplaza `repairQueue` del panel y `jobs` de la tienda)

| campo | tipo | notas |
|---|---|---|
| `id` | string | `EQ-001`… (uso interno del panel) |
| `order` | string | `OR-1001`… (número público que el cliente consulta) |
| `customer` | string | nombre |
| `customerId` | string\|null | |
| `brand`, `model` | string | |
| `device` | string | `brand + ' ' + model` |
| `details` | string | estado físico / observaciones |
| `work` | string | trabajo a realizar (equivalente al antiguo `issue`) |
| `accessories` | string | `'Ninguno'` si vacío |
| `pass` | string | `'Sin contraseña'` si vacío |
| `received` | string | `dd/mm/aaaa` (equivalente al antiguo `date`) |
| `status` | string | `Recibido \| En reparación \| Listo para entrega \| Entregado` |
| `type` | string | `reparacion \| glass \| software` |
| `cost` | number | monto cobrado o 0 |
| `charged` | boolean | |

Seed (12): `EQ-001..EQ-010` ← los 10 `jobs` actuales de la tienda, con `order` `OR-1001..OR-1010`, `work` = su `issue`, `received` = su `date`, `cost` = su `cost`, `status:'Entregado'`, `charged:true`, `details:'—'`, `accessories:'Ninguno'`, `pass:'Sin contraseña'`, `customerId` mapeado por nombre, y `brand`/`model`: Apple/iPhone 11, Samsung/A32, Apple/iPhone X, Xiaomi/Redmi 9, Apple/iPhone 12 Pro, Samsung/S10, Apple/iPhone 13, Samsung/A54, Apple/iPhone 12, Xiaomi/Redmi Note 10 (en ese orden).

Más los 2 del panel:

```js
{id:'EQ-011', order:'OR-1011', customer:'José Martínez', customerId:'C-001', brand:'Apple',   model:'iPhone 11', device:'Apple iPhone 11', details:'Cristal trasero trizado, enciende normal', work:'Cambio de pantalla', accessories:'Ninguno', pass:'1234', received:'09/09/2026', status:'En reparación', type:'reparacion', cost:0, charged:false},
{id:'EQ-012', order:'OR-1012', customer:'Karen Sánchez', customerId:'C-003', brand:'Samsung', model:'A32',       device:'Samsung A32',      details:'No carga desde ayer',                        work:'Diagnóstico y cambio de tableta de carga', accessories:'Cargador', pass:'Sin contraseña', received:'10/09/2026', status:'Recibido', type:'reparacion', cost:0, charged:false},
```

`counters.repair` = 12, `counters.order` = 1012.

### 4.5 `users[]` (los usa solo el panel; la tienda los conserva sin tocarlos)

```js
{name:'Dueño', username:'dueno', password:'dueno123', role:'dueno'},
{name:'Karla Méndez', username:'vendedor', password:'vendedor123', role:'vendedor'},
{name:'Luis Fernández', username:'admin', password:'admin123', role:'administrador'},
```

### 4.6 `caja` (solo panel)

`{abierta:boolean, montoInicial:number, aperturaHora:string|null, aperturaTs:number|null, cortes:[{categoria:'venta'|'reparacion', tipo:'Corte parcial'|'Corte final', hora, efectivo, tarjeta, transferencia, totalCorte, esperado, contado:number|null}]}`

### 4.7 Estado NO persistido (memoria, por archivo)

Panel: `currentView`, `currentRole`, `loggedInUser`, `ticket`, `activeCat`, `searchTerm`, `activePosSub`, `activeInvSub`, `activeCajaCat`, `editingSku`, `activeClientId`, `chargingRepairId`.
Tienda: `cart`, `loggedInCustomer`, `activeGroup`, `activeCat`, `searchTerm`, `activeProductSku`, `selectedStars`.

---

## 5. Stack y decisiones técnicas

- **Vanilla HTML/CSS/JS**, sin framework, sin build. Dos archivos autocontenidos en la raíz:
  ```
  RefacTel/
    refactel.html          # panel interno
    refactel-cliente.html  # tienda pública
    CLAUDE.md
    SPEC.md
  ```
  No se crean archivos `.js`/`.css` nuevos. CDNs permitidos: los ya presentes (Google Fonts, JsBarcode, qrcodejs vía `cdnjs.cloudflare.com`).
- **Mecanismo de persistencia: `localStorage`**, una sola clave con todo el DB serializado.
  Motivo: es síncrono (sin `async/await` que obligue a reescribir los renders), sobrevive al cierre del navegador, lo comparten todos los documentos del mismo origen (ambos archivos viven en la misma carpeta ⇒ mismo origen) y ~5 MB sobran para este dataset. Descartados: IndexedDB (API asíncrona, complica todos los handlers existentes), `sessionStorage` (no se comparte entre pestañas), cookies (4 KB y bloqueadas en `file://`).
- **Serialización**: `JSON.stringify` / `JSON.parse`, sin fechas `Date` en el store (solo strings y epoch numbers).
- **Capa de persistencia** — idéntica en ambos archivos, colocada **al inicio del `<script>`, antes de cualquier declaración de datos**:

  ```js
  const DB_KEY = 'refactel_db_v1';
  const DB_VERSION = 1;
  function seedDB(){ /* objeto completo de §4, literal e idéntico en ambos archivos */ }
  function loadDB(){
    let raw = null;
    try { raw = localStorage.getItem(DB_KEY); } catch(e){ raw = null; }
    let db = null;
    if(raw){ try { db = JSON.parse(raw); } catch(e){ db = null; } }
    if(!db || db.version !== DB_VERSION || !Array.isArray(db.products)) db = seedDB();
    // normaliza colecciones faltantes con valores del seed
    saveRaw(db);
    return db;
  }
  function saveRaw(db){ try { localStorage.setItem(DB_KEY, JSON.stringify(db)); } catch(e){} }
  function snapshotDB(){ /* arma el objeto desde las globales vivas */ }
  function saveDB(){ saveRaw(snapshotDB()); }
  ```

  Ambos archivos hidratan **todas** las colecciones (incluidas las que no usan) y las vuelven a escribir intactas en `snapshotDB()`; así ninguna app borra datos de la otra. Estrategia de concurrencia: *last write wins* (documentado en Assumptions).
- **Nombres de variables globales** (idénticos en ambos archivos para las colecciones compartidas): `products`, `customers`, `sales`, `repairs`, `users`, `counters`, `caja`. En la tienda, `jobs` se renombra a `repairs`; en el panel, `repairQueue` se renombra a `repairs`, `saleCounter/clientCounter/repairCounter` pasan a `counters.sale/.client/.repair` y `cortesHistory` pasa a `caja.cortes`.
- **Idioma español** en toda la UI, datos de ejemplo y mensajes.
- **Paleta**: sin cambios (`#f8f6f1`/`#3d6fd6` en el panel; blanco/`#2540d6` en la tienda).
- **Comandos de dev / cómo probar**:
  - Uso normal: abrir `refactel.html` o `refactel-cliente.html` con doble clic (`file://`).
  - Pruebas automatizadas (recomendado, garantiza un origen HTTP compartido y estable):
    `python -m http.server 8000` desde `C:\Users\elpib\Videos\Claude Code\RefacTel` y abrir `http://localhost:8000/refactel.html` y `http://localhost:8000/refactel-cliente.html`.
  - Playwright (global) debe usar **el mismo `browserContext`** para ambas páginas, de lo contrario no comparten `localStorage`.
- **Reglas de implementación (Generator)**: ediciones quirúrgicas sobre los archivos existentes, conservando estilo, nombres y estructura; el bloque `seedDB()` debe ser **texto idéntico** en los dos archivos (escribirlo una vez y copiarlo); commits chicos en español.

### 5.1 Puntos obligatorios de `saveDB()`

**Panel:** `cobrar()`; `cancelSale()`; confirmación del modal de cobro de reparación; alta de equipos (`rqAddBtn`); cambio de `status` en la tabla de reparaciones; alta de producto (`saveProduct`); guardado del modal de edición (`saveEditBtn`); borrado de producto; alta de cliente (`saveClient`); abono (`abonoBtn`); alta y borrado de usuario; abrir caja; corte parcial de ventas; corte parcial de reparaciones; corte final.
**Tienda:** envío de reseña (`revSubmit`); `checkoutOnline()`.

### 5.2 API global de pruebas (ambos archivos)

```js
window.RefacTelDB = {
  KEY: 'refactel_db_v1',
  read(){ /* devuelve el objeto parseado desde localStorage */ },
  save(){ saveDB(); },
  reset(){ /* escribe seedDB() en localStorage y recarga la página con location.reload() */ }
};
```

---

## 6. Assumptions (decisiones tomadas por el Planner)

1. **Mecanismo elegido: `localStorage` con una sola clave** `refactel_db_v1` (no IndexedDB, no varias claves). Un único `JSON.stringify` evita estados parcialmente escritos.
2. **Sin sincronización en vivo** entre pestañas abiertas a la vez; los cambios se ven al recargar/navegar, que es lo pedido. Si dos pestañas están abiertas, gana la última en escribir.
3. `file://` y `http://localhost` son orígenes distintos: los datos no se comparten entre ambos modos. Es esperado y no es un fallo.
4. Si `localStorage` lanza (modo restringido, Safari en `file://`), la app funciona en memoria con el seed y **no** rompe; la sincronización entre apps simplemente no ocurre en ese entorno.
5. **El catálogo maestro es el de la tienda** (20 SKUs con `desc`, `subcat` y `reviews`): el panel gana 4 insumos nuevos (`INS-003..INS-006`). Se considera mejora, no regresión.
6. Los productos creados desde el panel llevan `subcat:null` y `reviews:[]`; si su `cat` es `insumos` aparecerán en la tienda dentro del grupo Insumos solo con el filtro "Todos"/sin submenú activo, no dentro de GLASS/LIQUIDOS/HILOS/OTROS. Aceptado; no se agrega selector de subcategoría al panel.
7. **El checkout de la tienda sí genera una venta** con `method:'online'`, porque el requisito exige que una venta registrada en cualquiera de las dos apps se refleje en la otra. No hay pasarela de pago ni estado "pedido pendiente".
8. Las ventas `online` **no entran en los cortes de caja** (los cortes suman solo `efectivo`, `tarjeta` y `transferencia`), porque no representan dinero en el cajón. Sí cuentan en el panel de estadísticas.
9. Las ventas online **no llevan IVA** (`iva:0`, `total = suma del carrito`), para que el total coincida con los precios mostrados en la tienda. El POS del panel mantiene su IVA de 16 %.
10. **`balance` del cliente es un campo independiente**, no derivado de `sales`; el seed conserva los saldos de demo (340 / 0 / 120 / 0 / 275) aunque no cuadren con las ventas semilla.
11. **Los cortes de caja filtran por turno** (`ts >= caja.aperturaTs`); sin ese filtro, al persistir las ventas los cortes acumularían días anteriores. Las ventas semilla tienen `ts` de días previos y nunca caen dentro de un turno.
12. Las reparaciones tienen **dos identificadores** (`id` interno `EQ-###` para el panel, `order` público `OR-####` para el cliente). El panel muestra `order` en una columna nueva "Orden" y en el modal de detalle.
13. `cost` es el campo monetario canónico de una reparación (sustituye a `chargedAmount`); al cobrar se fija `cost = monto` y `charged = true`.
14. `users`, `caja` y `counters` viven en el mismo blob aunque la tienda no los use: la tienda los lee y los reescribe sin modificarlos.
15. El carrito, el ticket del POS y la sesión (usuario del panel / cliente de "Mi cuenta") **no** se persisten: cada carga exige volver a iniciar sesión, como hoy.
16. `window.RefacTelDB.reset()` existe como punto de reinicio determinista para pruebas; no se agrega botón visible en la UI.
17. Se conserva el `type` de reparación (`reparacion|glass|software`) porque la tienda ya lo modela; las altas desde el panel usan siempre `reparacion` (no se agrega selector).
18. `methodLabel()` se replica en la tienda (hoy no existe) e incluye `online → 'Pedido en línea'` en ambos archivos.

---

## 7. Rubric de evaluación

Ejecutar con Playwright/Chromium, un **único `browserContext`**, sirviendo la carpeta en `http://localhost:8000`. Salvo indicación contraria, cada criterio parte de `localStorage.clear()` + recarga. `DB` = `JSON.parse(localStorage.getItem('refactel_db_v1'))`. Login del panel con `dueno/dueno123` salvo que se indique otro.

1. **Dos archivos, autocontenidos.** Existen `refactel.html` y `refactel-cliente.html` en la raíz; no hay archivos `.js`/`.css` nuevos en el proyecto y ningún `<script src>` ni `<link href>` apunta a rutas locales (solo `cdnjs.cloudflare.com` y `fonts.googleapis.com`/`fonts.gstatic.com`).
2. **Siembra en el panel.** Con `localStorage` vacío, abrir `refactel.html` crea `refactel_db_v1` con `version === 1` y las claves `products, customers, sales, repairs, users, counters, caja`.
3. **Siembra idéntica.** `localStorage.clear()` + abrir el panel ⇒ guardar `JSON.stringify(DB.products)`, `DB.customers`, `DB.repairs`. Repetir con `localStorage.clear()` + abrir la tienda. Los tres strings son **iguales** entre ambos casos.
4. **Volúmenes del seed.** `DB.products.length === 20`, `DB.customers.length === 5`, `DB.sales.length === 5`, `DB.repairs.length === 12`, `DB.users.length === 3`, `DB.counters.sale === 1005`, `DB.counters.order === 1012`.
5. **Catálogo compartido.** En el panel (vista Tienda/Inventario→Editar) se listan 20 productos; en la tienda, la suma de productos visibles en los grupos Refacciones + Insumos + Herramientas es 20.
6. **Venta en efectivo baja stock en ambas apps.** Panel → POS → escanear `PANT-001` → efectivo `$2000` → Cobrar. `DB.products` con `sku==='PANT-001'` tiene `stock === 13`. Recargar la tienda: la ficha de `PANT-001` muestra "13 pzas".
7. **La venta persiste en el panel.** Tras recargar `refactel.html` y volver a entrar, el Panel de estadísticas muestra 6 ventas y el folio nuevo `V-1006` aparece en la lista de ventas recientes.
8. **Venta a crédito impacta la cartera y "Mi cuenta".** Panel → POS → producto + cliente `José Martínez` + método Crédito → Cobrar. El `balance` de `C-001` en `DB` aumentó exactamente el total de la venta. Recargar la tienda → "Mi cuenta" → buscar `C-001` ⇒ el saldo mostrado coincide con `fmt(DB.customers[0].balance)` y la venta nueva aparece en el historial.
9. **Abono cruzado.** Panel → Clientes → `José Martínez` → abonar `$100` ⇒ `balance` baja 100 en `DB`. Recargar la tienda → "Mi cuenta" de `C-001` muestra el saldo reducido.
10. **Reseña desde la tienda persiste.** Tienda → ficha de `BAT-001` → nombre "Ana Prueba", 5 estrellas, comentario "Excelente batería" → Publicar. La reseña aparece en la lista sin recargar, y tras recargar la página sigue presente; en `DB`, `products[sku==='BAT-001'].reviews[0].author === 'Ana Prueba'`.
11. **El panel no destruye reseñas ni descripción.** Tras el criterio 10, panel → Inventario → Editar `BAT-001` → cambiar precio a `399` → Guardar. En `DB`, ese producto tiene `price === 399`, conserva `reviews[0].author === 'Ana Prueba'` y `desc` no vacío. Recargar la tienda: la ficha muestra `$399.00` y la reseña de Ana Prueba.
12. **Checkout de la tienda registra venta visible en el panel.** Tienda → agregar `TAB-002` al carrito → Confirmar pedido ⇒ alerta que contiene "Folio V-". En `DB` la venta existe con `method === 'online'` y `tipo === 'venta'`, y `TAB-002` bajó a `stock === 34`. Recargar el panel: el Panel de estadísticas cuenta la venta y el inventario muestra 34.
13. **Checkout sin stock se rechaza.** Poner un producto en `stock: 0` desde el panel (editar) y, tras recargar la tienda, su botón "Agregar al carrito" está deshabilitado con texto "Sin stock"; el producto no se puede agregar al carrito.
14. **Alta de producto desde el panel aparece en la tienda.** Panel → Inventario → Agregar: nombre "Buzzer iPhone 11", SKU `BUZ-001`, categoría Cámaras, descripción "Altavoz auricular de repuesto", precio 150, stock 7 ⇒ recargar la tienda, buscar "Buzzer" ⇒ la tarjeta aparece y su ficha muestra la descripción "Altavoz auricular de repuesto".
15. **Baja de producto desaparece de la tienda.** Panel → Inventario → Borrar `BUZ-001` ⇒ recargar la tienda, buscar "Buzzer" ⇒ "No se encontraron productos".
16. **Alta de reparación genera orden consultable.** Panel → POS → "Equipos para reparar" → cliente "Karen Sánchez", marca "Apple", modelo "iPhone 14", trabajo "Cambio de batería" → Registrar. La fila nueva muestra un número de orden con formato `OR-1013`. Recargar la tienda → Reparaciones → buscar `OR-1013` ⇒ tarjeta con estado "Recibido", dispositivo "Apple iPhone 14" y trabajo "Cambio de batería".
17. **Cambio de estado visible para el cliente.** Panel → cambiar el estado de `OR-1013` a "Listo para entrega" ⇒ recargar la tienda y buscar `OR-1013` ⇒ la tarjeta muestra "Listo para entrega".
18. **Cobro de reparación.** Panel → botón "Cobrar" de `OR-1013` → monto `500`, método Efectivo → Confirmar. En `DB` existe una venta `R-####` con `tipo === 'reparacion'`, `total === 500`; la reparación tiene `charged === true` y `cost === 500`. Tras recargar el panel, la fila sigue mostrando "Cobrado $500.00"; al buscar `OR-1013` en la tienda, la tarjeta muestra `$500.00`.
19. **Caja persistente con cortes por turno.** Panel → "Abrir caja" con `$1000` ⇒ recargar el panel: el botón del quickbar dice "Cerrar caja" y `DB.caja.abierta === true`. Registrar una venta en efectivo de `$100` (cualquier producto) y abrir el corte: el efectivo de "Ventas y refacciones" del corte es el de esa venta (no incluye las ventas semilla, cuyo `ts` es previo). Corte final ⇒ `DB.caja.abierta === false` y `DB.caja.cortes.length >= 2`.
20. **Cancelación repone stock en ambas apps.** Panel (dueño) → POS → Cancelaciones → cancelar la venta del criterio 6 ⇒ la venta queda `cancelled === true` y `PANT-001` vuelve a `stock === 14`; recargar la tienda ⇒ la ficha muestra "14 pzas".
21. **Roles intactos.** Login `vendedor/vendedor123`: la pestaña "Usuarios" no es visible y la vista Panel muestra el bloqueo (`#panelLocked` visible, `#panelContent` oculto). Login `admin/admin123`: los sub-tabs de Inventario "Editar" y "Borrar" están visibles.
22. **Usuarios persistentes.** Dueño → Usuarios → crear `{Nombre: 'Prueba QA', usuario: 'qa', contraseña: 'qa123', rol: vendedor}` ⇒ recargar `refactel.html` e iniciar sesión con `qa/qa123` ⇒ entra y la etiqueta de sesión dice "Prueba QA · Vendedor".
23. **Reset determinista.** Ejecutar `window.RefacTelDB.reset()` en cualquiera de las dos apps ⇒ `DB` vuelve al seed (`products.length === 20`, `sales.length === 5`, `counters.sale === 1005`) y la otra app, al recargar, muestra el catálogo original (p. ej. `PANT-001` con 14 pzas).
24. **Tolerancia a datos corruptos.** Con `localStorage.setItem('refactel_db_v1', '{esto no es json')`, abrir cualquiera de las dos apps ⇒ carga normalmente (catálogo con 20 productos), reescribe el seed válido en la clave y **no** se registran errores no capturados en la consola (`pageerror`).

**Definición de terminado:** los 24 criterios pasan.
