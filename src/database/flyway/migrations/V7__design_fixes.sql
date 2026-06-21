-- ==============================================================================
-- V7__design_fixes.sql
-- Gathel Gaming Platform — Corrección de errores de diseño
-- SQL Server 2022 | Flyway
--
-- Errores corregidos:
--   1. Vote:                 falta columna direction (a favor / en contra)
--   2. AIModel:              falta relación con AIProvider (inconsistencia posible en AIReviewLog)
--   3. PropositionEvidence:  permite filas sin URL ni post_id (evidencia vacía)
--   4. SocialAccountSession: encryption_key_id sin FK (columna huérfana)
-- ==============================================================================

-- ==============================================================================
-- FIX 1: Vote.direction
-- Vote no tenía campo para distinguir si el voto es a favor (1) o en contra (0).
-- Se agrega nullable, se rellena el seeding existente con valores aleatorios,
-- y se convierte a NOT NULL con DEFAULT 1.
-- ==============================================================================

ALTER TABLE dbo.Vote ADD direction BIT NULL;
GO

UPDATE dbo.Vote
SET direction = ABS(CHECKSUM(NEWID())) % 2;
GO

ALTER TABLE dbo.Vote ALTER COLUMN direction BIT NOT NULL;
GO

ALTER TABLE dbo.Vote
    ADD CONSTRAINT DF_Vote_Direction DEFAULT 1 FOR direction;
GO

-- Reconstruir índice para incluir direction en las consultas de conteo
DROP INDEX IF EXISTS idx_vote_proposition ON dbo.Vote;
GO

CREATE INDEX idx_vote_proposition
    ON dbo.Vote (proposition_id)
    INCLUDE (player_id, direction);
GO

-- ==============================================================================
-- FIX 2: AIModel.ai_provider_id
-- AIModel no tenía relación con AIProvider. Esto permitía que AIReviewLog
-- almacenara combinaciones inválidas (ej: modelo GPT-4 + proveedor Anthropic).
-- Se agrega ai_provider_id a AIModel con FK, se poblan los datos existentes,
-- y se agrega un trigger de validación en AIReviewLog.
-- ==============================================================================

ALTER TABLE dbo.AIModel ADD ai_provider_id INT NULL;
GO

UPDATE dbo.AIModel
SET ai_provider_id = (SELECT ai_provider_id FROM dbo.AIProvider WHERE provider_code = 'ANTHROPIC')
WHERE model_code IN ('CLAUDE_SONNET_46', 'CLAUDE_OPUS_46');

UPDATE dbo.AIModel
SET ai_provider_id = (SELECT ai_provider_id FROM dbo.AIProvider WHERE provider_code = 'OPENAI')
WHERE model_code = 'GPT4O';

UPDATE dbo.AIModel
SET ai_provider_id = (SELECT ai_provider_id FROM dbo.AIProvider WHERE provider_code = 'GOOGLE')
WHERE model_code = 'GEMINI_15_PRO';
GO

ALTER TABLE dbo.AIModel ALTER COLUMN ai_provider_id INT NOT NULL;
GO

ALTER TABLE dbo.AIModel
    ADD CONSTRAINT FK_AIModel_Provider
    FOREIGN KEY (ai_provider_id) REFERENCES dbo.AIProvider(ai_provider_id);
GO

-- Trigger de consistencia: al insertar en AIReviewLog, valida que el
-- ai_provider_id coincida con el proveedor real del modelo usado.
CREATE OR ALTER TRIGGER trg_AIReviewLog_ProviderConsistency
ON dbo.AIReviewLog
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.AIModel m ON m.ai_model_id = i.ai_model_id
        WHERE m.ai_provider_id <> i.ai_provider_id
    )
    BEGIN
        THROW 50010, 'El ai_provider_id no coincide con el proveedor del modelo seleccionado.', 1;
    END
END;
GO

-- ==============================================================================
-- FIX 3: PropositionEvidence — CHECK que exija al menos una referencia
-- Antes era posible insertar una fila con post_id NULL y evidence_url NULL,
-- lo que resultaría en una evidencia sin ningún contenido útil.
-- ==============================================================================

ALTER TABLE dbo.PropositionEvidence
    ADD CONSTRAINT CK_Evidence_HasReference
    CHECK (post_id IS NOT NULL OR evidence_url IS NOT NULL);
GO

-- ==============================================================================
-- FIX 4: SocialAccountSession.encryption_key_id
-- Era un INT sin FK a ninguna tabla existente (referencia huérfana).
-- Se elimina. Si en el futuro se implementa un KeyStore formal, se agrega
-- en una nueva migración con FK y tabla de destino definida.
-- ==============================================================================

ALTER TABLE dbo.SocialAccountSession DROP COLUMN encryption_key_id;
GO
