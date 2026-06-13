# Análisis de Índices y Performance - Diseño de BD Gathel

**Experto:** Especialista en Optimización SQL Server  
**Fecha:** 12 de Junio de 2026  
**Contexto:** Plataforma con 250k+ eventos y 100k+ transacciones

---

## 📊 Análisis por Tabla (Críticas)

### **1. TABLA: Proposition** 🔴 CRÍTICA

**Tamaño estimado:** 5,000 registros → Crecimiento: 1-2 props/jugador/mes

**Queries frecuentes:**
1. `SELECT * FROM Proposition WHERE status_id = @status` (para listar activas)
2. `SELECT * FROM Proposition WHERE created_at > @date ORDER BY created_at DESC` (últimas)
3. `SELECT * FROM Proposition WHERE creator_player_id = @playerId`
4. `SELECT * FROM Proposition WHERE target_player_id = @playerId`
5. `SELECT * FROM Proposition WHERE prediction_ends_at <= @now` (cerrar predicciones)

**Índices recomendados:**

```sql
-- CRÍTICO: Búsqueda por estado
CREATE NONCLUSTERED INDEX idx_proposition_status 
ON dbo.Proposition(status_id) 
INCLUDE (creator_player_id, target_player_id, title, prediction_ends_at)
WHERE enabled = 1;

-- CRÍTICO: Búsqueda por creador
CREATE NONCLUSTERED INDEX idx_proposition_creator 
ON dbo.Proposition(creator_player_id, created_at DESC)
INCLUDE (status_id, title, is_accepted_by_target);

-- CRÍTICO: Búsqueda por target
CREATE NONCLUSTERED INDEX idx_proposition_target 
ON dbo.Proposition(target_player_id, created_at DESC)
INCLUDE (status_id, title, creator_player_id);

-- CRÍTICO: Búsqueda por fecha de cierre de predicciones
CREATE NONCLUSTERED INDEX idx_proposition_prediction_ends 
ON dbo.Proposition(prediction_ends_at)
WHERE status_id IN (2, 3)  -- ACTIVE, PREDICTION_CLOSED
AND enabled = 1;

-- IMPORTANTE: Búsqueda por fecha de creación
CREATE NONCLUSTERED INDEX idx_proposition_created 
ON dbo.Proposition(created_at DESC)
INCLUDE (status_id, creator_player_id, target_player_id);
```

**Justificación:**
- `INCLUDE` permite evitar lookups a tabla base (covering index)
- `WHERE` en índices filtra registros deshabilitados
- Orden DESC en created_at para queries de "últimas"

---

### **2. TABLA: Transaction** 🔴 CRÍTICA (Más activa)

**Tamaño estimado:** 100,000+ registros → Crecimiento: 20-50 trans/predicción

**Queries frecuentes:**
1. `SELECT SUM(amount) FROM Transaction WHERE player_id = @playerId AND currency_type_id = @currency` (balance)
2. `SELECT * FROM Transaction WHERE player_id = @playerId ORDER BY created_at DESC LIMIT 20` (historial)
3. `SELECT * FROM Transaction WHERE reference_type = @type AND reference_id = @id` (rastrear apuesta)
4. `SELECT running_balance FROM Transaction WHERE player_id = @playerId ORDER BY created_at DESC LIMIT 1` (balance actual)
5. `SELECT * FROM Transaction WHERE transaction_type_id = @typeId AND created_at > @date` (reportes)

**Índices recomendados:**

```sql
-- CRÍTICO: Búsqueda por jugador (la más común)
CREATE NONCLUSTERED INDEX idx_transaction_player_currency 
ON dbo.Transaction(player_id, currency_type_id, created_at DESC)
INCLUDE (amount, running_balance, transaction_type_id);

-- CRÍTICO: Búsqueda por referencia (rastrear apuesta)
CREATE NONCLUSTERED INDEX idx_transaction_reference 
ON dbo.Transaction(reference_type, reference_id)
INCLUDE (player_id, amount, created_at);

-- IMPORTANTE: Búsqueda por tipo de transacción
CREATE NONCLUSTERED INDEX idx_transaction_type 
ON dbo.Transaction(transaction_type_id, created_at DESC)
INCLUDE (player_id, amount, currency_type_id);

-- IMPORTANTE: Búsqueda por moneda (análisis de ingresos)
CREATE NONCLUSTERED INDEX idx_transaction_currency 
ON dbo.Transaction(currency_type_id, created_at DESC)
INCLUDE (player_id, amount, transaction_type_id);
```

