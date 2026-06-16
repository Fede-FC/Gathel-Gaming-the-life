-- ==============================================================================
-- V1__init_gathel.sql
-- Gathel Gaming Platform — Creación del Schema Completo
-- Basado en design.dbml v2.0 (13 de Junio de 2026)
-- Versionado con Flyway | SQL Server 2022
-- ==============================================================================

-- ==============================================================================
-- 1. CATÁLOGOS INDEPENDIENTES
-- ==============================================================================

CREATE TABLE PropositionStatus (
    status_id    INT IDENTITY(1,1)  NOT NULL,
    status_code  NVARCHAR(30)       NOT NULL,  -- PENDING, ACTIVE, PREDICTION_CLOSED, RESOLVED, REJECTED, CANCELLED
    description  NVARCHAR(200)      NULL,
    enabled      BIT                NOT NULL DEFAULT 1,
    created_at   DATETIME2          NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_PropositionStatus PRIMARY KEY (status_id),
    CONSTRAINT UQ_PropositionStatus_Code UNIQUE (status_code)
);

CREATE TABLE SocialNetwork (
    social_network_id INT IDENTITY(1,1)  NOT NULL,
    network_code      NVARCHAR(20)       NOT NULL,  -- INSTAGRAM, TIKTOK, TWITTER
    network_name      NVARCHAR(50)       NOT NULL,
    url               NVARCHAR(500)      NULL,
    api_url           NVARCHAR(500)      NULL,
    api_config        NVARCHAR(MAX)      NULL,       -- JSON: keys, scopes, etc.
    enabled           BIT                NOT NULL DEFAULT 1,
    created_at        DATETIME2          NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_SocialNetwork PRIMARY KEY (social_network_id),
    CONSTRAINT UQ_SocialNetwork_Code UNIQUE (network_code)
);

CREATE TABLE CurrencyType (
    currency_type_id INT IDENTITY(1,1) NOT NULL,
    currency_code    NVARCHAR(30)      NOT NULL,  -- POINTS, USD, EUR, ...
    currency_name    NVARCHAR(50)      NOT NULL,
    currency_symbol  NVARCHAR(10)      NULL,
    is_virtual       BIT               NOT NULL,  -- 1 = puntos virtuales; 0 = dinero real
    decimal_places   INT               NOT NULL DEFAULT 0,
    enabled          BIT               NOT NULL DEFAULT 1,
    created_at       DATETIME2         NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_CurrencyType PRIMARY KEY (currency_type_id),
    CONSTRAINT UQ_CurrencyType_Code UNIQUE (currency_code)
);

CREATE TABLE ExchangeRate (
    exchange_rate_id INT           IDENTITY(1,1) NOT NULL,
    currency_type_id INT           NOT NULL,
    rate_to_usd      DECIMAL(18,4) NOT NULL,
    effective_date   DATETIME2     NOT NULL,
    created_at       DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_ExchangeRate PRIMARY KEY (exchange_rate_id),
    CONSTRAINT FK_ExchangeRate_CurrencyType FOREIGN KEY (currency_type_id) REFERENCES CurrencyType(currency_type_id)
);

CREATE INDEX idx_exchange_rate_currency_date
    ON ExchangeRate (currency_type_id, effective_date DESC);

CREATE TABLE TransactionType (
    transaction_type_id INT IDENTITY(1,1) NOT NULL,
    type_code           NVARCHAR(30)      NOT NULL,  -- DEPOSIT, WITHDRAWAL, COMMISSION, WINNING
    description         NVARCHAR(200)     NULL,
    applies_to          NVARCHAR(10)      NOT NULL,  -- POINTS, MONEY, BOTH
    enabled             BIT               NOT NULL DEFAULT 1,
    created_at          DATETIME2         NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_TransactionType PRIMARY KEY (transaction_type_id),
    CONSTRAINT UQ_TransactionType_Code UNIQUE (type_code),
    CONSTRAINT CK_TransactionType_AppliesTo CHECK (applies_to IN ('POINTS','MONEY','BOTH'))
);

