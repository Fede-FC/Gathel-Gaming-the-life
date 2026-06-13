# Análisis de Escalabilidad - Diseño de BD Gathel

**Experto:** Especialista en Escalabilidad y Sistemas Distribuidos  
**Fecha:** 12 de Junio de 2026  
**Contexto:** Crecimiento de 1K a 100K+ jugadores

---

## 📈 Proyecciones de Crecimiento de Datos

### **Escenario 1: Caso de Estudio (Actual)**
```
Jugadores: 1,000
Proposiciones/jugador: 5
Predicciones/proposición: 50
Votos/proposición: 10

Cálculos:
- Player: 1,000 registros = 0.5 MB
- Proposition: 5,000 registros = 2.5 MB
- Vote: 50,000 registros = 2.5 MB
- Prediction: 250,000 registros = 50 MB
- Transaction: 100,000 registros (estimado) = 10 MB
- GameEvent: 250,000 registros = 150 MB (JSON)
- SocialAccountSession: 2,000 registros = 1 MB

TAMAÑO TOTAL: ~220 MB
CRECIMIENTO/MES: ~50 MB (si mantiene actividad)
```

---

### **Escenario 2: Crecimiento a 10K Jugadores**
```
10x en jugadores, 3x en actividad

Jugadores: 10,000
Proposiciones: 50,000
Predicciones: 1,250,000
Votos: 500,000
Transacciones: 1,000,000
GameEvent: 2,500,000

TAMAÑO TOTAL: ~2-3 GB
Índices: +0.5 GB
TOTAL CON ÍNDICES: ~3.5 GB

CRECIMIENTO/MES: ~500 MB
```

---

### **Escenario 3: Crecimiento a 100K Jugadores (Escala)**
```
100x en jugadores, 10x en actividad

Jugadores: 100,000
Proposiciones: 500,000
Predicciones: 12,500,000
Votos: 5,000,000
Transacciones: 10,000,000
GameEvent: 25,000,000

TAMAÑO TOTAL: ~25-30 GB
Índices: +5 GB
Logs de transacciones: +5 GB
TOTAL CON ÍNDICES Y LOGS: ~35-40 GB

CRECIMIENTO/MES: ~5 GB
TIEMPO DUPLICACIÓN: 2 meses
```

---

## 🚨 Cuellos de Botella Identificados

### **1. CRÍTICO: Tabla Transaction (Crecimiento exponencial)**

**Problema:**
```
- Crece 20+ registros por predicción
- Predicciones = 50+ por proposición
- Proposiciones = 5+ por jugador
- En 100K jugadores: 10M+ transacciones

Impacto:
- Índices en Transaction pueden crecer a 2-3 GB
- Backup/restore toma horas
- Full scan de Transaction toma minutos
- Fragmentation severa después de 6 meses
```

**Solución 1: Particionamiento por Rango de Fecha**
```sql
-- Particionar por mes
CREATE PARTITION FUNCTION pf_transaction_date (DATETIME2)
AS RANGE RIGHT FOR VALUES 
  ('2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01', ...);

CREATE PARTITION SCHEME ps_transaction_date
AS PARTITION pf_transaction_date
ALL TO ([PRIMARY]);

-- Beneficio:
-- - Queries de auditoría filtran partición (no leer 10M registros)
-- - Archivamiento: mover particiones antiguas a storage frío
-- - Mantenimiento: reorganizar partes por separado
```

**Solución 2: Desnormalización en Player**
```sql
-- Cachear balance por moneda
ALTER TABLE Player ADD (
  balance_points BIGINT DEFAULT 100,
  balance_currencies NVARCHAR(MAX)  -- {"USD": 1000, "EUR": 500}
);

-- Beneficio:
-- - Balance query = O(1) en lugar de O(n)
-- - No necesita leer 10M transacciones

-- Costo:
-- - Trigger para cada transaction
-- - Riesgo de inconsistencia si falla trigger
```

**Solución 3: Tabla Summary por Jugador**
```sql
CREATE TABLE TransactionSummary (
  summary_id INT PRIMARY KEY IDENTITY,
  player_id INT FK,
  currency_type_id INT FK,
  period_date DATE,  -- YYYY-MM-01 (primero del mes)
  opening_balance DECIMAL(18,4),
  closing_balance DECIMAL(18,4),
  transactions_count INT,
  created_at DATETIME2
);

-- Índice: (player_id, currency_type_id, period_date)
-- Beneficio: Queries de historial usan summary, no scannean todos los registros
```

