-- ==============================================================================
-- 05_concurrencia_demo.sql  |  Gathel — Transacciones y Concurrencia
-- Transacciones anidadas con savepoints, niveles de aislamiento.
-- NOTA: deadlocks requieren dos sesiones SSMS en paralelo (ver scripts en
--       src/database/concurrency/ para esos escenarios).
-- ==============================================================================

USE GathelDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: Transacciones anidadas (SP L1 → L2 → L3)
-- Flujo: resolver proposición → distribuir ganancias → registrar comisión
-- ══════════════════════════════════════════════════════════════════════════════

-- Ver una proposición en PREDICTION_CLOSED para resolver
SELECT TOP 5
    prop.proposition_id,
    prop.title,
    ps.status_code,
    COUNT(pred.prediction_id) AS predicciones
FROM Proposition prop
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
LEFT JOIN Prediction pred ON prop.proposition_id = pred.proposition_id
WHERE ps.status_code = 'PREDICTION_CLOSED'
GROUP BY prop.proposition_id, prop.title, ps.status_code
ORDER BY prop.proposition_id DESC;
GO

-- Ejecutar los 3 niveles de SP anidado (usa un proposition_id de arriba)
DECLARE @prop_id INT = 1;   -- <-- CAMBIAR por uno en PREDICTION_CLOSED

-- L1 llama a L2 que llama a L3 internamente
EXEC dbo.usp_Nested_L1_ResolveProposition
    @proposition_id = @prop_id,
    @is_fulfilled   = 1;
GO

-- Ver el log del proceso anidado
SELECT TOP 10 sp_name, action_description, status, executed_at
FROM ProcessLog
ORDER BY executed_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: Optimistic locking (ya implementado en todos los SPs)
-- El campo balance_version en Player evita condiciones de carrera.
-- ══════════════════════════════════════════════════════════════════════════════

-- Ver el campo balance_version de un jugador
SELECT player_id, username, balance_points, balance_version
FROM Player
WHERE player_id = 1;   -- <-- CAMBIAR
GO

-- Simular conflicto: actualizar con versión incorrecta (debe afectar 0 filas)
DECLARE @player_id     INT = 1;
DECLARE @version_vieja INT = 0;   -- versión incorrecta a propósito

UPDATE Player
SET balance_points  = balance_points - 10,
    balance_version = balance_version + 1,
    updated_at      = GETUTCDATE()
WHERE player_id = @player_id AND balance_version = @version_vieja;

PRINT 'Filas afectadas: ' + CAST(@@ROWCOUNT AS NVARCHAR) + '  (0 = conflicto detectado correctamente)';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: Niveles de aislamiento
-- Estos SPs muestran lectura sucia, no repetible, phantom read y serializable.
-- ══════════════════════════════════════════════════════════════════════════════

-- Ver nivel de aislamiento actual de la sesión
SELECT
    session_id,
    transaction_isolation_level,
    CASE transaction_isolation_level
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS nivel_nombre
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID;
GO

-- Demostrar READ UNCOMMITTED (puede leer datos no commiteados — dirty read)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN TRANSACTION;
    SELECT TOP 5 player_id, username, balance_points FROM Player;
ROLLBACK;
GO

-- Volver al nivel por defecto
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

-- Demostrar REPEATABLE READ (garantiza que releer la misma fila da el mismo resultado)
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    SELECT balance_points FROM Player WHERE player_id = 1;
    -- Si otra sesión intenta actualizar balance_points aquí, se bloqueará
    SELECT balance_points FROM Player WHERE player_id = 1;   -- mismo resultado garantizado
ROLLBACK;
GO

-- Volver al nivel por defecto
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

-- Demostrar SERIALIZABLE (nivel más estricto, evita phantom reads)
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    SELECT COUNT(*) AS jugadores_con_100pts FROM Player WHERE balance_points = 100;
    -- En otra sesión no se puede insertar un jugador con 100 pts mientras esto está abierto
    SELECT COUNT(*) AS jugadores_con_100pts FROM Player WHERE balance_points = 100;
ROLLBACK;
GO

-- Volver al nivel por defecto
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: Rollback y XACT_ABORT (demostrar que la BD queda consistente)
-- ══════════════════════════════════════════════════════════════════════════════

-- Antes
SELECT player_id, username, balance_points FROM Player WHERE player_id = 1;
GO

-- Transacción que falla a mitad: debe hacer ROLLBACK completo
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE Player SET balance_points = balance_points - 9999 WHERE player_id = 1;
        -- Forzar error
        RAISERROR('Error simulado para demostrar rollback', 16, 1);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Rollback ejecutado: ' + ERROR_MESSAGE();
END CATCH
GO

-- Después: balance_points debe ser el mismo que antes
SELECT player_id, username, balance_points FROM Player WHERE player_id = 1;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: Referencia — deadlocks (ejecutar en dos sesiones SSMS separadas)
-- ══════════════════════════════════════════════════════════════════════════════

/*
Para demostrar deadlock con escrituras (src/database/concurrency/02_deadlock_writes.sql):

  SESIÓN A: EXEC dbo.usp_DL_Write_SessionA
  SESIÓN B: EXEC dbo.usp_DL_Write_SessionB   (ejecutar inmediatamente después)

  SQL Server detecta el deadlock automáticamente en ~5 segundos y termina una sesión.
  El "deadlock victim" queda en el ErrorLog de SQL Server.

Para deadlock cíclico (T1 → T2 → T3 → T1):
  SESIÓN 1: EXEC dbo.usp_DL_Cyclic_T1
  SESIÓN 2: EXEC dbo.usp_DL_Cyclic_T2
  SESIÓN 3: EXEC dbo.usp_DL_Cyclic_T3

Ver sesiones bloqueadas en tiempo real:
*/
SELECT
    blocking.session_id AS bloqueador,
    blocked.session_id  AS bloqueado,
    blocked.wait_type,
    blocked.wait_time   AS espera_ms,
    SUBSTRING(sq.text, 1, 100) AS query_bloqueado
FROM sys.dm_exec_sessions blocked
JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.most_recent_sql_handle) sq
WHERE blocked.blocking_session_id > 0;
GO
