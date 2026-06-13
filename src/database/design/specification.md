# Gathel - Especificación de Base de Datos

**Versión:** 2.0  
**Última actualización:** 13 de Junio de 2026  
**Estado:** ✏️ En revisión (recomendaciones de los agentes de IA incorporadas)

---

## 📋 Tabla de contenidos

1. [Catálogos (Tablas de referencia)](#catálogos)
2. [Autenticación y Redes Sociales](#autenticación-y-redes-sociales)
3. [Proposiciones y Predicciones](#proposiciones-y-predicciones)
4. [Transacciones](#transacciones)
5. [Auditoría e IA](#auditoría-e-ia)
6. [Restricciones y Reglas de Negocio](#restricciones-y-reglas-de-negocio)

---

## 🏛️ Catálogos

### **PropositionStatus**
Estados posibles de una proposición.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `status_id` | INT | PK, IDENTITY | Identificador único |
| `status_code` | VARCHAR(30) | UNIQUE, NOT NULL | Código (ej: PENDING, ACTIVE, RESOLVED, REJECTED) |
| `description` | VARCHAR(200) | | Descripción del estado |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activo |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

**Estados:**
- `PENDING`: Proposición creada, esperando aceptación del target
- `ACTIVE`: Target aceptó, votación y predicción habilitadas
- `PREDICTION_CLOSED`: Fecha de cierre de predicciones alcanzada
- `RESOLVED`: Resultado determinado
- `REJECTED`: Target rechazó la proposición
- `CANCELLED`: Proposición cancelada

---

### **SocialNetwork** ⭐ (MODIFICADO)
Redes sociales integradas con la plataforma.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `social_network_id` | INT | PK, IDENTITY | Identificador único |
| `network_code` | VARCHAR(20) | UNIQUE, NOT NULL | Código (ej: INSTAGRAM, TIKTOK, TWITTER) |
| `network_name` | VARCHAR(50) | NOT NULL | Nombre legible (ej: Instagram, TikTok) |
| `url` | VARCHAR(500) | | URL principal de la red social (ej: https://instagram.com) |
| `api_url` | VARCHAR(500) | | URL del endpoint API (ej: https://graph.instagram.com/v18.0) |
| `api_config` | NVARCHAR(MAX) | | Configuración de la API en JSON (keys, scopes, etc.) |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

---

### **CurrencyType** ✨ (NUEVA - Reemplaza PointsTransaction y MoneyTransaction)
Tipos de monedas/fondos en el sistema. Permite N tipos de monedas sin agregar tablas.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `currency_type_id` | INT | PK, IDENTITY | Identificador único |
| `currency_code` | VARCHAR(30) | UNIQUE, NOT NULL | Código (ej: POINTS, USD, EUR, etc.) |
| `currency_name` | VARCHAR(50) | NOT NULL | Nombre (ej: Puntos Virtuales, Dólar Estadounidense) |
| `currency_symbol` | VARCHAR(10) | | Símbolo (ej: pts, $, €) |
| `is_virtual` | BIT | NOT NULL | TRUE: moneda virtual, FALSE: dinero real |
| `decimal_places` | INT | NOT NULL, DEFAULT 0 | Lugares decimales (0 para puntos, 2 para USD) |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

> **Nota:** La tasa de cambio se traslada a la tabla [`ExchangeRate`](#exchangerate) para mantener histórico. El tipo de cambio es un dato temporal/dinámico, no una propiedad estática de la moneda.

---

### **ExchangeRate** ✨ (NUEVA - Histórico de tasas de cambio)
Tasas de cambio de cada moneda a USD, con histórico para precisión en transacciones y auditoría.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `exchange_rate_id` | INT | PK, IDENTITY | Identificador único |
| `currency_type_id` | INT | FK(CurrencyType), NOT NULL | Moneda |
| `rate_to_usd` | DECIMAL(18,4) | NOT NULL | Tasa de cambio a USD vigente |
| `effective_date` | DATETIME2 | NOT NULL | Fecha desde la que la tasa es válida |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de registro |

**Índices:**
- FK(currency_type_id)
- INDEX(currency_type_id, effective_date DESC) — Buscar tasa vigente por fecha

**Reglas:**
- La tasa vigente es la de mayor `effective_date` ≤ fecha de la transacción
- Permite reconstruir el valor en USD de cualquier transacción histórica
- No se modifican registros: cada cambio de tasa es una fila nueva

---

### **TransactionType**
Tipos de transacciones (depósito, retiro, comisión, ganancia, penalización, etc.).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `transaction_type_id` | INT | PK, IDENTITY | Identificador único |
| `type_code` | VARCHAR(30) | UNIQUE, NOT NULL | Código (ej: DEPOSIT, WITHDRAWAL, COMMISSION, WINNING) |
| `description` | VARCHAR(200) | | Descripción |
| `applies_to` | VARCHAR(10) | NOT NULL | POINTS, MONEY, o BOTH |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

---

### **EventType**
Tipos de eventos del juego (proposition_created, vote_cast, prediction_made, etc.).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `event_type_id` | INT | PK, IDENTITY | Identificador único |
| `type_code` | VARCHAR(40) | UNIQUE, NOT NULL | Código (ej: PROPOSITION_CREATED, VOTE_CAST) |
| `description` | VARCHAR(200) | | Descripción del tipo de evento |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

**Eventos principales:**
- `PROPOSITION_CREATED`: Proposición creada
- `PROPOSITION_ACCEPTED`: Target aceptó proposición
- `PROPOSITION_REJECTED`: Target rechazó proposición
- `VOTE_CAST`: Jugador votó
- `PREDICTION_MADE`: Jugador realizó predicción
- `PREDICTION_UPDATED`: Predicción actualizada
- `PROPOSITION_RESOLVED`: Proposición resuelta
- `REWARDS_DISTRIBUTED`: Ganancias distribuidas
- `PENALTY_APPLIED`: Penalización aplicada

---

### **AIModel** ✨ (NUEVA - Para normalizar AIReviewLog)
Modelos de IA disponibles para revisiones.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `ai_model_id` | INT | PK, IDENTITY | Identificador único |
| `model_code` | VARCHAR(50) | UNIQUE, NOT NULL | Código (ej: GPT4, CLAUDE3, etc.) |
| `model_name` | VARCHAR(100) | NOT NULL | Nombre del modelo |
| `version` | VARCHAR(20) | NOT NULL | Versión (ej: 4.0, 3.5) |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

---

### **AIProvider** ✨ (NUEVA - Para normalizar AIReviewLog)
Proveedores de servicios de IA.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `ai_provider_id` | INT | PK, IDENTITY | Identificador único |
| `provider_code` | VARCHAR(30) | UNIQUE, NOT NULL | Código (ej: OPENAI, ANTHROPIC) |
| `provider_name` | VARCHAR(100) | NOT NULL | Nombre del proveedor |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

---

## 🔐 Autenticación y Redes Sociales

### **Player**
Usuarios de la plataforma.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `player_id` | INT | PK, IDENTITY | Identificador único |
| `username` | VARCHAR(50) | UNIQUE, NOT NULL | Nombre de usuario |
| `email` | VARCHAR(150) | UNIQUE, NOT NULL | Email del jugador |
| `password_hash` | VARCHAR(256) | NOT NULL | Hash de contraseña (PBKDF2, bcrypt, etc.) |
| `display_name` | VARCHAR(100) | | Nombre a mostrar |
| `balance_points` | BIGINT | NOT NULL, DEFAULT 100 | Balance de puntos virtuales (desnormalizado por performance) |
| `balance_version` | INT | NOT NULL, DEFAULT 1 | Versión para optimistic locking (evita race conditions) |
| `last_transaction_date` | DATETIME2 | | Fecha de la última transacción que afectó el balance |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Cuenta activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de registro |
| `updated_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Última actualización |
| `updated_by` | VARCHAR(100) | | Quién actualizó (sistema o admin) |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Índices:**
- UNIQUE(username)
- UNIQUE(email)
- INDEX(created_at)

**Reglas:**
- Al registrarse, balance_points = 100
- Email debe validarse antes de confirmar registro
- password_hash nunca debe exponerse
- `balance_points` se mantiene sincronizado vía trigger sobre Transaction (desnormalización intencional)
- `balance_version` se incrementa en cada actualización de balance para detectar escrituras concurrentes
- **Hashing recomendado:** Argon2id o bcrypt (cost ≥ 12). El algoritmo se documenta en el backend, no se hardcodea en BD

---

### **SocialAccount** ⭐ (MODIFICADO - Remover access_token)
Cuentas de redes sociales vinculadas a jugadores.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `social_account_id` | INT | PK, IDENTITY | Identificador único |
| `player_id` | INT | FK(Player), NOT NULL | Jugador propietario |
| `social_network_id` | INT | FK(SocialNetwork), NOT NULL | Red social |
| `account_username` | VARCHAR(100) | NOT NULL | Nombre de usuario en la red social |
| `is_verified` | BIT | NOT NULL, DEFAULT 0 | Verificado mediante OAuth |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Cuenta activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de vinculación |
| `updated_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Última actualización |

**Cambios:**
- ❌ REMOVIDO: `access_token_encrypted` (ver SocialAccountSession)

**Índices:**
- FK(player_id)
- FK(social_network_id)
- UNIQUE(player_id, social_network_id)

---

### **SocialAccountSession** ✨ (NUEVA - Para tokens que rotan)
Tokens de acceso a redes sociales (rotan entre sesiones).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `session_id` | BIGINT | PK, IDENTITY | Identificador único |
| `social_account_id` | INT | FK(SocialAccount), NOT NULL | Cuenta social |
| `access_token_encrypted` | VARCHAR(500) | NOT NULL | Token encriptado (Always Encrypted) |
| `refresh_token_encrypted` | VARCHAR(500) | | Token de refresco (si aplica) |
| `token_expires_at` | DATETIME2 | | Fecha de expiración |
| `encryption_key_id` | INT | | Referencia a la key que cifró el token (key store) |
| `last_used_at` | DATETIME2 | | Última vez que se usó el token (detectar inactivos) |
| `rotation_count` | INT | NOT NULL, DEFAULT 0 | Número de rotaciones del token (auditoría) |
| `is_active` | BIT | NOT NULL, DEFAULT 1 | Token activo |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de generación |
| `invalidated_at` | DATETIME2 | | Fecha de invalidación |

**Reglas:**
- Cada nuevo OAuth genera una sesión nueva
- Sesiones antiguas se invalidan cuando expiran
- Los tokens se renuevan automáticamente si se cuenta con refresh token
- `access_token_encrypted` / `refresh_token_encrypted` se protegen con **Always Encrypted**
- Expiración recomendada: 1 hora; cada uso puede generar rotación (incrementa `rotation_count`)
- El acceso a esta tabla debe auditarse (quién lee tokens)

---

## 🎮 Proposiciones y Predicciones

### **Proposition**
Proposiciones/predicciones que crean los jugadores.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `proposition_id` | INT | PK, IDENTITY | Identificador único |
| `creator_player_id` | INT | FK(Player), NOT NULL | Jugador que crea la proposición |
| `target_player_id` | INT | FK(Player), NOT NULL | Jugador sobre quien es la proposición |
| `title` | VARCHAR(150) | NOT NULL | Título de la proposición |
| `description` | VARCHAR(1000) | NOT NULL | Descripción detallada |
| `status_id` | INT | FK(PropositionStatus), NOT NULL | Estado actual |
| `ai_review_result` | VARCHAR(20) | | Resultado de revisión de IA (APPROVED, REJECTED, PENDING) |
| `ai_review_detail` | VARCHAR(500) | | Detalle de revisión |
| `rejection_reason` | VARCHAR(500) | | Razón si fue rechazada por target |
| `voting_ends_at` | DATETIME2 | | Fecha y hora de cierre de votación |
| `prediction_ends_at` | DATETIME2 | | Fecha y hora de cierre de predicciones |
| `is_accepted_by_target` | BIT | NOT NULL, DEFAULT 0 | Target aceptó la proposición |
| `is_fulfilled` | BIT | | Si el evento ocurrió (TRUE/FALSE) |
| `resolved_at` | DATETIME2 | | Fecha de resolución |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Proposición activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |
| `updated_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Última actualización |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |
| `checksum_timestamp` | DATETIME2 | | Momento en que se calculó el checksum (no modificable, refuerza auditoría) |

**Índices:**
- FK(creator_player_id)
- FK(target_player_id)
- FK(status_id)
- INDEX(created_at)
- INDEX(prediction_ends_at)

**Restricciones (CHECK):**
- `CHECK (creator_player_id <> target_player_id)` — no proponer sobre sí mismo vía creator/target distintos

**Reglas de negocio:**
- creator_player_id ≠ target_player_id
- El `checksum` incluye `created_at` para evitar recálculo malicioso; `checksum_timestamp` registra cuándo se generó
- Todo cambio de campos queda registrado en [`PropositionAudit`](#propositionaudit) vía trigger
- Al crear: status = PENDING, is_accepted_by_target = 0
- Target puede rechazar y perder 1 punto
- Al aceptar, se habilita votación por 24 horas
- Predicciones se cierran en prediction_ends_at
- is_fulfilled se determina con evidencia y validación de IA

---

### **Vote** ⭐ (MODIFICADO - Agregar checksum)
Votos de jugadores sobre proposiciones.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `vote_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition), NOT NULL | Proposición votada |
| `player_id` | INT | FK(Player), NOT NULL | Jugador que votó |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha del voto |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Índices:**
- FK(proposition_id)
- FK(player_id)
- UNIQUE(proposition_id, player_id) — Un jugador vota una sola vez por proposición

---

### **Prediction** ⭐ (MODIFICADO - Agregar checksum)
Predicciones de jugadores sobre proposiciones.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `prediction_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition), NOT NULL | Proposición predicha |
| `player_id` | INT | FK(Player), NOT NULL | Jugador que predice |
| `amount` | DECIMAL(18,4) | NOT NULL | Monto arriesgado |
| `currency_type_id` | INT | FK(CurrencyType), NOT NULL | Moneda del monto (POINTS, USD, etc.) |
| `direction` | BIT | NOT NULL | 1: Se cumple, 0: No se cumple |
| `result` | VARCHAR(10) | | Resultado: PENDING, WON, LOST |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de predicción |
| `updated_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Última actualización |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Cambios:**
- ❌ REMOVIDO: `prediction_type`, `amount_points`, `amount_real`
- ✨ AGREGADO: `amount` + `currency_type_id` (un solo monto en una sola moneda)

> **Razón:** Una predicción soporta un único monto en una única moneda. En lugar de dos campos paralelos (`amount_points`, `amount_real`) con nulls, se usa `amount` + FK a `CurrencyType`. Esto normaliza el diseño, escala a N monedas y elimina la redundancia. El tipo (puntos vs dinero) se deriva de `CurrencyType.is_virtual`.

**Índices:**
- FK(proposition_id)
- FK(player_id)
- FK(currency_type_id)
- INDEX(proposition_id, player_id)

**Restricciones (CHECK):**
- `CHECK (amount > 0)`
- Si la moneda es virtual (POINTS): `amount ≤ 1` (validado en SP, requiere lookup a CurrencyType)

**Reglas de negocio:**
- Si la moneda es POINTS (`is_virtual = 1`): se arriesga máximo 1 punto por predicción
- Si la moneda es dinero real (`is_virtual = 0`): `amount > 0`, incrementable hasta el cierre
- **Predicción con "ambos" (puntos y dinero):** se modela como dos filas de Prediction sobre la misma proposición (una POINTS, una de dinero). No existe un tipo BOTH en una sola fila
- Después de prediction_ends_at, no se permite modificar
- result se calcula cuando se resuelve la proposición

---

### **PropositionEvidence** ⭐ (MODIFICADO - Agregar post_id)
Evidencia multimedia para validación de proposiciones.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `evidence_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition), NOT NULL | Proposición |
| `post_id` | VARCHAR(100) | | ID del post en la red social (GUID/UUID) |
| `evidence_url` | VARCHAR(500) | | URL de la evidencia |
| `evidence_type` | VARCHAR(20) | NOT NULL | Tipo: PHOTO, VIDEO, STORY, REEL, TWEET, POST |
| `social_network_id` | INT | FK(SocialNetwork) | Red social de donde viene |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de captura |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Cambios:**
- ✨ AGREGADO: `post_id` (identificador único del post en la red social)

**Índices:**
- FK(proposition_id)
- FK(social_network_id)
- INDEX(post_id) — Para búsquedas rápidas

---

## 💰 Transacciones

### **Transaction** ✨ (NUEVA - Reemplaza PointsTransaction y MoneyTransaction)
Transacciones unificadas para cualquier tipo de moneda/fondo.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `transaction_id` | BIGINT | PK, IDENTITY | Identificador único |
| `player_id` | INT | FK(Player), NOT NULL | Jugador |
| `currency_type_id` | INT | FK(CurrencyType), NOT NULL | Tipo de moneda (POINTS, USD, etc.) |
| `amount` | DECIMAL(18,4) | NOT NULL | Cantidad (positivo: ingreso, negativo: egreso) |
| `running_balance` | DECIMAL(18,4) | NOT NULL | Balance total después de la transacción |
| `transaction_type_id` | INT | FK(TransactionType), NOT NULL | Tipo de transacción (DEPOSIT, WITHDRAWAL, etc.) |
| `reference_type` | VARCHAR(30) | | Tipo de referencia (PROPOSITION, PREDICTION, etc.) |
| `reference_id` | BIGINT | | ID de la referencia |
| `description` | VARCHAR(300) | | Descripción |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Índices:**
- FK(player_id)
- FK(currency_type_id)
- FK(transaction_type_id)
- INDEX(player_id, created_at)
- INDEX(reference_type, reference_id)

**Cambios:**
- ✨ NUEVA: Reemplaza PointsTransaction y MoneyTransaction
- Soporta N tipos de monedas sin nuevas tablas
- running_balance permite auditoría de balance en cualquier momento

**Reglas:**
- amount puede ser positivo o negativo
- running_balance es el total después de la transacción
- Debe haber integridad referencial en reference_id según reference_type

---

## 📊 Auditoría e IA

### **AIReviewLog** ⭐ (MODIFICADO - Normalizado y con payloads completos)
Registro completo de revisiones de IA.

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `review_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition), NOT NULL | Proposición revisada |
| `ai_model_id` | INT | FK(AIModel), NOT NULL | Modelo de IA usado |
| `ai_provider_id` | INT | FK(AIProvider), NOT NULL | Proveedor de IA |
| `review_result` | VARCHAR(20) | NOT NULL | APPROVED, REJECTED, PENDING |
| `confidence_score` | DECIMAL(5,4) | | Confianza (0.0000 a 1.0000) |
| `rejection_categories` | VARCHAR(500) | | Categorías de rechazo (JSON array) |
| `request_payload` | NVARCHAR(MAX) | CHECK(ISJSON(request_payload)=1) | Request completo enviado a la IA (JSON validado) |
| `response_payload` | NVARCHAR(MAX) | CHECK(ISJSON(response_payload)=1) | Response completo de la IA (JSON validado) |
| `review_details` | NVARCHAR(MAX) | | Detalles adicionales |
| `reviewed_at` | DATETIME2 | NOT NULL | Fecha de revisión |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Cambios:**
- ✨ AGREGADO: `ai_model_id` (FK a AIModel)
- ✨ AGREGADO: `ai_provider_id` (FK a AIProvider)
- ✨ AGREGADO: `request_payload` (request completo para debugging)
- ✨ AGREGADO: `response_payload` (response completo para análisis)
- ✨ AGREGADO: `checksum`

**Restricciones (CHECK):**
- `CHECK (ISJSON(request_payload) = 1)`
- `CHECK (ISJSON(response_payload) = 1)`

**Reglas:**
- request_payload y response_payload en JSON para facilitar análisis
- Permite reconstruir decisiones de IA
- Útil para debugging y auditoría regulatoria

---

### **GameEvent** ⭐ (CLARIFICADO - Historial de eventos del juego)
Registro de todos los eventos que ocurren en el juego (auditoría operacional).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `event_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition) | Proposición relacionada (puede ser NULL) |
| `event_type_id` | INT | FK(EventType), NOT NULL | Tipo de evento |
| `actor_player_id` | INT | FK(Player), NOT NULL | Jugador que provocó el evento |
| `event_data` | NVARCHAR(MAX) | CHECK(ISJSON(event_data)=1) | Datos adicionales en JSON validado |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha del evento |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Restricciones (CHECK):**
- `CHECK (ISJSON(event_data) = 1)` — garantiza JSON válido, previene inyección/corrupción

**Propósito:**
- Registro completo de la historia del juego
- Permite reconstruir el estado en cualquier momento
- Auditoría de cada acción
- Detección de anomalías
- Análisis de patrones de juego

**Eventos registrados:**
- PROPOSITION_CREATED: Crear proposición
- PROPOSITION_ACCEPTED: Target acepta
- PROPOSITION_REJECTED: Target rechaza
- VOTE_CAST: Voto realizado
- PREDICTION_MADE: Predicción realizada
- PREDICTION_UPDATED: Predicción actualizada (monto)
- PROPOSITION_RESOLVED: Resultado determinado
- REWARDS_DISTRIBUTED: Ganancias distribuidas
- PENALTY_APPLIED: Penalización
- BALANCE_UPDATED: Balance actualizado

**Ejemplo de event_data:**
```json
{
  "proposition_id": 123,
  "target_player_id": 456,
  "title": "Elizabeth terminará la maratón",
  "voted_by": 789,
  "prediction_amount_points": 1,
  "reward_amount": 150,
  "penalty_percent": 15
}
```

---

### **ProcessLog**
Registro de ejecución de Stored Procedures (trazabilidad de operaciones).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `log_id` | BIGINT | PK, IDENTITY | Identificador único |
| `sp_name` | VARCHAR(100) | NOT NULL | Nombre del SP ejecutado |
| `action_description` | VARCHAR(500) | | Descripción de la acción |
| `affected_table` | VARCHAR(50) | | Tabla afectada |
| `affected_record_id` | BIGINT | | ID del registro afectado |
| `status` | VARCHAR(15) | NOT NULL | SUCCESS, ERROR, PARTIAL |
| `error_detail` | VARCHAR(MAX) | | Detalle del error si aplica |
| `executed_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de ejecución |
| `executed_by` | VARCHAR(100) | | Usuario que ejecutó |

**Propósito:**
- Auditoría de cambios críticos
- Debugging de procesos complejos
- Cumplimiento regulatorio

---

### **PropositionAudit** ✨ (NUEVA - Auditoría de cambios a proposiciones)
Registra cada cambio de campo sobre una proposición (qué cambió, de qué a qué, quién y cuándo). Crítico para detectar fraude (ej. modificar `is_fulfilled` o `status_id`).

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| `audit_id` | BIGINT | PK, IDENTITY | Identificador único |
| `proposition_id` | INT | FK(Proposition), NOT NULL | Proposición modificada |
| `field_name` | VARCHAR(50) | NOT NULL | Nombre del campo que cambió |
| `old_value` | VARCHAR(MAX) | | Valor anterior |
| `new_value` | VARCHAR(MAX) | | Valor nuevo |
| `changed_by` | VARCHAR(100) | NOT NULL | Usuario/sistema que realizó el cambio |
| `changed_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha y hora del cambio |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Índices:**
- FK(proposition_id)
- INDEX(proposition_id, changed_at DESC)
- INDEX(changed_by, changed_at DESC)
- INDEX(field_name, changed_at DESC)

**Reglas:**
- Poblada automáticamente por un **trigger** sobre `Proposition` (AFTER UPDATE)
- Registra una fila por cada campo modificado
- Tabla append-only: no se actualiza ni elimina

---

## 🔗 Restricciones y Reglas de Negocio

### Restricciones de Integridad Referencial

| FK | PK | Acción |
|----|----|----|
| SocialAccount.player_id | Player.player_id | CASCADE |
| SocialAccount.social_network_id | SocialNetwork.social_network_id | RESTRICT |
| SocialAccountSession.social_account_id | SocialAccount.social_account_id | CASCADE |
| ExchangeRate.currency_type_id | CurrencyType.currency_type_id | RESTRICT |
| Proposition.creator_player_id | Player.player_id | RESTRICT |
| Proposition.target_player_id | Player.player_id | RESTRICT |
| Proposition.status_id | PropositionStatus.status_id | RESTRICT |
| PropositionEvidence.proposition_id | Proposition.proposition_id | CASCADE |
| PropositionEvidence.social_network_id | SocialNetwork.social_network_id | RESTRICT |
| Vote.proposition_id | Proposition.proposition_id | CASCADE |
| Vote.player_id | Player.player_id | RESTRICT |
| Prediction.proposition_id | Proposition.proposition_id | CASCADE |
| Prediction.player_id | Player.player_id | RESTRICT |
| Prediction.currency_type_id | CurrencyType.currency_type_id | RESTRICT |
| Transaction.player_id | Player.player_id | RESTRICT |
| Transaction.currency_type_id | CurrencyType.currency_type_id | RESTRICT |
| Transaction.transaction_type_id | TransactionType.transaction_type_id | RESTRICT |
| GameEvent.proposition_id | Proposition.proposition_id | CASCADE |
| GameEvent.event_type_id | EventType.event_type_id | RESTRICT |
| GameEvent.actor_player_id | Player.player_id | RESTRICT |
| AIReviewLog.proposition_id | Proposition.proposition_id | CASCADE |
| AIReviewLog.ai_model_id | AIModel.ai_model_id | RESTRICT |
| AIReviewLog.ai_provider_id | AIProvider.ai_provider_id | RESTRICT |
| PropositionAudit.proposition_id | Proposition.proposition_id | CASCADE |

### Reglas de Negocio Críticas

1. **Balance de Jugador:**
   - player.balance_points = SUM(Transaction WHERE currency_type.currency_code = 'POINTS')
   - Debe validarse en triggers

2. **Transacciones Atómicas:**
   - Crear predicción, debitar puntos/dinero, registrar transacción → TODO O NADA

3. **Distribución de Ganancias:**
   - Perdedores pierden el monto apostado
   - Ganadores reciben: (total_perdido - comisión_plataforma - comisión_creator) / N_ganadores
   - Comisiones registradas como transacciones

4. **Auditoría de Checksums:**
   - CHECKSUM = SHA-256(concatenar_campos_principales **incluyendo created_at**)
   - `checksum_timestamp` registra cuándo se calculó (no modificable)
   - Permite detectar manipulación y previene recálculo malicioso

5. **Proposición Rechazada:**
   - Creator pierde 1 punto automáticamente
   - Registrar como GameEvent y Transaction

6. **Proposición sin Validación:**
   - Si no se puede validar resultado: todos recuperan apuestas + creator pierde 15% balance

7. **Concurrencia en Balance:**
   - Las predicciones que debitan balance usan SPs transaccionales con isolation **SERIALIZABLE**
   - `Player.balance_version` implementa optimistic locking: el UPDATE valida la versión leída
   - Se valida saldo suficiente ANTES de debitar, dentro de la misma transacción

---

## 🔐 Estrategia de Seguridad

Resumen de los controles de seguridad incorporados al diseño (detalle e implementación en `/src/database/security-lab`).

### Cifrado
- **Always Encrypted** sobre `SocialAccountSession.access_token_encrypted` y `refresh_token_encrypted`
- Cifrado de contraseñas mediante **master certificate** (Security Lab)
- `password_hash` con Argon2id / bcrypt (cost ≥ 12) — algoritmo en backend, no hardcodeado

### Row-Level Security (RLS)
- **Transaction**: cada jugador sólo ve sus propias transacciones; Admin ve todo
- **Vote**: implementa la regla "sólo el target ve los votos de su proposición". El predicado de filtro permite ver una fila de Vote si:
  - es el voto propio del jugador (`player_id = SESSION_CONTEXT('user_id')`) — necesario para validar unicidad de voto, **o**
  - el jugador es el `target_player_id` de la proposición votada — ve todos los votos de sus proposiciones, **o**
  - el rol es `Admin`.
  - Efecto: un jugador común no puede inferir la popularidad de una proposición (sólo "ve" su propio voto); `vw_proposition_vote_counts` sólo devuelve el conteo real al target/Admin.
- Predicado de filtro basado en `SESSION_CONTEXT('user_id')` y `SESSION_CONTEXT('role')`

```sql
-- Función de predicado para RLS sobre Vote (inline TVF, SCHEMABINDING)
CREATE FUNCTION dbo.fn_VoteAccessPredicate(@proposition_id INT, @player_id INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS is_accessible
    WHERE
        @player_id = CAST(SESSION_CONTEXT(N'user_id') AS INT)                 -- voto propio
        OR CAST(SESSION_CONTEXT(N'role') AS VARCHAR(20)) = 'Admin'            -- admin ve todo
        OR EXISTS (
            SELECT 1 FROM dbo.Proposition p
            WHERE p.proposition_id = @proposition_id
              AND p.target_player_id = CAST(SESSION_CONTEXT(N'user_id') AS INT) -- target ve los votos de su proposición
        );

CREATE SECURITY POLICY dbo.VoteSecurityPolicy
    ADD FILTER PREDICATE dbo.fn_VoteAccessPredicate(proposition_id, player_id) ON dbo.Vote
    WITH (STATE = ON);
```

### Data Masking
| Campo | Estrategia |
|-------|-----------|
| `Player.password_hash` | Nunca se expone |
| `Player.email` | Enmascarado para no-dueños (`a***@dominio`) |
| `SocialAccountSession.*_token_encrypted` | Always Encrypted, nunca visible |
| `Player.balance_points` | Sólo el dueño ve el valor completo |

### Roles
- **Player**: SELECT/INSERT/UPDATE limitado a sus propias entidades
- **Admin**: acceso completo con auditoría
- **System**: ejecuta SPs; sin acceso a `password_hash`
- **AISystem**: INSERT en AIReviewLog, UPDATE de `ai_review_result` en Proposition

### Auditoría y Triggers
- `tr_proposition_audit`: AFTER UPDATE sobre Proposition → puebla `PropositionAudit`
- `tr_transaction_update_balance`: AFTER INSERT/UPDATE sobre Transaction → sincroniza `Player.balance_points` y `balance_version`
- Validación de JSON con `CHECK(ISJSON())` en `GameEvent` y `AIReviewLog`

---

## ⚡ Índices de Performance (covering)

Índices optimizados para las queries críticas del MVP. Usan `INCLUDE` (covering) e índices filtrados para evitar lookups a la tabla base. Complementan los índices declarados por tabla.

| Índice | Tabla | Definición | Query objetivo |
|--------|-------|-----------|----------------|
| `idx_proposition_status` | Proposition | (status_id) INCLUDE (creator_player_id, target_player_id, title, prediction_ends_at) WHERE enabled=1 | Listar proposiciones activas |
| `idx_proposition_creator` | Proposition | (creator_player_id, created_at DESC) INCLUDE (status_id, title, is_accepted_by_target) | Proposiciones de un creador |
| `idx_proposition_target` | Proposition | (target_player_id, created_at DESC) INCLUDE (status_id, title, creator_player_id) | Proposiciones sobre un jugador |
| `idx_proposition_prediction_ends` | Proposition | (prediction_ends_at) WHERE status_id IN (2,3) AND enabled=1 | Cerrar predicciones vencidas |
| `idx_transaction_player_currency` | Transaction | (player_id, currency_type_id, created_at DESC) INCLUDE (amount, running_balance, transaction_type_id) | Balance e historial por jugador |
| `idx_transaction_reference` | Transaction | (reference_type, reference_id) INCLUDE (player_id, amount, created_at) | Rastrear apuesta/predicción |
| `idx_prediction_proposition` | Prediction | (proposition_id) INCLUDE (player_id, direction, amount, currency_type_id, result) | Resolver proposición |
| `idx_prediction_player` | Prediction | (player_id, created_at DESC) INCLUDE (proposition_id, direction, result, amount) | Historial de predicciones |
| `idx_prediction_result_pending` | Prediction | (result) WHERE result='PENDING' INCLUDE (proposition_id, player_id, amount) | Predicciones por resolver |
| `idx_gameevent_proposition` | GameEvent | (proposition_id, created_at DESC) INCLUDE (event_type_id, actor_player_id) | Auditoría por proposición |
| `idx_gameevent_event_type` | GameEvent | (event_type_id, created_at DESC) INCLUDE (proposition_id, actor_player_id) | Eventos por tipo |
| `idx_vote_unique` | Vote | UNIQUE (proposition_id, player_id) | Un voto por jugador/proposición |
| `idx_vote_proposition` | Vote | (proposition_id) INCLUDE (player_id) | Contar votos |
| `idx_proposition_audit_prop_date` | PropositionAudit | (proposition_id, changed_at DESC) | Auditoría por proposición |
| `idx_proposition_audit_changed_by` | PropositionAudit | (changed_by, changed_at DESC) | Auditoría por usuario |
| `idx_proposition_audit_field` | PropositionAudit | (field_name, changed_at DESC) | Auditoría por campo |
| `idx_exchange_rate_currency_date` | ExchangeRate | (currency_type_id, effective_date DESC) | Tasa vigente por fecha |

> **Nota de escalabilidad:** Por tratarse de un MVP académico con bajo volumen de datos, **no** se implementa particionamiento, sharding ni archivamiento automático. Estos quedan documentados como roadmap futuro (>500K jugadores) pero fuera del alcance del caso.

---

## 📑 Vistas Recomendadas

```sql
-- Vista: Balance actual de cada jugador por moneda
CREATE VIEW vw_player_balances AS
SELECT 
    p.player_id,
    p.username,
    ct.currency_code,
    ct.currency_name,
    COALESCE(SUM(t.amount), 0) as balance
FROM Player p
CROSS JOIN CurrencyType ct
LEFT JOIN Transaction t ON p.player_id = t.player_id 
    AND ct.currency_type_id = t.currency_type_id
WHERE ct.enabled = 1 AND p.enabled = 1
GROUP BY p.player_id, p.username, ct.currency_type_id, ct.currency_code, ct.currency_name

-- Vista: Proposiciones activas con contador de predicciones
-- NOTA: NO expone vote_count. La regla de negocio prohíbe que los jugadores
-- vean cuántos votos tiene una proposición; sólo el target puede verlo.
-- El conteo de votos se entrega vía vw_proposition_vote_counts, protegida por RLS sobre Vote.
CREATE VIEW vw_active_propositions AS
SELECT 
    pr.proposition_id,
    pr.title,
    p_creator.username as creator,
    p_target.username as target,
    COUNT(DISTINCT pred.prediction_id) as prediction_count,
    pr.prediction_ends_at,
    pr.created_at
FROM Proposition pr
JOIN Player p_creator ON pr.creator_player_id = p_creator.player_id
JOIN Player p_target ON pr.target_player_id = p_target.player_id
LEFT JOIN Prediction pred ON pr.proposition_id = pred.proposition_id
WHERE pr.status_id IN (SELECT status_id FROM PropositionStatus WHERE status_code IN ('ACTIVE', 'PREDICTION_CLOSED'))
GROUP BY pr.proposition_id, pr.title, p_creator.username, p_target.username, pr.prediction_ends_at, pr.created_at

-- Vista: Conteo de votos por proposición (visibilidad controlada por RLS sobre Vote)
-- Debido a la RLS de Vote, sólo el target de la proposición (y Admin) obtiene el
-- conteo total real. Un jugador común sólo "ve" su propio voto, por lo que no puede
-- inferir la popularidad de una proposición.
CREATE VIEW vw_proposition_vote_counts AS
SELECT 
    v.proposition_id,
    COUNT(*) as vote_count
FROM Vote v
GROUP BY v.proposition_id
```

---

**Fin de especificación**

