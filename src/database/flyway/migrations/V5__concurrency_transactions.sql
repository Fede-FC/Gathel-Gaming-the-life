-- ==============================================================================
-- V5__concurrency_transactions.sql
-- Gathel Gaming Platform — Fase 4: Transacciones y Concurrencia
-- Flyway migration — SQL Server 2022
-- Incluye: transacciones anidadas, deadlocks (escritura, lectura/escritura,
--          cíclico) y demos de niveles de aislamiento.
-- ==============================================================================


-- ============================================================
-- Incluido desde: 01_nested_transactions.sql
-- ============================================================
-- ==============================================================================
-- V5__concurrency_01_nested_transactions.sql
-- Gathel Gaming Platform — Transacciones Anidadas (3 Niveles)
-- Demuestra flujo exitoso y fallo en el último SP de la cadena.
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- CONCEPTO CLAVE: SAVE TRANSACTION (Savepoints)
-- ------------------------------------------------------------------------------
-- SQL Server NO admite transacciones anidadas reales. Cuando se ejecuta un
-- BEGIN TRAN dentro de otro BEGIN TRAN, @@TRANCOUNT sube, pero solo el COMMIT
-- del nivel más externo hace el commit real. Un ROLLBACK en cualquier nivel
-- revierte TODO (no solo el nivel actual).
--
-- Para aislar el fallo de un SP interior sin revertir los niveles superiores,
-- se usa SAVE TRANSACTION <savepoint> + ROLLBACK TRANSACTION <savepoint>.
-- ==============================================================================

GO
-- ==============================================================================
-- SP Nivel 3 (más interno): Registrar comisión de plataforma
-- Puede fallar si la proposición no existe o el monto es negativo.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_Nested_L3_RegisterCommission
    @proposition_id      INT,
    @platform_commission DECIMAL(18,4),
    @currency_type_id    INT,
    @should_fail         BIT = 0      -- Parámetro de simulación de fallo
