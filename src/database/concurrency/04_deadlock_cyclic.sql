-- ==============================================================================
-- V5__concurrency_04_deadlock_cyclic.sql
-- Gathel Gaming Platform — Deadlock Cíclico T1 → T2 → T3 → T1
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- CONCEPTO CLAVE: Deadlock cíclico de 3 participantes
-- ------------------------------------------------------------------------------
-- Cada transacción tiene un lock sobre un recurso y espera el lock del siguiente:
--
--   T1 tiene lock en Recurso A → necesita lock en Recurso B
--   T2 tiene lock en Recurso B → necesita lock en Recurso C
--   T3 tiene lock en Recurso C → necesita lock en Recurso A
--
-- En Gathel:
--   Recurso A = Player X (jugador apostador)
--   Recurso B = Player Y (jugador proposición)
--   Recurso C = Proposition Z
--
-- Los tres SPs adquieren sus locks en el mismo orden relativo a sus recursos,
-- pero entre sí forman un ciclo.
-- ==============================================================================

GO
-- ==============================================================================
-- T1: Debita puntos del Jugador A y luego necesita acceder al Jugador B
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Cyclic_T1
    @player_a_id    INT,
    @player_b_id    INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Lock A
        UPDATE dbo.Player SET updated_at = GETUTCDATE() WHERE player_id = @player_a_id;
        PRINT 'T1: Lock sobre Player A (' + CAST(@player_a_id AS NVARCHAR) + ')';

        WAITFOR DELAY '00:00:05';

        -- Necesita Lock B (que T2 tiene)
        UPDATE dbo.Player SET updated_at = GETUTCDATE() WHERE player_id = @player_b_id;
        PRINT 'T1: Lock sobre Player B (' + CAST(@player_b_id AS NVARCHAR) + ')';

        COMMIT TRANSACTION;
        PRINT 'T1: Commit.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205 PRINT 'T1 es VÍCTIMA del deadlock cíclico.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- T2: Debita puntos del Jugador B y luego necesita actualizar la Proposición Z
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Cyclic_T2
    @player_b_id    INT,
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Lock B
        UPDATE dbo.Player SET updated_at = GETUTCDATE() WHERE player_id = @player_b_id;
        PRINT 'T2: Lock sobre Player B (' + CAST(@player_b_id AS NVARCHAR) + ')';

        WAITFOR DELAY '00:00:05';

        -- Necesita Lock C = Proposition (que T3 tiene)
        UPDATE dbo.Proposition
        SET updated_at = GETUTCDATE()
        WHERE proposition_id = @proposition_id;
        PRINT 'T2: Lock sobre Proposition (' + CAST(@proposition_id AS NVARCHAR) + ')';

        COMMIT TRANSACTION;
        PRINT 'T2: Commit.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205 PRINT 'T2 es VÍCTIMA del deadlock cíclico.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- T3: Actualiza la Proposición Z y luego necesita al Jugador A
-- ← CIERRA EL CICLO (T3 necesita lo que tiene T1)
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DL_Cyclic_T3
    @proposition_id INT,
    @player_a_id    INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Lock C = Proposition
        UPDATE dbo.Proposition
        SET updated_at = GETUTCDATE()
        WHERE proposition_id = @proposition_id;
        PRINT 'T3: Lock sobre Proposition (' + CAST(@proposition_id AS NVARCHAR) + ')';

        WAITFOR DELAY '00:00:05';

        -- Necesita Lock A = Player A (que T1 tiene) → CICLO CERRADO
        UPDATE dbo.Player SET updated_at = GETUTCDATE() WHERE player_id = @player_a_id;
        PRINT 'T3: Lock sobre Player A (' + CAST(@player_a_id AS NVARCHAR) + ')';

        COMMIT TRANSACTION;
        PRINT 'T3: Commit.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205 PRINT 'T3 es VÍCTIMA del deadlock cíclico.';
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- INSTRUCCIONES DE DEMOSTRACIÓN EN SSMS
-- Abrir TRES ventanas de query. Ajustar IDs según el seeding.
-- Ejecutar T1, T2 y T3 dentro de un intervalo de 2 segundos entre sí.
-- ==============================================================================

-- Obtener IDs de prueba:
/*
SELECT TOP 3 player_id FROM dbo.Player ORDER BY player_id;
SELECT TOP 1 proposition_id FROM dbo.Proposition
    INNER JOIN dbo.PropositionStatus ps ON ps.status_id = dbo.Proposition.status_id
    WHERE ps.status_code = 'ACTIVE';
*/

-- ─── Query Window 1 — T1 ─────────────────────────────────────────────────────
/*
DECLARE @pA INT = 1;
DECLARE @pB INT = 2;
BEGIN TRY
    EXEC dbo.usp_DL_Cyclic_T1 @player_a_id = @pA, @player_b_id = @pB;
END TRY
BEGIN CATCH
    SELECT 'T1' AS session_name, ERROR_NUMBER() AS err_num, ERROR_MESSAGE() AS msg;
END CATCH;
*/

-- ─── Query Window 2 — T2 ─────────────────────────────────────────────────────
/*
DECLARE @pB INT = 2;
DECLARE @pr INT = 1;
BEGIN TRY
    EXEC dbo.usp_DL_Cyclic_T2 @player_b_id = @pB, @proposition_id = @pr;
END TRY
BEGIN CATCH
    SELECT 'T2' AS session_name, ERROR_NUMBER() AS err_num, ERROR_MESSAGE() AS msg;
END CATCH;
*/

-- ─── Query Window 3 — T3 ─────────────────────────────────────────────────────
/*
DECLARE @pr INT = 1;
DECLARE @pA INT = 1;
BEGIN TRY
    EXEC dbo.usp_DL_Cyclic_T3 @proposition_id = @pr, @player_a_id = @pA;
END TRY
BEGIN CATCH
    SELECT 'T3' AS session_name, ERROR_NUMBER() AS err_num, ERROR_MESSAGE() AS msg;
END CATCH;
*/

-- ==============================================================================
-- GRAFO DEL CICLO:
--
--   T1 ──(espera B)──▶ T2 ──(espera C)──▶ T3 ──(espera A)──▶ T1
--   ^                                                          │
--   └──────────────────────────────────────────────────────────┘
--
-- SQL Server elige como víctima al proceso con menor coste de rollback.
-- Los otros dos se desbloquean y completan.
-- ==============================================================================

-- ==============================================================================
-- VERIFICACIÓN: Consultar el deadlock graph del Extended Events
-- ==============================================================================
/*
SELECT TOP 5
    xdr.value('@timestamp', 'datetime2')                        AS deadlock_time,
    xdr.value('(//victim-list/victimProcess/@id)[1]', 'varchar(50)') AS victim_process,
    xdr.query('(//process-list/process)[1]')                    AS process_1,
    xdr.query('(//process-list/process)[2]')                    AS process_2,
    xdr.query('(//process-list/process)[3]')                    AS process_3
FROM (
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets t
    INNER JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
    WHERE s.name = 'system_health'
      AND t.target_name = 'ring_buffer'
) AS data
CROSS APPLY target_data.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(xdr)
ORDER BY deadlock_time DESC;
*/
GO
