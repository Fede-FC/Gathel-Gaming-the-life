# Análisis de Normalización y Diseño - BD Gathel

**Experto:** Especialista en Modelado de Datos Relacional  
**Fecha:** 12 de Junio de 2026  
**Enfoque:** 3NF (Tercera Forma Normal) y BCNF (Boyce-Codd Normal Form)

---

## 📐 Análisis de Forma Normal por Tabla

### **Catálogos (PropositionStatus, SocialNetwork, CurrencyType, etc.)**

**Forma Normal:** ✅ **BCNF**

**Justificación:**
```
Ejemplo: PropositionStatus
- PK: status_id (surrogate key)
- Dependencias funcionales:
  - status_id → status_code
  - status_code → description (funcional, pero no por PK)
  
Análisis:
- Todo atributo depende solo de status_id (PK)
- No hay dependencias transitivas
- No hay multivalores
= BCNF ✓
```

**Evaluación:** Excelente. Sin cambios necesarios.

---

### **Player** (Core)

**Forma Normal:** ✅ **3NF** (casi BCNF)

**Análisis detallado:**
```
Atributos:
- player_id (PK)
- username, email, password_hash, display_name (atómicos)
- balance_points, balance_real (desnormalizados intencionalmente)
- enabled, created_at, updated_at, updated_by, checksum (auditoría)

Dependencias funcionales:
- player_id → username (funcional)
- player_id → email (funcional)
- player_id → balance_points (desnormalizado)
- player_id → balance_real (REMOVIDO - bien)

Problemas identificados:
- ¿Por qué balance_points en Player? 
  → Debería calcularse de Transaction
  → Pero se desnormaliza por PERFORMANCE
```

**Recomendación:** ✅ Aceptable (desnormalización intencional para performance)

**Cambios sugeridos:**
```sql
-- OPCIÓN 1: Mantener desnormalización (RECOMENDADO para performance)
ALTER TABLE Player ADD
  balance_version INT DEFAULT 1,  -- Para optimistic locking
  last_transaction_date DATETIME2;  -- Para saber cuándo se actualizó

-- OPCIÓN 2: Eliminar desnormalización (3NF puro)
-- CREATE VIEW vw_player_balances AS
-- SELECT p.player_id, SUM(t.amount) as balance
-- FROM Player p LEFT JOIN Transaction t...
-- (Pero cada query sería lenta)
```

**Decisión:** Mantener desnormalización + agregar balance_version ✅

---

### **SocialAccount**

**Forma Normal:** ✅ **BCNF**

```
Atributos:
- social_account_id (PK)
- player_id (FK)
- social_network_id (FK)
- account_username, is_verified, enabled (atómicos)

Dependencias:
- social_account_id → player_id, social_network_id (todos los atributos)
- No hay dependencias transitivas

Cambio importante:
- ❌ REMOVIDO: access_token_encrypted
- ✅ CREADO: SocialAccountSession (tabla separada)
  → Razón: Tokens rotan, no es atributo de SocialAccount
  → Esto es CORRECTO por 1NF (tokens multivalores)
```

**Evaluación:** ✅ Excelente. Separación correcta.

---

### **SocialAccountSession** (NUEVA)

**Forma Normal:** ✅ **BCNF**

**Justificación:**
```
Propósito: Guardar tokens que rotan

Atributos:
- session_id (PK)
- social_account_id (FK)
- access_token_encrypted, refresh_token_encrypted
- token_expires_at, is_active, created_at, invalidated_at

Análisis:
- session_id → todos los atributos
- Cada sesión tiene un token único (relación 1:1)
- No hay dependencias transitivas
= BCNF ✓

Decisión de desnormalización:
- Podría normalizarse: Token, RefreshToken en tablas separadas
- Pero INNECESARIO: Tokens rotan como unidad atómica
- Mantener juntos en SessionId es correcto
```

**Evaluación:** ✅ Muy bien diseñado.

---

### **Proposition**

**Forma Normal:** ⚠️ **3NF** (podría ser BCNF)

```
Atributos principales:
- proposition_id (PK)
- creator_player_id, target_player_id (FKs)
- status_id (FK)
- title, description (atómicos)
- ai_review_result, ai_review_detail (desnormalizados)
- is_accepted_by_target, is_fulfilled, resolved_at (auditoría)
- checksum, created_at, updated_at

Análisis:
- proposition_id → todos los atributos ✓
- status_id → descripción? (No, status_id es PK en PropositionStatus)

Posible problema:
- ¿ai_review_result debería estar aquí o solo en AIReviewLog?
  → Está aquí para evitar JOIN en queries frecuentes
  → Pero se duplica en AIReviewLog
  = Desnormalización intencional ✓

Otra desnormalización:
- created_at, updated_at (auditoría)
  → Están en Proposition
  → También en GameEvent (más granular)
  = Correcto: Proposition para "cuándo cambió prop", GameEvent para "qué acción"
```

