# Fase 4 — Transacciones y Concurrencia

Documentación completa de todos los scripts de concurrencia para **Gathel Gaming Platform**.  
Todos los scripts están versionados con Flyway bajo la migración `V5`.

---

## Índice de archivos

| Archivo | Contenido |
|---|---|
| `01_nested_transactions.sql` | SPs transaccionales anidados (3 niveles) |
| `02_deadlock_writes.sql` | Deadlock con dos escrituras concurrentes |
| `03_deadlock_read_write.sql` | Deadlock entre lectura y escritura |
| `04_deadlock_cyclic.sql` | Deadlock cíclico T1 → T2 → T3 → T1 |
| `05_isolation_levels.sql` | Los 4 niveles de aislamiento y sus anomalías |

---

## 01 — Transacciones Anidadas (3 Niveles)

### Concepto

SQL Server **no tiene transacciones anidadas reales**. Cuando se ejecuta `BEGIN TRAN` dentro de otro `BEGIN TRAN`, el contador `@@TRANCOUNT` sube, pero solo el `COMMIT` del nivel más externo confirma los cambios. Un `ROLLBACK` en cualquier nivel revierte **todo**.

Para aislar el fallo de un SP interno sin revertir los niveles superiores se usan **savepoints**:

```sql
SAVE TRANSACTION SaveL3;
-- trabajo del nivel 3 ...
ROLLBACK TRANSACTION SaveL3;  -- revierte solo el trabajo de L3
```

### Cadena de SPs

```
usp_Nested_L1_ResolveProposition   ← nivel exterior (BEGIN TRANSACTION real)
  └─ usp_Nested_L2_DistributeWinnings  ← nivel 2 (SAVE TRANSACTION SaveL2)
       └─ usp_Nested_L3_RegisterCommission  ← nivel 3 (SAVE TRANSACTION SaveL3)
```

### Demo 1: Flujo exitoso

```sql
EXEC dbo.usp_Nested_L1_ResolveProposition
    @proposition_id = 1,
    @is_fulfilled   = 1,
    @should_fail_l3 = 0;
```

Resultado esperado: los tres SPs se completan, la proposición queda `RESOLVED` y se registran las transacciones de ganancias y comisión.

### Demo 2: Fallo en el nivel 3

```sql
EXEC dbo.usp_Nested_L1_ResolveProposition
    @proposition_id = 2,
    @is_fulfilled   = 1,
    @should_fail_l3 = 1;  -- ← L3 lanza un error
```

Resultado esperado:
- L3 hace `ROLLBACK TRANSACTION SaveL3` (descarta su trabajo).
- L3 re-lanza el error (`THROW`).
- L2 captura el error, hace `ROLLBACK TRANSACTION SaveL2`, re-lanza.
- L1 captura el error, hace `ROLLBACK TRANSACTION` (toda la TX).
- La proposición **no** queda marcada como resuelta.
- El `ProcessLog` muestra entradas `ERROR` en los tres niveles.

### Verificación

```sql
SELECT sp_name, action_description, status, error_detail, executed_at
FROM dbo.ProcessLog
WHERE sp_name LIKE 'usp_Nested%'
ORDER BY executed_at DESC;
```

---

## 02 — Deadlock con Escrituras Concurrentes

### Concepto

Ocurre cuando dos transacciones adquieren locks en **orden inverso** sobre los mismos recursos:

```
T1: Lock(Player A) → espera Lock(Player B)
T2: Lock(Player B) → espera Lock(Player A)
→ Ciclo → SQL Server elige una víctima (error 1205)
```

### SPs involucrados

- `usp_DL_Write_SessionA`: actualiza Player A → luego Player B
- `usp_DL_Write_SessionB`: actualiza Player B → luego Player A (orden inverso)

### Instrucciones (SSMS)

1. Abrir dos ventanas de query.
2. Ventana 1: `EXEC dbo.usp_DL_Write_SessionA @player_a_id=1, @player_b_id=2, @proposition_id=1`
3. Ventana 2 (dentro de 2 segundos): `EXEC dbo.usp_DL_Write_SessionB @player_a_id=1, @player_b_id=2, @proposition_id=1`
4. Una de las dos sesiones recibirá error 1205 (deadlock victim).

### Mitigación

Acceder siempre a los recursos en el **mismo orden** (ej. siempre Player con ID menor primero):

```sql
-- Ordenar acceso por player_id ASC
IF @player_a_id < @player_b_id
BEGIN
    UPDATE dbo.Player SET ... WHERE player_id = @player_a_id;
    UPDATE dbo.Player SET ... WHERE player_id = @player_b_id;
END
ELSE
BEGIN
    UPDATE dbo.Player SET ... WHERE player_id = @player_b_id;
    UPDATE dbo.Player SET ... WHERE player_id = @player_a_id;
END
```

---

## 03 — Deadlock entre Lectura y Escritura

### Concepto

Un `SELECT` estándar toma locks **compartidos (S)**. Un `UPDATE` toma locks **exclusivos (X)**. El deadlock ocurre así:

```
T1 (lector):   S-lock(Player) → quiere S-lock(Prediction)
T2 (escritor): X-lock(Prediction) → quiere X-lock(Player)
               ← bloqueado porque T1 tiene S-lock(Player)
               ← T1 bloqueado porque X-lock pending impide nuevos S-locks
→ Deadlock
```

Este escenario puede ocurrir incluso con el nivel por defecto `READ COMMITTED`.

### SPs involucrados

- `usp_DL_Read_PlayerSummary`: lector con `HOLDLOCK` (Player → Prediction)
- `usp_DL_Write_PredictionProcess`: escritor (Prediction → Player, orden inverso)

