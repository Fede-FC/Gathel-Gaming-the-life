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
