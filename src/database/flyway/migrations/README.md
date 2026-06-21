# /migrations — Scripts de Migración Flyway

Los archivos siguen la convención `V{número}__{descripción}.sql`. Flyway los ejecuta en orden ascendente de versión y nunca vuelve a ejecutar uno que ya está en `flyway_schema_history`. **Nunca editar un archivo ya ejecutado** — si hay que cambiar algo, crear una nueva versión.

---

## V1__init_schema.sql

Crea el schema completo de la base de datos desde cero.

**Tablas de catálogo (datos fijos):**
- `PropositionStatus` — estados del ciclo de vida: PENDING, ACTIVE, PREDICTION_CLOSED, RESOLVED, REJECTED, CANCELLED
- `SocialNetwork` — redes sociales soportadas: Instagram, TikTok, Twitter
- `CurrencyType` — monedas: POINTS (virtual), USD, EUR, CRC
- `ExchangeRate` — tipos de cambio históricos por moneda (con índice para obtener el más reciente)
- `TransactionType` — tipos de movimiento: DEPOSIT, WITHDRAWAL, WAGER, WINNING, REFUND, COMMISSION
- `EventType` — tipos de evento del feed: PROPOSITION_CREATED, AI_APPROVED, PREDICTION_MADE, etc.
- `AIProvider` — proveedores de IA: OpenAI, Anthropic
- `AIModel` — modelos de IA: GPT-4, Claude 3, etc.

**Tablas de jugadores:**
- `Player` — jugadores registrados. Campo `balance_points` desnormalizado por performance (sincronizado vía SP). Campo `balance_version` para optimistic locking (evita condiciones de carrera en actualizaciones concurrentes de puntos)
- `SocialAccount` — cuentas de redes sociales vinculadas por jugador
- `SocialAccountSession` — tokens OAuth cifrados de las sesiones activas de redes sociales

**Tablas de negocio:**
- `Proposition` — el corazón del sistema. Tiene dos FK a `Player` (creator y target) con CHECK que garantiza que no sean la misma persona. Registra todo el ciclo: fechas de votación, predicción, resolución, resultado de IA, si fue aceptada por el sujeto
- `Vote` — votos de la comunidad sobre si una proposición se cumplirá. UNIQUE por (proposition, player) para evitar votar dos veces
- `Prediction` — apuesta concreta de un jugador: monto, moneda, dirección (1=se cumple/0=no), resultado (PENDING/WON/LOST)
- `PropositionEvidence` — evidencia multimedia (fotos, videos, posts) que respalda una proposición

**Tablas transaccionales:**
- `[Transaction]` — registro inmutable de todos los movimientos de dinero y puntos. `running_balance` guarda el saldo acumulado tras cada movimiento. Necesita corchetes porque `TRANSACTION` es palabra reservada en T-SQL
- `AIReviewLog` — historial de revisiones de IA con payload completo de request/response
- `GameEvent` — log de eventos del sistema para el feed público. `event_data` es JSON libre
- `ProcessLog` — log interno de ejecución de stored procedures (éxitos y errores)
- `PropositionAudit` — registro de cambios en campos clave de `Proposition` generado automáticamente por el trigger

**Índices creados (11+):**
Indexa los patrones de query más frecuentes: buscar proposiciones por estado, historial de transacciones de un jugador, eventos del feed ordenados por fecha, predicciones pendientes.

**Trigger `tr_proposition_audit`:**
Se dispara después de cada UPDATE sobre `Proposition` y registra automáticamente en `PropositionAudit` los cambios en `status_id`, `is_accepted_by_target`, `is_fulfilled` y `ai_review_result`. No requiere intervención manual — cualquier cambio de estado queda auditado.

---

## V2__stored_procedures.sql

Define los 12 stored procedures que implementan toda la lógica de negocio transaccional. Todos usan `SET XACT_ABORT ON` (rollback automático ante cualquier error) y el patrón `BEGIN TRY / BEGIN CATCH`.

