-- ==============================================================================
-- V5__concurrency_02_deadlock_writes.sql
-- Gathel Gaming Platform — Deadlock con Escrituras Concurrentes
-- Dos SPs con operaciones de escritura que se bloquean mutuamente.
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- CONCEPTO CLAVE: ¿Cómo ocurre un deadlock de escritura?
-- ------------------------------------------------------------------------------
-- T1 actualiza Recurso A y espera Recurso B.
-- T2 actualiza Recurso B y espera Recurso A.
-- SQL Server detecta el ciclo (normalmente en ~5 segundos) y elige una víctima
-- (generalmente la transacción con menor coste de rollback) para terminar.
--
-- En Gathel: T1 = debitar puntos al jugador X y luego actualizar predicción Y.
--            T2 = debitar puntos al jugador Y y luego actualizar predicción X.
-- Sin locks explícitos. WAITFOR DELAY simula el tiempo de procesamiento para
-- que ambas transacciones queden trabadas al mismo tiempo.
-- ==============================================================================

GO
-- ==============================================================================
-- SP A: Registra predicción A → actualiza balance del jugador A → luego toca al jugador B
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Write_SessionA
    @player_a_id    INT,
    @player_b_id    INT,
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Sin SET XACT_ABORT ON para que el deadlock sea capturado por el CATCH del cliente

    BEGIN TRANSACTION;

    BEGIN TRY
        -- PASO 1: Tocar al jugador A (adquiere lock sobre fila de player_a)
        UPDATE dbo.Player
        SET balance_points = balance_points - 1,
            updated_at     = GETUTCDATE()
        WHERE player_id = @player_a_id;

        PRINT 'SessionA: Lock sobre Player A (' + CAST(@player_a_id AS NVARCHAR) + ') adquirido.';

        -- Simular latencia de red / procesamiento para que SessionB también tome su lock
        WAITFOR DELAY '00:00:04';

        -- PASO 2: Intentar tocar al jugador B (bloqueado si SessionB ya tiene el lock)
        UPDATE dbo.Player
        SET balance_points = balance_points - 1,
            updated_at     = GETUTCDATE()
        WHERE player_id = @player_b_id;

        PRINT 'SessionA: Lock sobre Player B (' + CAST(@player_b_id AS NVARCHAR) + ') adquirido.';

        -- Insertar predicción
        INSERT INTO dbo.[Transaction]
            (player_id, currency_type_id, amount, running_balance,
             transaction_type_id, reference_type, reference_id, description, created_at)
        SELECT @player_a_id, ct.currency_type_id, -1,
               pl.balance_points,
               tt.transaction_type_id,
               'PROPOSITION', @proposition_id,
               'Predicción SessionA', GETUTCDATE()
        FROM dbo.CurrencyType ct
        CROSS JOIN dbo.Player pl
        CROSS JOIN dbo.TransactionType tt
        WHERE ct.currency_code = 'POINTS'
          AND pl.player_id = @player_a_id
          AND tt.type_code  = 'DEPOSIT';

        COMMIT TRANSACTION;
        PRINT 'SessionA: Commit exitoso.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(500) = 'SessionA CATCH — Error ' + CAST(ERROR_NUMBER() AS NVARCHAR)
                                    + ': ' + ERROR_MESSAGE();
        PRINT @msg;
        -- Error 1205 = deadlock victim
        IF ERROR_NUMBER() = 1205
            PRINT 'SessionA fue elegida como VÍCTIMA del deadlock.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP B: Hace lo inverso — toca al jugador B primero, luego al jugador A
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Write_SessionB
    @player_a_id    INT,
    @player_b_id    INT,
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- PASO 1: Tocar al jugador B primero (orden inverso al de SessionA)
        UPDATE dbo.Player
        SET balance_points = balance_points - 1,
            updated_at     = GETUTCDATE()
        WHERE player_id = @player_b_id;

        PRINT 'SessionB: Lock sobre Player B (' + CAST(@player_b_id AS NVARCHAR) + ') adquirido.';

        WAITFOR DELAY '00:00:04';

        -- PASO 2: Intentar tocar al jugador A (bloqueado por SessionA)
        UPDATE dbo.Player
        SET balance_points = balance_points - 1,
            updated_at     = GETUTCDATE()
        WHERE player_id = @player_a_id;

        PRINT 'SessionB: Lock sobre Player A (' + CAST(@player_a_id AS NVARCHAR) + ') adquirido.';

        INSERT INTO dbo.[Transaction]
            (player_id, currency_type_id, amount, running_balance,
             transaction_type_id, reference_type, reference_id, description, created_at)
        SELECT @player_b_id, ct.currency_type_id, -1,
               pl.balance_points,
               tt.transaction_type_id,
               'PROPOSITION', @proposition_id,
               'Predicción SessionB', GETUTCDATE()
        FROM dbo.CurrencyType ct
        CROSS JOIN dbo.Player pl
        CROSS JOIN dbo.TransactionType tt
        WHERE ct.currency_code = 'POINTS'
          AND pl.player_id = @player_b_id
          AND tt.type_code  = 'DEPOSIT';

        COMMIT TRANSACTION;
        PRINT 'SessionB: Commit exitoso.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(500) = 'SessionB CATCH — Error ' + CAST(ERROR_NUMBER() AS NVARCHAR)
                                    + ': ' + ERROR_MESSAGE();
        PRINT @msg;
        IF ERROR_NUMBER() = 1205
            PRINT 'SessionB fue elegida como VÍCTIMA del deadlock.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SCRIPT DE DEMOSTRACIÓN
