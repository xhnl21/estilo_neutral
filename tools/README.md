# Herramientas de despliegue

Automatiza los dos pasos manuales que hacíamos a mano en Google Sheets/Apps Script:

- `apps_script/` → sube `google_apps_script.js` y publica una nueva versión de la implementación Web App **existente** (la URL `/exec` no cambia).
- `sheets_sync/` → reemplaza el contenido del Google Sheet real con `Estilo Neutral.xlsx` (equivalente a Archivo → Importar → Reemplazar hoja de cálculo, pero por línea de comandos).

Cada una requiere una configuración única (una sola vez). Después de eso, actualizar es un solo comando.

---

## 1. Apps Script (`tools/apps_script/`)

### Setup (una sola vez)

1. Instalar dependencias:
   ```bash
   cd tools/apps_script
   npm install
   ```
2. Iniciar sesión con tu cuenta de Google (abre el navegador):
   ```bash
   npm run login
   ```
3. Conseguir el **Script ID** del proyecto:
   - Abrí tu Google Sheet → **Extensiones → Apps Script**.
   - Ícono de engranaje ⚙️ (Configuración del proyecto) en la barra lateral izquierda.
   - Copiá el valor de **"ID"** (bajo "IDs de proyecto").
4. Pegá ese ID en `tools/apps_script/.clasp.json`, reemplazando `PEGA_AQUI_TU_SCRIPT_ID`.

### Uso (cada vez que cambies `google_apps_script.js`)

```bash
cd tools/apps_script
npm run deploy
```

Esto corre `clasp push` (sube el código) y `clasp deploy --deploymentId ...` (publica una nueva versión sobre la implementación que ya existe, sin generar una URL nueva). El `DEPLOYMENT_ID` ya está fijado en `deploy.sh` (es el mismo que quedó configurado en `.env` como `APPS_SCRIPT_URL`).

Si alguna vez creás una implementación completamente nueva (URL distinta), actualizá `DEPLOYMENT_ID` en `deploy.sh` y los 4 archivos `.env*`.

---

## 2. Reemplazo del Sheet (`tools/sheets_sync/`)

### Setup (una sola vez)

1. Instalar dependencias de Python:
   ```bash
   cd tools/sheets_sync
   pip3 install -r requirements.txt
   ```
2. Crear credenciales OAuth en Google Cloud Console (mismo proyecto que ya usás para el login de Google de la app):
   - [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials) → **Create Credentials → OAuth Client ID**.
   - **Tipo de aplicación:** `Aplicación de escritorio` (Desktop app).
   - Nombre: `Estilo Neutral - Sheets Sync CLI` (o el que prefieras).
   - Click **Crear**, luego **Descargar JSON**.
3. Guardá ese archivo descargado como:
   ```
   tools/sheets_sync/client_secret.json
   ```
   (el nombre exacto importa, el script lo busca así).

### Uso (cada vez que cambies el .xlsx)

```bash
cd tools/sheets_sync
python3 upload_sheet.py
```

La primera vez abre el navegador para autorizar acceso a Drive (una sola vez — vas a ver la pantalla de "Google no verificó esta app", hacé clic en **Avanzado → Ir a ... (no seguro)**, es tu propia credencial). Después queda cacheado en `token.json` y no vuelve a pedir login.

Por defecto toma `Estilo Neutral.xlsx` de la raíz del repo. Podés pasar otra ruta:
```bash
python3 upload_sheet.py /ruta/a/otro/archivo.xlsx
```

⚠️ Esto **reemplaza todo el contenido** del Sheet real. Los datos que no estén en el `.xlsx` local se pierden. Asegurate de que el `.xlsx` que estás subiendo sea el que realmente querés que quede.

**Por eso, antes de editar el `.xlsx` a mano o de correr un script de migración, bajá primero el estado real:**

```bash
cd tools/sheets_sync
python3 download_sheet.py
```

Sobreescribe la copia local con el contenido actual de Drive (la app y la gente que la usa escriben directo en el Sheet real todo el tiempo — la copia local se desactualiza sola, no hay sincronización automática). Mismas credenciales que `upload_sheet.py`, sin setup adicional. Acepta también una ruta de salida opcional.

---

## Archivos sensibles

`client_secret.json` y `token.json` (Drive) nunca se commitean — están en `.gitignore`. Lo mismo aplica a cualquier credencial de `clasp login` (se guarda fuera del repo, en tu home).
