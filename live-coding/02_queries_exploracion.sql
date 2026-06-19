-- ==============================================================================
-- 02_queries_exploracion.sql  |  Gathel — Exploración y análisis de datos
-- Queries que el profesor probablemente pida: rankings, distribuciones, joins.
-- Ejecutar por sección (seleccionar + F5).
-- ==============================================================================

USE GathelDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN A: Rankings de jugadores
-- ══════════════════════════════════════════════════════════════════════════════

-- Top 10 jugadores por balance de puntos
SELECT TOP 10
    player_id,
    username,
    display_name,
    balance_points,
    created_at
FROM Player
ORDER BY balance_points DESC;
GO

-- Jugadores con más predicciones realizadas
SELECT TOP 10
    p.username,
    COUNT(pred.prediction_id) AS total_predicciones,
    SUM(CASE WHEN pred.result = 'WON'  THEN 1 ELSE 0 END) AS ganadas,
    SUM(CASE WHEN pred.result = 'LOST' THEN 1 ELSE 0 END) AS perdidas,
    SUM(CASE WHEN pred.result = 'PENDING' THEN 1 ELSE 0 END) AS pendientes
FROM Player p
JOIN Prediction pred ON p.player_id = pred.player_id
GROUP BY p.player_id, p.username
ORDER BY total_predicciones DESC;
GO

-- Jugadores con más proposiciones creadas
SELECT TOP 10
    p.username,
    COUNT(prop.proposition_id) AS proposiciones_creadas,
    SUM(CASE WHEN ps.status_code = 'RESOLVED' THEN 1 ELSE 0 END) AS resueltas,
    SUM(CASE WHEN ps.status_code = 'ACTIVE'   THEN 1 ELSE 0 END) AS activas
FROM Player p
JOIN Proposition prop ON p.player_id = prop.creator_player_id
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
GROUP BY p.player_id, p.username
ORDER BY proposiciones_creadas DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN B: Análisis de proposiciones
-- ══════════════════════════════════════════════════════════════════════════════

-- Distribución de proposiciones por estado
SELECT
    ps.status_code,
    COUNT(*) AS total,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS porcentaje
FROM Proposition p
JOIN PropositionStatus ps ON p.status_id = ps.status_id
GROUP BY ps.status_code
ORDER BY total DESC;
GO

-- Proposiciones con más predicciones (las más populares)
SELECT TOP 10
    prop.proposition_id,
    prop.title,
    creator.username AS creador,
    target.username  AS sujeto,
    ps.status_code   AS estado,
    COUNT(pred.prediction_id) AS total_predicciones,
    SUM(pred.amount) AS monto_total_apostado
FROM Proposition prop
JOIN Player creator ON prop.creator_player_id = creator.player_id
JOIN Player target  ON prop.target_player_id  = target.player_id
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
LEFT JOIN Prediction pred ON prop.proposition_id = pred.proposition_id
GROUP BY prop.proposition_id, prop.title, creator.username, target.username, ps.status_code
ORDER BY total_predicciones DESC;
GO

-- Ver detalle completo de una proposición específica (cambiar el ID)
DECLARE @pid INT = 1;   -- <-- CAMBIAR POR EL ID QUE QUIERAS

SELECT
    prop.proposition_id,
    prop.title,
    prop.description,
    ps.status_code,
    prop.ai_review_result,
    prop.is_accepted_by_target,
    prop.is_fulfilled,
    prop.voting_ends_at,
    prop.prediction_ends_at,
    prop.resolved_at,
    creator.username AS creador,
    target.username  AS sujeto,
    prop.created_at
FROM Proposition prop
JOIN PropositionStatus ps ON prop.status_id = ps.status_id
JOIN Player creator ON prop.creator_player_id = creator.player_id
JOIN Player target  ON prop.target_player_id  = target.player_id
WHERE prop.proposition_id = @pid;

-- Predicciones de esa proposición
SELECT
    pred.prediction_id,
    p.username,
    pred.amount,
    ct.currency_code,
    CASE pred.direction WHEN 1 THEN 'SE CUMPLE' ELSE 'NO SE CUMPLE' END AS apuesta,
    pred.result,
    pred.created_at
FROM Prediction pred
JOIN Player p ON pred.player_id = pred.player_id
JOIN CurrencyType ct ON pred.currency_type_id = ct.currency_type_id
WHERE pred.proposition_id = @pid
ORDER BY pred.created_at;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN C: Análisis financiero
-- ══════════════════════════════════════════════════════════════════════════════

-- Total apostado por moneda
SELECT
    ct.currency_code,
    ct.currency_symbol,
    COUNT(pred.prediction_id) AS num_predicciones,
    SUM(pred.amount)           AS monto_total
FROM Prediction pred
JOIN CurrencyType ct ON pred.currency_type_id = ct.currency_type_id
GROUP BY ct.currency_code, ct.currency_symbol
ORDER BY monto_total DESC;
GO

-- Transacciones por tipo
SELECT
    tt.type_code,
    COUNT(*) AS total_transacciones,
    SUM(t.amount) AS monto_total
FROM [Transaction] t
JOIN TransactionType tt ON t.transaction_type_id = tt.transaction_type_id
GROUP BY tt.type_code
ORDER BY total_transacciones DESC;
GO

-- Historial de transacciones de un jugador (cambiar el ID)
DECLARE @uid INT = 1;   -- <-- CAMBIAR POR EL player_id

SELECT TOP 20
    t.transaction_id,
    tt.type_code,
    ct.currency_code,
    t.amount,
    t.running_balance,
    t.reference_type,
    t.reference_id,
    t.description,
    t.created_at
FROM [Transaction] t
JOIN TransactionType tt ON t.transaction_type_id = tt.transaction_type_id
JOIN CurrencyType ct    ON t.currency_type_id    = ct.currency_type_id
WHERE t.player_id = @uid
ORDER BY t.created_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN D: Actividad reciente (Feed)
-- ══════════════════════════════════════════════════════════════════════════════

-- Últimos 20 eventos del sistema
SELECT TOP 20
    ge.event_id,
    et.type_code       AS evento,
    p.username         AS actor,
    prop.title         AS proposicion,
    ge.event_data,
    ge.created_at
FROM GameEvent ge
JOIN EventType et ON ge.event_type_id = et.event_type_id
JOIN Player p     ON ge.actor_player_id = p.player_id
LEFT JOIN Proposition prop ON ge.proposition_id = prop.proposition_id
ORDER BY ge.created_at DESC;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN E: Auditoría
-- ══════════════════════════════════════════════════════════════════════════════

-- Historial de cambios en proposiciones (trigger tr_proposition_audit)
SELECT TOP 20
    pa.audit_id,
    pa.proposition_id,
    pa.field_name,
    pa.old_value,
    pa.new_value,
    pa.changed_by,
    pa.changed_at
FROM PropositionAudit pa
ORDER BY pa.changed_at DESC;
GO

-- Ver log de errores de stored procedures
SELECT TOP 20
    log_id, sp_name, status, error_detail, executed_at
FROM ProcessLog
WHERE status = 'ERROR'
ORDER BY executed_at DESC;
GO
