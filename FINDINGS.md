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