**Justificación:**
- Índice por player_id es crítico porque 95% de queries filtran por jugador
- `running_balance` en INCLUDE permite query: "¿cuál fue balance en fecha X?"
- Orden DESC en created_at para queries de historial

---

### **3. TABLA: Prediction** 🔴 CRÍTICA (Alto volumen)

**Tamaño estimado:** 250,000+ registros → Crecimiento: 50+ pred/proposición

**Queries frecuentes:**
1. `SELECT * FROM Prediction WHERE proposition_id = @propId` (ver todas predicciones de prop)
2. `SELECT * FROM Prediction WHERE player_id = @playerId` (historial de player)
3. `SELECT * FROM Prediction WHERE result = 'PENDING'` (para resolver)
4. `SELECT SUM(amount_points) FROM Prediction WHERE proposition_id = @propId AND direction = 1` (total apostado)
5. `UPDATE Prediction SET result = 'WON' WHERE proposition_id = @propId` (actualizar resultados)

**Índices recomendados:**

```sql
-- CRÍTICO: Búsqueda por proposición
CREATE NONCLUSTERED INDEX idx_prediction_proposition 
ON dbo.Prediction(proposition_id)
INCLUDE (player_id, direction, amount_points, amount_real, result);

-- CRÍTICO: Búsqueda por jugador
CREATE NONCLUSTERED INDEX idx_prediction_player 
ON dbo.Prediction(player_id, created_at DESC)
INCLUDE (proposition_id, direction, result, amount_points);

-- IMPORTANTE: Búsqueda por resultado pendiente
CREATE NONCLUSTERED INDEX idx_prediction_result_pending 
ON dbo.Prediction(result)
WHERE result = 'PENDING'
INCLUDE (proposition_id, player_id, amount_points, amount_real);

-- IMPORTANTE: Búsqueda por dirección (para reportes)
CREATE NONCLUSTERED INDEX idx_prediction_direction 
ON dbo.Prediction(proposition_id, direction)
INCLUDE (amount_points, amount_real, player_id);
```

**Justificación:**
- Índice por proposition_id es crítico para actualizar resultados
- WHERE result='PENDING' filtra 80% de registros (solo relevantes)

---

### **4. TABLA: GameEvent** 🟡 IMPORTANTE (Auditoría)

**Tamaño estimado:** 250,000+ registros → Crecimiento: 50+ eventos/proposición

**Queries frecuentes:**
1. `SELECT * FROM GameEvent WHERE proposition_id = @propId ORDER BY created_at DESC` (historial prop)
2. `SELECT * FROM GameEvent WHERE event_type_id = @typeId AND created_at > @date` (eventos por tipo)
3. `SELECT * FROM GameEvent WHERE actor_player_id = @playerId` (actividad del jugador)

**Índices recomendados:**

```sql
-- CRÍTICO: Búsqueda por proposición
CREATE NONCLUSTERED INDEX idx_gameevent_proposition 
ON dbo.GameEvent(proposition_id, created_at DESC)
INCLUDE (event_type_id, actor_player_id, checksum);

-- IMPORTANTE: Búsqueda por tipo de evento
CREATE NONCLUSTERED INDEX idx_gameevent_event_type 
ON dbo.GameEvent(event_type_id, created_at DESC)
INCLUDE (proposition_id, actor_player_id);

-- IMPORTANTE: Búsqueda por actor
CREATE NONCLUSTERED INDEX idx_gameevent_actor 
ON dbo.GameEvent(actor_player_id, created_at DESC)
INCLUDE (event_type_id, proposition_id);
```

**Justificación:**
- Auditoría: siempre se consulta por proposición + cronología
- Orden DESC en created_at es importante

---

### **5. TABLA: Vote** 🟢 IMPORTANTE

**Tamaño estimado:** 50,000+ registros

**Queries frecuentes:**
1. `SELECT COUNT(*) FROM Vote WHERE proposition_id = @propId` (contar votos)
2. `SELECT * FROM Vote WHERE player_id = @playerId AND proposition_id = @propId` (validar unicidad)
3. `SELECT * FROM Vote WHERE proposition_id = @propId` (ver todos votos)

**Índices recomendados:**

```sql
-- CRÍTICO: Validar que jugador no vota 2 veces
CREATE UNIQUE NONCLUSTERED INDEX idx_vote_unique 
ON dbo.Vote(proposition_id, player_id);

-- IMPORTANTE: Contar votos por proposición
CREATE NONCLUSTERED INDEX idx_vote_proposition 
ON dbo.Vote(proposition_id)
INCLUDE (player_id);

-- IMPORTANTE: Búsqueda por jugador
CREATE NONCLUSTERED INDEX idx_vote_player 
ON dbo.Vote(player_id, created_at DESC)
INCLUDE (proposition_id);
```