-- ------------------------------------------------------------------------------
-- INSTRUCCIONES para reproducir el deadlock en SSMS:
--
--  1. Abrir dos ventanas de query (Query Window 1 y Query Window 2).
--  2. Ambas deben apuntar a la base de datos de Gathel.
--  3. En Query Window 1 ejecutar el bloque "SESIÓN A" de abajo.
--  4. Inmediatamente (< 2 seg) ejecutar en Query Window 2 el bloque "SESIÓN B".
--  5. SQL Server detectará el deadlock y terminará una de las dos sesiones
--     con error 1205 (Deadlock victim).
--
-- NOTA: Los IDs de jugadores y proposición deben existir en la BD.
--       Ajustar según el seeding.
-- ==============================================================================

-- ─── SESIÓN A — ejecutar en Query Window 1 ────────────────────────────────────
/*
DECLARE @pA INT = 1;   -- Ajustar a un player_id existente
DECLARE @pB INT = 2;   -- Ajustar a otro player_id existente
DECLARE @pr INT = 1;   -- Ajustar a un proposition_id existente

BEGIN TRY
    EXEC dbo.usp_DL_Write_SessionA @player_a_id = @pA, @player_b_id = @pB, @proposition_id = @pr;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_num, ERROR_MESSAGE() AS mensaje;
END CATCH;
*/

-- ─── SESIÓN B — ejecutar en Query Window 2 (inmediatamente después de A) ──────
/*
DECLARE @pA INT = 1;
DECLARE @pB INT = 2;
DECLARE @pr INT = 1;

BEGIN TRY
    EXEC dbo.usp_DL_Write_SessionB @player_a_id = @pA, @player_b_id = @pB, @proposition_id = @pr;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_num, ERROR_MESSAGE() AS mensaje;
END CATCH;
*/

-- ==============================================================================
-- MONITOREO: Ver deadlocks activos y víctimas recientes
-- Ejecutar en una tercera ventana mientras el deadlock está ocurriendo:
-- ==============================================================================
/*
-- Ver procesos que están bloqueando
SELECT
    blocking.session_id                     AS blocker_session,
    blocked.session_id                      AS blocked_session,
    blocked.wait_type,
    blocked.wait_time / 1000.0              AS wait_seconds,
    blocked_sql.text                        AS blocked_statement,
    blocking_sql.text                       AS blocking_statement
FROM sys.dm_exec_requests blocked
INNER JOIN sys.dm_exec_sessions blocking
    ON blocking.session_id = blocked.blocking_session_id
OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle)   AS blocked_sql
OUTER APPLY sys.dm_exec_sql_text(blocking.sql_handle)  AS blocking_sql
WHERE blocked.blocking_session_id <> 0;

-- Ver el graph de deadlocks capturado por el Extended Events default trace
SELECT
    xdr.value('@timestamp', 'datetime2')                AS deadlock_time,
    xdr.query('.')                                      AS deadlock_graph
FROM (
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets   t
    INNER JOIN sys.dm_xe_sessions    s ON s.address = t.event_session_address
    WHERE s.name = 'system_health'
      AND t.target_name = 'ring_buffer'
) AS data
CROSS APPLY target_data.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(xdr)
ORDER BY deadlock_time DESC;
*/
GO