AS
BEGIN
    SET NOCOUNT ON;

    SAVE TRANSACTION SaveL3;   -- Savepoint para poder revertir solo este nivel

    BEGIN TRY
        -- Simular fallo controlado para demostración
        IF @should_fail = 1
            THROW 50300, '[L3] Fallo simulado en registro de comisión (nivel 3).', 1;

        IF @platform_commission < 0
            THROW 50301, '[L3] La comisión no puede ser negativa.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proposition WHERE proposition_id = @proposition_id)
            THROW 50302, '[L3] La proposición no existe.', 1;

        -- Registrar transacción de comisión hacia la plataforma (player_id = 0 → sistema)
        INSERT INTO dbo.[Transaction]
            (player_id, currency_type_id, amount, running_balance,
             transaction_type_id, reference_type, reference_id, description, created_at)
        SELECT
            p.target_player_id,         -- jugador que ejecutó la proposición
            @currency_type_id,
            -@platform_commission,       -- descuento
            p2.balance_points - @platform_commission,
            tt.transaction_type_id,
            'PROPOSITION',
            @proposition_id,
            'Comisión de plataforma — Proposición #' + CAST(@proposition_id AS NVARCHAR),
            GETUTCDATE()
        FROM dbo.Proposition p
        INNER JOIN dbo.Player p2        ON p2.player_id = p.target_player_id
        INNER JOIN dbo.TransactionType tt ON tt.type_code = 'COMMISSION'
        WHERE p.proposition_id = @proposition_id;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
        VALUES
            ('usp_Nested_L3_RegisterCommission',
             'Comisión registrada para proposición #' + CAST(@proposition_id AS NVARCHAR),
             '[Transaction]', @proposition_id, 'SUCCESS', GETUTCDATE(), SYSTEM_USER);

    END TRY
    BEGIN CATCH
        -- Revertir SOLO el trabajo de este nivel, no el de los niveles superiores
        ROLLBACK TRANSACTION SaveL3;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, status, error_detail, executed_at, executed_by)
        VALUES
            ('usp_Nested_L3_RegisterCommission', 'Error en nivel 3', '[Transaction]',
             'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);

        THROW;   -- Re-lanza para que el nivel 2 también maneje el error
    END CATCH
END;
GO

-- ==============================================================================
-- SP Nivel 2 (intermedio): Distribuir ganancias a predictores ganadores
-- Llama al SP L3 para la comisión de plataforma.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_Nested_L2_DistributeWinnings
    @proposition_id   INT,
    @total_pot_points BIGINT,
    @should_fail_l3   BIT = 0    -- Propaga parámetro de fallo al nivel 3
AS
BEGIN
    SET NOCOUNT ON;

    SAVE TRANSACTION SaveL2;

    BEGIN TRY
        DECLARE @platform_rate      DECIMAL(5,4) = 0.05;   -- 5%
        DECLARE @platform_comm      DECIMAL(18,4) = @total_pot_points * @platform_rate;
        DECLARE @distributable      DECIMAL(18,4) = @total_pot_points - @platform_comm;
        DECLARE @currency_type_id   INT;
        DECLARE @winner_total_stake BIGINT;

        SELECT @currency_type_id = currency_type_id
        FROM dbo.CurrencyType WHERE currency_code = 'POINTS';

        -- Total apostado por los ganadores (para calcular proporción)
        SELECT @winner_total_stake = ISNULL(SUM(pred.amount_points), 0)
        FROM dbo.Prediction pred
        INNER JOIN dbo.Proposition prop ON prop.proposition_id = pred.proposition_id
        WHERE pred.proposition_id = @proposition_id
          AND pred.is_correct = 1;

        IF @winner_total_stake = 0
            THROW 50200, '[L2] No hay predictores ganadores con apuesta en puntos.', 1;

        -- Insertar ganancia proporcional para cada predictor ganador
        INSERT INTO dbo.[Transaction]
            (player_id, currency_type_id, amount, running_balance,
             transaction_type_id, reference_type, reference_id, description, created_at)
        SELECT
            pred.player_id,
            @currency_type_id,
            CAST((@distributable * CAST(pred.amount_points AS DECIMAL(18,4))
                  / @winner_total_stake) AS BIGINT),
            pl.balance_points
                + CAST((@distributable * CAST(pred.amount_points AS DECIMAL(18,4))
                        / @winner_total_stake) AS BIGINT),
            tt.transaction_type_id,
            'PROPOSITION',
            @proposition_id,
            'Ganancia en proposición #' + CAST(@proposition_id AS NVARCHAR),
            GETUTCDATE()
        FROM dbo.Prediction pred
        INNER JOIN dbo.Player pl            ON pl.player_id     = pred.player_id
        INNER JOIN dbo.TransactionType tt   ON tt.type_code     = 'WINNING'
        WHERE pred.proposition_id = @proposition_id
          AND pred.is_correct     = 1;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
        VALUES
            ('usp_Nested_L2_DistributeWinnings',
             'Ganancias distribuidas para proposición #' + CAST(@proposition_id AS NVARCHAR),
             '[Transaction]', @proposition_id, 'SUCCESS', GETUTCDATE(), SYSTEM_USER);

        -- ── Llamada al nivel 3 ──────────────────────────────────────────────
        EXEC dbo.usp_Nested_L3_RegisterCommission
            @proposition_id      = @proposition_id,
            @platform_commission = @platform_comm,
            @currency_type_id    = @currency_type_id,
            @should_fail         = @should_fail_l3;
        -- ────────────────────────────────────────────────────────────────────

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION SaveL2;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, status, error_detail, executed_at, executed_by)
        VALUES
            ('usp_Nested_L2_DistributeWinnings', 'Error en nivel 2', '[Transaction]',
             'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);

        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP Nivel 1 (más externo): Resolver proposición
-- Marca la proposición como resuelta y orquesta la distribución de premios
-- llamando al SP L2.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_Nested_L1_ResolveProposition
    @proposition_id INT,
    @is_fulfilled   BIT,
    @should_fail_l3 BIT = 0    -- Para demostración: indica si L3 debe fallar
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;    -- Necesario para que nuestros CATCH manejen el error

    DECLARE @total_pot_points   BIGINT;
    DECLARE @resolved_status_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;   -- Transacción principal (@@TRANCOUNT = 1)

        -- Validaciones
        IF NOT EXISTS (SELECT 1 FROM dbo.Proposition WHERE proposition_id = @proposition_id AND enabled = 1)
            THROW 50100, '[L1] La proposición no existe o está deshabilitada.', 1;

        SELECT @resolved_status_id = status_id
        FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED';

        -- Acumular el pozo total en puntos
        SELECT @total_pot_points = ISNULL(SUM(amount_points), 0)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;

        -- Actualizar estado de predicciones (correcto / incorrecto)
        UPDATE dbo.Prediction
        SET is_correct = CASE
                            WHEN predicted_outcome = @is_fulfilled THEN 1
                            ELSE 0
                         END
        WHERE proposition_id = @proposition_id;

        -- Marcar proposición como resuelta
        UPDATE dbo.Proposition
        SET status_id    = @resolved_status_id,
            is_fulfilled = @is_fulfilled,
            resolved_at  = GETUTCDATE(),
            updated_at   = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
        VALUES
            ('usp_Nested_L1_ResolveProposition',
             'Proposición #' + CAST(@proposition_id AS NVARCHAR) + ' resuelta. Cumplida: ' + CAST(@is_fulfilled AS NVARCHAR),
             'Proposition', @proposition_id, 'SUCCESS', GETUTCDATE(), SYSTEM_USER);

        -- ── Llamada al nivel 2 ──────────────────────────────────────────────
        EXEC dbo.usp_Nested_L2_DistributeWinnings
            @proposition_id   = @proposition_id,
            @total_pot_points = @total_pot_points,
            @should_fail_l3   = @should_fail_l3;
        -- ────────────────────────────────────────────────────────────────────

        COMMIT TRANSACTION;
        PRINT '[L1] Transacción completada con éxito. Proposición #' + CAST(@proposition_id AS NVARCHAR);

    END TRY
    BEGIN CATCH
        -- Si L3 revirtió su savepoint y re-lanzó, llegamos aquí.
        -- @@TRANCOUNT puede ser > 0 (la transacción del nivel 1 sigue abierta).
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        INSERT INTO dbo.ProcessLog
            (sp_name, action_description, affected_table, status, error_detail, executed_at, executed_by)
        VALUES
            ('usp_Nested_L1_ResolveProposition',
             'Error en nivel 1 — toda la cadena revertida', 'Proposition',
             'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);

        -- Emitir el error al cliente
        DECLARE @err_msg  NVARCHAR(2048) = ERROR_MESSAGE();
        DECLARE @err_sev  INT            = ERROR_SEVERITY();
        DECLARE @err_stat INT            = ERROR_STATE();
        RAISERROR(@err_msg, @err_sev, @err_stat);
    END CATCH
END;
GO

-- ==============================================================================
-- DEMOSTRACIÓN 1: FLUJO EXITOSO
-- Prerequisito: debe existir una proposición activa con predicciones en puntos.
-- En un ambiente con datos de seeding esto funcionará directamente.
-- ==============================================================================
PRINT '======================================================';
PRINT 'DEMO 1 — Flujo exitoso (3 niveles sin fallo)';
PRINT '======================================================';

-- Usar una proposición del seeding que tenga predicciones
DECLARE @prop_id_ok INT;
SELECT TOP 1 @prop_id_ok = p.proposition_id
FROM dbo.Proposition p
INNER JOIN dbo.Prediction pred ON pred.proposition_id = p.proposition_id
INNER JOIN dbo.PropositionStatus ps ON ps.status_id = p.status_id
WHERE ps.status_code IN ('ACTIVE', 'PREDICTION_CLOSED')
ORDER BY NEWID();

IF @prop_id_ok IS NULL
BEGIN
    PRINT 'No hay proposiciones activas con predicciones. Saltando demo 1.';
END
ELSE
BEGIN
    EXEC dbo.usp_Nested_L1_ResolveProposition
        @proposition_id = @prop_id_ok,
        @is_fulfilled   = 1,
        @should_fail_l3 = 0;    -- Sin fallo

    -- Evidencia del resultado
    SELECT 'DEMO 1 - ProcessLog' AS demo,
           sp_name, action_description, status, error_detail, executed_at
    FROM dbo.ProcessLog
    WHERE affected_record_id = @prop_id_ok
      AND sp_name LIKE 'usp_Nested%'
    ORDER BY executed_at DESC;
END
GO

-- ==============================================================================
-- DEMOSTRACIÓN 2: FALLO EN EL NIVEL 3
-- El nivel 1 y nivel 2 ejecutan su trabajo; L3 falla → TODO se revierte.
-- Los savepoints de L3 y L2 contienen el daño, pero al re-lanzar el error
-- la transacción principal en L1 hace el ROLLBACK final.
-- ==============================================================================
PRINT '======================================================';
PRINT 'DEMO 2 — Fallo en nivel 3 (L1 y L2 revertidos también)';
PRINT '======================================================';

DECLARE @prop_id_fail INT;
SELECT TOP 1 @prop_id_fail = p.proposition_id
FROM dbo.Proposition p
INNER JOIN dbo.Prediction pred ON pred.proposition_id = p.proposition_id
INNER JOIN dbo.PropositionStatus ps ON ps.status_id = p.status_id
WHERE ps.status_code IN ('ACTIVE', 'PREDICTION_CLOSED')
  AND p.proposition_id <> (
      SELECT TOP 1 proposition_id
      FROM dbo.Proposition
      INNER JOIN dbo.PropositionStatus ps2 ON ps2.status_id = dbo.Proposition.status_id
      WHERE ps2.status_code = 'RESOLVED'
      ORDER BY resolved_at DESC
  )
ORDER BY NEWID();

IF @prop_id_fail IS NULL
BEGIN
    PRINT 'No hay proposiciones activas adicionales. Saltando demo 2.';
END
ELSE
BEGIN
    -- Verificar estado ANTES de la llamada
    SELECT 'ANTES — Proposición' AS momento,
           proposition_id, status_id, is_fulfilled, resolved_at
    FROM dbo.Proposition WHERE proposition_id = @prop_id_fail;

    BEGIN TRY
        EXEC dbo.usp_Nested_L1_ResolveProposition
            @proposition_id = @prop_id_fail,
            @is_fulfilled   = 1,
            @should_fail_l3 = 1;   -- ← Forzar fallo en L3
    END TRY
    BEGIN CATCH
        PRINT 'Error capturado en cliente: ' + ERROR_MESSAGE();
    END CATCH;

    -- Verificar estado DESPUÉS — la proposición NO debe haberse marcado como resuelta
    SELECT 'DESPUÉS (debe ser igual al ANTES)' AS momento,
           proposition_id, status_id, is_fulfilled, resolved_at
    FROM dbo.Proposition WHERE proposition_id = @prop_id_fail;

    -- Ver el log de errores
    SELECT 'DEMO 2 - ProcessLog' AS demo,
           sp_name, action_description, status, error_detail, executed_at
    FROM dbo.ProcessLog
    WHERE sp_name LIKE 'usp_Nested%'
    ORDER BY executed_at DESC
    OFFSET 0 ROWS FETCH NEXT 6 ROWS ONLY;
END
GO

-- ============================================================
-- Incluido desde: 02_deadlock_writes.sql
-- ============================================================
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

-- ============================================================
-- Incluido desde: 03_deadlock_read_write.sql
-- ============================================================
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

-- ============================================================
-- Incluido desde: 04_deadlock_cyclic.sql
-- ============================================================
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

-- ============================================================
-- Incluido desde: 05_isolation_levels.sql
-- ============================================================
-- ==============================================================================
-- V5__concurrency_05_isolation_levels.sql
-- Gathel Gaming Platform — Niveles de Aislamiento
-- Demuestra los 4 niveles y los problemas asociados a cada uno.
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- TABLA DE REFERENCIA RÁPIDA
-- ╔══════════════════════╦═══════════╦══════════════╦════════════════╦═════════╗
-- ║ Nivel de aislamiento ║ Dirty Read║ Non-Rep. Read║ Phantom Read   ║ Bloq.   ║
-- ╠══════════════════════╬═══════════╬══════════════╬════════════════╬═════════╣
-- ║ READ UNCOMMITTED     ║    SÍ     ║    SÍ        ║    SÍ          ║ Mínimo  ║
-- ║ READ COMMITTED       ║    NO     ║    SÍ        ║    SÍ          ║ Bajo    ║
-- ║ REPEATABLE READ      ║    NO     ║    NO        ║    SÍ          ║ Medio   ║
-- ║ SERIALIZABLE         ║    NO     ║    NO        ║    NO          ║ Máximo  ║
-- ╚══════════════════════╩═══════════╩══════════════╩════════════════╩═════════╝
-- ==============================================================================

GO
-- ==============================================================================
-- HELPERS: SPs de apoyo para las demos
-- ==============================================================================

-- Consultar el balance de un jugador (usado en múltiples demos)
CREATE OR ALTER PROCEDURE dbo.usp_IL_GetBalance
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT player_id, username, balance_points, updated_at
    FROM dbo.Player
    WHERE player_id = @player_id;
END;
GO

-- Modificar el balance de un jugador (usado por el SP "escritor" en las demos)
CREATE OR ALTER PROCEDURE dbo.usp_IL_UpdateBalance
    @player_id   INT,
    @new_balance BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Player
    SET balance_points = @new_balance,
        updated_at     = GETUTCDATE()
    WHERE player_id = @player_id;
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 1: READ UNCOMMITTED                                               ║
-- ║ Problema: DIRTY READ                                                    ║
-- ║ Un lector puede ver datos que aún NO han sido confirmados (committed).  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

-- ESCRITOR: Inicia transacción, modifica balance, no hace commit todavía.
CREATE OR ALTER PROCEDURE dbo.usp_IL_DirtyWrite_Writer
    @player_id   INT,
    @new_balance BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    UPDATE dbo.Player
    SET balance_points = @new_balance,
        updated_at     = GETUTCDATE()
    WHERE player_id = @player_id;
    PRINT 'Escritor: balance actualizado a ' + CAST(@new_balance AS NVARCHAR) + ' (SIN commit aún)';
    -- Simular trabajo largo → el lector leerá el valor no confirmado
    WAITFOR DELAY '00:00:08';
    -- Después de que el lector lo haya leído, revertimos
    ROLLBACK TRANSACTION;
    PRINT 'Escritor: ROLLBACK ejecutado. El valor en BD volvió al original.';
END;
GO

-- LECTOR con READ UNCOMMITTED: puede leer el valor no confirmado
CREATE OR ALTER PROCEDURE dbo.usp_IL_DirtyRead_Reader
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    -- EQUIVALENTE: SELECT ... FROM Player WITH (NOLOCK)
    SELECT 'READ UNCOMMITTED (DIRTY READ)' AS nivel,
           player_id, username, balance_points AS balance_leido,
           'Puede ser un valor NO confirmado!' AS advertencia,
           GETUTCDATE() AS leido_en
    FROM dbo.Player
    WHERE player_id = @player_id;
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 2: READ COMMITTED (nivel por defecto en SQL Server)              ║
-- ║ Previene: Dirty Reads                                                   ║
-- ║ Problema: NON-REPEATABLE READ                                           ║
-- ║ Una segunda lectura dentro de la misma transacción puede devolver       ║
-- ║ un resultado diferente si otro commit ocurrió entre las dos lecturas.   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_NonRepeatableRead
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Primera lectura
        DECLARE @balance1 BIGINT;
        SELECT @balance1 = balance_points FROM dbo.Player WHERE player_id = @player_id;
        PRINT 'READ COMMITTED — Primera lectura: ' + CAST(@balance1 AS NVARCHAR);

        -- Pausa para que otro proceso pueda modificar el registro entre lecturas
        WAITFOR DELAY '00:00:06';

        -- Segunda lectura (dentro de la misma transacción)
        DECLARE @balance2 BIGINT;
        SELECT @balance2 = balance_points FROM dbo.Player WHERE player_id = @player_id;
        PRINT 'READ COMMITTED — Segunda lectura: ' + CAST(@balance2 AS NVARCHAR);

        IF @balance1 <> @balance2
            PRINT 'NON-REPEATABLE READ detectado: los valores son diferentes!';
        ELSE
            PRINT 'Los valores son iguales (no hubo modificación concurrente).';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 3: REPEATABLE READ                                                ║
-- ║ Previene: Dirty Reads + Non-Repeatable Reads                           ║
-- ║ Problema: PHANTOM READ                                                  ║
-- ║ Una segunda consulta con el mismo WHERE puede retornar FILAS NUEVAS    ║
-- ║ que no estaban en la primera lectura (insertadas por otro proceso).     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_PhantomRead
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Primera lectura: contar predicciones activas de la proposición
        DECLARE @count1 INT;
        SELECT @count1 = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;
        PRINT 'REPEATABLE READ — Primera lectura: ' + CAST(@count1 AS NVARCHAR) + ' predicciones';

        -- Pausa para que otro proceso inserte una predicción nueva
        WAITFOR DELAY '00:00:06';

        -- Segunda lectura (misma condición, puede haber nuevas filas)
        DECLARE @count2 INT;
        SELECT @count2 = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;
        PRINT 'REPEATABLE READ — Segunda lectura: ' + CAST(@count2 AS NVARCHAR) + ' predicciones';

        IF @count2 > @count1
            PRINT 'PHANTOM READ detectado: aparecieron ' + CAST(@count2 - @count1 AS NVARCHAR) + ' fila(s) nueva(s)!';
        ELSE
            PRINT 'No hubo phantom read en esta ejecución.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 4: SERIALIZABLE                                                   ║
-- ║ Previene: Dirty Reads + Non-Repeatable Reads + Phantom Reads           ║
-- ║ Problema: ALTA CONTENCIÓN (bloqueo de rangos con key-range locks)      ║
-- ║ Las inserciones concurrentes dentro del rango WHERE son BLOQUEADAS.     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_Serializable_Reader
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- SQL Server pone un key-range lock sobre todas las filas del WHERE
        -- y sobre el "gap" vacío, impidiendo que otro proceso inserte
        -- predicciones nuevas dentro de este rango hasta que hagamos COMMIT.
        DECLARE @count INT;
        SELECT @count = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;

        PRINT 'SERIALIZABLE — Predicciones leídas: ' + CAST(@count AS NVARCHAR);
        PRINT 'Ningún INSERT nuevo puede completarse para esta proposición mientras esta TX esté abierta.';

        -- Pausa larga para demostrar el bloqueo del escritor concurrente
        WAITFOR DELAY '00:00:08';

        -- Segunda lectura: garantizado el mismo resultado (no hay phantoms)
        SELECT @count = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;

        PRINT 'SERIALIZABLE — Segunda lectura: ' + CAST(@count AS NVARCHAR) + ' (debe ser igual a la primera)';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP escritor que intenta insertar una predicción (quedará bloqueado con SERIALIZABLE)
CREATE OR ALTER PROCEDURE dbo.usp_IL_Serializable_Writer
    @player_id      INT,
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @predicted_outcome BIT = 1;

        -- Este INSERT quedará BLOQUEADO mientras usp_IL_Serializable_Reader
        -- tenga abierta su transacción SERIALIZABLE con key-range locks.
        INSERT INTO dbo.Prediction
            (player_id, proposition_id, predicted_outcome, amount_points, created_at, updated_at)
        VALUES
            (@player_id, @proposition_id, @predicted_outcome, 1, GETUTCDATE(), GETUTCDATE());

        COMMIT TRANSACTION;
        PRINT 'Escritor: INSERT completado (el lector ya hizo COMMIT).';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Escritor: error al insertar — ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- RESUMEN DE DEMOS Y CÓMO EJECUTARLAS
-- ==============================================================================
/*
── DEMO 1: DIRTY READ (READ UNCOMMITTED) ──────────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_DirtyWrite_Writer @player_id = 1, @new_balance = 999999;
  Ventana 2: EXEC dbo.usp_IL_DirtyRead_Reader  @player_id = 1;
  Resultado: La ventana 2 ve 999999. La ventana 1 hace ROLLBACK → ese valor nunca existió.

── DEMO 2: NON-REPEATABLE READ (READ COMMITTED) ──────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_NonRepeatableRead @player_id = 1;
  Ventana 2 (durante los 6 s de espera):
             EXEC dbo.usp_IL_UpdateBalance @player_id = 1, @new_balance = 50;
             COMMIT;
  Resultado: Ventana 1 imprime dos valores distintos.

── DEMO 3: PHANTOM READ (REPEATABLE READ) ─────────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_PhantomRead @proposition_id = 1;
  Ventana 2 (durante los 6 s de espera):
             INSERT INTO dbo.Prediction (player_id, proposition_id, predicted_outcome,
                         amount_points, created_at, updated_at)
             VALUES (3, 1, 0, 1, GETUTCDATE(), GETUTCDATE());
             COMMIT;
  Resultado: La segunda lectura de ventana 1 muestra una fila más.

── DEMO 4: SERIALIZABLE BLOQUEA AL ESCRITOR ──────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_Serializable_Reader @proposition_id = 1;
  Ventana 2 (inmediatamente):
             EXEC dbo.usp_IL_Serializable_Writer @player_id = 3, @proposition_id = 1;
  Resultado: Ventana 2 ESPERA hasta que ventana 1 haga COMMIT (8 s).
             No hay phantom, pero hay alta contención.

── MITIGACIÓN PARA READ COMMITTED → READ_COMMITTED_SNAPSHOT ──────────────────
  Con RCSI, los lectores ven la última versión COMMITTED de la fila (row version)
  sin adquirir S-locks. Elimina dirty reads, reduce non-repeatable reads en la
  mayoría de casos y evita que lectores bloqueen escritores y viceversa.

  ALTER DATABASE GathelDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
*/
GO
