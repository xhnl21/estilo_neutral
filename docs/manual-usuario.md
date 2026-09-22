# Manual de Usuario

Guía de uso de la app **Estilo Neutral** para el equipo del negocio. No requiere conocimientos técnicos.

## ¿Qué es esta app?

Es el sistema donde se registra todo el negocio: clientes, inventario, ventas, compras de divisas y el cierre de caja diario. Todo lo que cargás acá queda guardado automáticamente y lo pueden ver los demás usuarios autorizados.

## Iniciar sesión

**La primera vez** (o después de haber cerrado sesión):

1. Al abrir la app vas a ver un video de introducción con el logo.
2. Aparece la pantalla **"Iniciar Sesión"**, con el botón **"Continuar con Google"** y un texto que te explica qué va a pasar (la primera vez es con Google; las próximas, con el método que tengas activado en Seguridad).
3. Tocá el botón y elegí tu cuenta de Google de la lista (tiene que ser una cuenta autorizada para usar el sistema — si tu cuenta no está habilitada, vas a ver un mensaje avisando que no tenés acceso; en ese caso, pedile al administrador que la agregue).
4. Listo, entrás directo a la vista de **Ventas** (o al paso siguiente, si tenés un método de Seguridad activado — ver abajo).

**Las veces siguientes** (sin haber cerrado sesión): no hace falta elegir la cuenta de Google de nuevo. El botón cambia para mostrarte con claridad qué te va a pedir:

- Si tenés **Biométrico** activado, el botón dice "Verificar con Biométrico" con un ícono de mano — tocalo y te pide la huella.
- Si tenés **Desbloqueo facial** activado, la app primero revisa si tu celular realmente tiene reconocimiento facial. Si lo tiene (por ejemplo un iPhone con Face ID), el botón dice "Verificar con Face ID" y te pide el rostro. Si tu celular no lo tiene (la mayoría de los Android con solo sensor de huella), el botón directamente dice "Verificar con Biométrico" y te pide la huella — nunca te va a prometer Face ID si tu equipo no lo puede cumplir.
- Si tenés **2FA** activado, dice "Verificar con 2FA" con un ícono de candado.
- Si no activaste ninguno, entrás derecho sin que te pida nada.

En todos los casos, el paso extra recién se pide **cuando tocás el botón** — no aparece solo apenas abrís la app.

## Cómo moverte por la app

- Arriba a la izquierda hay un botón de menú (☰) que abre una lista con las **12 secciones** del sistema, agrupadas en:
  - **Operaciones**: Clientes, Inventario, Ventas, Compras Divisas.
  - **Cierre y Finanzas**: Resumen Diario.
  - **Gobierno y Calidad**: Cuarentena, Auditoría, Reporte de Migración, Checklist ISO, Seguridad.
  - **Administración**: Usuarios, Organizaciones.
- Abajo tenés accesos directos a las 4 secciones más usadas, y un botón **"Más Vistas"** para el resto.
- Al final del menú lateral está el botón **"Cerrar sesión"**.

## Clientes

Acá se registran las personas que te compran.

- **Agregar uno nuevo:** botón **"Nuevo Cliente"** (abajo a la derecha) → completá nombre, teléfono, correo y si arranca con alguna deuda → **Guardar**.
- **Buscar:** usá el buscador de arriba, por nombre, teléfono o correo.
- **Ver sus compras:** ícono de carrito 🛒 en la tarjeta del cliente → te lleva a **Ventas** mostrando solo las facturas de ese cliente (con un botoncito para volver a ver todas).
- **Editar o borrar:** cada cliente tiene un ícono de lápiz (editar) y uno de papelera (borrar). Borrar pide confirmación porque no se puede deshacer.

## Inventario

Acá están los productos que vendés, con su stock y precio.

- **Agregar un producto:** botón **"Nuevo Producto"** → nombre, marca, modelo, talla, cantidad y precio en dólares. Opcionalmente podés poner el enlace de una foto guardada en Google Drive.
- **Sumar o restar stock rápido:** cada producto tiene botones **+** y **−** al lado de la cantidad, para no tener que abrir el formulario completo cada vez que entra o sale mercadería.
- **Cambiar la foto:** ícono de imagen en la tarjeta del producto.
- **Editar o borrar:** igual que en Clientes.

## Ventas

Acá se registra cada venta (factura) que hacés. Una venta puede tener **varios productos** — por ejemplo, si el cliente se lleva un pantalón y una gorra en la misma compra, es una sola factura con dos productos adentro, no dos ventas separadas.

