-- ==============================================================================
-- V2__stored_procedures_gathel.sql
-- Gathel Gaming Platform — Stored Procedures Transaccionales del MVP
-- Basado en design.dbml v2.0 | Versionado con Flyway | SQL Server 2022
-- ==============================================================================

-- ==============================================================================
-- SP 1: usp_RegisterPlayer
-- Registra un nuevo jugador con 100 puntos de bienvenida y registra la transacción.
-- ==============================================================================
GO
CREATE OR ALTER PROCEDURE dbo.usp_RegisterPlayer
    @username       NVARCHAR(50),
    @email          NVARCHAR(150),
    @password_hash  NVARCHAR(256),
    @display_name   NVARCHAR(100) = NULL,
    @new_player_id  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @welcome_points   BIGINT = 100;
    DECLARE @points_type_id   INT;
    DECLARE @deposit_type_id  INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar unicidad
        IF EXISTS (SELECT 1 FROM dbo.Player WHERE username = @username)
            THROW 50001, 'El username ya está en uso.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Player WHERE email = @email)
            THROW 50002, 'El email ya está registrado.', 1;

        -- Obtener IDs de catálogos
        SELECT @points_type_id  = currency_type_id  FROM dbo.CurrencyType    WHERE currency_code = 'POINTS';
        SELECT @deposit_type_id = transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'DEPOSIT';

        -- Insertar jugador
        INSERT INTO dbo.Player (username, email, password_hash, display_name,
                                 balance_points, balance_version, enabled, created_at, updated_at)
        VALUES (@username, @email, @password_hash, @display_name,
                @welcome_points, 1, 1, GETUTCDATE(), GETUTCDATE());

        SET @new_player_id = SCOPE_IDENTITY();

        -- Registrar transacción de bienvenida en puntos
        INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                       transaction_type_id, reference_type, reference_id,
                                       description, created_at)
        VALUES (@new_player_id, @points_type_id, @welcome_points, @welcome_points,
                @deposit_type_id, 'PLAYER', @new_player_id,
                'Puntos de bienvenida', GETUTCDATE());

        -- Log de proceso
        INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
        VALUES ('usp_RegisterPlayer', 'Jugador registrado con puntos de bienvenida',
                'Player', @new_player_id, 'SUCCESS', GETUTCDATE(), SYSTEM_USER);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, status, error_detail, executed_at, executed_by)
        VALUES ('usp_RegisterPlayer', 'Error al registrar jugador', 'Player',
                'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 2: usp_CreateProposition
-- Crea una proposición. Valida que creador ≠ sujeto, que ambos existen y están
-- habilitados. Estado inicial: PENDING (pendiente de revisión AI).
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_CreateProposition
    @creator_player_id   INT,
    @target_player_id    INT,
    @title               NVARCHAR(150),
    @description         NVARCHAR(1000),
    @voting_ends_at      DATETIME2,
    @new_proposition_id  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @pending_status_id INT;
    DECLARE @event_type_id     INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validaciones
        IF @creator_player_id = @target_player_id
            THROW 50010, 'El creador y el sujeto no pueden ser el mismo jugador.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Player WHERE player_id = @creator_player_id AND enabled = 1)
            THROW 50011, 'El jugador creador no existe o no está habilitado.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Player WHERE player_id = @target_player_id AND enabled = 1)
            THROW 50012, 'El jugador sujeto no existe o no está habilitado.', 1;

        -- El sujeto debe tener al menos 15 pts para cubrir penalización potencial
        IF (SELECT balance_points FROM dbo.Player WHERE player_id = @target_player_id) < 15
            THROW 50013, 'El sujeto no tiene suficientes puntos para cubrir una penalización potencial.', 1;

        IF @voting_ends_at <= GETUTCDATE()
            THROW 50014, 'La fecha de cierre de votación debe ser futura.', 1;

        SELECT @pending_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'PENDING';
        SELECT @event_type_id     = event_type_id FROM dbo.EventType       WHERE type_code  = 'PROPOSITION_CREATED';

        -- Insertar proposición
        INSERT INTO dbo.Proposition (creator_player_id, target_player_id, title, description,
                                      status_id, ai_review_result, voting_ends_at,
                                      is_accepted_by_target, enabled, created_at, updated_at)
        VALUES (@creator_player_id, @target_player_id, @title, @description,
                @pending_status_id, 'PENDING', @voting_ends_at,
                0, 1, GETUTCDATE(), GETUTCDATE());

        SET @new_proposition_id = SCOPE_IDENTITY();

        -- Evento de creación
        INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
        VALUES (@new_proposition_id, @event_type_id, @creator_player_id,
                (SELECT @new_proposition_id AS proposition_id, @title AS title FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                GETUTCDATE());

        INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
        VALUES ('usp_CreateProposition', 'Proposición creada, enviada a revisión AI',
                'Proposition', @new_proposition_id, 'SUCCESS', GETUTCDATE(), SYSTEM_USER);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, status, error_detail, executed_at, executed_by)
        VALUES ('usp_CreateProposition', 'Error al crear proposición', 'Proposition',
                'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 3: usp_RecordAIReview
-- Registra el resultado de la revisión AI y actualiza el estado de la proposición.
-- Si es APPROVED → pasa a ACTIVE (votación abierta).
-- Si es REJECTED → pasa a REJECTED.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_RecordAIReview
    @proposition_id      INT,
    @ai_model_id         INT,
    @ai_provider_id      INT,
    @review_result       NVARCHAR(20),    -- APPROVED, REJECTED
    @confidence_score    DECIMAL(5,4)   = NULL,
    @rejection_categories NVARCHAR(500) = NULL,
    @request_payload     NVARCHAR(MAX)  = NULL,
    @response_payload    NVARCHAR(MAX)  = NULL,
    @review_details      NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @active_status_id   INT;
    DECLARE @rejected_status_id INT;
    DECLARE @pending_status_id  INT;
    DECLARE @current_status_id  INT;
    DECLARE @new_status_id      INT;
    DECLARE @event_type_id      INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @review_result NOT IN ('APPROVED','REJECTED')
            THROW 50020, 'review_result debe ser APPROVED o REJECTED.', 1;

        SELECT @pending_status_id  = status_id FROM dbo.PropositionStatus WHERE status_code = 'PENDING';
        SELECT @active_status_id   = status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE';
        SELECT @rejected_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'REJECTED';

        SELECT @current_status_id = status_id
        FROM dbo.Proposition WITH (UPDLOCK, ROWLOCK)
        WHERE proposition_id = @proposition_id AND enabled = 1;

        IF @current_status_id IS NULL
            THROW 50021, 'La proposición no existe o no está habilitada.', 1;

        IF @current_status_id <> @pending_status_id
            THROW 50022, 'Solo se puede revisar una proposición en estado PENDING.', 1;

        SET @new_status_id = CASE WHEN @review_result = 'APPROVED' THEN @active_status_id
                                  ELSE @rejected_status_id END;

        -- Registrar resultado en AIReviewLog
        INSERT INTO dbo.AIReviewLog (proposition_id, ai_model_id, ai_provider_id, review_result,
                                      confidence_score, rejection_categories,
                                      request_payload, response_payload, review_details, reviewed_at)
        VALUES (@proposition_id, @ai_model_id, @ai_provider_id, @review_result,
                @confidence_score, @rejection_categories,
                @request_payload, @response_payload, @review_details, GETUTCDATE());

        -- Actualizar proposición
        UPDATE dbo.Proposition
        SET status_id        = @new_status_id,
            ai_review_result = @review_result,
            ai_review_detail = @review_details,
            rejection_reason = CASE WHEN @review_result = 'REJECTED' THEN @rejection_categories ELSE NULL END,
            updated_at       = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        -- Evento
        SELECT @event_type_id = event_type_id FROM dbo.EventType
        WHERE type_code = CASE WHEN @review_result = 'APPROVED' THEN 'AI_APPROVED' ELSE 'AI_REJECTED' END;

        IF @event_type_id IS NOT NULL
        BEGIN
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            SELECT @proposition_id, @event_type_id, creator_player_id,
                   (SELECT @review_result AS result, @confidence_score AS score FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                   GETUTCDATE()
            FROM dbo.Proposition WHERE proposition_id = @proposition_id;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 4: usp_AcceptProposition
-- El jugador sujeto acepta la proposición ganadora.
-- Transición: ACTIVE → PREDICTION_CLOSED (predicciones abiertas una vez aceptada).
-- Fija prediction_ends_at.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_AcceptProposition
    @proposition_id      INT,
    @target_player_id    INT,
    @prediction_ends_at  DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @active_status_id INT;
    DECLARE @open_status_id   INT;
    DECLARE @current_status   INT;
    DECLARE @event_type_id    INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @active_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE';
        SELECT @open_status_id   = status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED'; -- reutilizamos PREDICTION_CLOSED como "predicciones abiertas hasta prediction_ends_at"

        -- Para este flujo, el estado con predicciones abiertas lo dejamos como ACTIVE
        -- El estado PREDICTION_CLOSED se usa cuando ya cerró el período.
        -- Por consistencia con el DBML, aceptar → sigue en ACTIVE pero con is_accepted_by_target=1
        -- y prediction_ends_at fijado.

        SELECT @current_status = status_id
        FROM dbo.Proposition WITH (UPDLOCK, ROWLOCK)
        WHERE proposition_id = @proposition_id AND enabled = 1;

        IF @current_status IS NULL
            THROW 50030, 'La proposición no existe.', 1;

        IF @current_status <> @active_status_id
            THROW 50031, 'Solo se puede aceptar una proposición en estado ACTIVE.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proposition WHERE proposition_id = @proposition_id AND target_player_id = @target_player_id)
            THROW 50032, 'Solo el jugador sujeto puede aceptar esta proposición.', 1;

        IF @prediction_ends_at <= GETUTCDATE()
            THROW 50033, 'La fecha de cierre de predicciones debe ser futura.', 1;

        UPDATE dbo.Proposition
        SET is_accepted_by_target = 1,
            prediction_ends_at    = @prediction_ends_at,
            updated_at            = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        -- Evento
        SELECT @event_type_id = event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_ACCEPTED';
        IF @event_type_id IS NOT NULL
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            VALUES (@proposition_id, @event_type_id, @target_player_id,
                    (SELECT @prediction_ends_at AS prediction_ends_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                    GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 5: usp_RejectProposition
-- El jugador sujeto rechaza la proposición. Pierde 1 punto. Pasa a REJECTED.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_RejectProposition
    @proposition_id  INT,
    @target_player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @active_status_id   INT;
    DECLARE @rejected_status_id INT;
    DECLARE @current_status     INT;
    DECLARE @points_type_id     INT;
    DECLARE @withdrawal_type_id INT;
    DECLARE @current_points     BIGINT;
    DECLARE @current_version    INT;
    DECLARE @rows_affected      INT;
    DECLARE @event_type_id      INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @active_status_id   = status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE';
        SELECT @rejected_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'REJECTED';
        SELECT @points_type_id     = currency_type_id   FROM dbo.CurrencyType    WHERE currency_code = 'POINTS';
        SELECT @withdrawal_type_id = transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'WITHDRAWAL';

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Proposition WITH (UPDLOCK, ROWLOCK)
            WHERE proposition_id = @proposition_id
              AND target_player_id = @target_player_id
              AND status_id = @active_status_id
              AND is_accepted_by_target = 0
              AND enabled = 1
        )
            THROW 50040, 'La proposición no existe, ya fue aceptada, o no está en estado ACTIVE.', 1;

        -- Leer puntos del sujeto con optimistic locking
        SELECT @current_points = balance_points, @current_version = balance_version
        FROM dbo.Player WITH (UPDLOCK, ROWLOCK)
        WHERE player_id = @target_player_id;

        IF @current_points < 1
            THROW 50041, 'El sujeto no tiene suficientes puntos para la penalización por rechazo.', 1;

        -- Descontar 1 punto con optimistic locking
        UPDATE dbo.Player
        SET balance_points  = balance_points - 1,
            balance_version = balance_version + 1,
            last_transaction_date = GETUTCDATE(),
            updated_at      = GETUTCDATE()
        WHERE player_id = @target_player_id AND balance_version = @current_version;

        SET @rows_affected = @@ROWCOUNT;
        IF @rows_affected = 0
            THROW 50042, 'Conflicto de concurrencia al actualizar puntos del sujeto. Reintente.', 1;

        -- Transacción
        INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                        transaction_type_id, reference_type, reference_id,
                                        description, created_at)
        VALUES (@target_player_id, @points_type_id, -1, @current_points - 1,
                @withdrawal_type_id, 'PROPOSITION', @proposition_id,
                'Penalización por rechazo de proposición', GETUTCDATE());

        -- Cambiar estado
        UPDATE dbo.Proposition
        SET status_id  = @rejected_status_id,
            updated_at = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        -- Evento
        SELECT @event_type_id = event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_REJECTED';
        IF @event_type_id IS NOT NULL
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            VALUES (@proposition_id, @event_type_id, @target_player_id,
                    N'{"reason":"Sujeto rechazó la proposición","-1_pts":true}', GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 6: usp_PlacePrediction
-- Registra una predicción sobre una proposición aceptada.
-- Valida saldo, límite de 1 pt para moneda virtual.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_PlacePrediction
    @proposition_id  INT,
    @player_id       INT,
    @amount          DECIMAL(18,4),
    @currency_code   NVARCHAR(30),  -- POINTS, USD, EUR, ...
    @direction       BIT,            -- 1 = se cumple; 0 = no se cumple
    @new_prediction_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @currency_type_id   INT;
    DECLARE @is_virtual         BIT;
    DECLARE @wager_type_id      INT;
    DECLARE @current_points     BIGINT;
    DECLARE @current_version    INT;
    DECLARE @rows_affected      INT;
    DECLARE @prop_ends_at       DATETIME2;
    DECLARE @prop_accepted      BIT;
    DECLARE @prop_status        INT;
    DECLARE @active_status_id   INT;
    DECLARE @running_balance     DECIMAL(18,4);
    DECLARE @event_type_id      INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @currency_type_id = currency_type_id, @is_virtual = is_virtual
        FROM dbo.CurrencyType WHERE currency_code = @currency_code;

        IF @currency_type_id IS NULL
            THROW 50050, 'Moneda inválida.', 1;

        SELECT @wager_type_id   = transaction_type_id FROM dbo.TransactionType WHERE type_code = 'WAGER';
        SELECT @active_status_id = status_id           FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE';

        IF @amount <= 0
            THROW 50051, 'El monto debe ser mayor a cero.', 1;

        -- Verificar proposición activa y aceptada
        SELECT @prop_ends_at = prediction_ends_at,
               @prop_accepted = is_accepted_by_target,
               @prop_status   = status_id
        FROM dbo.Proposition WITH (ROWLOCK)
        WHERE proposition_id = @proposition_id AND enabled = 1;

        IF @prop_status IS NULL
            THROW 50052, 'La proposición no existe.', 1;

        IF @prop_status <> @active_status_id OR @prop_accepted <> 1
            THROW 50053, 'La proposición no está activa o no ha sido aceptada por el sujeto.', 1;

        IF @prop_ends_at IS NULL OR GETUTCDATE() > @prop_ends_at
            THROW 50054, 'El período de predicciones ya cerró.', 1;

        -- Verificar que no exista predicción previa del mismo jugador/proposición/moneda
        IF EXISTS (SELECT 1 FROM dbo.Prediction
                   WHERE proposition_id = @proposition_id
                     AND player_id = @player_id
                     AND currency_type_id = @currency_type_id)
            THROW 50055, 'Ya realizaste una predicción en esta moneda para esta proposición.', 1;

        -- Validar saldo y límite de puntos
        IF @is_virtual = 1
        BEGIN
            IF @amount > 1
                THROW 50056, 'Las predicciones con POINTS tienen un máximo de 1 punto.', 1;

            SELECT @current_points = balance_points, @current_version = balance_version
            FROM dbo.Player WITH (UPDLOCK, ROWLOCK)
            WHERE player_id = @player_id;

            IF @current_points < 1
                THROW 50057, 'Saldo de puntos insuficiente.', 1;

            UPDATE dbo.Player
            SET balance_points  = balance_points - 1,
                balance_version = balance_version + 1,
                last_transaction_date = GETUTCDATE(),
                updated_at      = GETUTCDATE()
            WHERE player_id = @player_id AND balance_version = @current_version;

            SET @rows_affected = @@ROWCOUNT;
            IF @rows_affected = 0
                THROW 50058, 'Conflicto de concurrencia al descontar puntos. Reintente.', 1;

            SET @running_balance = CAST(@current_points - 1 AS DECIMAL(18,4));
        END
        ELSE
        BEGIN
            -- Para dinero real: verificar saldo en Transaction (último running_balance)
            SELECT TOP 1 @running_balance = running_balance
            FROM dbo.[Transaction]
            WHERE player_id = @player_id AND currency_type_id = @currency_type_id
            ORDER BY created_at DESC;

            SET @running_balance = ISNULL(@running_balance, 0);

            IF @running_balance < @amount
                THROW 50059, 'Saldo de dinero real insuficiente.', 1;

            SET @running_balance = @running_balance - @amount;
        END

        -- Insertar predicción
        INSERT INTO dbo.Prediction (proposition_id, player_id, amount, currency_type_id,
                                     direction, result, created_at, updated_at)
        VALUES (@proposition_id, @player_id, @amount, @currency_type_id,
                @direction, 'PENDING', GETUTCDATE(), GETUTCDATE());

        SET @new_prediction_id = SCOPE_IDENTITY();

        -- Registrar transacción
        INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                        transaction_type_id, reference_type, reference_id,
                                        description, created_at)
        VALUES (@player_id, @currency_type_id, -@amount, @running_balance,
                @wager_type_id, 'PREDICTION', @new_prediction_id,
                CONCAT('Apuesta en proposición #', @proposition_id), GETUTCDATE());

        -- Evento
        SELECT @event_type_id = event_type_id FROM dbo.EventType WHERE type_code = 'PREDICTION_MADE';
        IF @event_type_id IS NOT NULL
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            VALUES (@proposition_id, @event_type_id, @player_id,
                    (SELECT @new_prediction_id AS prediction_id, @amount AS amount,
                             @currency_code AS currency, @direction AS direction
                     FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                    GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 7: usp_ClosePropositionPredictions
-- Cierra el período de predicciones. Transición: ACTIVE → PREDICTION_CLOSED.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ClosePropositionPredictions
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @active_status_id INT;
    DECLARE @closed_status_id INT;
    DECLARE @current_status   INT;
    DECLARE @event_type_id    INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @active_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE';
        SELECT @closed_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED';

        SELECT @current_status = status_id
        FROM dbo.Proposition WITH (UPDLOCK, ROWLOCK)
        WHERE proposition_id = @proposition_id AND enabled = 1;

        IF @current_status IS NULL
            THROW 50060, 'La proposición no existe.', 1;

        IF @current_status <> @active_status_id
            THROW 50061, 'La proposición no está activa; no se puede cerrar.', 1;

        UPDATE dbo.Proposition
        SET status_id  = @closed_status_id,
            updated_at = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        SELECT @event_type_id = event_type_id FROM dbo.EventType WHERE type_code = 'PREDICTIONS_CLOSED';
        IF @event_type_id IS NOT NULL
        BEGIN
            DECLARE @creator_id INT;
            SELECT @creator_id = creator_player_id FROM dbo.Proposition WHERE proposition_id = @proposition_id;
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            VALUES (@proposition_id, @event_type_id, @creator_id,
                    N'{"reason":"Cierre automático de período de predicciones"}', GETUTCDATE());
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 8: usp_ResolveProposition
-- Valida el resultado y distribuye recompensas.
-- outcome: TRUE (se cumplió) | FALSE (no se cumplió) | NULL (unresolvable)
-- Si outcome IS NULL: reembolso total + penalización 15% al sujeto.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ResolveProposition
    @proposition_id  INT,
    @is_fulfilled    BIT,            -- 1 = se cumplió; 0 = no; NULL = unresolvable
    @resolved_by     INT = NULL      -- player_id del validador; NULL = sistema/AI
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @closed_status_id   INT;
    DECLARE @resolved_status_id INT;
    DECLARE @current_status     INT;
    DECLARE @target_player_id   INT;
    DECLARE @creator_player_id  INT;
    DECLARE @points_type_id     INT;
    DECLARE @winning_type_id    INT;
    DECLARE @refund_type_id     INT;
    DECLARE @commission_type_id INT;
    DECLARE @event_type_id      INT;

    -- Pozo
    DECLARE @total_pot_pts     DECIMAL(18,4) = 0;
    DECLARE @total_pot_money   DECIMAL(18,4) = 0;
    DECLARE @winner_pot_pts    DECIMAL(18,4) = 0;
    DECLARE @winner_pot_money  DECIMAL(18,4) = 0;
    DECLARE @net_pts           DECIMAL(18,4);
    DECLARE @net_money         DECIMAL(18,4);
    DECLARE @platform_pct      DECIMAL(5,2)  = 5.00;
    DECLARE @proposer_pct      DECIMAL(5,2)  = 2.00;
    DECLARE @winning_direction BIT;

    -- Cursor variables
    DECLARE @pred_id       BIGINT;
    DECLARE @pred_player   INT;
    DECLARE @pred_amount   DECIMAL(18,4);
    DECLARE @pred_currency INT;
    DECLARE @pred_is_virtual BIT;
    DECLARE @pred_direction BIT;
    DECLARE @earned        DECIMAL(18,4);
    DECLARE @running_bal   DECIMAL(18,4);
    DECLARE @current_pts   BIGINT;
    DECLARE @cur_version   INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @closed_status_id   = status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED';
        SELECT @resolved_status_id = status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED';
        SELECT @points_type_id     = currency_type_id   FROM dbo.CurrencyType    WHERE currency_code = 'POINTS';
        SELECT @winning_type_id    = transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'WINNING';
        SELECT @refund_type_id     = transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'REFUND';
        SELECT @commission_type_id = transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'COMMISSION';

        SELECT @current_status   = status_id,
               @target_player_id = target_player_id,
               @creator_player_id = creator_player_id
        FROM dbo.Proposition WITH (UPDLOCK, ROWLOCK)
        WHERE proposition_id = @proposition_id AND enabled = 1;

        IF @current_status IS NULL
            THROW 50070, 'La proposición no existe.', 1;

        IF @current_status <> @closed_status_id
            THROW 50071, 'La proposición no está en PREDICTION_CLOSED.', 1;

        -- ===================== CASO UNRESOLVABLE (NULL) =====================
        IF @is_fulfilled IS NULL
        BEGIN
            -- Reembolso total a todos los predictores
            DECLARE cur_refund CURSOR LOCAL FAST_FORWARD FOR
                SELECT p.prediction_id, p.player_id, p.amount, p.currency_type_id, ct.is_virtual
                FROM dbo.Prediction p
                JOIN dbo.CurrencyType ct ON p.currency_type_id = ct.currency_type_id
                WHERE p.proposition_id = @proposition_id AND p.result = 'PENDING';

            OPEN cur_refund;
            FETCH NEXT FROM cur_refund INTO @pred_id, @pred_player, @pred_amount, @pred_currency, @pred_is_virtual;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Reembolso puntos
                IF @pred_is_virtual = 1
                BEGIN
                    SELECT @current_pts = balance_points, @cur_version = balance_version
                    FROM dbo.Player WHERE player_id = @pred_player;

                    UPDATE dbo.Player
                    SET balance_points  = balance_points + CAST(@pred_amount AS BIGINT),
                        balance_version = balance_version + 1,
                        last_transaction_date = GETUTCDATE(),
                        updated_at      = GETUTCDATE()
                    WHERE player_id = @pred_player;

                    SET @running_bal = CAST(@current_pts + CAST(@pred_amount AS BIGINT) AS DECIMAL(18,4));
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @running_bal = running_balance
                    FROM dbo.[Transaction]
                    WHERE player_id = @pred_player AND currency_type_id = @pred_currency
                    ORDER BY created_at DESC;
                    SET @running_bal = ISNULL(@running_bal, 0) + @pred_amount;
                END

                INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                               transaction_type_id, reference_type, reference_id, description, created_at)
                VALUES (@pred_player, @pred_currency, @pred_amount, @running_bal,
                        @refund_type_id, 'PROPOSITION', @proposition_id,
                        'Reembolso por proposición no resuelta', GETUTCDATE());

                UPDATE dbo.Prediction SET result = 'LOST', updated_at = GETUTCDATE()
                WHERE prediction_id = @pred_id;

                FETCH NEXT FROM cur_refund INTO @pred_id, @pred_player, @pred_amount, @pred_currency, @pred_is_virtual;
            END
            CLOSE cur_refund; DEALLOCATE cur_refund;

            -- Penalización 15% al sujeto (solo puntos)
            DECLARE @penalty_pts BIGINT;
            SELECT @current_pts = balance_points, @cur_version = balance_version
            FROM dbo.Player WITH (UPDLOCK) WHERE player_id = @target_player_id;

            SET @penalty_pts = CAST(FLOOR(@current_pts * 0.15) AS BIGINT);

            IF @penalty_pts > 0
            BEGIN
                UPDATE dbo.Player
                SET balance_points  = balance_points - @penalty_pts,
                    balance_version = balance_version + 1,
                    last_transaction_date = GETUTCDATE(),
                    updated_at      = GETUTCDATE()
                WHERE player_id = @target_player_id;

                INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                               transaction_type_id, reference_type, reference_id, description, created_at)
                VALUES (@target_player_id, @points_type_id, -@penalty_pts,
                        CAST(@current_pts - @penalty_pts AS DECIMAL(18,4)),
                        @commission_type_id, 'PROPOSITION', @proposition_id,
                        'Penalización 15% por proposición no resuelta', GETUTCDATE());
            END
        END
        ELSE
        BEGIN
            -- ===================== CASO NORMAL: resolved =====================
            SET @winning_direction = @is_fulfilled;  -- 1 ganadores predicen 1, 0 ganan los que predicen 0

            -- Calcular pozo total y pozo ganadores
            SELECT
                @total_pot_pts   = SUM(CASE WHEN ct.is_virtual = 1 THEN p.amount ELSE 0 END),
                @total_pot_money = SUM(CASE WHEN ct.is_virtual = 0 THEN p.amount ELSE 0 END),
                @winner_pot_pts  = SUM(CASE WHEN p.direction = @winning_direction AND ct.is_virtual = 1 THEN p.amount ELSE 0 END),
                @winner_pot_money= SUM(CASE WHEN p.direction = @winning_direction AND ct.is_virtual = 0 THEN p.amount ELSE 0 END)
            FROM dbo.Prediction p
            JOIN dbo.CurrencyType ct ON p.currency_type_id = ct.currency_type_id
            WHERE p.proposition_id = @proposition_id AND p.result = 'PENDING';

            SET @total_pot_pts   = ISNULL(@total_pot_pts,   0);
            SET @total_pot_money = ISNULL(@total_pot_money, 0);
            SET @winner_pot_pts  = ISNULL(@winner_pot_pts,  0);
            SET @winner_pot_money= ISNULL(@winner_pot_money,0);

            -- Pozo neto tras comisiones
            SET @net_pts   = @total_pot_pts   * (1.0 - (@platform_pct + @proposer_pct) / 100.0);
            SET @net_money = @total_pot_money * (1.0 - (@platform_pct + @proposer_pct) / 100.0);

            -- Comisión al creador (puntos)
            IF @total_pot_pts > 0 AND @proposer_pct > 0
            BEGIN
                DECLARE @creator_commission DECIMAL(18,4) = FLOOR(@total_pot_pts * (@proposer_pct / 100.0));
                IF @creator_commission > 0
                BEGIN
                    SELECT @current_pts = balance_points FROM dbo.Player WHERE player_id = @creator_player_id;

                    UPDATE dbo.Player
                    SET balance_points  = balance_points + CAST(@creator_commission AS BIGINT),
                        balance_version = balance_version + 1,
                        last_transaction_date = GETUTCDATE(),
                        updated_at      = GETUTCDATE()
                    WHERE player_id = @creator_player_id;

                    INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                                   transaction_type_id, reference_type, reference_id, description, created_at)
                    VALUES (@creator_player_id, @points_type_id, @creator_commission,
                            CAST(@current_pts + CAST(@creator_commission AS BIGINT) AS DECIMAL(18,4)),
                            @commission_type_id, 'PROPOSITION', @proposition_id,
                            'Comisión del creador (pts)', GETUTCDATE());
                END
            END

            -- Distribuir a ganadores/perdedores
            DECLARE cur_dist CURSOR LOCAL FAST_FORWARD FOR
                SELECT p.prediction_id, p.player_id, p.amount, p.currency_type_id, ct.is_virtual, p.direction
                FROM dbo.Prediction p
                JOIN dbo.CurrencyType ct ON p.currency_type_id = ct.currency_type_id
                WHERE p.proposition_id = @proposition_id AND p.result = 'PENDING';

            OPEN cur_dist;
            FETCH NEXT FROM cur_dist INTO @pred_id, @pred_player, @pred_amount, @pred_currency, @pred_is_virtual, @pred_direction;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @pred_direction = @winning_direction
                BEGIN
                    -- Ganador: devuelve apuesta + proporción del pozo neto
                    IF @pred_is_virtual = 1 AND @winner_pot_pts > 0
                        SET @earned = @pred_amount + FLOOR(@net_pts * (@pred_amount / @winner_pot_pts));
                    ELSE IF @pred_is_virtual = 0 AND @winner_pot_money > 0
                        SET @earned = @pred_amount + (@net_money * (@pred_amount / @winner_pot_money));
                    ELSE
                        SET @earned = @pred_amount;

                    IF @pred_is_virtual = 1
                    BEGIN
                        SELECT @current_pts = balance_points FROM dbo.Player WHERE player_id = @pred_player;
                        UPDATE dbo.Player
                        SET balance_points  = balance_points + CAST(@earned AS BIGINT),
                            balance_version = balance_version + 1,
                            last_transaction_date = GETUTCDATE(),
                            updated_at      = GETUTCDATE()
                        WHERE player_id = @pred_player;
                        SET @running_bal = CAST(@current_pts + CAST(@earned AS BIGINT) AS DECIMAL(18,4));
                    END
                    ELSE
                    BEGIN
                        SELECT TOP 1 @running_bal = running_balance
                        FROM dbo.[Transaction]
                        WHERE player_id = @pred_player AND currency_type_id = @pred_currency
                        ORDER BY created_at DESC;
                        SET @running_bal = ISNULL(@running_bal, 0) + @earned;
                    END

                    INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                                   transaction_type_id, reference_type, reference_id, description, created_at)
                    VALUES (@pred_player, @pred_currency, @earned, @running_bal,
                            @winning_type_id, 'PREDICTION', @pred_id,
                            'Premio por predicción ganadora', GETUTCDATE());

                    UPDATE dbo.Prediction SET result = 'WON', updated_at = GETUTCDATE()
                    WHERE prediction_id = @pred_id;
                END
                ELSE
                BEGIN
                    -- Perdedor: solo marca como LOST
                    UPDATE dbo.Prediction SET result = 'LOST', updated_at = GETUTCDATE()
                    WHERE prediction_id = @pred_id;
                END

                FETCH NEXT FROM cur_dist INTO @pred_id, @pred_player, @pred_amount, @pred_currency, @pred_is_virtual, @pred_direction;
            END
            CLOSE cur_dist; DEALLOCATE cur_dist;
        END

        -- Marcar proposición como resuelta
        UPDATE dbo.Proposition
        SET status_id   = @resolved_status_id,
            is_fulfilled = @is_fulfilled,
            resolved_at = GETUTCDATE(),
            updated_at  = GETUTCDATE()
        WHERE proposition_id = @proposition_id;

        -- Evento de resolución
        SELECT @event_type_id = event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_RESOLVED';
        IF @event_type_id IS NOT NULL
        BEGIN
            DECLARE @actor INT = ISNULL(@resolved_by, @creator_player_id);
            INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
            VALUES (@proposition_id, @event_type_id, @actor,
                    (SELECT @is_fulfilled AS is_fulfilled FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
                    GETUTCDATE());
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, affected_record_id,
                                     status, error_detail, executed_at, executed_by)
        VALUES ('usp_ResolveProposition', 'Error al resolver proposición',
                'Proposition', @proposition_id, 'ERROR', ERROR_MESSAGE(), GETUTCDATE(), SYSTEM_USER);
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 9: usp_DepositMoney
-- Registra un depósito de dinero real para un jugador.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_DepositMoney
    @player_id     INT,
    @currency_code NVARCHAR(30),
    @amount        DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @currency_type_id INT;
    DECLARE @deposit_type_id  INT;
    DECLARE @is_virtual       BIT;
    DECLARE @running_bal      DECIMAL(18,4);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @currency_type_id = currency_type_id, @is_virtual = is_virtual
        FROM dbo.CurrencyType WHERE currency_code = @currency_code;

        IF @currency_type_id IS NULL
            THROW 50080, 'Moneda inválida.', 1;

        IF @is_virtual = 1
            THROW 50081, 'Use usp_PurchasePoints para recargar puntos virtuales.', 1;

        IF @amount <= 0
            THROW 50082, 'El monto del depósito debe ser mayor a cero.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Player WHERE player_id = @player_id AND enabled = 1)
            THROW 50083, 'Jugador no encontrado o inactivo.', 1;

        SELECT @deposit_type_id = transaction_type_id FROM dbo.TransactionType WHERE type_code = 'DEPOSIT';

        SELECT TOP 1 @running_bal = running_balance
        FROM dbo.[Transaction]
        WHERE player_id = @player_id AND currency_type_id = @currency_type_id
        ORDER BY created_at DESC;

        SET @running_bal = ISNULL(@running_bal, 0) + @amount;

        INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                        transaction_type_id, reference_type, description, created_at)
        VALUES (@player_id, @currency_type_id, @amount, @running_bal,
                @deposit_type_id, 'DEPOSIT',
                CONCAT('Depósito de ', @currency_code), GETUTCDATE());

        UPDATE dbo.Player
        SET last_transaction_date = GETUTCDATE(), updated_at = GETUTCDATE()
        WHERE player_id = @player_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- SP 10: usp_GetPlayerDashboard
