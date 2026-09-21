# Estilo Neutral — Conector Móvil Flutter & Google Sheets ORM

Arquitectura de cliente para Google Sheets refactorizada bajo las normas internacionales **ISO/IEC 25010**, **ISO 8000** (Calidad de Datos), **ISO 8601** (Fechas), **ISO/IEC 27001** (Seguridad), **GDPR Art. 5**, **COBIT 2019** y **OWASP MASVS**.

## Documentación

La documentación completa (arquitectura, dominio, integraciones con Google, automatización) vive en `docs/` y se navega con [MkDocs](https://www.mkdocs.org/):

```bash
pip3 install -r docs-requirements.txt   # una vez
python3 -m mkdocs serve                  # sirve en http://127.0.0.1:8000 con recarga en vivo
python3 -m mkdocs build                  # genera el sitio estático en site/ (gitignoreado)
```

---

## 1. Declaración de Política: CERO POLLING (Pull Bajo Demanda)

> [!IMPORTANT]
> **NO se implementó polling.** La aplicación NO utiliza temporizadores (`Timer.periodic`), tareas de fondo periódicas ni `Streams` basados en tiempo.
>
> - **Carga Inicial**: Se realiza una única petición puntual de lectura cuando el usuario ingresa a una pantalla.
> - **Refresco Manual**: La actualización es 100% controlada por el usuario mediante botones de refresco (`RefreshIndicator` o botones "Actualizar").
> - **Mutaciones (Escritura)**: Cada operación de guardado ejecuta una escritura atómica (`append` / `update`), invalida la memoria caché local y ejecuta una relectura puntual de confirmación.

---

## 2. Configuración en Google Cloud Platform (GCP)

Para conectar la app de Flutter con la hoja de cálculo de Google Sheets:

### 2.1 Habilitar APIs en Google Cloud Console

1. Ingresa a [Google Cloud Console](https://console.cloud.google.com/).
2. Crea o selecciona tu proyecto de Google Cloud.
3. Dirígete a **APIs & Services → Library** y habilita:
   - **Google Sheets API**
   - **Google Drive API**

### 2.2 Pantalla de Consentimiento OAuth (OAuth Consent Screen)

1. En **OAuth consent screen**, selecciona el tipo de usuario (Interno o Externo).
2. Agrega los **Scopes requeridos**:
   - `https://www.googleapis.com/auth/spreadsheets` _(Lectura y escritura de la hoja)_
   - `https://www.googleapis.com/auth/drive.readonly` _(Lectura de metadatos y fotos de productos en Drive)_

### 2.3 Crear Credenciales de Cliente OAuth 2.0

1. En **Credentials → Create Credentials → OAuth Client ID**:
   - Para **Android**: Configura el nombre del paquete (Package Name) y la huella digital SHA-1 de tu certificado de desarrollo (`keytool`).
   - Para **iOS/macOS**: Configura el Bundle Identifier.
2. Descarga los archivos de configuración (`google-services.json` para Android / `GoogleService-Info.plist` para iOS) e intégralos en las carpetas nativas de Flutter.

---

## 3. Mapeo de Entidades y Estructura de Hojas

| Hoja en Google Sheets | Clase en Dart        | Modo de Acceso               | Clave Primaria / Columnas Críticas                            |
| :-------------------- | :------------------- | :--------------------------- | :------------------------------------------------------------ |
| `clientes`            | `Cliente`            | Lectura / Escritura          | ID `c00000001` (A), Teléfono E.164 (C), Deuda (E)             |
| `inventario`          | `Producto`           | Lectura / Escritura          | ID `p00000001` (A), Stock (B), Precio USD (G), `foto_url` (H) |
| `ventas`              | `Venta`              | Lectura / Escritura          | ID `v00000001` (A), FK Cliente (C), FK Item (D), Estado (P)   |
| `compras_divisas`     | `CompraDivisa`       | Lectura / Escritura          | ID `d00000001` (A), Fecha (B, C), Capital (D), Validación (K) |
| `resumen_diario`      | `ResumenDiario`      | **Solo Lectura (Inmutable)** | Fecha (A), Fórmulas dinámicas `COUNTIF` / `SUMIF`             |
| `cuarentena`          | `RegistroCuarentena` | **Solo Lectura (Inmutable)** | Evidencia histórica forense con `hash_evidencia` SHA-256      |
| `audit_log`           | `AuditLog`           | **Solo Lectura (Inmutable)** | Bitácora continua ISO 27001 con timestamps ISO 8601           |
| `reporte_migracion`   | `ReporteMigracion`   | **Solo Lectura (Inmutable)** | Resumen ejecutivo de auditoría y firmas digitales             |
| `checklist_iso`       | `ChecklistISO`       | **Solo Lectura (Inmutable)** | 20 Controles de auditoría técnica marcados con `☑`            |

---

## 4. Política de Manejo de Errores y Validaciones Offline

1.  **Detección de Referencias Huérfanas**:
    - Antes de enviar una nueva transacción, el repositorio verifica que el `cliente_id` exista en el catálogo de `clientes` y el `item_id` exista en `inventario`. Si no existen, se rechaza la operación localmente impidiendo datos huérfanos.
2.  **Validación de Consistencia Matemática**:
    - Si una fila tiene `validacion == "ERROR"`, la interfaz de usuario la resalta visualmente en rojo suave y advierte al operador para su revisión o cuarentena.
3.  **Manejo de Excepciones de Red**:
    - Las fallas de conexión no cierran la app de forma abrupta; emiten eventos capturables mediante `ValidationResult` o `SnackBar` sin interrumpir la navegación.
4.  **Almacenamiento Seguro**:
    - Los tokens de autenticación se persisten de manera cifrada utilizando `flutter_secure_storage` (Keychain en iOS/macOS y EncryptedSharedPreferences en Android).


        Nuevos Datos del Almacén de Claves

    Parámetro Valor
    Archivo Keystore android/app/upload-keystore.jks
    Formato / Tipo PKCS12
    Contraseña del Keystore (storePassword) estiloneutral
    Nombre de Alias (keyAlias) upload
    Contraseña de Clave (keyPassword) estiloneutral
    Tipo de Clave RSA 2048 bits
    Algoritmo de Firma SHA256withRSA
    Vigencia 10.000 días (hasta el 03-Feb-2054)
    🏛️ Datos del Certificado (Distinguished Name)
    Nombre Común (CN): Estilo Neutral
    Unidad Organizativa (OU): Mobile
    Organización (O): Estilo Neutral (actualizado)
    Ciudad/Localidad (L): Caracas
    Estado/Provincia (ST): Miranda
    País (C): VE