CREATE TABLE EventType (
    event_type_id INT IDENTITY(1,1) NOT NULL,
    type_code     NVARCHAR(40)      NOT NULL,  -- PROPOSITION_CREATED, VOTE_CAST, PREDICTION_MADE, ...
    description   NVARCHAR(200)     NULL,
    enabled       BIT               NOT NULL DEFAULT 1,
    created_at    DATETIME2         NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_EventType PRIMARY KEY (event_type_id),
    CONSTRAINT UQ_EventType_Code UNIQUE (type_code)
);

CREATE TABLE AIProvider (
    ai_provider_id INT IDENTITY(1,1) NOT NULL,
    provider_code  NVARCHAR(30)      NOT NULL,  -- OPENAI, ANTHROPIC
    provider_name  NVARCHAR(100)     NOT NULL,
    enabled        BIT               NOT NULL DEFAULT 1,
    created_at     DATETIME2         NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AIProvider PRIMARY KEY (ai_provider_id),
    CONSTRAINT UQ_AIProvider_Code UNIQUE (provider_code)
);

CREATE TABLE AIModel (
    ai_model_id INT IDENTITY(1,1) NOT NULL,
    model_code  NVARCHAR(50)      NOT NULL,  -- GPT4, CLAUDE3, ...
    model_name  NVARCHAR(100)     NOT NULL,
    version     NVARCHAR(20)      NOT NULL,
    enabled     BIT               NOT NULL DEFAULT 1,
    created_at  DATETIME2         NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_AIModel PRIMARY KEY (ai_model_id),
    CONSTRAINT UQ_AIModel_Code UNIQUE (model_code)
);

-- ==============================================================================
-- 2. AUTENTICACIÓN Y JUGADORES
-- ==============================================================================

CREATE TABLE Player (
    player_id             INT           IDENTITY(1,1) NOT NULL,
    username              NVARCHAR(50)  NOT NULL,
    email                 NVARCHAR(150) NOT NULL,
    password_hash         NVARCHAR(256) NOT NULL,   -- Argon2id / bcrypt
    display_name          NVARCHAR(100) NULL,
    balance_points        BIGINT        NOT NULL DEFAULT 100,  -- Desnormalizado; sincronizado vía trigger
    balance_version       INT           NOT NULL DEFAULT 1,     -- Optimistic locking
    last_transaction_date DATETIME2     NULL,
    enabled               BIT           NOT NULL DEFAULT 1,
    created_at            DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    updated_at            DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    updated_by            NVARCHAR(100) NULL,
    checksum              NVARCHAR(64)  NULL,
    CONSTRAINT PK_Player PRIMARY KEY (player_id),
    CONSTRAINT UQ_Player_Username UNIQUE (username),
    CONSTRAINT UQ_Player_Email UNIQUE (email)
);

CREATE INDEX idx_player_created ON Player (created_at);

CREATE TABLE SocialAccount (
    social_account_id INT       IDENTITY(1,1) NOT NULL,
    player_id         INT       NOT NULL,
    social_network_id INT       NOT NULL,
    account_username  NVARCHAR(100) NOT NULL,
    is_verified       BIT       NOT NULL DEFAULT 0,
    enabled           BIT       NOT NULL DEFAULT 1,
    created_at        DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    updated_at        DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_SocialAccount PRIMARY KEY (social_account_id),
    CONSTRAINT UQ_SocialAccount_Player_Network UNIQUE (player_id, social_network_id),
    CONSTRAINT FK_SocialAccount_Player FOREIGN KEY (player_id) REFERENCES Player(player_id) ON DELETE CASCADE,
    CONSTRAINT FK_SocialAccount_Network FOREIGN KEY (social_network_id) REFERENCES SocialNetwork(social_network_id)
);

CREATE INDEX idx_social_account_unique ON SocialAccount (player_id, social_network_id);

