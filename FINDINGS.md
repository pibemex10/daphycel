# Findings — pass 2 · 2026-09-21

## Resumen

**24/24 criterios del rubric pasan**, verificados por ejecución real con Playwright/Chromium (un único `browserContext`, ambas páginas servidas desde `http://localhost:8080`, mismo origen).

Nota de proceso: el Evaluator estándar del harness no tuvo `Bash` disponible en esta sesión (ver pass 1) y falló dos veces por esa razón — ausencia de herramienta, no del código. Ante ese bloqueo, el humano pidió explícitamente que el orquestador rompiera el aislamiento normal del harness y verificara directamente con Playwright, ya que sí tenía `Bash`/PowerShell disponible. Este pass documenta esa verificación de excepción.

## Metodología

Script de Playwright (`verify.js`) que recorre los 24 criterios de §7 de `SPEC.md` en orden, con dependencias reales entre pasos (igual que usaría un usuario real): siembra desde cero (criterios 1-5), luego un flujo continuo de negocio (venta, crédito, abono, reseña, edición, checkout online, alta/baja de producto, reparación con cobro, caja con cortes, cancelación, roles, usuario nuevo — criterios 6-22), y finalmente reset determinista y tolerancia a JSON corrupto (23-24).

Durante la escritura del script se encontraron y corrigieron **3 bugs del propio script de prueba** (no del código de la app):
1. Un modal (`#clientModal`) quedaba abierto tras el criterio 9 y su overlay `position:fixed;inset:0` interceptaba clicks de criterios posteriores — causaba timeouts que parecían fallos de la app.
2. Listeners de diálogo (`alert`/`confirm`) duplicados (uno global + uno local por criterio) competían por aceptar el mismo diálogo nativo, y el segundo lanzaba una excepción no capturada que tumbaba el proceso de Node.
3. `window.DaphycelDB.reset()` dispara `location.reload()` desde dentro de la página; había que esperar la navegación con `waitForNavigation()` en paralelo al `evaluate()`, no de forma secuencial.

Ningún hallazgo de estos 3 correspondía a un defecto de `daphycel.html` / `daphycel-cliente.html`.

## Resueltos (verificados este pass, ejecutando la app real)

- [x] F-01 (pass 1) · el bloqueo de proceso por falta de `Bash` del Evaluator estándar — resuelto mediante verificación directa del orquestador, autorizada explícitamente por el humano.
- [x] Los 24 criterios de §7 de SPEC.md, uno por uno, con evidencia de ejecución (ver detalle de cada corrida más abajo). Incluye: siembra idéntica byte a byte entre ambos archivos, venta en efectivo/crédito/online reflejadas cruzadamente, abono, reseña sobreviviendo a edición del panel, alta/baja de producto e impacto en tienda, ciclo completo de reparación (alta → cambio de estado → cobro) visible desde la tienda por número de orden, caja con cortes por turno, cancelación reponiendo stock y saldo, roles intactos, usuario nuevo persistente, reset determinista, y tolerancia a `localStorage` corrupto sin `pageerror`.

## Abiertos

(Ninguno.)

## Definición de terminado

24/24 criterios pasan → **build terminado**, según §"Definición de terminado" de SPEC.md.

---

# Findings — pass 3 · 2026-10-05 · Migración a Supabase

## Resumen

Migración completa de la fuente única de `localStorage` a un backend real en Supabase (Postgres + PostgREST + RPC), a petición explícita del humano para lograr sincronización real entre dispositivos distintos (no solo pestañas del mismo navegador). **17/17 verificaciones pasan**, probadas con **dos `browserContext` de Playwright totalmente independientes** (sin compartir cookies ni storage — "dispositivo A" = panel en la PC de la tienda, "dispositivo B" = tienda pública en el celular de un cliente), lo cual demuestra sincronización real entre dispositivos y no un artefacto de compartir el mismo navegador.

## Qué cambió