**Evaluación:** ✅ Aceptable. Desnormalización es intencional y justificada.

---

### **Transaction** (Reemplazo de 2 tablas)

**Forma Normal:** ✅ **BCNF**

**Análisis de la unificación:**
```
ANTES: PointsTransaction + MoneyTransaction (2 tablas)
DESPUÉS: Transaction + CurrencyType (1 tabla + catálogo)

Estructura actual:
- transaction_id (PK)
- player_id (FK)
- currency_type_id (FK) → Soporta N monedas
- amount (positivo o negativo)
- running_balance (saldo después de transacción)
- transaction_type_id (FK)
- reference_type, reference_id (polimórfico)

Análisis:
- transaction_id → todos los atributos ✓
- currency_type_id → (no propiedades, solo referencia)
- No hay dependencias transitivas ✓

Ventajas de unificación:
✅ Elimina duplicación de lógica
✅ Soporta N monedas sin nuevas tablas
✅ Simplifica SPs transaccionales
✅ Facilita reportes consolidados

Desventajas:
- ¿Campos NULL si currency no aplica? (No, currency_id siempre presente)
- ¿Índices menos específicos? (No, ambas monedas usan mismo índice)

Evaluación: ✅ Excelente decisión
```

**Validación de integridad:**
```sql
-- Necesario: Validar que amount tenga sentido para currency
-- Si CurrencyType.is_virtual = 1, amount_points debe ser INT, no decimal
-- Si is_virtual = 0, amount debe permitir decimales

-- PROPUESTA: Agregar CHECK constraint
ALTER TABLE Transaction ADD CONSTRAINT ck_transaction_amount_type
CHECK (
  CASE 
    WHEN (SELECT is_virtual FROM CurrencyType ct WHERE ct.currency_type_id = Transaction.currency_type_id) = 1 
    THEN amount = FLOOR(amount)  -- Puntos: enteros
    ELSE 1 = 1  -- Dinero: cualquier decimal
  END = 1
);
```

---

### **Prediction**

**Forma Normal:** ✅ **3NF**

```
Atributos:
- prediction_id (PK)
- proposition_id, player_id (FKs)
- prediction_type (POINTS, MONEY, BOTH)
- amount_points, amount_real (pueden ser NULL)
- direction (1=sí, 0=no)
- result (PENDING, WON, LOST)
- created_at, updated_at, checksum

Dependencias:
- prediction_id → todos los atributos ✓

Posible problema:
- prediction_type = 'POINTS' pero amount_points = NULL?
  → Debería ser validado en aplicación
  → Propuesta: Agregar CHECK constraint
```

**Cambio recomendado:**
```sql
ALTER TABLE Prediction ADD CONSTRAINT ck_prediction_type_amounts
CHECK (
  (prediction_type = 'POINTS' AND amount_points IS NOT NULL AND amount_real IS NULL)
  OR (prediction_type = 'MONEY' AND amount_points IS NULL AND amount_real IS NOT NULL)
  OR (prediction_type = 'BOTH' AND amount_points IS NOT NULL AND amount_real IS NOT NULL)
);
```

---

### **Vote**

**Forma Normal:** ✅ **BCNF**

**Muy simple:**
```
- vote_id (PK)
- proposition_id, player_id (FKs)
- created_at
- checksum

Todo depende de vote_id. Excelente.

Nota: (proposition_id, player_id) debería ser UNIQUE
→ Ya existe como índice único ✓
```

---

### **GameEvent**

**Forma Normal:** ⚠️ **1NF** (no 3NF)

```
Problema identificado:
- event_data (NVARCHAR(MAX)) es JSON
- Contiene múltiples valores anidados
- No está atomizado

Ejemplo de event_data:
{
  "proposition_id": 123,
  "target_player_id": 456,
  "title": "Elizabeth terminará maratón",
  "voted_by": 789,
  "prediction_amount": 50,
  "reward_amount": 150
}

¿Es esto una violación de 1NF (atomicidad)?
- SÍ TÉCNICAMENTE: event_data contiene múltiples conceptos
- NO PRÁCTICAMENTE: SQL Server trata JSON como string (atómico)

¿Debería separarse en tablas?
- Opción 1: Normalizar completamente
  → GameEvent (evento base)
  → GameEventPropositionData, GameEventVoteData, GameEventPredictionData
  → 10+ tablas para casos diferentes
  = Sobre-normalización, ineficiente

- Opción 2: Mantener JSON (actual)
  → event_data es auto-documentado
  → Flexible para nuevos tipos de eventos
  = Mejor por practicidad

Recomendación: ✅ MANTENER JSON pero validar con CHECK(ISJSON())
```

