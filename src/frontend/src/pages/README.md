# /src/frontend/src/pages — Páginas de la Aplicación

Cada archivo corresponde a una ruta de la aplicación. Las páginas consumen la API a través del cliente Axios (`/api/client.js`) y manejan su propio estado local con hooks de React.

---

## Login.jsx — `/login`

Formulario de inicio de sesión.

**Flujo:**
1. El usuario ingresa username + password
2. Llama a `AuthContext.login()` que hace `POST /api/auth/login`
3. El backend devuelve el JWT que se guarda en `localStorage`
4. Redirige automáticamente a `/`

**Detalles:** link a `/register` para nuevos usuarios. Si ya hay sesión activa, `App.jsx` redirige a `/` antes de mostrar esta página.

---

## Register.jsx — `/register`

Formulario de registro de cuenta nueva.

**Flujo:**
1. El usuario llena username, email, contraseña y display name (opcional)
2. `POST /api/auth/register` → crea el jugador en la BD con 100 puntos de bienvenida
3. Auto-login inmediato: hace `POST /api/auth/login` con las mismas credenciales
4. Redirige a `/` con sesión activa

**Por qué auto-login:** mejora la experiencia de usuario — no tiene sentido registrarse y luego tener que loguearse manualmente.

---

## Dashboard.jsx — `/`

Página principal del jugador autenticado.

**Contenido:**
- Balance de puntos virtuales (número grande destacado)
- Balances de dinero real por moneda (USD, EUR, CRC) con su símbolo
- Fecha de última transacción

**Datos:** `GET /api/players/me` → `usp_GetPlayerDashboard` en el backend, que retorna puntos + balances reales en una sola llamada.

---

## Propositions.jsx — `/propositions`

La página más compleja del frontend. Maneja el ciclo completo de proposiciones con 3 tabs.

**Tab 1 — Activas (para predecir):**
- Lista proposiciones en estado ACTIVE + aceptadas + con predicciones abiertas
- Muestra creador, sujeto, descripción y fecha de cierre
- Botón "Predecir": abre un modal con campos de monto, moneda y dirección
  - Si la moneda es POINTS: bloquea el monto en 1 (regla del caso)
  - Muestra el balance disponible de la moneda seleccionada en el modal
- Autocomplete de usuario al crear una proposición nueva (debounce de 300ms, busca en `GET /api/players/search`)

**Tab 2 — Mis Proposiciones:**
- Lista todas las proposiciones creadas por el jugador autenticado
- Muestra el `proposition_id` (útil para identificarlas en SSMS durante la demo)
- Badge de estado con color (pending=gris, active=verde, resolved=azul, rejected=rojo)

**Tab 3 — Sobre Mí:**
- Lista proposiciones donde el jugador es el sujeto
- Botones "Aceptar" / "Rechazar" para proposiciones en estado ACTIVE que aún no han sido respondidas
- Al rechazar se descuenta 1 punto automáticamente (validado en el backend via `usp_RejectProposition`)

---

## Wallet.jsx — `/wallet`

Gestión de dinero real: saldos, tipos de cambio, depósito e historial.

**Secciones:**
1. **Saldos actuales** por moneda (USD, EUR, CRC) con su equivalente en USD
2. **Tipos de cambio** — muestra la tasa respecto al USD. Para monedas con tasa < $0.01 (ej. CRC) muestra el inverso: "1 USD = ₡524"
3. **Depósito simulado** — formulario para depositar cualquier monto en cualquier moneda real (`POST /api/wallet/deposit`)
4. **Historial de transacciones** — lista de todos los movimientos con tipo, monto (positivo=ingreso/negativo=egreso), balance acumulado y descripción. Los tipos de transacción tienen etiquetas en español y clases CSS para colorear entradas (verde) vs salidas (rojo)

---

## Feed.jsx — `/feed`

Feed de actividad reciente de la plataforma.

**Contenido:** lista de los últimos 40 eventos del sistema, ordenados del más reciente al más antiguo. Cada evento muestra:
- Ícono según tipo de evento
- Descripción en lenguaje natural
- Username del actor
- Título de la proposición relacionada (si aplica)
- Tiempo relativo (ej. "hace 3 minutos")

**Tipos de evento mostrados:** PROPOSITION_CREATED, AI_APPROVED, PROPOSITION_ACCEPTED, PROPOSITION_REJECTED, PREDICTION_MADE, PROPOSITION_RESOLVED.

---

## Results.jsx — `/results`

Historial de resultados de proposiciones donde el jugador participó como predictor.

**Contenido por resultado:**
- Título de la proposición
- Si se cumplió o no (`is_fulfilled`)
- Fecha de resolución
- Monto apostado y moneda
- Si la predicción fue ganadora o perdedora (`WON`/`LOST`)
- Badge visual de resultado

**Datos:** `GET /api/propositions/results` → `usp_GetPropositionResults` en el backend.
