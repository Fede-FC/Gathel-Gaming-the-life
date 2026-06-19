# /src/backend/app/routers — Endpoints de la API

Cada archivo define un grupo de endpoints bajo un prefijo de URL. Todos los endpoints excepto `/api/auth/login` y `/api/auth/register` requieren JWT válido en el header `Authorization: Bearer <token>`.

---

## auth.py — `/api/auth`

Maneja el ciclo completo de autenticación.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/api/auth/login` | Busca el jugador por username, verifica la contraseña con SHA2-256 UTF-16-LE, devuelve JWT con 8h de vida |
| `POST` | `/api/auth/logout` | Invalida la sesión del lado del cliente (el JWT en sí no se revoca — stateless) |
| `POST` | `/api/auth/register` | Hashea la contraseña, llama a `usp_RegisterPlayer` vía SP (crea el jugador + transacción de 100 puntos de bienvenida), devuelve el `player_id` |

**Nota sobre el registro:** el hash se genera en Python antes de enviarlo al SP, igual que en el login. Esto garantiza consistencia — ambos usan la misma función `hash_password()`.

---

## players.py — `/api/players`

Dashboard personal y búsqueda de usuarios.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/players/me` | Llama a `usp_GetPlayerDashboard` + query adicional de balances reales por moneda. Devuelve balance de puntos + lista de saldos en USD/EUR/CRC |
| `GET` | `/api/players/search?q=` | Búsqueda de jugadores por username o display_name con `LIKE %q%`. Máximo 10 resultados. Usado por el autocomplete al crear una proposición |

---

## propositions.py — `/api/propositions`

El router más complejo. Gestiona todo el ciclo de vida de las proposiciones.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/propositions/active` | Lista proposiciones en estado ACTIVE + aceptadas + con predicciones abiertas. Usa `usp_GetActivePropositions` con paginación |
| `GET` | `/api/propositions/mine` | Proposiciones creadas por el jugador autenticado (todos los estados). Incluye el `proposition_id` visible |
| `GET` | `/api/propositions/incoming` | Proposiciones donde el jugador es el sujeto (target). Muestra las que puede accept/reject |
| `POST` | `/api/propositions` | Crea proposición. Recibe `target_username` (busca el `player_id` internamente), llama a `usp_CreateProposition`. La proposición nace en estado PENDING |
| `POST` | `/api/propositions/{id}/accept` | El sujeto acepta la proposición. Llama a `usp_AcceptProposition` con la `prediction_ends_at` recibida. Solo funciona si el jugador autenticado ES el sujeto de esa proposición |
| `POST` | `/api/propositions/{id}/reject` | El sujeto rechaza la proposición. Llama a `usp_RejectProposition`. El sujeto pierde 1 punto como penalización |
| `GET` | `/api/propositions/results` | Proposiciones ya resueltas donde el jugador participó como predictor. Usa `usp_GetPropositionResults` |

---

## predictions.py — `/api/predictions`

Registrar una predicción sobre una proposición activa.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/api/predictions` | Llama a `usp_PlacePrediction`. Valida en la BD: saldo suficiente, límite de 1 POINT por predicción, que la proposición esté activa y aceptada, que no hayas predicho antes en esa moneda |

**Parámetros clave:**
- `direction: true` → apostás a que "sí se cumple"
- `direction: false` → apostás a que "no se cumple"
- `currency_code: "POINTS"` → máximo 1 punto por predicción (regla del caso)

---

## feed.py — `/api/feed`

Feed de actividad reciente de la plataforma.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/feed?size=40` | Devuelve los últimos N eventos de `GameEvent` filtrados por tipos visibles. Incluye: PROPOSITION_CREATED, AI_APPROVED, PROPOSITION_ACCEPTED, PROPOSITION_REJECTED, PREDICTION_MADE, PROPOSITION_RESOLVED |

Los eventos se enriquecen con el username del actor y el título de la proposición relacionada mediante JOIN en la misma query.

---

## wallet.py — `/api/wallet`

Gestión de dinero real y historial de transacciones.

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/wallet/currencies` | Lista monedas reales disponibles (USD, EUR, CRC) con el tipo de cambio más reciente respecto al USD, obtenido con `ROW_NUMBER()` sobre `ExchangeRate` |
| `POST` | `/api/wallet/deposit` | Deposita dinero real. Llama a `usp_DepositMoney`. Valida que sea moneda real (no POINTS) y monto > 0 |
| `GET` | `/api/wallet/history` | Historial de todas las transacciones del jugador autenticado (puntos + dinero real), ordenadas por fecha descendente |