---

### **AIReviewLog**

**Forma Normal:** ✅ **BCNF** (después de mejoras)

```
ANTES:
- ai_model_version: VARCHAR(50) - string
- ai_provider: VARCHAR(30) - string
= Repetición de datos

DESPUÉS:
- ai_model_id: INT (FK a AIModel)
- ai_provider_id: INT (FK a AIProvider)
= Normalizado ✓

Atributos:
- review_id (PK)
- proposition_id, ai_model_id, ai_provider_id (FKs)
- review_result, confidence_score
- request_payload, response_payload (JSON)
- review_details
- reviewed_at, checksum

Análisis:
- review_id → todos los atributos ✓
- No hay dependencias transitivas ✓
= BCNF ✓

JSON: Mismo análisis que GameEvent
- request_payload y response_payload son auditoría
- Deben ser completos, no fragmentados
= Correcto mantenerlos como JSON ✓
```

---

## 🔄 Evaluación de Decisiones Principales

### **Decisión 1: Unificación Transaction (PointsTransaction + MoneyTransaction)**

**¿Es correcta?** ✅ **SÍ**

| Aspecto | Análisis |
|---------|----------|
| Normalización | Sigue BCNF (no introduce anomalías) |
| Consultas | Más fáciles (no necesita UNION ALL) |
| Mantenimiento | Una tabla en lugar de dos |
| Flexibilidad | Soporta N monedas sin schema change |
| Integridad | Currency_type_id valida tipo de dato |

**Comparación:**
```
ANTES (2 tablas):
- PointsTransaction(transaction_id, player_id, amount_points, ...)
- MoneyTransaction(transaction_id, player_id, amount_real, ...)
Problemas:
- IDs pueden colisionar
- Consultas: UNION ALL transaction_id
- Agregar EUR: nueva tabla MoneyTransactionEUR

DESPUÉS (1 tabla):
- Transaction(transaction_id, player_id, currency_type_id, amount, ...)
Ventajas:
- IDs únicos
- Una tabla para todas las monedas
- Índices más eficientes
- Soporta N tipos de fondos futuros
```

**Cambio requerido:**
```sql
-- Validar en aplicación que amount tiene sentido para currency
-- Propuesta: Trigger que valida tipo de dato según currency
```

---

### **Decisión 2: Separación SocialAccountSession (de SocialAccount)**

**¿Es correcta?** ✅ **SÍ**

```
ANTES: access_token_encrypted en SocialAccount
Problema:
- Tokens rotan entre sesiones
- Actualizar atributo de multivalores (violación de 1NF)
- Cada refresh token cambia la fecha

DESPUÉS: Tabla separada SocialAccountSession
Ventajas:
- 1:M correcto (SocialAccount → N sesiones)
- Histórico de tokens
- Expiración automática
- Auditoría de cada sesión
```

**BCNF:** ✅ Perfecto

---

### **Decisión 3: JSON para event_data y payloads**

**¿Es correcta?** ✅ **SÍ, pero con precaución**

```
Ventajas:
✅ Flexible para diferentes tipos de eventos
✅ Evita 20+ tablas de casos específicos
✅ Fácil auditoría (response completo)
✅ Escalable (nuevos eventos sin schema change)

Desventajas:
⚠️ No es 1NF puro
⚠️ Queries en JSON son más lentas
⚠️ Falta de constraint a nivel DB

Mitigación:
✅ Validar con CHECK(ISJSON()) en schema
✅ Usar indices en JSON para queries frecuentes
✅ Documentar estructura de JSON
✅ Validar en aplicación antes de insertar
```

**Recomendación:** Mantener, pero agregar validaciones

---

## 🚨 Anomalías Detectadas

### **1. Anomalía de Actualización: Player.balance_points**

```
Situación:
- balance_points se desnormaliza en Player
- También se calcula en Transaction

Problema:
- UPDATE Transaction → debe UPDATE Player.balance_points
- ¿Qué pasa si uno falla?

Solución:
- TRIGGER en Transaction que actualiza Player.balance_points
- O SP transaccional que actualiza ambos atómicamente
```

---

### **2. Anomalía de Inserción: Proposition.ai_review_result**

```
Situación:
- ai_review_result está en Proposition
- También está completo en AIReviewLog

Problema:
- Al insertar Proposition, ¿cuándo se calcula ai_review_result?
- ¿Antes o después de AIReviewLog?

Solución:
- SP que: INSERT Proposition (ai_review_result=PENDING)
- Luego ejecuta IA en background
- UPDATE Proposition con resultado
- INSERT AIReviewLog con detalles
```

