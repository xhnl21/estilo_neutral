# Copias de Seguridad Automáticas (Respaldos)

**Norma de referencia:** ISO/IEC 27001:2022 control §8.13 (Information backup)  
**Ubicación:** Google Drive en la carpeta privada `Estilo Neutral · Privado/Respaldos`  
**Frecuencia:** Semanal automática (domingos a las 2:00 a. m. hora de Venezuela, `GMT-4`)  

---

## 1. Cómo funciona el sistema de respaldos

1. **Sin costo adicional:** Utiliza exclusivamente las cuotas nativas y gratuitas de Google Drive y Google Apps Script. No requiere servidores externos ni cuentas de facturación.
2. **Privacidad garantizada:** Las copias se generan dentro de la subcarpeta `Respaldos`, que cuelga directamente de la carpeta privada `Estilo Neutral · Privado`. Al estar fuera de la carpeta pública de fotos y heredar los permisos restringidos, ninguna copia es accesible por terceros ni por enlace público.
3. **Nombre fechado:** Cada copia conserva el nombre de la hoja seguido de la marca temporal exacta de Venezuela:
   ```
   Estilo Neutral · Respaldo yyyy-MM-dd_HH-mm-ss
   ```
4. **Registro de auditoría inmutable:** Cada ejecución (exitosa o con error) deja asentada una fila en la hoja `audit_log`:
   - `hoja`: `sistema`
   - `celda`: `Drive/Respaldos`
   - `valorNuevo`: ID del archivo copiado (o `ERROR`)
   - `accion`: `respaldo_hoja` (o `respaldo_hoja_error`)
   - `norma`: `ISO/IEC 27001 §8.13`
   - `observaciones`: Detalle del archivo creado

---

## 2. Activador semanal automático

El activador se instala ejecutando la función `crearTriggerRespaldo()` en Apps Script:
- **Día y hora:** Domingos a las 2:00 a. m. (horario de mínimo tráfico comercial, antes de la reorganización de Drive de los lunes).
- **Protección contra duplicados:** Si el activador ya existe, la función elimina los duplicados previos y deja uno solo activo.
- **Consulta:** La función `listarTriggersRespaldo()` permite verificar los activadores instalados.

---

## 3. Interruptor de emergencia (Kill-Switch)

Si por algún motivo operativo el dueño desea pausar temporalmente los respaldos automáticos sin desinstalar el activador ni tocar código:
1. En el editor de Google Apps Script ir a **⚙ Configuración del proyecto** → **Propiedades del script**.
2. Agregar la propiedad:
   - **Propiedad:** `RESPALDO_AUTOMATICO`
   - **Valor:** `no`
3. Al ejecutarse, `respaldarHoja()` registrará en los logs que el respaldo fue omitido por configuración y retornará `{ status: "skipped" }`.
4. Para reactivar los respaldos, simplemente borrar la propiedad o cambiar su valor a `si`.

---

## 4. Procedimiento de restauración paso a paso

Si ocurriera una pérdida accidental de datos o corrupción en la hoja principal, el dueño puede restaurar el sistema en tres pasos simples:

### Opción A (Recomendada): Copiar los datos desde el respaldo a la hoja principal
*Esta opción conserva el mismo ID de hoja y no requiere actualizar ninguna propiedad ni aplicación móvil.*

1. Abrir Google Drive y entrar a la carpeta:
   `Mi unidad` → `Estilo Neutral · Privado` → `Respaldos`.
2. Abrir la copia de respaldo deseada (por ejemplo, `Estilo Neutral · Respaldo 2026-10-09_15-52-38`).
3. En la hoja de respaldo abierta:
   - Seleccionar la hoja o los datos que se deseen recuperar (por ejemplo `clientes`, `ventas` o `inventario`).
   - Copiar las filas afectadas y pegarlas en la hoja activa de producción `Estilo Neutral`.

---

### Opción B: Cambiar la hoja activa por el archivo de respaldo
*Útil en caso de desastre total donde la hoja original haya sido eliminada.*

1. Abrir la carpeta `Estilo Neutral · Privado/Respaldos` en Google Drive.
2. Hacer clic derecho sobre la copia de seguridad que se desea activar → **Hacer una copia** (para preservar el archivo de respaldo intacto).
3. Renombrar la copia a `Estilo Neutral` y moverla a la raíz de tu Drive.
4. Obtener el ID de la nueva hoja desde su URL:
   `https://docs.google.com/spreadsheets/d/<NUEVO_SPREADSHEET_ID>/edit`
5. En el editor de Apps Script → **Configuración del proyecto** → **Propiedades del script**:
   - Asignar la propiedad `SPREADSHEET_ID` con el `<NUEVO_SPREADSHEET_ID>`.
6. La Web App y la aplicación móvil comenzarán a utilizar inmediatamente la hoja restaurada sin necesidad de compilar un nuevo APK.

---

## 5. Política de retención recomendada

- Las copias de seguridad de Google Sheets no ocupan cuota significativa (cada hoja representa apenas unos pocos kilobytes/megabytes de metadatos en Google Drive).
- **Recomendación:** Mantener las últimas **12 copias semanales** (~3 meses de historial completo).
- Siguiendo la regla 4 del proyecto, el sistema **nunca elimina automáticamente copias viejas**. Cuando el dueño desee depurar respaldos antiguos de más de 3 o 6 meses, puede moverlos manualmente a la Papelera de Google Drive.