| SP | Descripción |
|----|-------------|
| `usp_RegisterPlayer` | Crea jugador + transacción de 100 puntos de bienvenida en una sola transacción |
| `usp_CreateProposition` | Crea proposición en estado PENDING + GameEvent. Valida que el sujeto tenga ≥15 pts |
| `usp_RecordAIReview` | Registra resultado de IA en `AIReviewLog`. Si APPROVED → pasa a ACTIVE. Si REJECTED → pasa a REJECTED |
| `usp_AcceptProposition` | El sujeto acepta → fija `prediction_ends_at`, `is_accepted_by_target=1`. Solo funciona en estado ACTIVE |
| `usp_RejectProposition` | El sujeto rechaza → descuenta 1 pt al sujeto, pasa a REJECTED. Usa optimistic locking en `balance_version` |
| `usp_PlacePrediction` | Registra predicción. Límite: 1 POINT por predicción. Para dinero real verifica saldo en `[Transaction]`. Descuenta el monto inmediatamente |
| `usp_ClosePropositionPredictions` | Cierra el período de predicciones: ACTIVE → PREDICTION_CLOSED |
| `usp_ResolveProposition` | Distribuye ganancias a ganadores (5% plataforma + 2% creador). Si `is_fulfilled=NULL` → reembolso total + penalización 15% al sujeto |
| `usp_DepositMoney` | Deposita dinero real. Valida que sea moneda real (no POINTS) |
| `usp_GetPlayerDashboard` | Retorna 4 result sets: info del jugador, balances reales, proposiciones activas y predicciones pendientes |
| `usp_GetActivePropositions` | Lista proposiciones disponibles para predecir con paginación (OFFSET/FETCH) |
| `usp_GetPropositionResults` | Historial de resultados donde el jugador participó como predictor |

---

## V3__seeding.sql

Genera datos de prueba masivos para que la demo tenga datos reales que mostrar.

**Volumen generado:**
- 1001 jugadores (1 admin + 1000 jugadores aleatorios)
- Catálogos completos: 6 estados, 3 redes sociales, 4 monedas, 7 tipos de transacción, 12+ tipos de evento, 2 proveedores IA, 3 modelos IA
- 5000 proposiciones con estados distribuidos realísticamente
- Revisiones de IA para proposiciones ACTIVE/RESOLVED
- 107K+ transacciones de distintos tipos
- GameEvents para el feed

**Técnica usada:** loops con `WHILE` en T-SQL que generan datos semi-aleatorios usando `NEWID()`, `ABS(CHECKSUM(NEWID()))` y aritmética de módulo para distribución entre valores posibles.

---

## V4__security_setup.sql

Implementa toda la capa de seguridad de la base de datos.

**Cifrado:**
- `Master Key` — clave maestra de la BD, protegida por contraseña
- `gathel_cert` — certificado digital con expiración en 2030
- `gathel_sym_key` — clave simétrica AES-256 cifrada con el certificado. Se usa para cifrar/descifrar valores sensibles con `EncryptByKey`/`DecryptByKey`

**Roles y usuarios:**

| Rol | Permisos | Usuario |
|-----|----------|---------|
| `db_gathel_admin` | SELECT + INSERT/UPDATE + EXECUTE + UNMASK (ve datos reales) | `gathel_admin_usr` |
| `db_gathel_system` | Solo EXECUTE (no puede hacer SELECT directo) | `gathel_system_usr` |
| `db_gathel_player` | SELECT en catálogos + EXECUTE en 4 SPs específicos | `gathel_player_usr` |
| `db_gathel_readonly` | SELECT solo en `Proposition` y `PropositionStatus` | `gathel_readonly_usr` |

**Data Masking dinámico:**
- `Player.email` → enmascarado como `aXXX@XXXX.com`
- `Player.balance_points` → enmascarado como `0`
- `SocialAccount.account_username` → enmascarado como `xxxx`

Los usuarios con `UNMASK` (admin) ven los datos reales. El resto ve la versión enmascarada.

**Row-Level Security (RLS):**
Política sobre `[Transaction]` que filtra las filas según el `SESSION_CONTEXT('player_id')`. Cada jugador solo puede ver sus propias transacciones cuando se conecta con `db_gathel_player`.

