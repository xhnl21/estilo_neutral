# Manual de Usuario

Guía de uso de la app **Estilo Neutral** para el equipo del negocio. No requiere conocimientos técnicos.

## ¿Qué es esta app?

Es el sistema donde se registra todo el negocio: clientes, inventario, ventas, compras de divisas y el cierre de caja diario. Todo lo que cargás acá queda guardado automáticamente y lo pueden ver los demás usuarios autorizados.

## Iniciar sesión

1. Al abrir la app vas a ver un video de introducción con el logo.
2. Aparece la pantalla **"Iniciar Sesión"**. Tocá **"Continuar con Google"**.
3. Elegí tu cuenta de Google de la lista (tiene que ser una cuenta autorizada para usar el sistema — si tu cuenta no está habilitada, vas a ver un mensaje avisando que no tenés acceso; en ese caso, pedile al administrador que la agregue).
4. Si en tu negocio está activado el **Biométrico** (ver sección Seguridad más abajo), te va a pedir tu huella o Face ID antes de dejarte entrar.
5. Listo, entrás directo a la vista de **Ventas**.

## Cómo moverte por la app

- Arriba a la izquierda hay un botón de menú (☰) que abre una lista con las **10 secciones** del sistema, agrupadas en:
  - **Operaciones**: Clientes, Inventario, Ventas, Compras Divisas.
  - **Cierre y Finanzas**: Resumen Diario.
  - **Gobierno y Calidad**: Cuarentena, Auditoría, Reporte de Migración, Checklist ISO, Seguridad.
- Abajo tenés accesos directos a las 4 secciones más usadas, y un botón **"Más Vistas"** para el resto.
- Al final del menú lateral está el botón **"Cerrar sesión"**.

## Clientes

Acá se registran las personas que te compran.

- **Agregar uno nuevo:** botón **"Nuevo Cliente"** (abajo a la derecha) → completá nombre, teléfono, correo y si arranca con alguna deuda → **Guardar**.
- **Buscar:** usá el buscador de arriba, por nombre, teléfono o correo.
- **Editar o borrar:** cada cliente tiene un ícono de lápiz (editar) y uno de papelera (borrar). Borrar pide confirmación porque no se puede deshacer.

## Inventario

Acá están los productos que vendés, con su stock y precio.

- **Agregar un producto:** botón **"Nuevo Producto"** → nombre, marca, modelo, talla, cantidad y precio en dólares. Opcionalmente podés poner el enlace de una foto guardada en Google Drive.
- **Sumar o restar stock rápido:** cada producto tiene botones **+** y **−** al lado de la cantidad, para no tener que abrir el formulario completo cada vez que entra o sale mercadería.
- **Cambiar la foto:** ícono de imagen en la tarjeta del producto.
- **Editar o borrar:** igual que en Clientes.

## Ventas

Acá se registra cada venta que hacés.

- **Registrar una venta:** botón **"Nueva Venta"** → elegís el cliente y el producto (tienen que estar ya cargados en sus secciones), cantidad, forma de pago y cuánto te pagó el cliente en el momento (abono). El sistema calcula solo el total en bolívares y dólares, y si quedó algo pendiente de cobrar.
- **Registrar un abono:** si una venta quedó con saldo pendiente, entrás al detalle y usás **"Registrar Abono"** cada vez que el cliente te vaya pagando.
- **Anular una venta:** pide confirmación, es para corregir errores de carga.

## Compras Divisas (Tesorería)

Acá registrás cuando comprás dólares (por ejemplo en Binance u otra plataforma P2P).

- **Nueva Compra:** capital en USD, comisión, número de orden, plataforma y vendedor, y las tasas del día.
- Si algo no cierra matemáticamente (por ejemplo las fechas o los montos no coinciden), la fila se marca en rojo para que la revises.

## Resumen Diario

Es el cierre de caja del día: cuántas ventas hubo, cuánto entró en bolívares y dólares, y cuánto compraste/vendiste en divisas. Se calcula automáticamente a partir de lo que ya cargaste en Ventas y Compras Divisas — vos solo cargás la fecha y las tasas del día con **"Nuevo Cierre"**.

## Cuarentena, Auditoría, Reporte de Migración y Checklist ISO

Estas 4 secciones son de control y trazabilidad interna del sistema (pensadas más para revisión administrativa que para el uso diario del negocio):

- **Cuarentena:** registros que quedaron marcados como "raros" para revisar manualmente antes de darlos por buenos.
- **Auditoría:** un historial de qué se cambió en el sistema y cuándo — útil si hay que investigar algo.
- **Reporte de Migración:** un panel con métricas generales de calidad de los datos.
- **Checklist ISO:** una lista de controles de calidad/seguridad que se pueden marcar como cumplidos (☑) o pendientes (☐).

## Seguridad

Acá activás o desactivás cómo querés poder entrar a la app además del login con Google:

- **Biométrico** (huella dactilar o Face ID) — ya funciona: si lo activás, la próxima vez que cualquiera del negocio inicie sesión le va a pedir la huella/rostro además de la cuenta de Google.
- **Desbloqueo facial** y **2FA** (verificación en dos pasos) — todavía no tienen efecto al activarlos, quedan guardados como preferencia para más adelante.

Con tocar el switch alcanza — se guarda solo. Este ajuste es compartido por todos los usuarios de tu mismo negocio (si otro usuario lo cambia, vos también lo vas a ver cambiado).

## Cerrar sesión

Menú lateral (☰) → **"Cerrar sesión"** → confirmar. La próxima vez que abras la app vas a tener que volver a elegir tu cuenta de Google.

## ¿Algo no funciona?

- Si una pantalla no muestra datos nuevos, buscá el botón de **refrescar** (ícono de flechas circulares) arriba de la vista — la app no actualiza sola, hay que pedirle que revise de nuevo.
- Si aparece un mensaje de "sin conexión" o "documento privado", avisale al administrador del sistema.