**RECOMENDACIÓN:** ✅ Implementar Solución 1 (particionamiento) + Solución 3 (summary)

---

### **2. CRÍTICO: Tabla GameEvent (Auditoría masiva)**

**Problema:**
```
- 25M registros en escala 100K jugadores
- event_data es JSON (consume 6-8 KB por registro)
- = 150-200 GB solo en GameEvent

Impacto:
- Auditoría lenta
- Backup toma días
- Índices fragmentados
```

**Solución 1: Particionamiento por Fecha**
```sql
CREATE PARTITION FUNCTION pf_gameevent_date (DATETIME2)
AS RANGE RIGHT FOR VALUES ('2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01', '2027-01-01');

CREATE PARTITION SCHEME ps_gameevent_date
AS PARTITION pf_gameevent_date
ALL TO ([PRIMARY]);

-- Beneficio:
-- - Queries de "eventos últimos 30 días" filtran 1-2 particiones
-- - Archivamiento: mover particiones antiguas a storage frío
```

**Solución 2: Archivamiento Automático**
```sql
-- Crear tabla archive
CREATE TABLE GameEventArchive (
  LIKE GameEvent
) ON [ARCHIVE_FILEGROUP];

-- Job mensual: Mover eventos de 12+ meses a archive
-- SWAP PARTITION sintaxis SQL Server 2014+
ALTER TABLE GameEvent SWITCH PARTITION 1 TO GameEventArchive PARTITION 1;

-- Beneficio:
-- - BD activa: 2-3 últimos meses (manejo rápido)
-- - Archive: histórico (acceso raro)
-- - Tamaño BD activa: 2-3 GB en lugar de 200 GB
```

**RECOMENDACIÓN:** ✅ Implementar particionamiento + archivamiento automático

---

### **3. IMPORTANTE: Tabla Prediction (Alto volumen de escrituras)**

**Problema:**
```
- 12.5M registros en escala
- Actualización masiva al resolver: UPDATE Prediction SET result = 'WON'
  → 100,000+ registros en una transacción
  → Bloquea otras queries

Impacto:
- Contenciones de locks
- Timeouts en queries de lectura
- Ralentización durante resolución de proposiciones
```

**Solución: Batch Updates Pequeños**
```sql
-- En lugar de:
UPDATE Prediction SET result = 'WON' 
WHERE proposition_id = @propId;

-- Hacer:
DECLARE @batch_size = 1000;
WHILE EXISTS(SELECT 1 FROM Prediction WHERE proposition_id = @propId AND result = 'PENDING')
BEGIN
  UPDATE TOP(@batch_size) Prediction 
  SET result = 'WON'
  WHERE proposition_id = @propId AND result = 'PENDING';
  
  WAITFOR DELAY '00:00:00.1';  -- Pequeña pausa para no bloquear
END

-- Beneficio:
-- - Múltiples transacciones pequeñas
-- - Permite otras queries entre batches
-- - Menos lock escalation
```

**RECOMENDACIÓN:** ✅ Usar batch updates en SPs críticos

---

### **4. IMPORTANTE: Indices Fragmentación**

**Problema:**
```
En escala 100K jugadores:
- Transaction: 10M registros, crecimiento continuo
- GameEvent: 25M registros, crecimiento continuo
- Prediction: 12.5M registros, muchos updates

Fragmentation esperada:
- Después de 6 meses: 30-40% fragmentation
- Después de 1 año: 50%+ fragmentation

Impacto:
- Queries 2-3x más lento
- Índices más grandes (no caben en cache)
- I/O multiplicado
```

**Solución: Mantenimiento Automático**
```sql
-- Índices activos (writes frecuentes): Reorganización semanal
ALTER INDEX idx_transaction_player_currency ON Transaction REORGANIZE;

-- Índices menos activos: Reconstrucción mensual
ALTER INDEX idx_proposition_status ON Proposition REBUILD 
WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON);

-- Script automático (job SQL Agent):
DECLARE @table_name NVARCHAR(128) = 'Transaction';
DECLARE @fill_factor INT = 80;

ALTER INDEX ALL ON dbo.Transaction 
REBUILD WITH (FILLFACTOR = @fill_factor, SORT_IN_TEMPDB = ON);

-- Duración: 1-2 horas por tabla en escala 100K
-- Ejecutar: domingo 2 AM (off-peak)
```

**RECOMENDACIÓN:** ✅ Automatizar mantenimiento de índices

---

## 🔀 Sharding / Distribución

### **¿Necesitará sharding?**

