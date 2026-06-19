-- ==============================================================================
-- 06_queries_ad_hoc.sql  |  Gathel — Queries de live coding (preguntas típicas)
-- Plantillas listas para adaptar cuando el profesor pida algo en vivo.
-- Seleccionar la sección relevante y modificar los parámetros.
-- ==============================================================================

USE GathelDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA A: Cualquier consulta con JOIN rápido
-- "Muéstrame X junto con Y"
-- ══════════════════════════════════════════════════════════════════════════════

-- Esqueleto genérico
SELECT
    p.player_id,
    p.username,
    -- agregar columnas según necesites
    prop.proposition_id,
    prop.title,
    ps.status_code
FROM Player p
JOIN Proposition prop ON p.player_id = prop.creator_player_id
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
WHERE ps.status_code = 'ACTIVE'   -- filtro típico
ORDER BY prop.created_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA B: Agregación por grupo
-- "¿Cuántos/cuánto por cada X?"
-- ══════════════════════════════════════════════════════════════════════════════

-- Predicciones por resultado y moneda
SELECT
    ct.currency_code,
    pred.result,
    COUNT(*)      AS total,
    SUM(pred.amount) AS monto_total,
    AVG(pred.amount) AS monto_promedio
FROM Prediction pred
JOIN CurrencyType ct ON pred.currency_type_id = ct.currency_type_id
GROUP BY ct.currency_code, pred.result
ORDER BY ct.currency_code, pred.result;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA C: Subconsulta / EXISTS
-- "Jugadores que nunca han predicho"
-- ══════════════════════════════════════════════════════════════════════════════

SELECT player_id, username, balance_points
FROM Player
WHERE NOT EXISTS (
    SELECT 1 FROM Prediction WHERE player_id = Player.player_id
)
ORDER BY created_at DESC;
GO

-- "Proposiciones sin ninguna predicción todavía"
SELECT prop.proposition_id, prop.title, ps.status_code
FROM Proposition prop
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
WHERE NOT EXISTS (
    SELECT 1 FROM Prediction WHERE proposition_id = prop.proposition_id
)
ORDER BY prop.created_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA D: Window functions (ROW_NUMBER, RANK, SUM OVER)
-- "¿Cuál fue la predicción más alta por proposición?"
-- ══════════════════════════════════════════════════════════════════════════════

SELECT
    proposition_id,
    player_id,
    amount,
    currency_type_id,
    ROW_NUMBER() OVER (PARTITION BY proposition_id, currency_type_id ORDER BY amount DESC) AS ranking
FROM Prediction
WHERE result = 'PENDING';
GO

-- Running balance acumulado por jugador (para auditoría)
SELECT
    t.transaction_id,
    t.player_id,
    ct.currency_code,
    t.amount,
    SUM(t.amount) OVER (
        PARTITION BY t.player_id, t.currency_type_id
        ORDER BY t.created_at
        ROWS UNBOUNDED PRECEDING
    ) AS balance_acumulado,
    t.running_balance AS balance_registrado,
    t.created_at
FROM [Transaction] t
JOIN CurrencyType ct ON t.currency_type_id = ct.currency_type_id
WHERE t.player_id = 1   -- <-- CAMBIAR
ORDER BY t.currency_type_id, t.created_at;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA E: CTE
-- "Dame el jugador más activo por mes"
-- ══════════════════════════════════════════════════════════════════════════════

WITH EventosPorMes AS (
    SELECT
        actor_player_id,
        YEAR(created_at)  AS anio,
        MONTH(created_at) AS mes,
        COUNT(*) AS total_eventos
    FROM GameEvent
    GROUP BY actor_player_id, YEAR(created_at), MONTH(created_at)
),
RankedPorMes AS (
    SELECT *,
        RANK() OVER (PARTITION BY anio, mes ORDER BY total_eventos DESC) AS rk
    FROM EventosPorMes
)
SELECT
    r.anio,
    r.mes,
    p.username,
    r.total_eventos
FROM RankedPorMes r
JOIN Player p ON r.actor_player_id = p.player_id
WHERE r.rk = 1
ORDER BY r.anio, r.mes;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA F: PIVOT — distribución de estados de proposición por mes
-- ══════════════════════════════════════════════════════════════════════════════

SELECT *
FROM (
    SELECT
        YEAR(p.created_at)  AS anio,
        MONTH(p.created_at) AS mes,
        ps.status_code
    FROM Proposition p
    JOIN PropositionStatus ps ON p.status_id = ps.status_id
) src
PIVOT (
    COUNT(status_code)
    FOR status_code IN ([PENDING],[ACTIVE],[PREDICTION_CLOSED],[RESOLVED],[REJECTED])
) pvt
ORDER BY anio, mes;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA G: UPDATE con lógica de negocio (sin SP)
-- "Deshabilitar un jugador manualmente"
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @player_id INT = 999;   -- <-- CAMBIAR

BEGIN TRANSACTION;
    UPDATE Player
    SET enabled    = 0,
        updated_at = GETUTCDATE(),
        updated_by = SYSTEM_USER
    WHERE player_id = @player_id;

    -- Verificar antes de confirmar
    SELECT player_id, username, enabled FROM Player WHERE player_id = @player_id;
ROLLBACK;   -- cambiar a COMMIT cuando estés seguro
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTILLA H: Buscar por username parcial (como el autocomplete del frontend)
-- ══════════════════════════════════════════════════════════════════════════════

DECLARE @q NVARCHAR(50) = N'demo';   -- <-- CAMBIAR

SELECT TOP 10
    player_id,
    username,
    display_name,
    balance_points
FROM Player
WHERE (username LIKE '%' + @q + '%' OR display_name LIKE '%' + @q + '%')
  AND enabled = 1
ORDER BY username;
GO