- **Registrar una venta:** botón **"Nueva Venta"** → elegís el cliente → armás el carrito: elegís un producto, la cantidad, y tocás **"Agregar"** (repetís esto por cada producto que se lleve el cliente — vas viendo el subtotal de cada uno y el total de la factura) → forma de pago, tasas y cuánto te pagó el cliente en el momento (abono) → **"Guardar Venta"**. El sistema calcula solo el total en bolívares y dólares, y si quedó algo pendiente de cobrar.
- **Ver el detalle de una factura:** tocá la factura en la lista para ver cada producto que incluye, con su foto, cantidad, precio y subtotal.
- **Registrar un abono:** si una factura quedó con saldo pendiente, usás **"Registrar Abono"** en su tarjeta cada vez que el cliente te vaya pagando.
- **Anular una venta:** pide confirmación, es para corregir errores de carga — repone automáticamente el stock de todos los productos que tenía esa factura.

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

Acá elegís **un solo** método adicional para entrar a la app, además del login con Google (elegir uno desactiva automáticamente el anterior — no se pueden combinar):

- **Ninguno** — solo pide la cuenta de Google, sin paso extra.
- **Biométrico** (huella dactilar) — ya funciona: la próxima vez que cualquiera del negocio inicie sesión le va a pedir la huella.
- **Desbloqueo facial** — solo funciona en equipos que realmente tienen reconocimiento facial (por ejemplo Face ID de iPhone).
- **2FA** (verificación en dos pasos) — todavía no tiene efecto al elegirlo, queda guardado como preferencia para más adelante.

**La pantalla revisa tu celular antes de mostrarte las opciones**: si tu equipo no tiene sensor de huella ni reconocimiento facial, esas dos opciones directamente no aparecen en la lista (solo vas a ver "Ninguno" y "2FA"), para que no elijas algo que tu equipo no puede cumplir. Si el método que vos mismo habías activado deja de ser compatible (por ejemplo, activaste "Desbloqueo facial" desde un iPhone y ahora entrás a esta pantalla desde un Android sin esa función), la app lo desactiva sola y vuelve a "Ninguno".

Con tocar la opción alcanza — se guarda sola. **Este ajuste es personal**: es tu propia preferencia, no la de todo el negocio — si otro usuario de tu misma organización cambia el suyo, el tuyo no se ve afectado, y viceversa.

## Usuarios

Acá se administra quién puede entrar al sistema.

- **Dar acceso a alguien nuevo:** botón **"Nuevo Usuario"** → correo de Google, nombre (opcional) y a qué organización pertenece → guardar.
- **Editar:** ícono de lápiz — se puede cambiar el nombre o mover a otra organización. El correo no se puede cambiar una vez creado (si alguien cambió de cuenta de Google, hay que eliminarlo y darlo de alta de nuevo con el correo correcto).
- **Quitar acceso:** ícono de papelera → confirmar. Esa cuenta deja de poder entrar al sistema.

## Organizaciones

Acá se administran las organizaciones que usan el sistema (relevante solo si tu negocio maneja más de una).

- **Crear una organización:** botón **"Nueva Organización"** → nombre → guardar.
- **Editar:** solo se puede cambiar el nombre.
- **Eliminar:** si todavía tiene usuarios asignados, el sistema no te deja borrarla — primero hay que moverlos o eliminarlos.
- **Ver y asignar usuarios:** tocá el ícono de personas 👤 en la tarjeta de la organización para ver quién pertenece a ella. Desde ahí podés:
  - **Agregar un usuario que ya existe** (elegilo de la lista desplegable y tocá "Agregar").
  - **Mover un usuario a otra organización** (ícono de flechas cruzadas junto a su nombre).

  Esto es lo mismo que elegir la organización al crear o editar un usuario desde **Usuarios** — está disponible en los dos lugares para más comodidad.

## Cerrar sesión

Menú lateral (☰) → **"Cerrar sesión"** → confirmar. Lo que pasa después depende de si tenés un método activado en Seguridad:

- **Si no tenés ningún método activado:** la próxima vez que abras la app vas a tener que volver a elegir tu cuenta de Google.
- **Si tenés Biométrico, Desbloqueo facial o 2FA activado:** la próxima vez que abras la app **no** te va a pedir elegir la cuenta de Google de nuevo — va directo a pedirte ese método (huella, rostro o 2FA) para entrar.

## ¿Algo no funciona?

- Si una pantalla no muestra datos nuevos, buscá el botón de **refrescar** (ícono de flechas circulares) arriba de la vista — la app no actualiza sola, hay que pedirle que revise de nuevo.
- Si aparece un mensaje de "sin conexión" o "documento privado", avisale al administrador del sistema.