**Análisis:**
```
Escala 100K jugadores:
- BD tamaño: 35-40 GB
- Índices: +5 GB
- Total: ~50 GB

SQL Server Enterprise puede manejar:
- 2-4 TB en una instancia (no es problema)
- 100K conexiones simultáneas (POSIBLE pero limitado)
- IOPS: 100K transacciones/segundo (POSIBLE con SSD)

Decisión:
- CON sharding: Complejidad 10x, operaciones complejas
- SIN sharding: Un servidor robusto suficiente hasta 500K jugadores

RECOMENDACIÓN: ✅ NO necesita sharding aún
- En 500K+ jugadores, considerar sharding por player_id
```

---

### **Si necesita sharding en el futuro:**

**Estrategia: Player-ID Based Sharding**
```
Shard 1: player_id % 10 = 0-2 (players 0, 10, 20, ...)
Shard 2: player_id % 10 = 3-5
Shard 3: player_id % 10 = 6-8
Shard 4: player_id % 10 = 9

Ventajas:
✅ Todas las transacciones de un player en un shard
✅ No necesita distributed transactions entre shards
✅ Cada shard: 25% de los datos

Desventajas:
⚠️ Queries cross-shard (reportes globales) lentas
⚠️ Rebalancing es complejo

Tablas sharded:
- Player, SocialAccount, Transaction, Prediction, Proposition (creator/target), GameEvent

Tablas globales (no sharded):
- Catálogos (PropositionStatus, CurrencyType, etc.)
- Proposiciones (requiere búsqueda global de targets)
```

---

## 💾 Archivamiento y Retención

### **Política de Retención Recomendada**

```
Activo (BD principal):
- Últimos 12 meses de datos
- Tamaño: 5-10 GB
- Performance: Óptimo

Frío (Storage económico - Blob Storage, S3):
- 1-3 años de datos
- Acceso: Raro (reportes regulatorios)
- Tamaño: 50-200 GB comprimido

Eliminación:
- > 3 años: Eliminar (cumplimiento GDPR)
- O pseudonimizar: Reemplazar player_id con hash

Implementación:
```sql
-- Procedimiento mensual de archivamiento
CREATE PROCEDURE sp_archive_old_data
AS
BEGIN
  DECLARE @archive_date DATE = DATEADD(MONTH, -12, CAST(GETUTCDATE() AS DATE));
  
  -- Exportar GameEvent a archivo
  SELECT * INTO dbo.GameEventArchive_2024
  FROM GameEvent
  WHERE created_at < @archive_date;
  
  -- Eliminar de tabla activa
  DELETE FROM GameEvent
  WHERE created_at < @archive_date;
  
  -- Comprimir archive
  -- BACKUP dbo.GameEventArchive_2024 TO BLOB STORAGE
  
  -- Eliminar tabla local
  -- DROP TABLE dbo.GameEventArchive_2024;
END
```

---

## 🖥️ Recomendaciones de Infraestructura

### **Escala Actual (1K-10K jugadores)**
```
Servidor:
- SQL Server 2022 Standard (1-2 sockets)
- CPU: 8 cores, 2.4+ GHz
- RAM: 32 GB (DB en memoria)
- Storage: 500 GB SSD (fast I/O)
- Backup: 1 TB local + cloud

Licencia: Standard (OK hasta 2 sockets)
Costo: $3,000-5,000 año

Performance esperado:
- Read: 1000s queries/seg
- Write: 100s predicciones/seg
- Respuesta: <100ms promedio
```

---

### **Escala Media (10K-100K jugadores)**
```
Servidor:
- SQL Server 2022 Enterprise (2-4 sockets)
- CPU: 16-32 cores
- RAM: 128-256 GB
- Storage: 2-4 TB SSD (muy fast I/O)
- Backup: 10 TB (local + 2 cloud)
- HA/DR: Always On Availability Groups

Licencia: Enterprise
Costo: $20,000-40,000 año

Performance esperado:
- Read: 10,000s queries/seg
- Write: 1,000s predicciones/seg
- Respuesta: <50ms promedio
```

---

### **Escala Grande (100K+ jugadores)**
```
Infraestructura distribuida:
- 4 servidores SQL Server Enterprise (2 para writes, 2 para reads)
- Cada servidor: 32+ cores, 256 GB RAM
- Storage: SAN dedicada (10k+ IOPS)
- Sharding: 4-8 shards distribuidos

Load Balancing:
- Write: Siempre a shard primario
- Read: Distribuido entre replicas

Backup/DR:
- Replicación transaccional
- Backups diferenciales cada hora
- Cloud DR site con RTO < 1 hora