CREATE TABLE SocialAccountSession (
    session_id              BIGINT        IDENTITY(1,1) NOT NULL,
    social_account_id       INT           NOT NULL,
    access_token_encrypted  NVARCHAR(500) NOT NULL,   -- Always Encrypted
    refresh_token_encrypted NVARCHAR(500) NULL,       -- Always Encrypted
    token_expires_at        DATETIME2     NULL,
    encryption_key_id       INT           NULL,        -- Referencia a key store
    last_used_at            DATETIME2     NULL,
    rotation_count          INT           NOT NULL DEFAULT 0,
    is_active               BIT           NOT NULL DEFAULT 1,
    created_at              DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    invalidated_at          DATETIME2     NULL,
    CONSTRAINT PK_SocialAccountSession PRIMARY KEY (session_id),
    CONSTRAINT FK_SocialAccountSession_Account FOREIGN KEY (social_account_id) REFERENCES SocialAccount(social_account_id) ON DELETE CASCADE
);

-- ==============================================================================
-- 3. PROPOSICIONES Y PREDICCIONES
-- ==============================================================================

CREATE TABLE Proposition (
    proposition_id        INT            IDENTITY(1,1) NOT NULL,
    creator_player_id     INT            NOT NULL,
    target_player_id      INT            NOT NULL,
    title                 NVARCHAR(150)  NOT NULL,
    description           NVARCHAR(1000) NOT NULL,
    status_id             INT            NOT NULL,
    ai_review_result      NVARCHAR(20)   NULL,   -- APPROVED, REJECTED, PENDING
    ai_review_detail      NVARCHAR(500)  NULL,
    rejection_reason      NVARCHAR(500)  NULL,
    voting_ends_at        DATETIME2      NULL,
    prediction_ends_at    DATETIME2      NULL,
    is_accepted_by_target BIT            NOT NULL DEFAULT 0,
    is_fulfilled          BIT            NULL,
    resolved_at           DATETIME2      NULL,
    enabled               BIT            NOT NULL DEFAULT 1,
    created_at            DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    updated_at            DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    checksum              NVARCHAR(64)   NULL,
    checksum_timestamp    DATETIME2      NULL,
    CONSTRAINT PK_Proposition PRIMARY KEY (proposition_id),
    CONSTRAINT CK_Proposition_DiffPlayers CHECK (creator_player_id <> target_player_id),
    CONSTRAINT FK_Proposition_Creator FOREIGN KEY (creator_player_id) REFERENCES Player(player_id),
    CONSTRAINT FK_Proposition_Target  FOREIGN KEY (target_player_id)  REFERENCES Player(player_id),
    CONSTRAINT FK_Proposition_Status  FOREIGN KEY (status_id)         REFERENCES PropositionStatus(status_id)
);

CREATE INDEX idx_proposition_status
    ON Proposition (status_id)
    INCLUDE (creator_player_id, target_player_id, title, prediction_ends_at)
    WHERE enabled = 1;

CREATE INDEX idx_proposition_creator
    ON Proposition (creator_player_id, created_at DESC)
    INCLUDE (status_id, title, is_accepted_by_target);

CREATE INDEX idx_proposition_target
    ON Proposition (target_player_id, created_at DESC)
    INCLUDE (status_id, title, creator_player_id);

CREATE INDEX idx_proposition_prediction_ends
    ON Proposition (prediction_ends_at)
    WHERE status_id IN (2, 3) AND enabled = 1;

CREATE INDEX idx_proposition_created ON Proposition (created_at);

CREATE TABLE Vote (
    vote_id        BIGINT    IDENTITY(1,1) NOT NULL,
    proposition_id INT       NOT NULL,
    player_id      INT       NOT NULL,
    created_at     DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    checksum       NVARCHAR(64) NULL,
    CONSTRAINT PK_Vote PRIMARY KEY (vote_id),
    CONSTRAINT UQ_Vote_Prop_Player UNIQUE (proposition_id, player_id),
    CONSTRAINT FK_Vote_Proposition FOREIGN KEY (proposition_id) REFERENCES Proposition(proposition_id) ON DELETE CASCADE,
    CONSTRAINT FK_Vote_Player      FOREIGN KEY (player_id)      REFERENCES Player(player_id)
);

CREATE INDEX idx_vote_proposition ON Vote (proposition_id) INCLUDE (player_id);