---

### **3. Anomalía de Eliminación: Proposition con GameEvent**

```
Situación:
- Si se delete Proposition, ¿qué pasa con GameEvent?
- ON DELETE CASCADE elimina historial

Solución:
- ON DELETE RESTRICT: No permitir delete si hay GameEvent
- O ON DELETE SOFT: marcar como deleted, no eliminar
- O conservar histórico en tabla Archive
```

---

## 📋 Campos JSON - Estructura Recomendada

### **GameEvent.event_data - Esquema**

```json
// Para PROPOSITION_CREATED
{
  "event_type": "PROPOSITION_CREATED",
  "proposition_id": 123,
  "creator_id": 1,
  "target_id": 2,
  "title": "Elizabeth terminará maratón"
}

// Para VOTE_CAST
{
  "event_type": "VOTE_CAST",
  "proposition_id": 123,
  "voter_id": 3,
  "vote_count_after": 5
}

// Para PREDICTION_MADE
{
  "event_type": "PREDICTION_MADE",
  "proposition_id": 123,
  "predictor_id": 4,
  "amount": 100,
  "currency": "USD",
  "direction": 1
}

// Para REWARDS_DISTRIBUTED
{
  "event_type": "REWARDS_DISTRIBUTED",
  "proposition_id": 123,
  "total_pool": 500,
  "winners": [
    {"player_id": 1, "reward": 300, "currency": "USD"},
    {"player_id": 2, "reward": 150, "currency": "USD"}
  ],
  "commissions": {
    "platform": 50,
    "creator": 0
  }
}
```

**Validación en SQL:**
```sql
ALTER TABLE GameEvent ADD CONSTRAINT ck_event_data_structure
CHECK (
  JSON_VALUE(event_data, '$.event_type') IN (
    'PROPOSITION_CREATED', 'PROPOSITION_ACCEPTED', 'VOTE_CAST', 
    'PREDICTION_MADE', 'PROPOSITION_RESOLVED', 'REWARDS_DISTRIBUTED'
  )
);
```

---

## ✅ Conclusión de Normalización

| Aspecto | Evaluación |
|---------|-----------|
| **Forma Normal** | 3NF/BCNF con desnormalización intencional |
| **Integridad Referencial** | ✅ Excelente (FKs bien definidas) |
| **Anomalías** | ⚠️ 3 anomalías identificadas, mitiguables |
| **Decisiones de Diseño** | ✅ Correctas (unificación, separación) |
| **JSON** | ✅ Aceptable con validaciones |
| **Cambios Necesarios** | Menores (CHECKs, validaciones) |

---

## 🎯 TOP 5 Cambios Recomendados (Normalización)

```sql
-- 1. CHECK para validar Prediction amounts
ALTER TABLE Prediction ADD CONSTRAINT ck_prediction_type_amounts
CHECK (
  (prediction_type = 'POINTS' AND amount_points IS NOT NULL AND amount_real IS NULL)
  OR (prediction_type = 'MONEY' AND amount_points IS NULL AND amount_real IS NOT NULL)
  OR (prediction_type = 'BOTH' AND amount_points IS NOT NULL AND amount_real IS NOT NULL)
);

-- 2. CHECK para validar JSON
ALTER TABLE GameEvent ADD CONSTRAINT ck_event_data_json
CHECK (ISJSON(event_data) = 1);

ALTER TABLE AIReviewLog ADD CONSTRAINT ck_request_payload_json
CHECK (ISJSON(request_payload) = 1);

-- 3. Índice UNIQUE para Proposition (validar creator ≠ target)
-- YA EXISTE implícitamente en lógica, pero documentar con CHECK:
ALTER TABLE Proposition ADD CONSTRAINT ck_creator_not_target
CHECK (creator_player_id <> target_player_id);

-- 4. ON DELETE RESTRICT para proposiciones
ALTER TABLE Proposition DROP CONSTRAINT FK_Proposition_Status;
ALTER TABLE Proposition ADD CONSTRAINT FK_Proposition_Status
FOREIGN KEY (status_id) REFERENCES PropositionStatus(status_id)
ON DELETE RESTRICT;

-- 5. Trigger para mantener balance_points sincronizado
CREATE TRIGGER tr_transaction_update_balance
ON Transaction AFTER INSERT, UPDATE
AS
BEGIN
  UPDATE Player SET 
    balance_points = (SELECT SUM(amount) FROM Transaction 
                     WHERE player_id = Player.player_id 
                     AND currency_type_id = 1)  -- POINTS
  WHERE player_id IN (SELECT DISTINCT player_id FROM inserted);
END;
```

---

**Próximo análisis:** Escalabilidad