-- Retorna balance, proposiciones activas y predicciones pendientes del jugador.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetPlayerDashboard
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Balance de puntos
    SELECT p.player_id, p.username, p.display_name,
           p.balance_points,
           p.last_transaction_date
    FROM dbo.Player p
    WHERE p.player_id = @player_id;

    -- Último balance de dinero real por moneda
    SELECT ct.currency_code, ct.currency_symbol,
           t.running_balance AS current_balance,
           t.created_at AS last_tx_date
    FROM dbo.CurrencyType ct
    CROSS APPLY (
        SELECT TOP 1 running_balance, created_at
        FROM dbo.[Transaction]
        WHERE player_id = @player_id AND currency_type_id = ct.currency_type_id
        ORDER BY created_at DESC
    ) t
    WHERE ct.is_virtual = 0;

    -- Proposiciones activas del jugador (creador o sujeto)
    SELECT
        prop.proposition_id,
        prop.title,
        prop.description,
        ps.status_code,
        prop.prediction_ends_at,
        prop.is_accepted_by_target,
        prop.voting_ends_at,
        creator.username    AS creator_username,
        target.username     AS target_username,
        prop.created_at
    FROM dbo.Proposition prop
    JOIN dbo.PropositionStatus ps ON prop.status_id = ps.status_id
    JOIN dbo.Player creator       ON prop.creator_player_id = creator.player_id
    JOIN dbo.Player target        ON prop.target_player_id  = target.player_id
    WHERE (prop.creator_player_id = @player_id OR prop.target_player_id = @player_id)
      AND ps.status_code IN ('ACTIVE','PREDICTION_CLOSED','PENDING')
      AND prop.enabled = 1
    ORDER BY prop.created_at DESC;

    -- Predicciones pendientes del jugador
    SELECT
        pred.prediction_id,
        pred.proposition_id,
        prop.title          AS proposition_title,
        ct.currency_code,
        pred.amount,
        pred.direction,
        pred.result,
        pred.created_at
    FROM dbo.Prediction pred
    JOIN dbo.Proposition prop   ON pred.proposition_id  = prop.proposition_id
    JOIN dbo.CurrencyType ct    ON pred.currency_type_id = ct.currency_type_id
    WHERE pred.player_id = @player_id
      AND pred.result     = 'PENDING'
    ORDER BY pred.created_at DESC;