CREATE TABLE Prediction (
    prediction_id    BIGINT        IDENTITY(1,1) NOT NULL,
    proposition_id   INT           NOT NULL,
    player_id        INT           NOT NULL,
    amount           DECIMAL(18,4) NOT NULL,
    currency_type_id INT           NOT NULL,
    direction        BIT           NOT NULL,   -- 1 = se cumple; 0 = no se cumple
    result           NVARCHAR(10)  NULL,       -- PENDING, WON, LOST
    created_at       DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    updated_at       DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    checksum         NVARCHAR(64)  NULL,
    CONSTRAINT PK_Prediction PRIMARY KEY (prediction_id),
    CONSTRAINT CK_Prediction_Amount CHECK (amount > 0),
    CONSTRAINT CK_Prediction_Result CHECK (result IS NULL OR result IN ('PENDING','WON','LOST')),
    CONSTRAINT FK_Prediction_Proposition FOREIGN KEY (proposition_id)   REFERENCES Proposition(proposition_id) ON DELETE CASCADE,
    CONSTRAINT FK_Prediction_Player      FOREIGN KEY (player_id)         REFERENCES Player(player_id),
    CONSTRAINT FK_Prediction_Currency    FOREIGN KEY (currency_type_id)  REFERENCES CurrencyType(currency_type_id)
);

CREATE INDEX idx_prediction_proposition
    ON Prediction (proposition_id)
    INCLUDE (player_id, direction, amount, currency_type_id, result);

CREATE INDEX idx_prediction_player
    ON Prediction (player_id, created_at DESC)
    INCLUDE (proposition_id, direction, result, amount);

CREATE INDEX idx_prediction_result_pending
    ON Prediction (result)
    INCLUDE (proposition_id, player_id, amount)
    WHERE result = 'PENDING';

CREATE TABLE PropositionEvidence (
    evidence_id       BIGINT        IDENTITY(1,1) NOT NULL,
    proposition_id    INT           NOT NULL,
    post_id           NVARCHAR(100) NULL,   -- ID del post en la red social
    evidence_url      NVARCHAR(500) NULL,
    evidence_type     NVARCHAR(20)  NOT NULL,  -- PHOTO, VIDEO, STORY, REEL, TWEET, POST
    social_network_id INT           NULL,
    created_at        DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    checksum          NVARCHAR(64)  NULL,
    CONSTRAINT PK_PropositionEvidence PRIMARY KEY (evidence_id),
    CONSTRAINT CK_PropositionEvidence_Type CHECK (evidence_type IN ('PHOTO','VIDEO','STORY','REEL','TWEET','POST')),
    CONSTRAINT FK_Evidence_Proposition FOREIGN KEY (proposition_id)   REFERENCES Proposition(proposition_id) ON DELETE CASCADE,
    CONSTRAINT FK_Evidence_Network     FOREIGN KEY (social_network_id) REFERENCES SocialNetwork(social_network_id)
);

CREATE INDEX idx_evidence_post ON PropositionEvidence (post_id);

-- ==============================================================================
-- 4. TRANSACCIONES
-- ==============================================================================

CREATE TABLE [Transaction] (
    transaction_id      BIGINT        IDENTITY(1,1) NOT NULL,
    player_id           INT           NOT NULL,
    currency_type_id    INT           NOT NULL,
    amount              DECIMAL(18,4) NOT NULL,           -- Positivo: ingreso; negativo: egreso
    running_balance     DECIMAL(18,4) NOT NULL,           -- Balance tras la transacción
    transaction_type_id INT           NOT NULL,
    reference_type      NVARCHAR(30)  NULL,               -- PROPOSITION, PREDICTION, ...
    reference_id        BIGINT        NULL,
    description         NVARCHAR(300) NULL,
    created_at          DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    checksum            NVARCHAR(64)  NULL,
    CONSTRAINT PK_Transaction PRIMARY KEY (transaction_id),
    CONSTRAINT FK_Transaction_Player          FOREIGN KEY (player_id)           REFERENCES Player(player_id),
    CONSTRAINT FK_Transaction_Currency        FOREIGN KEY (currency_type_id)    REFERENCES CurrencyType(currency_type_id),
    CONSTRAINT FK_Transaction_TransactionType FOREIGN KEY (transaction_type_id) REFERENCES TransactionType(transaction_type_id)
);

