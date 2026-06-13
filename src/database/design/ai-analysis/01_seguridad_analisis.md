# Análisis de Seguridad - Diseño de BD Gathel

**Experto:** Especialista en Seguridad de Bases de Datos Financieras  
**Fecha:** 12 de Junio de 2026  
**Contexto:** Plataforma de predicciones con transacciones monetarias reales

---

## 🔴 Vulnerabilidades Críticas (ALTO RIESGO)

### 1. **Almacenamiento de Tokens en Sesiones**
**Riesgo:** Alta  
**Descripción:** Aunque los tokens están separados en `SocialAccountSession`, si el servidor es comprometido, todos los tokens activos se exponen.

**Impacto:**
- Acceso a cuentas sociales de jugadores
- Posibilidad de publicar evidencia falsa
- Suplantación de identidad en redes sociales

**Recomendaciones:**
- ✅ Encriptación de `access_token_encrypted` con **Transparent Data Encryption (TDE)** o **Always Encrypted**
- ✅ Usar **Always Encrypted** con enclaves seguros para tokens
- ✅ Expiración automática de tokens después de 1 hora
- ✅ Implementar token rotation: cada uso genera nuevo token
- ✅ Auditar acceso a SocialAccountSession (quién lee tokens)

**Cambio recomendado en esquema:**
```sql
ALTER TABLE SocialAccountSession ADD
  last_used_at DATETIME2,
  rotation_count INT DEFAULT 0,
  encryption_key_id INT;  -- Referencia a key store
```

---

### 2. **Falta de Validación de Integridad en Transacciones Concurrentes**
**Riesgo:** Alta  
**Descripción:** Múltiples predicciones simultáneas en la misma proposición podrían crear race conditions en `running_balance`.

**Escenario de ataque:**
```
T1: Player A predice 50 POINTS (balance: 100 → 50)
T2: Player A predice simultáneamente 50 POINTS (lee balance=100, resta 50 = 50)
Resultado: Se restan 100 en lugar de los permitidos
```

**Impacto:**
- Balance negativo
- Fraude de puntos
- Inconsistencia de datos

**Recomendaciones:**
- ✅ Usar **SERIALIZABLE** isolation level para predicciones
- ✅ Implementar locks optimistas con versioning (`version` field)
- ✅ Usar SPs transaccionales con `XLOCK` en Player
- ✅ Validar balance ANTES de debitar en SP

**Cambio recomendado:**
```sql
ALTER TABLE Player ADD
  balance_version INT DEFAULT 1;  -- Para optimistic locking
```

---

### 3. **JSON sin Validación Abre Riesgos de Inyección**
**Riesgo:** Media-Alta  
**Descripción:** `GameEvent.event_data` y `AIReviewLog.request_payload/response_payload` son NVARCHAR(MAX) JSON sin validación.

**Riesgo:**
- Inyección de SQL vía JSON malformado
- XSS si se renderiza en UI sin sanitizar
- Corrupción de datos

**Impacto:**
- Ejecución de queries maliciosas
- Modificación de datos sensibles

**Recomendaciones:**
- ✅ Validar JSON al insertar con `ISJSON()`
- ✅ Usar CHECK constraint: `CHECK (ISJSON(event_data) = 1)`
- ✅ Limitar tamaño de JSON: MAX 10MB para event_data
- ✅ Sanitizar en aplicación antes de insertar
- ✅ No usar CONVERT/PARSE directo en queries, usar JSON functions

**Cambio recomendado:**
```sql
ALTER TABLE GameEvent ADD CONSTRAINT ck_event_data_json 
  CHECK (ISJSON(event_data) = 1);

ALTER TABLE AIReviewLog ADD CONSTRAINT ck_request_payload_json 
  CHECK (ISJSON(request_payload) = 1);
```

---

### 4. **Exposición de reference_id en Transaction**
**Riesgo:** Media-Alta  
**Descripción:** `Transaction.reference_type + reference_id` permite rastrear proposiciones/predicciones. Un jugador malicioso podría enumerar todas las transacciones de otro.