### Mitigación recomendada

Habilitar **Read Committed Snapshot Isolation (RCSI)**. Los lectores leen la última versión confirmada sin adquirir S-locks sobre las filas:

```sql
ALTER DATABASE GathelDB
SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
```

---

## 04 — Deadlock Cíclico T1 → T2 → T3 → T1

### Concepto

Tres transacciones forman un ciclo de espera:

```
T1: Lock(Player A) → espera Lock(Player B)
T2: Lock(Player B) → espera Lock(Proposition Z)
T3: Lock(Proposition Z) → espera Lock(Player A)   ← CIERRA EL CICLO
```

### SPs involucrados

| SP | Adquiere primero | Luego necesita |
|---|---|---|
| `usp_DL_Cyclic_T1` | Player A | Player B |
| `usp_DL_Cyclic_T2` | Player B | Proposition Z |
| `usp_DL_Cyclic_T3` | Proposition Z | Player A |

### Instrucciones (SSMS)

Abrir **tres** ventanas. Ejecutar T1, T2 y T3 dentro de un intervalo de 2 segundos.  
SQL Server detecta el ciclo y elimina a la víctima con menor coste de rollback.

### Monitoreo del deadlock graph

```sql
SELECT TOP 5
    xdr.value('@timestamp', 'datetime2') AS deadlock_time,
    xdr.query('.')                       AS deadlock_graph
FROM (
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets t
    INNER JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
    WHERE s.name = 'system_health' AND t.target_name = 'ring_buffer'
) data
CROSS APPLY target_data.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') XEventData(xdr)
ORDER BY deadlock_time DESC;
```

---

## 05 — Niveles de Aislamiento

### Tabla resumen de anomalías

| Nivel | Dirty Read | Non-Rep. Read | Phantom Read | Contención |
|---|---|---|---|---|
| `READ UNCOMMITTED` | ✅ Posible | ✅ Posible | ✅ Posible | Mínima |
| `READ COMMITTED` | ❌ Prevenido | ✅ Posible | ✅ Posible | Baja |
| `REPEATABLE READ` | ❌ | ❌ Prevenido | ✅ Posible | Media |
| `SERIALIZABLE` | ❌ | ❌ | ❌ Prevenido | Alta |

### Demo 1 — Dirty Read (`READ UNCOMMITTED`)

```
Ventana 1: EXEC dbo.usp_IL_DirtyWrite_Writer @player_id=1, @new_balance=999999;
Ventana 2: EXEC dbo.usp_IL_DirtyRead_Reader  @player_id=1;
```

Ventana 2 ve `999999`. Ventana 1 hace ROLLBACK → ese valor nunca existió en la BD.

**Mitigación:** No usar `READ UNCOMMITTED` ni `WITH (NOLOCK)` en tablas financieras.

### Demo 2 — Non-Repeatable Read (`READ COMMITTED`)

```
Ventana 1: EXEC dbo.usp_IL_NonRepeatableRead @player_id=1;
Ventana 2 (durante la espera de 6s):
    EXEC dbo.usp_IL_UpdateBalance @player_id=1, @new_balance=50; COMMIT;
```

Ventana 1 imprime dos valores distintos en la misma transacción.

**Mitigación:** Usar `REPEATABLE READ` o RCSI para lecturas críticas multi-paso.

### Demo 3 — Phantom Read (`REPEATABLE READ`)

```
Ventana 1: EXEC dbo.usp_IL_PhantomRead @proposition_id=1;
Ventana 2 (durante la espera de 6s):
    INSERT INTO dbo.Prediction (...) VALUES (3, 1, 0, 1, GETUTCDATE(), GETUTCDATE());
```

La segunda lectura en Ventana 1 muestra más filas que la primera.

**Mitigación:** Usar `SERIALIZABLE` para conteos o validaciones que no pueden tener filas nuevas entre dos lecturas.

### Demo 4 — Serializable bloquea al escritor

```
Ventana 1: EXEC dbo.usp_IL_Serializable_Reader @proposition_id=1;
Ventana 2 (inmediatamente):
    EXEC dbo.usp_IL_Serializable_Writer @player_id=3, @proposition_id=1;
```

Ventana 2 queda **bloqueada** hasta que Ventana 1 hace COMMIT (~8 s).

**Mitigación:** Usar `SERIALIZABLE` solo cuando sea estrictamente necesario. Para la mayoría de operaciones de Gathel, `READ COMMITTED` + RCSI es suficiente.

---

## Integración con Flyway

Todos los scripts de esta fase se versionan como **V5**:

```
src/database/flyway/migrations/
├── V1__init_schema.sql
├── V2__stored_procedures.sql
├── V3__seeding.sql
├── V4__security_setup.sql
└── V5__concurrency_transactions.sql   ← Fase 4
```

El archivo `V5__concurrency_transactions.sql` en la carpeta de migraciones de Flyway concatena los 5 scripts en orden.

---

## Configuración recomendada para Gathel en producción

```sql
-- 1. Habilitar RCSI para reducir contención lector-escritor
ALTER DATABASE GathelDB SET READ_COMMITTED_SNAPSHOT ON;

-- 2. Nivel de aislamiento por defecto del pool de conexiones
-- (configurar en el ORM / connection string)
-- ApplicationIntent=ReadWrite; TransactionIsolation=ReadCommitted

-- 3. Monitorear deadlocks con Extended Events (ya activo en system_health)
-- Ver deadlock graphs periódicamente y ajustar índices / orden de acceso

-- 4. Para SPs críticos financieros (distribución de ganancias, pagos):
-- Usar SERIALIZABLE con lógica de retry en la aplicación ante error 1205
```