CREATE INDEX idx_transaction_player_currency
    ON [Transaction] (player_id, currency_type_id, created_at DESC)
    INCLUDE (amount, running_balance, transaction_type_id);

CREATE INDEX idx_transaction_reference
    ON [Transaction] (reference_type, reference_id)
    INCLUDE (player_id, amount, created_at);

-- ==============================================================================
-- 5. AUDITORÍA E IA
-- ==============================================================================

CREATE TABLE AIReviewLog (
    review_id            BIGINT        IDENTITY(1,1) NOT NULL,
    proposition_id       INT           NOT NULL,
    ai_model_id          INT           NOT NULL,
    ai_provider_id       INT           NOT NULL,
    review_result        NVARCHAR(20)  NOT NULL,   -- APPROVED, REJECTED, PENDING
    confidence_score     DECIMAL(5,4)  NULL,
    rejection_categories NVARCHAR(500) NULL,        -- JSON array
    request_payload      NVARCHAR(MAX) NULL,
    response_payload     NVARCHAR(MAX) NULL,
    review_details       NVARCHAR(MAX) NULL,
    reviewed_at          DATETIME2     NOT NULL,
    checksum             NVARCHAR(64)  NULL,
    CONSTRAINT PK_AIReviewLog PRIMARY KEY (review_id),
    CONSTRAINT CK_AIReviewLog_Result CHECK (review_result IN ('APPROVED','REJECTED','PENDING')),
    CONSTRAINT CK_AIReviewLog_RequestJSON CHECK (request_payload IS NULL OR ISJSON(request_payload) = 1),
    CONSTRAINT CK_AIReviewLog_ResponseJSON CHECK (response_payload IS NULL OR ISJSON(response_payload) = 1),
    CONSTRAINT FK_AIReviewLog_Proposition FOREIGN KEY (proposition_id) REFERENCES Proposition(proposition_id) ON DELETE CASCADE,
    CONSTRAINT FK_AIReviewLog_Model       FOREIGN KEY (ai_model_id)    REFERENCES AIModel(ai_model_id),
    CONSTRAINT FK_AIReviewLog_Provider    FOREIGN KEY (ai_provider_id) REFERENCES AIProvider(ai_provider_id)
);

CREATE TABLE GameEvent (
    event_id        BIGINT        IDENTITY(1,1) NOT NULL,
    proposition_id  INT           NULL,
    event_type_id   INT           NOT NULL,
    actor_player_id INT           NOT NULL,
    event_data      NVARCHAR(MAX) NULL,
    created_at      DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    checksum        NVARCHAR(64)  NULL,
    CONSTRAINT PK_GameEvent PRIMARY KEY (event_id),
    CONSTRAINT CK_GameEvent_JSON CHECK (event_data IS NULL OR ISJSON(event_data) = 1),
    CONSTRAINT FK_GameEvent_Proposition FOREIGN KEY (proposition_id)  REFERENCES Proposition(proposition_id) ON DELETE CASCADE,
    CONSTRAINT FK_GameEvent_EventType   FOREIGN KEY (event_type_id)   REFERENCES EventType(event_type_id),
    CONSTRAINT FK_GameEvent_Actor       FOREIGN KEY (actor_player_id) REFERENCES Player(player_id)
);

CREATE INDEX idx_gameevent_proposition
    ON GameEvent (proposition_id, created_at DESC)
    INCLUDE (event_type_id, actor_player_id);

CREATE INDEX idx_gameevent_event_type
    ON GameEvent (event_type_id, created_at DESC)
    INCLUDE (proposition_id, actor_player_id);

CREATE TABLE ProcessLog (
    log_id             BIGINT        IDENTITY(1,1) NOT NULL,
    sp_name            NVARCHAR(100) NOT NULL,
    action_description NVARCHAR(500) NULL,
    affected_table     NVARCHAR(50)  NULL,
    affected_record_id BIGINT        NULL,
    status             NVARCHAR(15)  NOT NULL,   -- SUCCESS, ERROR, PARTIAL
    error_detail       NVARCHAR(MAX) NULL,
    executed_at        DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    executed_by        NVARCHAR(100) NULL,
    CONSTRAINT PK_ProcessLog PRIMARY KEY (log_id),
    CONSTRAINT CK_ProcessLog_Status CHECK (status IN ('SUCCESS','ERROR','PARTIAL'))
);

