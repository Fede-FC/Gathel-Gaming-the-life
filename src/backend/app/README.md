# /src/backend/app — Núcleo de la Aplicación

Contiene toda la lógica del backend: punto de entrada, autenticación, base de datos, modelos y schemas.

---

## main.py

Punto de entrada de FastAPI. Define la aplicación, configura el middleware de CORS y registra todos los routers.

**Detalles importantes:**
- CORS habilitado con `allow_origins=["*"]` — permite peticiones desde el frontend en cualquier origen (válido para desarrollo/demo; en producción se restringiría al dominio del frontend)
- Registra 6 routers: `auth`, `players`, `propositions`, `predictions`, `feed`, `wallet`
- Expone `GET /api/health` como endpoint de healthcheck (usado por Docker para saber cuándo el backend está listo)

---

## auth.py

Maneja hashing de contraseñas y ciclo de vida de JWT.

**Hashing de contraseñas — detalle crítico:**
Usa `SHA2-256` sobre la codificación `UTF-16-LE` del texto plano:
```python
hashlib.sha256(plain.encode("utf-16-le")).hexdigest().upper()
```
Esto produce exactamente el mismo resultado que `HASHBYTES('SHA2_256', N'password')` en SQL Server (que internamente trabaja en UTF-16-LE). Sin esto, el login fallaría aunque la contraseña sea correcta.

**JWT:**
- Algoritmo: `HS256`
- Expiración: 8 horas
- El `payload` contiene el `player_id` en el campo `sub`
- La función `get_current_player_id` es un dependencia de FastAPI: cualquier endpoint que la declare en sus parámetros queda automáticamente protegido — si el token es inválido o falta, devuelve 401

---

## database.py

Configura la conexión a SQL Server y el pool de conexiones.

**Cadena de conexión:** `mssql+pymssql://sa:password@sql-server:1433/GathelDB`

**Pool fijo:**
```python
pool_size=5, max_overflow=0
```
Exactamente 5 conexiones abiertas, sin posibilidad de crear más. Esto evita que bajo carga se abran decenas de conexiones simultáneas, que en SQL Server Express (el que corre en Docker) degradan el rendimiento.

**`get_db()`:** generador que FastAPI usa como dependencia. Abre una sesión antes del request y la cierra garantizadamente al terminar (incluso si hay error).

---

## models.py

Modelos ORM de SQLAlchemy que mapean las tablas de la base de datos a clases Python.

**Uso:** solo para lectura. Todas las operaciones de escritura (crear jugador, crear proposición, predecir, etc.) pasan por stored procedures mediante `db.execute(text("EXEC usp_..."))`. Los modelos permiten hacer queries SELECT de forma tipada sin escribir SQL crudo.

**Modelos definidos:**

| Clase | Tabla SQL | Propósito |
|-------|-----------|-----------|
| `Player` | `Player` | Jugadores registrados. Campos clave: `balance_points`, `balance_version`, `enabled` |
| `Proposition` | `Proposition` | Predicciones sociales. Relaciones ORM a `creator` y `target` (ambos Player) |
| `Prediction` | `Prediction` | Apuesta de un jugador sobre una proposición. `direction=True` significa "sí se cumple" |
| `PropositionStatus` | `PropositionStatus` | Catálogo de estados: PENDING, ACTIVE, PREDICTION_CLOSED, RESOLVED, REJECTED |
| `CurrencyType` | `CurrencyType` | Catálogo de monedas: POINTS (virtual), USD, EUR, CRC |

---

## schemas.py

Define los contratos de entrada y salida de todos los endpoints usando Pydantic. Pydantic valida automáticamente los tipos al recibir un request y al serializar la respuesta.

**Schemas de autenticación:**

| Schema | Dirección | Descripción |
|--------|-----------|-------------|
| `LoginRequest` | Entrada | `username` + `password` en texto plano |
| `RegisterRequest` | Entrada | `username`, `email` (validado como email real), `password`, `display_name` opcional |
| `TokenResponse` | Salida | JWT + `player_id` + `username` + `display_name` |
| `RegisterResponse` | Salida | `player_id` + `username` + mensaje de confirmación |

**Schemas de jugadores:**

| Schema | Descripción |
|--------|-------------|
| `PlayerDashboard` | Balance de puntos + lista de `MoneyBalance` por moneda |
| `MoneyBalance` | Balance en una moneda específica (`currency_code`, `currency_symbol`, `current_balance`) |
| `PlayerSearchResult` | Resultado del autocomplete: `player_id`, `username`, `display_name` |

**Schemas de proposiciones:**

| Schema | Descripción |
|--------|-------------|
| `CreatePropositionRequest` | `target_username` (no ID, para que el frontend use el autocomplete), `title`, `description`, `voting_ends_at` |
| `PropositionActive` | Proposición disponible para predecir, incluye `total_predictions` |
| `MyProposition` | Mis proposiciones creadas, incluye `proposition_id` visible (útil en SSMS) |
| `IncomingProposition` | Proposiciones donde soy el sujeto (para accept/reject) |
| `AcceptPropositionRequest` | Solo recibe `prediction_ends_at` — el `target_player_id` se toma del JWT |

**Schemas de predicciones y wallet:**

| Schema | Descripción |
|--------|-------------|
| `PlacePredictionRequest` | `proposition_id`, `amount`, `currency_code`, `direction` (bool) |
| `PlacePredictionResponse` | `prediction_id` del registro creado |
| `CurrencyWithRate` | Moneda con su tipo de cambio actual respecto al USD |
| `DepositRequest` | `currency_code` + `amount` para depósito de dinero real |
| `TransactionRecord` | Registro de historial: tipo, monto, balance acumulado, descripción |
| `FeedEvent` | Evento del feed: tipo, actor, proposición relacionada, timestamp |
