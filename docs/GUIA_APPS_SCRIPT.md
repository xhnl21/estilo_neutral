# Guía de Instalación y Despliegue de Google Apps Script (Opción A)

Esta guía te permite habilitar la **escritura remota bidireccional (CRUD completo)** y la **subida de fotos a Google Drive** directamente desde la app Flutter hacia tu archivo de Google Sheets.

---

### Paso 1: Abrir el Editor de Apps Script en tu Hoja
1. Abre tu hoja de cálculo en el navegador:  
   👉 [Abrir Google Sheet: Estilo Neutral](https://docs.google.com/spreadsheets/d/1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI/edit)
2. En la barra superior de menús, haz clic en **Extensiones** > **Apps Script**.

---

### Paso 2: Pegar el Código del Script
1. Borra cualquier código que aparezca por defecto en el archivo `Código.gs`.
2. Abre y copia todo el contenido del archivo [`google_apps_script.js`](file:///Users/programacion/Documents/sheets/estilo_neutral/google_apps_script.js) de este repositorio.
3. Pégalo en el editor de Apps Script.
4. Haz clic en el ícono de **Guardar** (o presiona `Cmd+S` / `Ctrl+S`).

---

### Paso 3: Desplegar como Aplicación Web (Web App)
1. En la esquina superior derecha del editor de Apps Script, haz clic en el botón azul **Implementar** (o *Deploy*) > **Nueva implementación**.
2. En la ventana emergente, haz clic en el ícono de engranaje ⚙️ junto a *Seleccionar tipo* y elige **Aplicación web**.
3. Configura los siguientes campos:
   - **Descripción:** `Estilo Neutral API v1`
   - **Ejecutar como:** `Yo (tu correo de Google)`
   - **Quién tiene acceso:** `Cualquier usuario` (*Anyone*) ⚠️ *(Muy importante para permitir que la app móvil envíe datos)*.
4. Haz clic en **Implementar** (*Deploy*).
5. Google te pedirá **Autorizar el acceso**:
   - Haz clic en *Autorizar acceso*.
   - Elige tu cuenta de Google.
   - Haz clic en *Avanzado* > *Ir a Estilo Neutral (no seguro)*.
   - Haz clic en *Permitir*.
6. Copia la **URL de la aplicación web** generada (empieza por `https://script.google.com/macros/s/.../exec`).

---

### Paso 4: Configurar la URL en la Aplicación
Pega la URL que copiaste en tus archivos `.env`, `.env.dev` y `.env.test`:
```env
APPS_SCRIPT_URL=https://script.google.com/macros/s/TU_SCRIPT_ID/exec
```

¡Listo! A partir de ese momento, cada vez que crees, modifiques o elimines un cliente, producto, venta o divisa, los cambios se guardarán automáticamente en tu archivo de Google Sheets en tiempo real.