Licencia: Enterprise
Costo: $100,000+ año

Performance esperado:
- Read: 100,000s queries/seg
- Write: 10,000s predicciones/seg
- Respuesta: <20ms promedio
```

---

## 🎯 Riesgos de Escalabilidad

### **1. Fragmentación de Índices** 🔴
**Cuando:** Después de 6 meses en escala media
**Impacto:** Queries 2-3x lento
**Mitigación:** Mantenimiento automatizado

### **2. Lock Escalation** 🔴
**Cuando:** 1000+ updates simultáneos
**Impacto:** Deadlocks, timeouts
**Mitigación:** Batch updates, SERIALIZABLE isolation

### **3. Plan Cache Invalidation** 🟡
**Cuando:** > 1 millón de execution plans
**Impacto:** Memory pressure, CPU
**Mitigación:** Parámetros en queries, no strings dinámicas

### **4. Transaction Log Growth** 🔴
**Cuando:** > 1 millón de transacciones/hora
**Impacto:** Disk full en 24 horas si no mantenía
**Mitigación:** Backup log cada 15 minutos, truncate log

### **5. Corrupción de Datos** 🔴
**Cuando:** Falla de hardware bajo load
**Impacto:** Pérdida de datos, inactividad
**Mitigación:** RAID 10, UPS, backups diarios + verificación

---

## 📋 Plan de Escalabilidad (Roadmap)

```
FASE 1 (Ahora - 6 meses): 1K - 10K jugadores
✅ Índices críticos (Transaction, Proposition, Prediction)
✅ Vistas indexadas para reportes
❌ Sharding (no necesario aún)
❌ Archivamiento (poco volumen)

Acciones:
- Crear índices prioritarios
- Monitorear fragmentation semanal
- Backup diario

FASE 2 (6-12 meses): 10K - 50K jugadores
✅ Particionamiento (Transaction, GameEvent)
✅ Archivamiento automático
✅ Mantenimiento de índices (nightly job)
⚠️ Considerar Always On (HA)

Acciones:
- Implementar particionamiento
- Automatizar archivamiento
- Monitoreo de performance (profiler)

FASE 3 (1-2 años): 50K - 100K+ jugadores
✅ Sharding (si necesario)
✅ Always On Availability Groups
✅ Read replicas distribuidas
✅ Caché distribuida (Redis)

Acciones:
- Arquitectura multi-shard
- DR site con replicación transaccional
- Análisis de hot spots (qué tablas/queries ralentizan)

FASE 4 (2+ años): 100K+ jugadores
✅ Microservicios (BD por dominio)
✅ Event Sourcing (auditoría inmutable)
✅ Time-series DB para eventos (InfluxDB)
✅ Graph DB para relaciones sociales

Acciones:
- Refactor a microservicios
- Event sourcing para transacciones
- Separar eventos a Time-series DB
```

---

## ✅ Conclusión de Escalabilidad

| Aspecto | Análisis |
|---------|----------|
| **Crecimiento esperado** | 50 MB/mes → 5 GB/mes en escala |
| **Cuello de botella 1** | Transaction (particionamiento resuelve) |
| **Cuello de botella 2** | GameEvent (archivamiento resuelve) |
| **Cuello de botella 3** | Índices fragmentation (mantenimiento resuelve) |
| **¿Necesita sharding ahora?** | ❌ NO (hasta 500K+ jugadores) |
| **¿Necesita HA/DR?** | ✅ SÍ (a partir de 100K jugadores) |
| **Infraestructura recomendada** | SQL Server Enterprise + SSD + backup cloud |
| **Inversión requerida** | $3K/año (actual) → $100K+/año (grande) |

---

## 🚀 TOP 5 Acciones Prioritarias (Escalabilidad)

**1. AHORA: Implementar índices prioritarios**
- idx_transaction_player_currency
- idx_prediction_proposition
- idx_proposition_status

**2. MES 1: Monitoreo de performance**
- Queries más lentas (Query Store)
- Fragmentation de índices (semanal)
- Wait statistics (bottlenecks)

**3. MES 3: Particionamiento de Transaction**
- Por mes (RANGE RIGHT en created_at)
- Archivamiento de 12+ meses

**4. MES 6: Particionamiento de GameEvent**
- Por trimestre (quarterly)
- Archivamiento automático

**5. MES 12: Always On Availability Groups**
- Si alcanza 50K+ jugadores
- HA local + DR en otra región

---

**Fin de análisis de escalabilidad**