CREATE TABLE PropositionAudit (
    audit_id       BIGINT        IDENTITY(1,1) NOT NULL,
    proposition_id INT           NOT NULL,
    field_name     NVARCHAR(50)  NOT NULL,
    old_value      NVARCHAR(MAX) NULL,
    new_value      NVARCHAR(MAX) NULL,
    changed_by     NVARCHAR(100) NOT NULL,
    changed_at     DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    checksum       NVARCHAR(64)  NULL,
    CONSTRAINT PK_PropositionAudit PRIMARY KEY (audit_id),
    CONSTRAINT FK_PropositionAudit_Proposition FOREIGN KEY (proposition_id) REFERENCES Proposition(proposition_id) ON DELETE CASCADE
);

CREATE INDEX idx_proposition_audit_prop_date
    ON PropositionAudit (proposition_id, changed_at DESC);

CREATE INDEX idx_proposition_audit_changed_by
    ON PropositionAudit (changed_by, changed_at DESC);

CREATE INDEX idx_proposition_audit_field
    ON PropositionAudit (field_name, changed_at DESC);

-- ==============================================================================
-- 6. TRIGGER DE AUDITORÍA SOBRE Proposition
-- Registra en PropositionAudit cada UPDATE sobre campos clave.
-- ==============================================================================
GO
CREATE OR ALTER TRIGGER tr_proposition_audit
ON Proposition
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @changedBy NVARCHAR(100) = SYSTEM_USER;

    -- status_id
    IF UPDATE(status_id)
    INSERT INTO PropositionAudit (proposition_id, field_name, old_value, new_value, changed_by, changed_at)
    SELECT d.proposition_id, 'status_id',
           CAST(d.status_id AS NVARCHAR(MAX)),
           CAST(i.status_id AS NVARCHAR(MAX)),
           @changedBy, GETUTCDATE()
    FROM deleted d JOIN inserted i ON d.proposition_id = i.proposition_id
    WHERE d.status_id <> i.status_id;

    -- is_accepted_by_target
    IF UPDATE(is_accepted_by_target)
    INSERT INTO PropositionAudit (proposition_id, field_name, old_value, new_value, changed_by, changed_at)
    SELECT d.proposition_id, 'is_accepted_by_target',
           CAST(d.is_accepted_by_target AS NVARCHAR(MAX)),
           CAST(i.is_accepted_by_target AS NVARCHAR(MAX)),
           @changedBy, GETUTCDATE()
    FROM deleted d JOIN inserted i ON d.proposition_id = i.proposition_id
    WHERE d.is_accepted_by_target <> i.is_accepted_by_target;

    -- is_fulfilled
    IF UPDATE(is_fulfilled)
    INSERT INTO PropositionAudit (proposition_id, field_name, old_value, new_value, changed_by, changed_at)
    SELECT d.proposition_id, 'is_fulfilled',
           CAST(d.is_fulfilled AS NVARCHAR(MAX)),
           CAST(i.is_fulfilled AS NVARCHAR(MAX)),
           @changedBy, GETUTCDATE()
    FROM deleted d JOIN inserted i ON d.proposition_id = i.proposition_id
    WHERE ISNULL(d.is_fulfilled,-1) <> ISNULL(i.is_fulfilled,-1);

    -- ai_review_result
    IF UPDATE(ai_review_result)
    INSERT INTO PropositionAudit (proposition_id, field_name, old_value, new_value, changed_by, changed_at)
    SELECT d.proposition_id, 'ai_review_result',
           d.ai_review_result, i.ai_review_result,
           @changedBy, GETUTCDATE()
    FROM deleted d JOIN inserted i ON d.proposition_id = i.proposition_id
    WHERE ISNULL(d.ai_review_result,'') <> ISNULL(i.ai_review_result,'');
END;
GO