**Impacto:**
- Privacidad: descubrir hábitos de predicción de otros
- Phishing: targeting de jugadores por patrones de apuestas

**Recomendaciones:**
- ✅ Implementar Row-Level Security (RLS) en Transaction
- ✅ Solo el dueño de la transacción ve sus propios records
- ✅ Admins ven auditoría, pero con data masking
- ✅ Endpoint de API para obtener transacciones: validar player_id actual

---

### 5. **Falta de Auditoría de Cambios a Proposiciones**
**Riesgo:** Media-Alta  
**Descripción:** Aunque hay `updated_at` y `updated_by`, no hay tabla de auditoría de cambios específicos (qué campo cambió, de qué a qué).

**Impacto:**
- Imposible rastrear si alguien modificó is_fulfilled o status_id
- Fraude: modificar resultado de proposición

**Recomendaciones:**
- ✅ Crear tabla `PropositionAudit` que registre TODOS los cambios
- ✅ Trigger en Proposition que cree registro en PropositionAudit
- ✅ Registrar: old_value, new_value, changed_by, changed_at, field_name

**Nuevo schema:**
```sql
CREATE TABLE PropositionAudit (
  audit_id BIGINT PRIMARY KEY IDENTITY,
  proposition_id INT NOT NULL FK,
  field_name VARCHAR(50),
  old_value VARCHAR(MAX),
  new_value VARCHAR(MAX),
  changed_by VARCHAR(100),
  changed_at DATETIME2 DEFAULT GETUTCDATE(),
  checksum VARCHAR(64)
);
```

---

## 🟡 Vulnerabilidades Medias (RIESGO MODERADO)

### 6. **Password Hash sin Salting Específico**
**Riesgo:** Media  
**Descripción:** Se dice `password_hash` pero no se especifica el algoritmo. ¿Es bcrypt con salt? ¿PBKDF2?

**Recomendación:**
- ✅ Usar **bcrypt** con cost factor ≥ 12
- ✅ O **Argon2id** (mejor)
- ✅ Documentar claramente en código: "Argon2id(password, salt=random, time=2, memory=65536, parallelism=1)"

---

### 7. **Checksum sin Timestamp**
**Riesgo:** Media  
**Descripción:** El checksum valida que no cambió, pero ¿cuándo se calculó? Un atacante podría modificar registro y recalcular checksum.

**Mejora:**
- ✅ Agregar campo `checksum_timestamp` que no pueda ser modificado
- ✅ Checksum debe incluir created_at: `SHA256(player_id | amount | created_at | ...)`

---

### 8. **Falta de Rate Limiting en Schema**
**Riesgo:** Media  
**Descripción:** No hay forma de validar en BD que un jugador no cree 1000 proposiciones por segundo.

**Recomendación:**
- ✅ Aplicación debe implementar rate limiting
- ✅ BD: agregar índice para `(player_id, created_at)` para auditoría post-facto

---

## 🟢 Recomendaciones de Mejora

### Control de Acceso y Roles Necesarios

```sql
-- ROLES DE SEGURIDAD RECOMENDADOS

CREATE ROLE [Player] AUTHORIZATION [dbo];
-- Permisos:
-- SELECT: Player (solo su registro), Transaction (solo sus transacciones), GameEvent (de sus proposiciones)
-- INSERT: Prediction, Vote, Proposition, GameEvent
-- UPDATE: Prediction (solo si no pasó prediction_ends_at), Proposition (solo fields permitidos)

CREATE ROLE [Admin] AUTHORIZATION [dbo];
-- Permisos: SELECT, INSERT, UPDATE, DELETE en todas las tablas
-- Con auditoría en ProcessLog

CREATE ROLE [System] AUTHORIZATION [dbo];
-- Permisos: Ejecutar SPs para IA, transacciones, cálculos
-- No tiene acceso a Player.password_hash

CREATE ROLE [AISystem] AUTHORIZATION [dbo];
-- Permisos: INSERT AIReviewLog, UPDATE Proposition (ai_review_result)
-- No modifica transacciones ni predicciones
```

---

### Campos Sensibles que Requieren Data Masking