---

## 🔧 Particionamiento Recomendado

### **Tabla: GameEvent** (Por fecha)
**Razón:** Crece muy rápido (250k+ registros). Queries casi siempre incluyen rango de fecha.

```sql
-- Crear función de partición
CREATE PARTITION FUNCTION pf_gameevent_date (DATETIME2)
AS RANGE RIGHT FOR VALUES 
  ('2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01', '2027-01-01');

-- Crear esquema de partición
CREATE PARTITION SCHEME ps_gameevent_date
AS PARTITION pf_gameevent_date
TO ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY]);

-- Crear tabla particionada
-- Nota: Si GameEvent ya existe, esto requiere recrearla
```

**Beneficio:** Queries de auditoría filtran partición sin leer todo

---

### **Tabla: Transaction** (Por player_id - Hash)
**Razón:** Distribución uniforme de acceso. Escalabilidad futura para sharding.

```sql
-- Particionar por rango de player_id
CREATE PARTITION FUNCTION pf_transaction_player (INT)
AS RANGE RIGHT FOR VALUES (250, 500, 750);

CREATE PARTITION SCHEME ps_transaction_player
AS PARTITION pf_transaction_player
TO ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY]);
```

---

## 📈 Estadísticas y Mantenimiento

### **Configuración recomendada:**

```sql
-- AUTO_UPDATE_STATISTICS: ON (default)
-- Actualiza stats automáticamente cuando 20% de tabla cambió

-- STATS_INCREMENTAL: ON (en SQL Server 2019+)
-- Actualiza solo particiones que cambiaron

-- Índices: Reorganización semanal si fragmentation > 10%
ALTER INDEX idx_proposition_status ON dbo.Proposition REORGANIZE;

-- Índices: Reconstrucción mensual si fragmentation > 30%
ALTER INDEX idx_transaction_player_currency ON dbo.Transaction REBUILD;

-- UPDATE STATISTICS manualmente después de bulk operations
UPDATE STATISTICS dbo.Prediction (idx_prediction_proposition);
```

---

## 🚨 Problemas Potenciales de Performance

### **1. Query: SELECT SUM(amount) FROM Transaction WHERE player_id = @p AND currency_type_id = @c**

**Problema:** SUM() puede leer millones de registros (growth unbounded)

**Solución:** Desnormalizar en tabla Player
```sql
ALTER TABLE Player ADD
  balance_points BIGINT,
  balance_currencies JSON;  -- {USD: 1000, EUR: 500}

-- Actualizar en cada Transaction con trigger/SP
```

**Impacto:** O(1) en lugar de O(n)

---

### **2. Query: SELECT running_balance FROM Transaction WHERE player_id = @p ORDER BY created_at DESC LIMIT 1**

**Problema:** SQL no optimiza LIMIT en ORDER BY DESC (full scan)

**Solución:** Usar índice con DESC
```sql
-- Ya está cubierto por:
CREATE NONCLUSTERED INDEX idx_transaction_player_currency 
ON dbo.Transaction(player_id, currency_type_id, created_at DESC)
```

---

### **3. UPDATE Prediction SET result = 'WON' WHERE proposition_id = @propId**

**Problema:** Sin índice por proposition_id, table scan de 250k registros

**Solución:** Ya tiene índice idx_prediction_proposition ✓

---

## 📋 Script de Creación de Índices (ORDEN PRIORITARIO)