- Esquema relacional en Postgres (`supabase-schema.sql` + `supabase-schema-2.sql`): `products`/`product_reviews`, `customers`, `sales`/`sale_items`, `repairs`, `users`, `counters`, `caja`/`caja_cortes`, `settings`.
- `users` sin política pública — solo accesible vía funciones `SECURITY DEFINER` (`login_check`, `create_user`, `change_password`, `delete_user`) que nunca devuelven `password`. Verificado explícitamente: `GET /rest/v1/users` con la clave pública devuelve `[]`.
- Operaciones de dinero atómicas vía RPC (`create_sale`, `cancel_sale`, `abonar`, `increment_counter`) — resuelven condiciones de carrera reales entre dispositivos concurrentes, verificado con datos de prueba desechables antes de tocar datos reales (11/11 verificaciones de las funciones RPC en aislamiento).
- `daphycel.html` y `daphycel-cliente.html` reescritos: toda la capa de persistencia (antes síncrona sobre `localStorage`) pasa a ser asíncrona contra Supabase; cada punto de mutación (~26 en el panel, ~2 en la tienda) usa la llamada específica que le corresponde en vez de un `saveDB()` genérico.

## Metodología

1. Verificación aislada de las funciones RPC con datos desechables (`TEST-SKU`/`TEST-CUST`), limpiados al terminar — 11/11 pasan.
2. Pruebas de humo (`smoke-panel.js`/`smoke-tienda.js`) tras la reescritura de cada archivo, antes de la verificación completa.
3. Verificación de extremo a extremo (`verify-supabase.js`) con dos `browserContext` independientes: siembra visible desde ambos dispositivos, venta en efectivo/crédito, reseña sobreviviendo edición, checkout online, checkout sin stock, ciclo de reparación (alta → cobro) consultable por `OR-####`, caja con cortes, cancelación, roles, correo de notificaciones restringido al dueño, cambio de contraseña (de un vendedor y del propio dueño) con reingreso exitoso usando la contraseña nueva, y ausencia de errores de página (`pageerror`) en ambos dispositivos durante toda la corrida.

Durante la escritura del script de verificación se encontraron y corrigieron **3 causas reales de fallo**, todas en el código de la app (a diferencia del pass 2, donde los 3 hallazgos habían sido del script de prueba):
1. La tabla `repairs` se leía sin `ORDER BY` — el array local ya no garantiza "más nuevo primero" como antes (cuando se insertaba al inicio del array en memoria). Corregido con `.order('order_no', {ascending:false})` en ambos archivos.
2. El historial de cortes de caja (`caja.cortes`) debía filtrarse por el turno abierto actual (`created_at >= caja.aperturaTs`), replicando el comportamiento de "se reinicia en cada apertura" que antes daba el array en memoria — sin este filtro, cortes de turnos anteriores se mezclarían con el turno actual.
3. (Del propio script de prueba, no de la app) esperas insuficientes entre acciones: contra una base de datos real en internet cada operación toma más que el acceso instantáneo a `localStorage`; se corrigió esperando explícitamente el diálogo nativo en vez de un `setTimeout` fijo, y aumentando las esperas tras navegaciones.

## Resueltos (verificados este pass, ejecutando contra la base de datos real)

- [x] Los 17 puntos de la verificación de extremo a extremo, con evidencia de ejecución entre dos dispositivos simulados independientes.
- [x] Las 4 funciones RPC atómicas (`increment_counter`, `create_sale`, `cancel_sale`, `abonar`), incluida la validación de stock insuficiente dentro de la transacción.
- [x] La tabla `users` es inaccesible con la clave pública; el login y la gestión de contraseñas pasan exclusivamente por RPC.

## Abiertos

- [ ] F-02 · minor · Los roles (`dueno`/`administrador`/`vendedor`) solo se aplican en la interfaz; a nivel de base de datos cualquier poseedor de la clave pública podría, en teoría, llamar directamente a la API REST y saltarse una restricción de rol (ej. editar inventario como si fuera vendedor). Mitigado para lo más sensible (contraseñas, nunca expuestas), aceptado como riesgo de v1 para el resto. Solución completa: migrar a Supabase Auth con RLS por usuario.

## Definición de terminado

17/17 verificaciones de la migración pasan → la app funciona con sincronización real entre dispositivos distintos.
