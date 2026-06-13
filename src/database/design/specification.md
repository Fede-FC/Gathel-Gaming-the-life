# Gathel - Especificación de Base de Datos

**Versión:** 1.0  
**Última actualización:** 12 de Junio de 2026  
**Estado:** ✏️ En revisión (feedback del profesor incorporado)

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
| `exchange_rate_to_usd` | DECIMAL(18,4) | | Tasa de cambio a USD (si aplica) |
| `enabled` | BIT | NOT NULL, DEFAULT 1 | Indica si está activa |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de creación |

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
| `balance_points` | BIGINT | NOT NULL, DEFAULT 100 | Balance de puntos virtuales |
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
| `access_token_encrypted` | VARCHAR(500) | NOT NULL | Token encriptado |
| `refresh_token_encrypted` | VARCHAR(500) | | Token de refresco (si aplica) |
| `token_expires_at` | DATETIME2 | | Fecha de expiración |
| `is_active` | BIT | NOT NULL, DEFAULT 1 | Token activo |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de generación |
| `invalidated_at` | DATETIME2 | | Fecha de invalidación |

**Reglas:**
- Cada nuevo OAuth genera una sesión nueva
- Sesiones antiguas se invalidan cuando expiran
- Los tokens se renuevan automáticamente si se cuenta con refresh token

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

**Índices:**
- FK(creator_player_id)
- FK(target_player_id)
- FK(status_id)
- INDEX(created_at)
- INDEX(prediction_ends_at)

**Reglas de negocio:**
- creator_player_id ≠ target_player_id
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
| `prediction_type` | VARCHAR(10) | NOT NULL | Tipo (POINTS, MONEY, BOTH) |
| `amount_points` | BIGINT | | Cantidad de puntos arriesgados (max 1 por predicción en POINTS) |
| `amount_real` | DECIMAL(18,2) | | Cantidad de dinero real arriesgado |
| `direction` | BIT | NOT NULL | 1: Se cumple, 0: No se cumple |
| `result` | VARCHAR(10) | | Resultado: PENDING, WON, LOST |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha de predicción |
| `updated_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Última actualización |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Índices:**
- FK(proposition_id)
- FK(player_id)
- INDEX(proposition_id, player_id)

**Reglas de negocio:**
- Si prediction_type = POINTS: amount_points ≤ 1
- Si prediction_type = MONEY: amount_real > 0
- Si prediction_type = BOTH: ambos > 0
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
| `request_payload` | NVARCHAR(MAX) | | Request completo enviado a la IA |
| `response_payload` | NVARCHAR(MAX) | | Response completo de la IA |
| `review_details` | NVARCHAR(MAX) | | Detalles adicionales |
| `reviewed_at` | DATETIME2 | NOT NULL | Fecha de revisión |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

**Cambios:**
- ✨ AGREGADO: `ai_model_id` (FK a AIModel)
- ✨ AGREGADO: `ai_provider_id` (FK a AIProvider)
- ✨ AGREGADO: `request_payload` (request completo para debugging)
- ✨ AGREGADO: `response_payload` (response completo para análisis)
- ✨ AGREGADO: `checksum`

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
| `event_data` | NVARCHAR(MAX) | | Datos adicionales en JSON |
| `created_at` | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() | Fecha del evento |
| `checksum` | VARCHAR(64) | | SHA-256 para auditoría |

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

## 🔗 Restricciones y Reglas de Negocio

### Restricciones de Integridad Referencial

| FK | PK | Acción |
|----|----|----|
| SocialAccount.player_id | Player.player_id | CASCADE |
| SocialAccount.social_network_id | SocialNetwork.social_network_id | RESTRICT |
| SocialAccountSession.social_account_id | SocialAccount.social_account_id | CASCADE |
| Proposition.creator_player_id | Player.player_id | RESTRICT |
| Proposition.target_player_id | Player.player_id | RESTRICT |
| Proposition.status_id | PropositionStatus.status_id | RESTRICT |
| PropositionEvidence.proposition_id | Proposition.proposition_id | CASCADE |
| Vote.proposition_id | Proposition.proposition_id | CASCADE |
| Vote.player_id | Player.player_id | RESTRICT |
| Prediction.proposition_id | Proposition.proposition_id | CASCADE |
| Prediction.player_id | Player.player_id | RESTRICT |
| Transaction.player_id | Player.player_id | RESTRICT |
| Transaction.currency_type_id | CurrencyType.currency_type_id | RESTRICT |
| Transaction.transaction_type_id | TransactionType.transaction_type_id | RESTRICT |
| GameEvent.proposition_id | Proposition.proposition_id | CASCADE |
| GameEvent.event_type_id | EventType.event_type_id | RESTRICT |
| GameEvent.actor_player_id | Player.player_id | RESTRICT |
| AIReviewLog.proposition_id | Proposition.proposition_id | CASCADE |
| AIReviewLog.ai_model_id | AIModel.ai_model_id | RESTRICT |
| AIReviewLog.ai_provider_id | AIProvider.ai_provider_id | RESTRICT |

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
   - CHECKSUM = SHA-256(concatenar_campos_principales)
   - Permite detectar manipulación

5. **Proposición Rechazada:**
   - Creator pierde 1 punto automáticamente
   - Registrar como GameEvent y Transaction

6. **Proposición sin Validación:**
   - Si no se puede validar resultado: todos recuperan apuestas + creator pierde 15% balance

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
GROUP BY p.player_id, p.username, ct.currency_type_id, ct.currency_code, ct.currency_name

-- Vista: Proposiciones activas con contador de votos y predicciones
CREATE VIEW vw_active_propositions AS
SELECT 
    pr.proposition_id,
    pr.title,
    p_creator.username as creator,
    p_target.username as target,
    COUNT(DISTINCT v.vote_id) as vote_count,
    COUNT(DISTINCT pred.prediction_id) as prediction_count,
    pr.prediction_ends_at,
    pr.created_at
FROM Proposition pr
JOIN Player p_creator ON pr.creator_player_id = p_creator.player_id
JOIN Player p_target ON pr.target_player_id = p_target.player_id
LEFT JOIN Vote v ON pr.proposition_id = v.proposition_id
LEFT JOIN Prediction pred ON pr.proposition_id = pred.proposition_id
WHERE pr.status_id IN (SELECT status_id FROM PropositionStatus WHERE status_code IN ('ACTIVE', 'PREDICTION_CLOSED'))
GROUP BY pr.proposition_id, pr.title, p_creator.username, p_target.username, pr.prediction_ends_at, pr.created_at
```

---

**Fin de especificación**

