-- ==============================================================================
-- V5__concurrency_03_deadlock_read_write.sql
-- Gathel Gaming Platform — Deadlock entre Lectura y Escritura
-- Demuestra que un SELECT también puede participar en un deadlock.
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- CONCEPTO CLAVE: ¿Cómo puede un SELECT causar un deadlock?
-- ------------------------------------------------------------------------------
-- Por defecto, un SELECT toma locks compartidos (S). Un UPDATE toma locks
-- exclusivos (X). Puede ocurrir un deadlock cuando:
--
-- T1 (lector):   S-lock en tabla Player → necesita S-lock en tabla Prediction
-- T2 (escritor): X-lock en tabla Prediction → necesita X-lock en tabla Player
--
-- T2 no puede actualizar Player (T1 tiene S-lock).
-- T1 no puede leer Prediction (T2 tiene X-lock pending → conversión a X
-- bloquea nuevos S-locks).
-- → Ciclo → Deadlock.
--
-- Esto ocurre incluso con READ COMMITTED (el nivel por defecto de SQL Server).
-- La solución es usar READ_COMMITTED_SNAPSHOT o acceder a los recursos
-- siempre en el mismo orden.
-- ==============================================================================

GO
-- ==============================================================================
-- SP LECTOR (T1): Calcula el resumen de balance de un jugador + sus predicciones
-- Accede en orden: Player → Prediction
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Read_PlayerSummary
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @balance BIGINT;
        DECLARE @total_predictions INT;

        -- Lock S sobre Player
        SELECT @balance = balance_points
        FROM dbo.Player WITH (HOLDLOCK)   -- HOLDLOCK mantiene el S-lock hasta fin de transacción
        WHERE player_id = @player_id;

        PRINT 'Lector (T1): S-lock sobre Player ' + CAST(@player_id AS NVARCHAR) + ' adquirido.';

        WAITFOR DELAY '00:00:04';   -- Simular procesamiento lento

        -- Intentar S-lock sobre Prediction (puede estar bloqueado por T2)
        SELECT @total_predictions = COUNT(*)
        FROM dbo.Prediction WITH (HOLDLOCK)
        WHERE player_id = @player_id;

        COMMIT TRANSACTION;

        SELECT 'Resumen jugador' AS resultado,
               @player_id       AS player_id,
               @balance         AS balance_points,
               @total_predictions AS total_predictions;

        PRINT 'Lector (T1): Commit exitoso.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
            PRINT 'T1 (Lector) fue elegida como VÍCTIMA del deadlock.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP ESCRITOR (T2): Procesa una predicción y actualiza balance del jugador
-- Accede en orden inverso: Prediction → Player
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Write_PredictionProcess
    @player_id      INT,
    @prediction_id  INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- X-lock sobre Prediction
        UPDATE dbo.Prediction
        SET updated_at = GETUTCDATE()
        WHERE prediction_id = @prediction_id
          AND player_id     = @player_id;

        PRINT 'Escritor (T2): X-lock sobre Prediction ' + CAST(@prediction_id AS NVARCHAR) + ' adquirido.';

        WAITFOR DELAY '00:00:04';   -- Simular procesamiento lento

        -- Intentar X-lock sobre Player (bloqueado si T1 tiene S-lock)
        UPDATE dbo.Player
        SET updated_at = GETUTCDATE()
        WHERE player_id = @player_id;

        COMMIT TRANSACTION;
        PRINT 'Escritor (T2): Commit exitoso.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
            PRINT 'T2 (Escritor) fue elegida como VÍCTIMA del deadlock.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- INSTRUCCIONES DE DEMOSTRACIÓN EN SSMS
-- ==============================================================================
-- 1. Obtener IDs válidos del seeding:
--    SELECT TOP 1 player_id FROM dbo.Player;
--    SELECT TOP 1 prediction_id, player_id FROM dbo.Prediction;
--
-- 2. SESIÓN T1 — ejecutar en Query Window 1:
/*
DECLARE @pid INT = 1;   -- player_id
BEGIN TRY
    EXEC dbo.usp_DL_Read_PlayerSummary @player_id = @pid;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS err, ERROR_MESSAGE() AS msg;
END CATCH;
*/

-- 3. SESIÓN T2 — ejecutar en Query Window 2 (inmediatamente después):
/*
DECLARE @pid  INT = 1;   -- mismo player_id
DECLARE @pred INT = 1;   -- prediction_id del jugador
BEGIN TRY
    EXEC dbo.usp_DL_Write_PredictionProcess @player_id = @pid, @prediction_id = @pred;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS err, ERROR_MESSAGE() AS msg;
END CATCH;
*/

-- ==============================================================================
-- MITIGACIÓN: Usar READ_COMMITTED_SNAPSHOT (RCSI)
-- Con RCSI activo, los lectores NO adquieren S-locks sobre las filas;
-- leen la versión anterior de la fila del version store, eliminando el
-- conflicto lector-escritor para deadlocks de este tipo.
-- ==============================================================================
/*
-- Habilitar RCSI (ejecutar como sysadmin, requiere que no haya conexiones activas):
ALTER DATABASE GathelDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;

-- Verificar:
SELECT name, is_read_committed_snapshot_on
FROM sys.databases WHERE name = DB_NAME();
*/

-- ==============================================================================
-- MITIGACIÓN ALTERNATIVA: Acceder siempre en el mismo orden
-- Si T1 y T2 acceden Player → Prediction (mismo orden), nunca hay ciclo.
-- ==============================================================================
GO