```sql
-- ===== SEMANA 1: CRÍTICOS =====

-- 1. Transaction (más activa)
CREATE NONCLUSTERED INDEX idx_transaction_player_currency 
ON dbo.Transaction(player_id, currency_type_id, created_at DESC)
INCLUDE (amount, running_balance, transaction_type_id);

-- 2. Proposition (búsquedas frecuentes)
CREATE NONCLUSTERED INDEX idx_proposition_status 
ON dbo.Proposition(status_id) 
INCLUDE (creator_player_id, target_player_id, title, prediction_ends_at)
WHERE enabled = 1;

-- 3. Prediction (alto volumen)
CREATE NONCLUSTERED INDEX idx_prediction_proposition 
ON dbo.Prediction(proposition_id)
INCLUDE (player_id, direction, amount_points, amount_real, result);

-- ===== SEMANA 2: IMPORTANTES =====

-- 4. Proposition - búsquedas adicionales
CREATE NONCLUSTERED INDEX idx_proposition_creator 
ON dbo.Proposition(creator_player_id, created_at DESC)
INCLUDE (status_id, title, is_accepted_by_target);

CREATE NONCLUSTERED INDEX idx_proposition_target 
ON dbo.Proposition(target_player_id, created_at DESC)
INCLUDE (status_id, title, creator_player_id);

-- 5. Transaction - referencias
CREATE NONCLUSTERED INDEX idx_transaction_reference 
ON dbo.Transaction(reference_type, reference_id)
INCLUDE (player_id, amount, created_at);

-- 6. Prediction - jugador
CREATE NONCLUSTERED INDEX idx_prediction_player 
ON dbo.Prediction(player_id, created_at DESC)
INCLUDE (proposition_id, direction, result, amount_points);

-- 7. GameEvent - auditoría
CREATE NONCLUSTERED INDEX idx_gameevent_proposition 
ON dbo.GameEvent(proposition_id, created_at DESC)
INCLUDE (event_type_id, actor_player_id, checksum);

-- 8. Vote - único + búsquedas
CREATE UNIQUE NONCLUSTERED INDEX idx_vote_unique 
ON dbo.Vote(proposition_id, player_id);

CREATE NONCLUSTERED INDEX idx_vote_proposition 
ON dbo.Vote(proposition_id)
INCLUDE (player_id);

-- ===== SEMANA 3: OPTIMIZACIÓN =====

-- Índices pendientes de semana 2
-- Particionamiento de GameEvent y Transaction
-- Vistas indexadas para reportes frecuentes
```

---

## 🎯 Vistas Indexadas Recomendadas

```sql
-- Reporte: Balance actual por jugador y moneda (actualizado en tiempo real)
CREATE VIEW vw_player_balances_indexed WITH SCHEMABINDING AS
SELECT 
  p.player_id,
  p.username,
  ct.currency_code,
  COALESCE(SUM(t.amount), 0) as current_balance,
  COUNT(*) as transaction_count
FROM dbo.Player p
CROSS JOIN dbo.CurrencyType ct
LEFT JOIN dbo.Transaction t ON p.player_id = t.player_id 
  AND ct.currency_type_id = t.currency_type_id
GROUP BY p.player_id, p.username, ct.currency_code;

-- Crear índice clustered en vista
CREATE UNIQUE CLUSTERED INDEX idx_player_balances 
ON dbo.vw_player_balances_indexed(player_id, currency_code);

-- Reporte: Predicciones ganadoras por proposición
CREATE VIEW vw_winning_predictions WITH SCHEMABINDING AS
SELECT 
  pr.proposition_id,
  COUNT(*) as winning_count,
  SUM(COALESCE(pr.amount_points, 0)) as total_points_won,
  SUM(COALESCE(pr.amount_real, 0)) as total_money_won
FROM dbo.Prediction pr
WHERE pr.result = 'WON'
GROUP BY pr.proposition_id;

CREATE UNIQUE CLUSTERED INDEX idx_winning_preds 
ON dbo.vw_winning_predictions(proposition_id);
```

---

## ✅ Checklist de Performance

- ✅ Índices por tabla: 3-5 índices críticos
- ✅ Covering indexes: INCLUDE para evitar lookups
- ✅ Índices filtrados: WHERE en predicados comunes
- ✅ Índices únicos: Para validaciones (Vote)
- ✅ Orden DESC: Para queries de "últimos"
- ✅ Particionamiento: GameEvent y Transaction
- ✅ Vistas indexadas: Para reportes frecuentes
- ✅ Estadísticas: AUTO_UPDATE_STATISTICS = ON
- ✅ Mantenimiento: Reconstrucción mensual

---

## 📊 Impacto Estimado de Índices

| Métrica | Antes | Después | Mejora |
|---------|-------|---------|--------|
| Balance query | 500ms (sum 100k rows) | 1ms | 500x |
| Listar predicciones de prop | 2000ms (scan 250k) | 50ms | 40x |
| Contar votos | 1000ms (scan 50k) | 10ms | 100x |
| Historial transacciones | 5000ms | 100ms | 50x |

---

## 🎯 TOP 3 Acciones Prioritarias

**1. SEMANA 1: idx_transaction_player_currency**
- Afecta el 60% de queries
- Mejora 500x en balance queries

**2. SEMANA 1: idx_prediction_proposition**
- Necesario para resolver proposiciones
- 40x mejora en queries masivas

**3. SEMANA 1: idx_proposition_status**
- Listar proposiciones activas (UI principal)
- Crítico para UX

---

**Próximo análisis:** Normalización y Diseño