| Campo | Justificación | Estrategia |
|-------|---------------|-----------|
| Player.password_hash | Credencial crítica | NEVER expose (incluso en logs) |
| Player.email | PII | Maskear para no-owners: a***@email.com |
| SocialAccountSession.access_token_encrypted | Token de acceso | NEVER expose, usar Always Encrypted |
| SocialAccountSession.refresh_token_encrypted | Token de refresco | NEVER expose, usar Always Encrypted |
| Proposition.description | Puede contener datos sensibles | Maskear en reportes públicos |
| Player.balance_points | Info financiera | Solo dueño ve completo, otros ven "Suficientes" |

**Implementación:**
```sql
-- Vistas con Data Masking
CREATE VIEW vw_player_public AS
SELECT 
  player_id,
  display_name,
  -- email enmascarado
  LEFT(email, 1) + '***@' + SUBSTRING(email, CHARINDEX('@', email), LEN(email)) AS email_masked,
  -- Balance enmascarado para otros
  CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'CONTROL') = 1 THEN balance_points ELSE NULL END AS balance_points
FROM Player;
```

---

### Row-Level Security (RLS) Recomendado

```sql
-- Predicción: Jugador solo ve sus predicciones
CREATE SECURITY POLICY dbo.TransactionSecurityPolicy
ADD FILTER PREDICATE dbo.TransactionFilter(player_id)
ON dbo.Transaction
WITH (STATE = ON);

CREATE FUNCTION dbo.TransactionFilter(@player_id int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS is_accessible
WHERE @player_id = CAST(SESSION_CONTEXT(N'user_id') AS int)
   OR CAST(SESSION_CONTEXT(N'role') AS varchar) = 'Admin';
```

---

## 📋 Cambios Recomendados al Esquema (SEGURIDAD)

| Campo | Tabla | Acción | Razón |
|-------|-------|--------|-------|
| encryption_key_id | SocialAccountSession | Agregar | Trackear qué key encrypta cada token |
| last_used_at | SocialAccountSession | Agregar | Detectar tokens no usados |
| rotation_count | SocialAccountSession | Agregar | Auditoría de rotaciones |
| balance_version | Player | Agregar | Optimistic locking |
| PropositionAudit | (nueva tabla) | Crear | Auditoría completa de cambios |
| checksum | GameEvent, PropositionEvidence | Verificar presencia | Detectar manipulación |
| CONSTRAINTS JSON | GameEvent, AIReviewLog | Agregar CHECK(ISJSON()) | Validar integridad |

---

## 🎯 TOP 5 Acciones Prioritarias

**1. CRÍTICO: Implementar Always Encrypted en tokens (Semana 1)**
```sql
ALTER TABLE SocialAccountSession
ADD access_token_encrypted_encrypted VARBINARY(MAX) ENCRYPTED WITH (...);
```

**2. CRÍTICO: Agregar PropositionAudit (Semana 1)**
- Trackear todos los cambios a proposiciones
- Trigger para registrar cambios

**3. IMPORTANTE: RLS en Transaction (Semana 2)**
- Jugadores solo ven sus transacciones
- Admins ven todo con data masking

**4. IMPORTANTE: Validación JSON con CHECK constraints (Semana 1)**
- `CHECK(ISJSON(event_data) = 1)`
- `CHECK(ISJSON(request_payload) = 1)`

**5. IMPORTANTE: Revisión de isolation levels (Semana 2)**
- SPs transaccionales con SERIALIZABLE
- Testing de race conditions

---

## ✅ Conclusión

El diseño es **fundamentalmente seguro** porque:
- ✅ Separación de tokens en tabla propia
- ✅ Checksums para detectar manipulación
- ✅ Auditoría con GameEvent + ProcessLog
- ✅ Restricciones de FK para integridad

Pero necesita **mejoras en**:
- 🔴 Encriptación de tokens
- 🔴 Auditoría de cambios específicos
- 🔴 RLS para privacidad
- 🔴 Validación de JSON
- 🔴 Race conditions en transacciones

**Esfuerzo estimado:** 3-4 semanas para implementar todas las mejoras

---

**Próximo análisis:** Indices y Performance