---

## V5__concurrency_transactions.sql

Define los SPs de demostración de concurrencia y transacciones anidadas.

**Transacciones anidadas (3 niveles con savepoints):**
- `usp_Nested_L1_ResolveProposition` → llama a L2
- `usp_Nested_L2_DistributeWinnings` → llama a L3
- `usp_Nested_L3_RegisterCommission` — nivel más profundo, registra la comisión
- Si L3 falla, el SAVEPOINT permite hacer rollback solo de L3 sin deshacer L1 y L2

**Deadlocks (para demostración en dos sesiones SSMS):**
- `usp_DL_Write_SessionA` y `usp_DL_Write_SessionB` — bloquean las mismas tablas en orden inverso → deadlock por escrituras
- `usp_DL_Read_PlayerSummary` y `usp_DL_Write_PredictionProcess` — HOLDLOCK en lectura + escritura concurrente → deadlock lectura/escritura
- `usp_DL_Cyclic_T1/T2/T3` — tres sesiones que forman un ciclo T1→T2→T3→T1

**Niveles de aislamiento:**
- `usp_IL_DirtyRead_Reader/Writer` — demostración de lectura sucia con READ UNCOMMITTED
- `usp_IL_NonRepeatableRead` — demostración de lectura no repetible
- `usp_IL_PhantomRead` — demostración de lectura fantasma
- `usp_IL_Serializable_Reader/Writer` — demostración de SERIALIZABLE bloqueando phantom reads
- `usp_IL_GetBalance/UpdateBalance` — helpers de apoyo

---

## V6__demo_passwords.sql

Migración auxiliar que normaliza las contraseñas del usuario `demo_admin` y otros usuarios de seeding para garantizar que el hash almacenado en la BD coincida con lo que genera el backend en Python (SHA2-256 sobre UTF-16-LE).

**Por qué existe esta migración:** durante el seeding (V3) las contraseñas se generaron con `HASHBYTES` directamente en SQL. Cuando el backend Python hace login, usa su propia función `hash_password()`. Esta migración asegura que ambos produzcan el mismo hash para las cuentas de demo, permitiendo que el login desde el frontend funcione correctamente.

---

## V7__design_fixes.sql

Corrige cuatro errores de diseño identificados en revisión post-implementación. Todos los cambios son aditivos o correctivos — no rompen datos existentes.

| # | Tabla | Problema | Corrección |
|---|-------|---------|------------|
| 1 | `Vote` | Faltaba `direction` — no se sabía si el voto era a favor o en contra | `ALTER TABLE ADD direction BIT NOT NULL DEFAULT 1` + rellena datos existentes |
| 2 | `AIModel` | Sin relación con `AIProvider` — `AIReviewLog` podía registrar modelo+proveedor incompatibles | `ALTER TABLE ADD ai_provider_id INT NOT NULL FK(AIProvider)` + trigger de validación en `AIReviewLog` |
| 3 | `PropositionEvidence` | Ambos `post_id` y `evidence_url` eran `NULL` — se podía insertar evidencia vacía | `ADD CONSTRAINT CK_Evidence_HasReference CHECK (post_id IS NOT NULL OR evidence_url IS NOT NULL)` |
| 4 | `SocialAccountSession` | `encryption_key_id` era un `INT` sin FK a ninguna tabla | `ALTER TABLE DROP COLUMN encryption_key_id` |

**Notas técnicas:**
- `Vote.direction` se agrega como `NULL` primero, se pobla con `ABS(CHECKSUM(NEWID())) % 2` para los datos del seeding, y luego se convierte a `NOT NULL`
- `AIModel.ai_provider_id` se agrega como `NULL`, se actualiza con los proveedores conocidos (Anthropic → CLAUDE*, OpenAI → GPT4O, Google → GEMINI*), y luego se convierte a `NOT NULL`
- El trigger `trg_AIReviewLog_ProviderConsistency` valida en cada INSERT que el `ai_provider_id` del log coincida con el del modelo usado
