# Datos bancarios

Cuentas para **transferencias** y datos de **pago móvil** de cada organización, para tenerlos a mano y pasárselos a los clientes.

En la app: menú lateral → **Administración → Datos bancarios**. Cada organización ve y administra solo los suyos.

## Qué se puede hacer

| Acción | Cómo |
|---|---|
| Crear | Botón **Nuevo**: tipo (Transferencia o Pago móvil), banco, titular, cédula/RIF y, según el tipo, número de cuenta y tipo de cuenta, o teléfono. |
| Filtrar | Chips **Todos / Transferencia / Pago móvil**. |
| Ver | Muestra los datos listos para compartir y el botón **Copiar datos** (para pegarlos en el chat con el cliente). Desde ahí también se activa o inactiva. |
| Editar | Cambia cualquier dato. El interruptor **Activo** marca los que ya no se usan sin borrarlos. |
| Eliminar | Pide confirmación y borra la fila. |

## Reglas (las valida la app y, otra vez, el Apps Script)

- **Banco** del catálogo (hoja `bancos`).
- **Titular** obligatorio (hasta 80 caracteres) y **cédula o RIF** válidos (el RIF con su dígito verificador). Se puede escribir `J-12345678-9` o `12.345.678`: se guarda normalizado.
- **Transferencia:** número de cuenta de **20 dígitos** que **empieza con el código del banco** (por ejemplo, las cuentas de Banesco empiezan con `0134`), y tipo de cuenta **corriente** o **ahorro**.
- **Pago móvil:** celular venezolano (`04XX` + 7 dígitos).
- **Sin duplicados** en la organización: la misma cuenta, o el mismo banco + teléfono de pago móvil. Otra organización sí puede registrar la misma cuenta.

## Hojas

**`bancos`** (catálogo común; la crea el script con los bancos venezolanos y su código SUDEBAN):

| Columna | Contenido |
|---|---|
| `id` | `bn00000001`… (lo genera el servidor). |
| `codigo` | 4 dígitos, como texto (`0102`, `0134`…). Único. |
| `nombre` | Único. |
| `status` | `activo` / `inactivo`. Un banco inactivo no se ofrece para datos nuevos. |

Para agregar o corregir un banco, editá la hoja (el código tiene que tener 4 dígitos y no repetirse).

**`cuentas_bancarias`** (una fila por dato bancario):

| Columna | Contenido |
|---|---|
| `id` | `cb00000001`… (lo genera el servidor). |
| `organizacion_id` | Organización dueña. No cambia al editar. |
| `tipo` | `transferencia` o `pago_movil`. |
| `banco_id` | FK a `bancos.id`. |
| `titular` | Nombre del titular. |
| `tipo_documento`, `documento` | `V`/`E`/`J`/`G`… y el número normalizado, como texto. |
| `numero_cuenta`, `tipo_cuenta` | Solo transferencia: 20 dígitos (texto) y `corriente`/`ahorro`. |
| `telefono` | Solo pago móvil: `04121234567` (texto). |
| `status` | `activo` / `inactivo`. |
| `actualizado_en` | Último cambio (lo escribe el script). |

Las dos hojas se crean solas con la primera escritura, o con `prepararHojasDatosBancarios()` desde el editor de Apps Script (o la acción `preparar_datos_bancarios`). Es idempotente.

## Archivos

| Parte | Archivos |
|---|---|
| Modelos | `lib/models/cuenta_bancaria.dart` (`Banco`, `CuentaBancaria`, `TipoCuentaBancaria`, `ModalidadCuenta`) |
| Servicio | `SheetsDataService.addCuentaBancaria`, `updateCuentaBancaria`, `deleteCuentaBancaria`, `motivoCuentaBancariaInvalida`, `releerDatosBancarios` |
| Estado | `lib/presentation/cubits/datos_bancarios/` (`DatosBancariosCubit`, `CuentaBancariaFormCubit`) |
| Pantalla | `lib/presentation/pages/datos_bancarios_page.dart`, ruta `/datos-bancarios` |
| Script | `_hojaBancos`, `prepararHojasDatosBancarios`, `_normalizarCuentaBancaria`, `_validarCuentaBancaria`, `_validarBanco` en `google_apps_script.js` |
| Tests | `test/features/datos_bancarios/`, `tools/apps_script/tests/datos_bancarios.test.js` |
