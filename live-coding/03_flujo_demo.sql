-- ==============================================================================
-- 03_flujo_demo.sql  |  Gathel — Flujo completo de demostración
-- Sigue los pasos EN ORDEN. Cada bloque es independiente (seleccionar + F5).
-- Ruta: Registro → Proposición → AI Review → Aceptar → Predecir → Resolver
-- ==============================================================================

USE GathelDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 1: Ver jugadores existentes para usar en la demo
-- ══════════════════════════════════════════════════════════════════════════════

SELECT TOP 10 player_id, username, balance_points
FROM Player
ORDER BY player_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 2: Registrar un jugador nuevo desde SSMS
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @nuevo_id INT;

EXEC dbo.usp_RegisterPlayer
    @username      = N'demo_defensa',
    @email         = N'demo_defensa@gathel.com',
    @password_hash = N'hash_placeholder',
    @display_name  = N'Demo Defensa',
    @new_player_id = @nuevo_id OUTPUT;

PRINT 'Nuevo player_id: ' + CAST(@nuevo_id AS NVARCHAR);

-- Verificar que tiene 100 puntos de bienvenida
SELECT player_id, username, balance_points FROM Player WHERE username = 'demo_defensa';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 3: Crear una proposición
-- (Usa dos player_ids existentes; ajusta @creator y @target)
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @creator   INT = 1;    -- <-- player_id del creador
DECLARE @target    INT = 2;    -- <-- player_id del sujeto (diferente al creador)
DECLARE @prop_id   INT;

EXEC dbo.usp_CreateProposition
    @creator_player_id  = @creator,
    @target_player_id   = @target,
    @title              = N'Demo: Fulano irá al gimnasio esta semana',
    @description        = N'Predicción de defensa: el sujeto publicará evidencia en Instagram.',
    @voting_ends_at     = '2027-12-31 23:59:59',
    @new_proposition_id = @prop_id OUTPUT;

PRINT 'Nueva proposition_id: ' + CAST(@prop_id AS NVARCHAR);

-- Verificar que quedó en PENDING
SELECT proposition_id, title, status_id, ai_review_result
FROM Proposition WHERE proposition_id = @prop_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 4: Simular revisión de IA (APPROVED)
-- Necesitas el proposition_id del paso anterior.
-- Ajusta @prop_id, @ai_model_id, @ai_provider_id según lo que viste en 00_startup.sql
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @prop_id       INT = 1;   -- <-- CAMBIAR al ID real del paso 3
DECLARE @ai_model_id   INT = 1;   -- <-- ver: SELECT ai_model_id, model_code FROM AIModel
DECLARE @ai_provider_id INT = 1;  -- <-- ver: SELECT ai_provider_id, provider_code FROM AIProvider

EXEC dbo.usp_RecordAIReview
    @proposition_id       = @prop_id,
    @ai_model_id          = @ai_model_id,
    @ai_provider_id       = @ai_provider_id,
    @review_result        = 'APPROVED',
    @confidence_score     = 0.9750,
    @review_details       = N'Contenido apropiado. Sin violaciones detectadas.';

-- Verificar que pasó a ACTIVE
SELECT proposition_id, title, status_id, ai_review_result
FROM Proposition WHERE proposition_id = @prop_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 5: El sujeto acepta la proposición
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @prop_id   INT = 1;   -- <-- CAMBIAR
DECLARE @target_id INT = 2;   -- <-- player_id del sujeto (mismo que en Paso 3)

EXEC dbo.usp_AcceptProposition
    @proposition_id     = @prop_id,
    @target_player_id   = @target_id,
    @prediction_ends_at = '2027-12-30 23:59:59';

-- Verificar is_accepted_by_target = 1
SELECT proposition_id, title, is_accepted_by_target, prediction_ends_at
FROM Proposition WHERE proposition_id = @prop_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 6: Realizar una predicción (con POINTS)
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @prop_id    INT = 1;   -- <-- CAMBIAR
DECLARE @player_id  INT = 3;   -- <-- otro jugador que NO sea creator ni target
DECLARE @pred_id    BIGINT;

EXEC dbo.usp_PlacePrediction
    @proposition_id    = @prop_id,
    @player_id         = @player_id,
    @amount            = 1,
    @currency_code     = 'POINTS',
    @direction         = 1,            -- 1 = "sí se cumple"
    @new_prediction_id = @pred_id OUTPUT;

PRINT 'Nueva prediction_id: ' + CAST(@pred_id AS NVARCHAR);

-- Ver balance actualizado
SELECT player_id, username, balance_points FROM Player WHERE player_id = @player_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 7: Depositar dinero real y predecir con USD
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @player_id INT = 3;   -- <-- mismo jugador
DECLARE @prop_id   INT = 1;   -- <-- CAMBIAR
DECLARE @pred_id   BIGINT;

-- Depositar 50 USD
EXEC dbo.usp_DepositMoney
    @player_id     = @player_id,
    @currency_code = 'USD',
    @amount        = 50.00;

-- Predecir 10 USD
EXEC dbo.usp_PlacePrediction
    @proposition_id    = @prop_id,
    @player_id         = @player_id,
    @amount            = 10.00,
    @currency_code     = 'USD',
    @direction         = 1,
    @new_prediction_id = @pred_id OUTPUT;

-- Ver transacciones
SELECT TOP 5 t.amount, tt.type_code, ct.currency_code, t.running_balance, t.description
FROM [Transaction] t
JOIN TransactionType tt ON t.transaction_type_id = tt.transaction_type_id
JOIN CurrencyType ct    ON t.currency_type_id    = ct.currency_type_id
WHERE t.player_id = @player_id
ORDER BY t.created_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 8: Cerrar predicciones y resolver proposición
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @prop_id INT = 1;   -- <-- CAMBIAR

-- Cerrar período de predicciones (ACTIVE → PREDICTION_CLOSED)
EXEC dbo.usp_ClosePropositionPredictions @proposition_id = @prop_id;

-- Verificar estado
SELECT proposition_id, status_id FROM Proposition WHERE proposition_id = @prop_id;
GO

DECLARE @prop_id INT = 1;   -- <-- CAMBIAR

-- Resolver: 1 = se cumplió, 0 = no se cumplió, NULL = irresoluble
EXEC dbo.usp_ResolveProposition
    @proposition_id = @prop_id,
    @is_fulfilled   = 1;

-- Ver resultados de predicciones
SELECT
    pred.prediction_id,
    p.username,
    pred.amount,
    ct.currency_code,
    CASE pred.direction WHEN 1 THEN 'SÍ' ELSE 'NO' END AS apostó,
    pred.result
FROM Prediction pred
JOIN Player p ON pred.player_id = p.player_id
JOIN CurrencyType ct ON pred.currency_type_id = ct.currency_type_id
WHERE pred.proposition_id = @prop_id;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 9: Verificar dashboard final de un jugador
-- ══════════════════════════════════════════════════════════════════════════════

EXEC dbo.usp_GetPlayerDashboard @player_id = 3;   -- <-- CAMBIAR
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PASO 10 (BONUS): Ver la auditoría del trigger
-- ══════════════════════════════════════════════════════════════════════════════

-- Muestra todos los cambios de estado de la proposición registrados automáticamente
SELECT pa.field_name, pa.old_value, pa.new_value, pa.changed_by, pa.changed_at
FROM PropositionAudit pa
WHERE pa.proposition_id = 1   -- <-- CAMBIAR
ORDER BY pa.changed_at;
GO
