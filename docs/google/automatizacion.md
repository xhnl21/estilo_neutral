# Automatización local

Dos scripts en [`tools/`](../../tools/) evitan tener que copiar/pegar código en el editor de Apps Script o re-subir el `.xlsx` a mano desde la interfaz de Google Drive. Instrucciones completas también en [`tools/README.md`](../../tools/README.md).

## 1. Apps Script (`tools/apps_script/`) — vía `clasp`

`clasp` es la herramienta oficial de Google para gestionar proyectos de Apps Script por línea de comandos.

### Setup (una sola vez)

```bash
cd tools/apps_script
npm install
```

```bash
npm run login   # abre el navegador, autorizá con tu cuenta de Google
```

Conseguir el **Script ID** (editor de Apps Script → ⚙️ Configuración del proyecto → "ID") y pegarlo en `.clasp.json`, **en la raíz del repo** (no en `tools/apps_script/`):

```json
{
  "scriptId": "1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6",
  "rootDir": "."
}
```

⚠️ Además hay que activar, una vez por cuenta, la **API de Apps Script** en [script.google.com/home/usersettings](https://script.google.com/home/usersettings) — ver [Apps Script → requisito de cuenta](apps-script.md#requisito-de-cuenta-api-de-apps-script).

### Uso

```bash
cd tools/apps_script
npm run deploy
```

Esto corre `clasp push` (sube `google_apps_script.js` + `appsscript.json`) y después `clasp deploy --deploymentId ...` sobre la implementación **existente** — la URL `/exec` nunca cambia.

### Por qué `.clasp.json` vive en la raíz del repo, no en `tools/apps_script/`

`clasp` v3 tiene un chequeo de seguridad que rechaza cualquier `rootDir` que "escape" del directorio donde se ejecuta el comando (para evitar path traversal malicioso). Como el código real (`google_apps_script.js`) vive en la raíz del repo, `.clasp.json` y `.claspignore` también viven ahí (`rootDir: "."`), y los scripts (`login.sh`, `deploy.sh`) hacen `cd` a la raíz del repo antes de invocar el binario de `clasp` instalado en `tools/apps_script/node_modules/.bin/`.

`.claspignore` restringe lo que sube: solo `google_apps_script.js` y `appsscript.json`, ignorando el resto del proyecto Flutter.

## 2. Reemplazo del Sheet (`tools/sheets_sync/`) — vía Drive API

Reemplaza el contenido completo del Google Sheet real a partir de un `.xlsx` local (equivalente a "Archivo → Importar → Reemplazar hoja de cálculo", pero por comando).

### Setup (una sola vez)

```bash
cd tools/sheets_sync
pip3 install -r requirements.txt
```

Crear una credencial OAuth de tipo **Aplicación de escritorio** en el mismo proyecto de Google Cloud que usás para el login (ver [Google Sign-In](sign-in.md)):

1. [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials) → **Create Credentials → OAuth Client ID → App de escritorio**.
2. **Descargar JSON antes de cerrar el diálogo** — el secreto solo se puede descargar en el momento de creación (después queda oculto; si te lo perdiste, hay que borrar el cliente y crear uno nuevo, o entrar al detalle del cliente y usar el ícono de descarga junto a "Secreto del cliente").
3. Guardarlo como `tools/sheets_sync/client_secret.json`.
4. Activar la **Google Drive API** en el proyecto: [console.cloud.google.com/apis/library/drive.googleapis.com](https://console.cloud.google.com/apis/library/drive.googleapis.com) → Habilitar.

### Uso

```bash
cd tools/sheets_sync
python3 upload_sheet.py
```

Por defecto usa `Estilo Neutral.xlsx` de la raíz del repo. La primera vez abre el navegador para autorizar (una sola vez — vas a ver "Google no verificó esta app", click en Avanzado → Ir a... no seguro, es tu propia credencial). El token queda cacheado en `token.json` y no vuelve a pedir login.

⚠️ **Esto reemplaza todo el contenido del Sheet real.** Los datos que no estén en el `.xlsx` local se pierden — verificá siempre el archivo antes de correrlo.

## Archivos sensibles

Nunca se commitean (ya están en `.gitignore`):

- `~/.clasprc.json` (fuera del repo, credencial de `clasp login`)
- `tools/sheets_sync/client_secret.json`
- `tools/sheets_sync/token.json`
- `tools/apps_script/node_modules/`