END;
GO

-- ==============================================================================
-- SP 11: usp_GetActivePropositions
-- Lista proposiciones activas y aceptadas disponibles para predicción.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetActivePropositions
    @page_number INT = 1,
    @page_size   INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        prop.proposition_id,
        prop.title,
        prop.description,
        creator.username  AS creator_username,
        target.username   AS target_username,
        prop.prediction_ends_at,
        prop.created_at,
        COUNT(pred.prediction_id) AS total_predictions
    FROM dbo.Proposition prop
    JOIN dbo.PropositionStatus ps ON prop.status_id = ps.status_id
    JOIN dbo.Player creator       ON prop.creator_player_id = creator.player_id
    JOIN dbo.Player target        ON prop.target_player_id  = target.player_id
    LEFT JOIN dbo.Prediction pred ON prop.proposition_id = pred.proposition_id
    WHERE ps.status_code = 'ACTIVE'
      AND prop.is_accepted_by_target = 1
      AND prop.prediction_ends_at > GETUTCDATE()
      AND prop.enabled = 1
    GROUP BY prop.proposition_id, prop.title, prop.description,
             creator.username, target.username,
             prop.prediction_ends_at, prop.created_at
    ORDER BY prop.created_at DESC
    OFFSET (@page_number - 1) * @page_size ROWS
    FETCH NEXT @page_size ROWS ONLY;
END;
GO

-- ==============================================================================
-- SP 12: usp_GetPropositionResults
-- Retorna proposiciones resueltas donde el jugador participó.
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetPropositionResults
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        prop.proposition_id,
        prop.title,
        prop.is_fulfilled,
        prop.resolved_at,
        pred.amount,
        ct.currency_code,
        ct.currency_symbol,
        pred.direction,
        pred.result         AS prediction_result,
        CASE WHEN pred.result = 'WON' THEN 1 ELSE 0 END AS is_winner
    FROM dbo.Proposition prop
    JOIN dbo.PropositionStatus ps ON prop.status_id = ps.status_id
    JOIN dbo.Prediction pred      ON prop.proposition_id = pred.proposition_id
                                 AND pred.player_id      = @player_id
    JOIN dbo.CurrencyType ct      ON pred.currency_type_id = ct.currency_type_id
    WHERE ps.status_code = 'RESOLVED'
    ORDER BY prop.resolved_at DESC;
END;
GO
