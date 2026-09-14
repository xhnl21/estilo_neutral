# Política de Cero Polling (No Polling Policy) — Estilo Neutral

Este documento formaliza la decisión arquitectónica de **eliminar cualquier mecanismo de sondeo periódico (polling)** en el cliente móvil y de escritorio, conforme a las directrices de eficiencia energética, seguridad y buenas prácticas de **OWASP MASVS** e **ISO/IEC 25010**.

---

## 1. Declaración de Principio

> **LA APLICACIÓN OPERA EXCLUSIVAMENTE BAJO DEMANDA DEL USUARIO (PULL MANUAL).**  
> Se prohíbe terminantemente el uso de `Timer.periodic`, `Stream.periodic`, cron jobs internos o bucles de espera activa para consultar cambios en Google Sheets.

---

## 2. Razones de la Decisión Arquitectónica

1. **Cuotas y Límites de la API de Google Sheets**:
   - La API de Google Sheets impone límites estrictos de cuota por proyecto y por usuario (60 peticiones/minuto/usuario y 300 peticiones/minuto/proyecto). El polling periódico de múltiples clientes agota rápidamente las cuotas y provoca errores `429 Too Many Requests`.
2. **Consumo de Batería y Datos Móviles**:
   - El sondeo constante en segundo plano mantiene la radio celular activa, degradando la batería del dispositivo del operador y consumiendo su plan de datos innecesariamente.
3. **Consistencia Transaccional Controlada**:
   - En una arquitectura bajo demanda, el usuario actualiza cuando necesita ver datos frescos o antes de efectuar una venta, garantizando que sabe exactamente cuándo se realizó la última sincronización.
4. **Alternativas Rechazadas**:
   - *Polling periódico (Rechazado)*: Alto riesgo de saturación de cuotas y gasto de recursos.
   - *WebSockets constantes a Google Sheets (Rechazado)*: Google Sheets no ofrece soporte nativo para WebSockets bidireccionales directos sin servidores intermedios complejos.

---

## 3. Mecanismos Implementados en Sustitución del Polling

1. **Carga Inicial al Abrir la Pantalla**:
   - Al inicializar una vista, se efectúa **una sola lectura puntual** del rango requerido (`A1:P1000`).
2. **Refresco Manual Controlado por el Usuario**:
   - La interfaz incluye botones prominentes de **"Actualizar"** y gestos de arrastre (`RefreshIndicator` / `pull-to-refresh`).
3. **Escritura con Relectura de Confirmación Atómica**:
   - Cada operación CRUD (ej. registrar venta) escribe la fila en la hoja de cálculo y ejecuta una sola relectura puntual para actualizar el caché local en memoria.
4. **Invalidación Explícita de Caché**:
   - El caché local en memoria tiene un TTL manual pasivo (se evalúa solo cuando el usuario pide datos) y se invalida automáticamente ante cualquier operación de escritura.
