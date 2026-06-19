-- ==============================================================================
-- 00_startup.sql  |  Gathel — Verificación de arranque
-- Ejecutar primero, antes de la defensa. Confirma que el stack está vivo.
-- ==============================================================================

USE GathelDB;
GO

-- ── 1. Verificar que las tablas existen y tienen datos ────────────────────────
SELECT
    'Player'           AS tabla, COUNT(*) AS filas FROM Player           UNION ALL
SELECT 'Proposition',            COUNT(*)           FROM Proposition       UNION ALL
SELECT 'Prediction',             COUNT(*)           FROM Prediction        UNION ALL
SELECT '[Transaction]',          COUNT(*)           FROM [Transaction]     UNION ALL
SELECT 'GameEvent',              COUNT(*)           FROM GameEvent         UNION ALL
SELECT 'AIReviewLog',            COUNT(*)           FROM AIReviewLog       UNION ALL
SELECT 'PropositionAudit',       COUNT(*)           FROM PropositionAudit  UNION ALL
SELECT 'Vote',                   COUNT(*)           FROM Vote;
GO

-- ── 2. Verificar catálogos ────────────────────────────────────────────────────
SELECT status_id, status_code FROM PropositionStatus ORDER BY status_id;
SELECT currency_type_id, currency_code, is_virtual FROM CurrencyType ORDER BY currency_type_id;
SELECT transaction_type_id, type_code FROM TransactionType ORDER BY transaction_type_id;
SELECT event_type_id, type_code FROM EventType ORDER BY event_type_id;
GO

-- ── 3. Verificar IDs de IA (necesarios para usp_RecordAIReview) ───────────────
SELECT ai_model_id, model_code FROM AIModel WHERE enabled = 1;
SELECT ai_provider_id, provider_code FROM AIProvider WHERE enabled = 1;
GO

-- ── 4. Usuarios de demostración ───────────────────────────────────────────────
SELECT TOP 5 player_id, username, email, balance_points
FROM Player
ORDER BY player_id;
GO

-- ── 5. Verificar roles de seguridad ──────────────────────────────────────────
SELECT name AS rol FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'db_gathel%'
ORDER BY name;
GO

-- ── 6. Estado general de proposiciones ───────────────────────────────────────
SELECT ps.status_code, COUNT(*) AS total
FROM Proposition p
JOIN PropositionStatus ps ON p.status_id = ps.status_id
GROUP BY ps.status_code
ORDER BY total DESC;
GO

PRINT '✔  Stack verificado — listo para la defensa.';
