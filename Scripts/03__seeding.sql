-- ==============================================================================
-- V3__seeding_gathel.sql
-- Gathel Gaming Platform — Seeding Masivo
-- Genera: 1000 jugadores, 5000 proposiciones, 250000 eventos, predicciones y pagos
-- Basado en design.dbml v2.0 | Versionado con Flyway | SQL Server 2022
-- ==============================================================================
-- Ejecutar DESPUÉS de V1__init_gathel.sql y V2__stored_procedures_gathel.sql
-- Es idempotente: verifica existencia antes de insertar.
-- ==============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ==============================================================================
-- SECCIÓN 0: Catálogos base del sistema
-- ==============================================================================

-- PropositionStatus
IF NOT EXISTS (SELECT 1 FROM dbo.PropositionStatus WHERE status_code = 'PENDING')
BEGIN
    INSERT INTO dbo.PropositionStatus (status_code, description, enabled) VALUES
        ('PENDING',            'En revisión por inteligencia artificial',            1),
        ('ACTIVE',             'Aprobada, votación y predicciones habilitadas',      1),
        ('PREDICTION_CLOSED',  'Período de predicciones cerrado',                    1),
        ('RESOLVED',           'Resultado validado y recompensas distribuidas',      1),
        ('REJECTED',           'Rechazada por moderación IA o por el sujeto',       1),
        ('CANCELLED',          'Cancelada antes de resolución',                      1);
    PRINT 'PropositionStatus insertados.';
END

-- SocialNetwork
IF NOT EXISTS (SELECT 1 FROM dbo.SocialNetwork WHERE network_code = 'INSTAGRAM')
BEGIN
    INSERT INTO dbo.SocialNetwork (network_code, network_name, url, enabled) VALUES
        ('INSTAGRAM', 'Instagram',   'https://www.instagram.com', 1),
        ('TIKTOK',    'TikTok',      'https://www.tiktok.com',    1),
        ('TWITTER',   'X (Twitter)', 'https://www.twitter.com',   1),
        ('YOUTUBE',   'YouTube',     'https://www.youtube.com',   1);
    PRINT 'SocialNetwork insertados.';
END

-- CurrencyType
IF NOT EXISTS (SELECT 1 FROM dbo.CurrencyType WHERE currency_code = 'POINTS')
BEGIN
    INSERT INTO dbo.CurrencyType (currency_code, currency_name, currency_symbol, is_virtual, decimal_places, enabled) VALUES
        ('POINTS', 'Puntos Gathel', 'PTS', 1, 0, 1),
        ('USD',    'US Dollar',     '$',   0, 2, 1),
        ('CRC',    'Colón CR',      '₡',  0, 2, 1),
        ('EUR',    'Euro',          '€',   0, 2, 1);
    PRINT 'CurrencyType insertados.';
END

-- ExchangeRate (referencia base)
IF NOT EXISTS (SELECT 1 FROM dbo.ExchangeRate WHERE currency_type_id = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'CRC'))
BEGIN
    DECLARE @usd_id INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'USD');
    DECLARE @crc_id INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'CRC');
    DECLARE @eur_id INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'EUR');

    INSERT INTO dbo.ExchangeRate (currency_type_id, rate_to_usd, effective_date) VALUES
        (@crc_id, 0.00191, GETUTCDATE()),
        (@eur_id, 1.08,    GETUTCDATE());
    PRINT 'ExchangeRate insertados.';
END

-- TransactionType
IF NOT EXISTS (SELECT 1 FROM dbo.TransactionType WHERE type_code = 'DEPOSIT')
BEGIN
    INSERT INTO dbo.TransactionType (type_code, description, applies_to, enabled) VALUES
        ('DEPOSIT',    'Depósito de dinero real',             'MONEY',  1),
        ('WITHDRAWAL', 'Retiro de dinero real',               'MONEY',  1),
        ('WAGER',      'Apuesta en predicción',               'BOTH',   1),
        ('WINNING',    'Premio por predicción ganadora',      'BOTH',   1),
        ('COMMISSION', 'Comisión de plataforma o creador',    'BOTH',   1),
        ('REFUND',     'Reembolso por proposición no resuelta','BOTH',  1),
        ('PENALTY',    'Penalización de puntos',              'POINTS', 1);
    PRINT 'TransactionType insertados.';
END

-- EventType
IF NOT EXISTS (SELECT 1 FROM dbo.EventType WHERE type_code = 'PROPOSITION_CREATED')
BEGIN
    INSERT INTO dbo.EventType (type_code, description, enabled) VALUES
        ('PROPOSITION_CREATED',   'Proposición creada',                        1),
        ('AI_APPROVED',           'Proposición aprobada por IA',               1),
        ('AI_REJECTED',           'Proposición rechazada por IA',              1),
        ('PROPOSITION_ACCEPTED',  'Sujeto aceptó la proposición',              1),
        ('PROPOSITION_REJECTED',  'Sujeto rechazó la proposición',             1),
        ('VOTE_CAST',             'Voto registrado',                            1),
        ('PREDICTION_MADE',       'Predicción realizada',                      1),
        ('PREDICTIONS_CLOSED',    'Cierre del período de predicciones',        1),
        ('PROPOSITION_RESOLVED',  'Resultado validado y recompensas distribuidas', 1),
        ('EVIDENCE_SUBMITTED',    'Evidencia del resultado enviada',            1),
        ('SYSTEM_MONITORING',     'Verificación periódica del sistema',         1),
        ('NOTIFICATION_SENT',     'Notificación enviada a participantes',       1),
        ('SOCIAL_SYNC',           'Sincronización de redes sociales',           1);
    PRINT 'EventType insertados.';
END

-- AIProvider
IF NOT EXISTS (SELECT 1 FROM dbo.AIProvider WHERE provider_code = 'ANTHROPIC')
BEGIN
    INSERT INTO dbo.AIProvider (provider_code, provider_name, enabled) VALUES
        ('ANTHROPIC', 'Anthropic', 1),
        ('OPENAI',    'OpenAI',    1),
        ('GOOGLE',    'Google AI', 1);
    PRINT 'AIProvider insertados.';
END

-- AIModel
IF NOT EXISTS (SELECT 1 FROM dbo.AIModel WHERE model_code = 'CLAUDE_SONNET_46')
BEGIN
    INSERT INTO dbo.AIModel (model_code, model_name, version, enabled) VALUES
        ('CLAUDE_SONNET_46', 'Claude Sonnet', '4.6',      1),
        ('CLAUDE_OPUS_46',   'Claude Opus',   '4.6',      1),
        ('GPT4O',            'GPT-4o',        '2024-11',  1),
        ('GEMINI_15_PRO',    'Gemini',        '1.5-pro',  1);
    PRINT 'AIModel insertados.';
END
GO

-- ==============================================================================
-- SECCIÓN 1: 1000 JUGADORES
-- ==============================================================================
DECLARE @i            INT = 1;
DECLARE @total_players INT = 1000;

DECLARE @points_type_id  INT = (SELECT currency_type_id   FROM dbo.CurrencyType    WHERE currency_code = 'POINTS');
DECLARE @deposit_type_id INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code     = 'DEPOSIT');

IF (SELECT COUNT(1) FROM dbo.Player WHERE username LIKE 'player\_%' ESCAPE '\') >= @total_players
BEGIN
    PRINT 'Jugadores ya sembrados. Se omite la sección.';
    GOTO skip_players;
END

DECLARE @first_names TABLE (idx INT IDENTITY(1,1), name NVARCHAR(50));
INSERT INTO @first_names (name) VALUES
    ('Sofia'),('Diego'),('Valeria'),('Carlos'),('Daniela'),('Miguel'),('Gabriela'),('Andres'),
    ('Camila'),('Luis'),('Isabella'),('Juan'),('Laura'),('Roberto'),('Mariana'),('Alejandro'),
    ('Paula'),('Fernando'),('Ana'),('Ricardo'),('Natalia'),('Sergio'),('Monica'),('Eduardo'),
    ('Paola'),('Jorge'),('Diana'),('Marcos'),('Elena'),('Antonio'),('Sara'),('Victor'),
    ('Fernanda'),('Pablo'),('Lucia'),('Hector'),('Adriana'),('Oscar'),('Claudia'),('Manuel');

DECLARE @last_names TABLE (idx INT IDENTITY(1,1), name NVARCHAR(50));
INSERT INTO @last_names (name) VALUES
    ('Garcia'),('Rodriguez'),('Martinez'),('Lopez'),('Gonzalez'),('Perez'),('Sanchez'),('Ramirez'),
    ('Torres'),('Flores'),('Rivera'),('Gomez'),('Diaz'),('Reyes'),('Cruz'),('Morales'),('Ortiz'),
    ('Gutierrez'),('Chavez'),('Ruiz'),('Mendez'),('Castro'),('Vargas'),('Rojas'),('Herrera'),
    ('Medina'),('Aguilar'),('Jimenez'),('Moreno'),('Soto'),('Navarro'),('Ramos'),('Vega'),
    ('Campos'),('Fuentes'),('Rios'),('Cabrera'),('Silva'),('Delgado'),('Nunez');

DECLARE @fn_count  INT = (SELECT COUNT(1) FROM @first_names);
DECLARE @ln_count  INT = (SELECT COUNT(1) FROM @last_names);

DECLARE @username      NVARCHAR(50);
DECLARE @email         NVARCHAR(150);
DECLARE @fn            NVARCHAR(50);
DECLARE @ln            NVARCHAR(50);
DECLARE @welcome_pts   BIGINT;
DECLARE @new_player_id INT;
DECLARE @enabled_flag  BIT;

-- Tabla temporal para mapear seq → player_id
CREATE TABLE #PlayerMap (seq INT, player_id INT);

WHILE @i <= @total_players
BEGIN
    SET @fn       = (SELECT name FROM @first_names WHERE idx = (@i % @fn_count) + 1);
    SET @ln       = (SELECT name FROM @last_names  WHERE idx = (@i % @ln_count) + 1);
    SET @username = LOWER(@fn) + '_' + LOWER(@ln) + '_' + CAST(@i AS NVARCHAR(10));
    SET @email    = LOWER(@fn) + '.' + LOWER(@ln) + CAST(@i AS NVARCHAR(10)) + '@gathel.dev';
    SET @welcome_pts = 100 + (ABS(CHECKSUM(NEWID())) % 900);  -- 100-999 pts iniciales

    -- 5% suspendidos (enabled=0)
    SET @enabled_flag = CASE WHEN @i % 20 = 0 THEN 0 ELSE 1 END;

    INSERT INTO dbo.Player (username, email, password_hash, display_name,
                             balance_points, balance_version, enabled, created_at, updated_at)
    VALUES (
        @username, @email,
        CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', @username + 'gathel_salt_' + CAST(@i AS NVARCHAR)), 2),
        @fn + ' ' + @ln,
        @welcome_pts, 1, @enabled_flag,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETUTCDATE()),
        GETUTCDATE()
    );

    SET @new_player_id = SCOPE_IDENTITY();

    -- Transacción de puntos de bienvenida
    INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                   transaction_type_id, reference_type, reference_id,
                                   description, created_at)
    VALUES (@new_player_id, @points_type_id, @welcome_pts, @welcome_pts,
            @deposit_type_id, 'PLAYER', @new_player_id,
            'Puntos de bienvenida', GETUTCDATE());

    -- Depósito inicial USD (60% de jugadores)
    IF @i % 5 < 3
    BEGIN
        DECLARE @usd_amount DECIMAL(18,4) = CAST(ABS(CHECKSUM(NEWID())) % 500 AS DECIMAL(18,4));
        DECLARE @usd_type_id INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'USD');
        IF @usd_amount > 0
            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@new_player_id, @usd_type_id, @usd_amount, @usd_amount,
                    @deposit_type_id, 'PLAYER', @new_player_id,
                    'Depósito inicial USD', GETUTCDATE());
    END

    INSERT INTO #PlayerMap (seq, player_id) VALUES (@i, @new_player_id);

    SET @i = @i + 1;
END

PRINT CONCAT('Players insertados: ', @total_players);

skip_players:
GO

-- ==============================================================================
-- SECCIÓN 2: SOCIAL ACCOUNTS
-- Asocia 1 red social por jugador activo.
-- ==============================================================================
DECLARE @si  INT = 1;
DECLARE @pid INT;
DECLARE @plat_count INT = (SELECT COUNT(1) FROM dbo.SocialNetwork WHERE enabled = 1);

DECLARE @social_players TABLE (seq INT IDENTITY(1,1), player_id INT, username NVARCHAR(50));
INSERT INTO @social_players SELECT TOP 1000 player_id, username FROM dbo.Player ORDER BY player_id;

WHILE @si <= (SELECT MAX(seq) FROM @social_players)
BEGIN
    SELECT @pid = player_id FROM @social_players WHERE seq = @si;

    DECLARE @net_id INT = (@si % @plat_count) + 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.SocialAccount WHERE player_id = @pid AND social_network_id = @net_id)
    BEGIN
        INSERT INTO dbo.SocialAccount (player_id, social_network_id, account_username,
                                        is_verified, enabled, created_at, updated_at)
        VALUES (@pid, @net_id,
                (SELECT username FROM dbo.Player WHERE player_id = @pid),
                CASE WHEN @si % 3 = 0 THEN 1 ELSE 0 END,
                1, GETUTCDATE(), GETUTCDATE());
    END

    SET @si = @si + 1;
END
PRINT 'SocialAccount insertados.';
GO

-- ==============================================================================
-- SECCIÓN 3: 5000 PROPOSICIONES
-- Distribución realista de estados.
-- ==============================================================================
DECLARE @total_props  INT = 5000;
DECLARE @pj           INT = 1;

DECLARE @status_pending    INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'PENDING');
DECLARE @status_active     INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE');
DECLARE @status_closed     INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED');
DECLARE @status_resolved   INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED');
DECLARE @status_rejected   INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'REJECTED');
DECLARE @status_cancelled  INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'CANCELLED');

DECLARE @prop_texts TABLE (idx INT IDENTITY(1,1), title NVARCHAR(150), descr NVARCHAR(500));
INSERT INTO @prop_texts (title, descr) VALUES
    ('¿Correrá un maratón?',           'El jugador indicó que entrena para una maratón próxima.'),
    ('¿Publicará 10 posts este mes?',   'Sube contenido regularmente a Instagram.'),
    ('¿Viajará fuera del país?',        'Tiene planes de viaje en el horizonte próximo.'),
    ('¿Irá al gimnasio 5 veces?',       'Ha publicado sobre su rutina de ejercicios.'),
    ('¿Adoptará una mascota?',          'Ha mostrado interés en adoptar un perro.'),
    ('¿Aprenderá a cocinar nuevo?',     'Publicó que quiere aprender repostería.'),
    ('¿Leerá un libro completo?',       'Tiene un reto de lectura este mes.'),
    ('¿Completará un curso en línea?',  'Se inscribió en un curso de programación.'),
    ('¿Asistirá a evento musical?',     'Tiene boletos para un concierto.'),
    ('¿Cambiará su foto de perfil?',    'Comentó que quiere renovar su imagen.'),
    ('¿Hará ejercicio outdoor?',        'Publicó que quiere correr en el parque.'),
    ('¿Iniciará un emprendimiento?',    'Ha hablado de ideas de negocio.'),
    ('¿Visitará a su familia?',         'Vive lejos y planea visitarlos.'),
    ('¿Participará en competencia?',    'Se inscribió en un torneo local.'),
    ('¿Hará una donación este mes?',    'Sigue varias causas benéficas.'),
    ('¿Aprenderá un idioma nuevo?',     'Tiene la app de idiomas instalada.'),
    ('¿Realizará cambio de look?',      'Ha consultado sobre cortes de cabello.'),
    ('¿Compartirá un logro académico?', 'Está terminando un programa de estudios.'),
    ('¿Completará los 10k pasos?',      'Tiene smartwatch y sigue su actividad.'),
    ('¿Organizará reunión social?',     'Sus amigos esperan un encuentro pronto.'),
    ('¿Publicará un reel viral?',       'Crea contenido creativo con frecuencia.'),
    ('¿Terminará su proyecto personal?','Tiene un proyecto artístico pendiente.'),
    ('¿Hará voluntariado este mes?',    'Sigue organizaciones comunitarias.'),
    ('¿Ganará torneo de videojuegos?',  'Es jugador competitivo online.'),
    ('¿Publicará contenido cada día?',  'Ha retado a publicar contenido diario.');

DECLARE @prop_text_count INT = (SELECT COUNT(1) FROM @prop_texts);

DECLARE @active_players TABLE (seq INT IDENTITY(1,1), player_id INT);
INSERT INTO @active_players
    SELECT TOP 900 player_id FROM dbo.Player
    WHERE enabled = 1
    ORDER BY player_id;

DECLARE @active_player_count INT = (SELECT COUNT(1) FROM @active_players);

CREATE TABLE #PropMap (
    seq             INT,
    proposition_id  INT,
    creator_id      INT,
    target_id       INT,
    status_id       INT,
    created_at      DATETIME2,
    prediction_ends_at DATETIME2
);

DECLARE @prop_status      INT;
DECLARE @creator_seq      INT;
DECLARE @target_seq       INT;
DECLARE @creator_id       INT;
DECLARE @target_id        INT;
DECLARE @prop_title       NVARCHAR(150);
DECLARE @prop_descr       NVARCHAR(500);
DECLARE @p_created_at     DATETIME2;
DECLARE @p_voting_ends    DATETIME2;
DECLARE @p_pred_ends      DATETIME2;
DECLARE @p_accepted       BIT;
DECLARE @p_fulfilled      BIT;
DECLARE @p_resolved_at    DATETIME2;
DECLARE @ai_result        NVARCHAR(20);
DECLARE @new_prop_id      INT;
DECLARE @rnd              INT;

WHILE @pj <= @total_props
BEGIN
    -- Distribución de estados:
    -- 40% resolved | 20% closed | 20% active | 10% pending | 5% rejected | 5% cancelled
    SET @rnd = @pj % 100;
    IF      @rnd < 40 SET @prop_status = @status_resolved;
    ELSE IF @rnd < 60 SET @prop_status = @status_closed;
    ELSE IF @rnd < 80 SET @prop_status = @status_active;
    ELSE IF @rnd < 90 SET @prop_status = @status_pending;
    ELSE IF @rnd < 95 SET @prop_status = @status_rejected;
    ELSE               SET @prop_status = @status_cancelled;

    SET @creator_seq = (@pj % @active_player_count) + 1;
    SELECT @creator_id = player_id FROM @active_players WHERE seq = @creator_seq;

    -- Sujeto diferente al creador (70% con sujeto; 30% deja sujeto como se puede)
    SET @target_seq = ((@pj + 5) % @active_player_count) + 1;
    SELECT @target_id = player_id FROM @active_players WHERE seq = @target_seq;
    IF @target_id = @creator_id
    BEGIN
        SET @target_seq = ((@pj + 10) % @active_player_count) + 1;
        SELECT @target_id = player_id FROM @active_players WHERE seq = @target_seq;
    END

    SELECT @prop_title = title, @prop_descr = descr
    FROM @prop_texts WHERE idx = (@pj % @prop_text_count) + 1;

    -- Asignar la variante del texto con índice del jugador para hacerlos únicos
    SET @prop_title = LEFT(@prop_title + ' #' + CAST(@pj AS NVARCHAR), 150);

    -- Timestamps coherentes según estado final
    IF @prop_status = @status_resolved
    BEGIN
        SET @p_created_at  = DATEADD(DAY, -(30 + ABS(CHECKSUM(NEWID())) % 335), GETUTCDATE());
        SET @p_voting_ends = DATEADD(HOUR, 24, @p_created_at);
        SET @p_pred_ends   = DATEADD(DAY,  1 + ABS(CHECKSUM(NEWID())) % 7, @p_voting_ends);
        SET @p_accepted    = 1;
        SET @ai_result     = 'APPROVED';
        SET @p_fulfilled   = CASE WHEN @pj % 3 > 0 THEN 1 ELSE 0 END;
        SET @p_resolved_at = DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 24, @p_pred_ends);
    END
    ELSE IF @prop_status = @status_closed
    BEGIN
        SET @p_created_at  = DATEADD(DAY, -(5 + ABS(CHECKSUM(NEWID())) % 20), GETUTCDATE());
        SET @p_voting_ends = DATEADD(HOUR, 24, @p_created_at);
        SET @p_pred_ends   = DATEADD(HOUR, -1, GETUTCDATE());
        SET @p_accepted    = 1;
        SET @ai_result     = 'APPROVED';
        SET @p_fulfilled   = NULL;
        SET @p_resolved_at = NULL;
    END
    ELSE IF @prop_status = @status_active
    BEGIN
        SET @p_created_at  = DATEADD(HOUR, -(ABS(CHECKSUM(NEWID())) % 48), GETUTCDATE());
        SET @p_voting_ends = DATEADD(HOUR,  ABS(CHECKSUM(NEWID())) % 12, @p_created_at);
        SET @p_pred_ends   = DATEADD(HOUR,  6 + ABS(CHECKSUM(NEWID())) % 72, GETUTCDATE());
        SET @p_accepted    = 1;
        SET @ai_result     = 'APPROVED';
        SET @p_fulfilled   = NULL;
        SET @p_resolved_at = NULL;
    END
    ELSE
    BEGIN
        SET @p_created_at  = DATEADD(HOUR, -(ABS(CHECKSUM(NEWID())) % 24), GETUTCDATE());
        SET @p_voting_ends = DATEADD(HOUR,  12, @p_created_at);
        SET @p_pred_ends   = NULL;
        SET @p_accepted    = 0;
        SET @ai_result     = CASE WHEN @prop_status = @status_rejected THEN 'REJECTED' ELSE 'PENDING' END;
        SET @p_fulfilled   = NULL;
        SET @p_resolved_at = NULL;
    END

    INSERT INTO dbo.Proposition (
        creator_player_id, target_player_id, title, description,
        status_id, ai_review_result, voting_ends_at, prediction_ends_at,
        is_accepted_by_target, is_fulfilled, resolved_at,
        enabled, created_at, updated_at
    )
    VALUES (
        @creator_id, @target_id, @prop_title, @prop_descr,
        @prop_status, @ai_result, @p_voting_ends, @p_pred_ends,
        @p_accepted, @p_fulfilled, @p_resolved_at,
        1, @p_created_at, GETUTCDATE()
    );

    SET @new_prop_id = SCOPE_IDENTITY();

    INSERT INTO #PropMap (seq, proposition_id, creator_id, target_id,
                           status_id, created_at, prediction_ends_at)
    VALUES (@pj, @new_prop_id, @creator_id, @target_id,
            @prop_status, @p_created_at, @p_pred_ends);

    SET @pj = @pj + 1;
END

PRINT CONCAT('Propositions insertadas: ', @total_props);
GO

-- ==============================================================================
-- SECCIÓN 4: VOTES sobre proposiciones ACTIVE, PREDICTION_CLOSED y RESOLVED
-- ==============================================================================
DECLARE @vote_props TABLE (seq INT IDENTITY(1,1), proposition_id INT, creator_id INT);
INSERT INTO @vote_props
    SELECT pm.proposition_id, pm.creator_id
    FROM #PropMap pm
    WHERE pm.status_id IN (
        SELECT status_id FROM dbo.PropositionStatus
        WHERE status_code IN ('ACTIVE','PREDICTION_CLOSED','RESOLVED')
    );

DECLARE @voter_pool TABLE (seq INT IDENTITY(1,1), player_id INT);
INSERT INTO @voter_pool SELECT TOP 500 player_id FROM dbo.Player ORDER BY player_id;
DECLARE @voter_pool_size INT = (SELECT COUNT(1) FROM @voter_pool);

DECLARE @vi         INT = 1;
DECLARE @vp_count   INT = (SELECT COUNT(1) FROM @vote_props);
DECLARE @vp_id      INT;
DECLARE @v_creator  INT;
DECLARE @votes_per  INT;
DECLARE @vj         INT;
DECLARE @voter_seq  INT;
DECLARE @voter_id   INT;

WHILE @vi <= @vp_count
BEGIN
    SELECT @vp_id = proposition_id, @v_creator = creator_id FROM @vote_props WHERE seq = @vi;
    SET @votes_per = 3 + (ABS(CHECKSUM(NEWID())) % 12);
    SET @vj = 0;

    WHILE @vj < @votes_per
    BEGIN
        SET @voter_seq = ((@vi * 7 + @vj * 13) % @voter_pool_size) + 1;
        SELECT @voter_id = player_id FROM @voter_pool WHERE seq = @voter_seq;

        IF @voter_id <> @v_creator AND
           NOT EXISTS (SELECT 1 FROM dbo.Vote WHERE proposition_id = @vp_id AND player_id = @voter_id)
        BEGIN
            INSERT INTO dbo.Vote (proposition_id, player_id, created_at)
            VALUES (@vp_id, @voter_id, GETUTCDATE());
        END
        SET @vj = @vj + 1;
    END

    SET @vi = @vi + 1;
END
PRINT 'Vote insertados.';
GO

-- ==============================================================================
-- SECCIÓN 5: 250,000 GAME EVENTS
-- ~50 eventos por proposición (varía ±10).
-- ==============================================================================
DECLARE @evt_pending   INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'PENDING');
DECLARE @evt_active    INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'ACTIVE');
DECLARE @evt_closed    INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED');
DECLARE @evt_resolved  INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED');
DECLARE @evt_rejected  INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'REJECTED');
DECLARE @evt_cancelled INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'CANCELLED');

DECLARE @et_created   INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_CREATED');
DECLARE @et_approved  INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'AI_APPROVED');
DECLARE @et_rejected  INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'AI_REJECTED');
DECLARE @et_accepted  INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_ACCEPTED');
DECLARE @et_pred_made INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'PREDICTION_MADE');
DECLARE @et_p_closed  INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'PREDICTIONS_CLOSED');
DECLARE @et_resolved  INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'PROPOSITION_RESOLVED');
DECLARE @et_monitor   INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'SYSTEM_MONITORING');
DECLARE @et_notify    INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'NOTIFICATION_SENT');
DECLARE @et_social    INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'SOCIAL_SYNC');
DECLARE @et_vote      INT = (SELECT event_type_id FROM dbo.EventType WHERE type_code = 'VOTE_CAST');

DECLARE @evt_pool TABLE (seq INT IDENTITY(1,1), proposition_id INT, status_id INT,
                          created_at DATETIME2, creator_id INT, target_id INT);
INSERT INTO @evt_pool SELECT proposition_id, status_id, created_at, creator_id, target_id
FROM #PropMap ORDER BY seq;

DECLARE @total_evt_target  INT = 250000;
DECLARE @props_count       INT = (SELECT COUNT(1) FROM @evt_pool);
DECLARE @base_per_prop     INT = @total_evt_target / @props_count;
DECLARE @ei                INT = 1;
DECLARE @total_inserted    INT = 0;

DECLARE @ep_id        INT;
DECLARE @ep_status    INT;
DECLARE @ep_created   DATETIME2;
DECLARE @ep_creator   INT;
DECLARE @ep_target    INT;
DECLARE @evt_count    INT;
DECLARE @ej           INT;
DECLARE @evt_ts       DATETIME2;
DECLARE @delta_min    INT;
DECLARE @evt_type_id  INT;
DECLARE @note_idx     INT;
DECLARE @monitoring_types TABLE (idx INT IDENTITY(1,1), type_id INT);
INSERT INTO @monitoring_types VALUES (@et_monitor), (@et_notify), (@et_social), (@et_vote);
DECLARE @mon_count INT = 4;

WHILE @ei <= @props_count AND @total_inserted < @total_evt_target
BEGIN
    SELECT @ep_id = proposition_id, @ep_status = status_id,
           @ep_created = created_at, @ep_creator = creator_id, @ep_target = target_id
    FROM @evt_pool WHERE seq = @ei;

    SET @evt_count = @base_per_prop - 10 + (ABS(CHECKSUM(NEWID())) % 21);
    IF @total_inserted + @evt_count > @total_evt_target
        SET @evt_count = @total_evt_target - @total_inserted;

    SET @ej    = 0;
    SET @evt_ts = @ep_created;

    -- Evento 1: Creación → PENDING
    INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id,
                                event_data, created_at)
    VALUES (@ep_id, @et_created, @ep_creator,
            N'{"action":"proposition_created","status":"PENDING"}', @evt_ts);
    SET @total_inserted += 1; SET @ej += 1;

    -- Evento 2: AI aprueba o rechaza
    SET @delta_min = 2 + ABS(CHECKSUM(NEWID())) % 8;
    SET @evt_ts    = DATEADD(MINUTE, @delta_min, @evt_ts);
    SET @evt_type_id = CASE WHEN @ep_status = @evt_rejected THEN @et_rejected ELSE @et_approved END;
    INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
    VALUES (@ep_id, @evt_type_id, @ep_creator,
            N'{"action":"ai_review","confidence":0.95}', @evt_ts);
    SET @total_inserted += 1; SET @ej += 1;

    -- Evento 3: Sujeto acepta (si aplica)
    IF @ep_status IN (@evt_active, @evt_closed, @evt_resolved)
    BEGIN
        SET @delta_min = 30 + ABS(CHECKSUM(NEWID())) % 120;
        SET @evt_ts    = DATEADD(MINUTE, @delta_min, @evt_ts);
        INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
        VALUES (@ep_id, @et_accepted, @ep_target,
                N'{"action":"accepted_by_target"}', @evt_ts);
        SET @total_inserted += 1; SET @ej += 1;
    END

    -- Evento 4: Cierre de predicciones
    IF @ep_status IN (@evt_closed, @evt_resolved)
    BEGIN
        SET @delta_min = 1440 + ABS(CHECKSUM(NEWID())) % 4320;
        SET @evt_ts    = DATEADD(MINUTE, @delta_min, @evt_ts);
        INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
        VALUES (@ep_id, @et_p_closed, @ep_creator,
                N'{"action":"predictions_closed"}', @evt_ts);
        SET @total_inserted += 1; SET @ej += 1;
    END

    -- Evento 5: Resolución
    IF @ep_status = @evt_resolved
    BEGIN
        SET @delta_min = 60 + ABS(CHECKSUM(NEWID())) % 1440;
        SET @evt_ts    = DATEADD(MINUTE, @delta_min, @evt_ts);
        INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
        VALUES (@ep_id, @et_resolved, @ep_creator,
                N'{"action":"proposition_resolved","outcome":"validated"}', @evt_ts);
        SET @total_inserted += 1; SET @ej += 1;
    END

    -- Eventos adicionales de monitoreo para llegar al objetivo de ~50 por proposición
    WHILE @ej < @evt_count AND @total_inserted < @total_evt_target
    BEGIN
        SET @delta_min   = ABS(CHECKSUM(NEWID())) % 480;
        SET @evt_ts      = DATEADD(MINUTE, @delta_min, @evt_ts);
        SET @note_idx    = (@ej % @mon_count) + 1;
        SELECT @evt_type_id = type_id FROM @monitoring_types WHERE idx = @note_idx;

        INSERT INTO dbo.GameEvent (proposition_id, event_type_id, actor_player_id, event_data, created_at)
        VALUES (@ep_id, @evt_type_id, @ep_creator,
                CONCAT('{"action":"system_event","seq":', @ej, '}'), @evt_ts);

        SET @total_inserted += 1;
        SET @ej += 1;
    END

    SET @ei += 1;
END

PRINT CONCAT('GameEvent insertados: ', @total_inserted);
GO

-- ==============================================================================
-- SECCIÓN 6: PREDICTIONS sobre proposiciones ACTIVE, PREDICTION_CLOSED y RESOLVED
-- ==============================================================================
DECLARE @pred_props TABLE (seq INT IDENTITY(1,1), proposition_id INT, status_id INT);
INSERT INTO @pred_props
    SELECT pm.proposition_id, pm.status_id FROM #PropMap pm
    WHERE pm.status_id IN (
        SELECT status_id FROM dbo.PropositionStatus
        WHERE status_code IN ('ACTIVE','PREDICTION_CLOSED','RESOLVED')
    )
    ORDER BY pm.seq;

DECLARE @ppi          INT = 1;
DECLARE @pred_props_cnt INT = (SELECT COUNT(1) FROM @pred_props);
DECLARE @pp_id        INT;
DECLARE @pp_status    INT;
DECLARE @predictors_per INT;
DECLARE @ppj          INT;

DECLARE @pts_type_id  INT = (SELECT currency_type_id   FROM dbo.CurrencyType    WHERE currency_code = 'POINTS');
DECLARE @usd_type_id  INT = (SELECT currency_type_id   FROM dbo.CurrencyType    WHERE currency_code = 'USD');
DECLARE @wager_type_id INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code    = 'WAGER');
DECLARE @resolved_status INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED');
DECLARE @closed_status   INT = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'PREDICTION_CLOSED');

DECLARE @pred_pool TABLE (seq INT IDENTITY(1,1), player_id INT);
INSERT INTO @pred_pool SELECT TOP 1000 player_id FROM dbo.Player ORDER BY player_id;
DECLARE @pool_size INT = (SELECT COUNT(1) FROM @pred_pool);

DECLARE @predictor_seq INT;
DECLARE @predictor_id  INT;
DECLARE @use_points    BIT;
DECLARE @pred_curr_id  INT;
DECLARE @pred_amount   DECIMAL(18,4);
DECLARE @pred_dir      BIT;
DECLARE @pred_result   NVARCHAR(10);
DECLARE @run_bal       DECIMAL(18,4);
DECLARE @curr_pts      BIGINT;
DECLARE @new_pred_id   BIGINT;

WHILE @ppi <= @pred_props_cnt
BEGIN
    SELECT @pp_id = proposition_id, @pp_status = status_id FROM @pred_props WHERE seq = @ppi;
    SET @predictors_per = 5 + (ABS(CHECKSUM(NEWID())) % 46);
    SET @ppj = 0;

    WHILE @ppj < @predictors_per
    BEGIN
        SET @predictor_seq = ((@ppi * 17 + @ppj * 11) % @pool_size) + 1;
        SELECT @predictor_id = player_id FROM @pred_pool WHERE seq = @predictor_seq;

        -- 60% puntos, 40% USD
        SET @use_points = CASE WHEN (@ppj % 5 < 3) THEN 1 ELSE 0 END;
        SET @pred_curr_id = CASE WHEN @use_points = 1 THEN @pts_type_id ELSE @usd_type_id END;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Prediction
            WHERE proposition_id = @pp_id
              AND player_id = @predictor_id
              AND currency_type_id = @pred_curr_id
        )
        BEGIN
            SET @pred_amount = CASE WHEN @use_points = 1 THEN 1.0000
                                    ELSE CAST(1 + (ABS(CHECKSUM(NEWID())) % 50) AS DECIMAL(18,4)) END;
            SET @pred_dir    = CASE WHEN (@ppj % 20 < 11) THEN 1 ELSE 0 END;
            SET @pred_result = CASE WHEN @pp_status IN (@resolved_status) THEN
                                        CASE WHEN @pred_dir = 1 AND @ppj % 3 > 0 THEN 'WON'
                                             WHEN @pred_dir = 0 AND @ppj % 3 = 0 THEN 'WON'
                                             ELSE 'LOST' END
                                    ELSE 'PENDING' END;

            -- Verificar/descontar puntos
            IF @use_points = 1
            BEGIN
                SELECT @curr_pts = balance_points FROM dbo.Player WHERE player_id = @predictor_id;
                IF @curr_pts < 1 GOTO next_pred;

                UPDATE dbo.Player
                SET balance_points  = balance_points - 1,
                    balance_version = balance_version + 1,
                    last_transaction_date = GETUTCDATE(),
                    updated_at      = GETUTCDATE()
                WHERE player_id = @predictor_id;

                SET @run_bal = CAST(@curr_pts - 1 AS DECIMAL(18,4));
            END
            ELSE
            BEGIN
                SELECT TOP 1 @run_bal = running_balance
                FROM dbo.[Transaction]
                WHERE player_id = @predictor_id AND currency_type_id = @pred_curr_id
                ORDER BY created_at DESC;
                SET @run_bal = ISNULL(@run_bal, 0);
                IF @run_bal < @pred_amount GOTO next_pred;
                SET @run_bal = @run_bal - @pred_amount;
            END

            INSERT INTO dbo.Prediction (proposition_id, player_id, amount, currency_type_id,
                                         direction, result, created_at, updated_at)
            VALUES (@pp_id, @predictor_id, @pred_amount, @pred_curr_id,
                    @pred_dir, @pred_result, GETUTCDATE(), GETUTCDATE());
            SET @new_pred_id = SCOPE_IDENTITY();

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@predictor_id, @pred_curr_id, -@pred_amount, @run_bal,
                    @wager_type_id, 'PREDICTION', @new_pred_id,
                    CONCAT('Apuesta en proposición #', @pp_id), GETUTCDATE());
        END

        next_pred:
        SET @ppj += 1;
    END

    SET @ppi += 1;
END
PRINT 'Predictions insertadas.';
GO

-- ==============================================================================
-- SECCIÓN 7: PROPOSAL EVIDENCE para proposiciones RESOLVED
-- ==============================================================================
DECLARE @ev_props TABLE (seq INT IDENTITY(1,1), proposition_id INT, target_id INT);
INSERT INTO @ev_props
    SELECT pm.proposition_id, pm.target_id FROM #PropMap pm
    WHERE pm.status_id = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED')
    ORDER BY pm.seq;

DECLARE @ev_count INT = (SELECT COUNT(1) FROM @ev_props);
DECLARE @exi      INT = 1;
DECLARE @ex_prop  INT;
DECLARE @ex_target INT;

DECLARE @ev_types TABLE (idx INT IDENTITY(1,1), ev_type NVARCHAR(20));
INSERT INTO @ev_types VALUES ('PHOTO'),('VIDEO'),('STORY'),('REEL'),('POST');
DECLARE @ev_type_count INT = 5;

DECLARE @sn_ids TABLE (idx INT IDENTITY(1,1), sn_id INT);
INSERT INTO @sn_ids SELECT social_network_id FROM dbo.SocialNetwork WHERE enabled = 1;
DECLARE @sn_count INT = (SELECT COUNT(1) FROM @sn_ids);

WHILE @exi <= @ev_count
BEGIN
    SELECT @ex_prop = proposition_id, @ex_target = target_id FROM @ev_props WHERE seq = @exi;

    INSERT INTO dbo.PropositionEvidence (
        proposition_id, post_id, evidence_url, evidence_type, social_network_id, created_at
    )
    VALUES (
        @ex_prop,
        CONCAT('post_', @ex_prop, '_', @exi),
        CONCAT('https://social.example.com/post/', @ex_prop, '/', @exi),
        (SELECT ev_type FROM @ev_types WHERE idx = (@exi % @ev_type_count) + 1),
        (SELECT sn_id FROM @sn_ids WHERE idx = (@exi % @sn_count) + 1),
        GETUTCDATE()
    );

    SET @exi += 1;
END
PRINT 'PropositionEvidence insertadas.';
GO

-- ==============================================================================
-- SECCIÓN 8: AI REVIEW LOGS para proposiciones aprobadas y rechazadas
-- ==============================================================================
DECLARE @ai_review_props TABLE (seq INT IDENTITY(1,1), proposition_id INT, ai_result NVARCHAR(20));
INSERT INTO @ai_review_props
    SELECT proposition_id, ai_review_result
    FROM dbo.Proposition
    WHERE ai_review_result IN ('APPROVED','REJECTED')
    ORDER BY proposition_id;

DECLARE @ai_model_id    INT = (SELECT TOP 1 ai_model_id FROM dbo.AIModel WHERE enabled = 1 ORDER BY ai_model_id);
DECLARE @ai_provider_id INT = (SELECT TOP 1 ai_provider_id FROM dbo.AIProvider WHERE enabled = 1 ORDER BY ai_provider_id);
DECLARE @ari_count      INT = (SELECT COUNT(1) FROM @ai_review_props);
DECLARE @ari            INT = 1;
DECLARE @ari_prop_id    INT;
DECLARE @ari_result     NVARCHAR(20);

WHILE @ari <= @ari_count
BEGIN
    SELECT @ari_prop_id = proposition_id, @ari_result = ai_result
    FROM @ai_review_props WHERE seq = @ari;

    INSERT INTO dbo.AIReviewLog (
        proposition_id, ai_model_id, ai_provider_id, review_result,
        confidence_score, rejection_categories, reviewed_at
    )
    VALUES (
        @ari_prop_id, @ai_model_id, @ai_provider_id, @ari_result,
        CAST(0.7 + (ABS(CHECKSUM(NEWID())) % 30) / 100.0 AS DECIMAL(5,4)),
        CASE WHEN @ari_result = 'REJECTED' THEN '["violence","explicit"]' ELSE NULL END,
        GETUTCDATE()
    );

    SET @ari += 1;
END
PRINT 'AIReviewLog insertados.';
GO

-- ==============================================================================
-- SECCIÓN 9: PAGOS (recompensas, comisiones, reembolsos, penalizaciones)
-- Resuelve económicamente las proposiciones RESOLVED (40% de las 5000):
--   - Distribuye el pozo perdido entre ganadores (WINNING)
--   - Cobra comisión de plataforma y comisión del creador (COMMISSION)
--   - REFUND para proposiciones que no pudieron validarse
--   - PENALTY del 15% al jugador asociado si no se pudo validar
-- ==============================================================================
IF OBJECT_ID('tempdb..#PredPool') IS NOT NULL DROP TABLE #PredPool;
CREATE TABLE #PredPool (
    prediction_id    BIGINT,
    player_id        INT,
    amount           DECIMAL(18,4),
    currency_type_id INT,
    direction        BIT,
    result           NVARCHAR(10)
);

DECLARE @resolved_props TABLE (seq INT IDENTITY(1,1), proposition_id INT, creator_id INT, target_id INT);
INSERT INTO @resolved_props
    SELECT pm.proposition_id, pm.creator_id, pm.target_id
    FROM #PropMap pm
    WHERE pm.status_id = (SELECT status_id FROM dbo.PropositionStatus WHERE status_code = 'RESOLVED')
    ORDER BY pm.seq;

DECLARE @res_count        INT = (SELECT COUNT(1) FROM @resolved_props);
DECLARE @ri               INT = 1;
DECLARE @r_prop_id        INT;
DECLARE @r_creator_id     INT;
DECLARE @r_target_id      INT;
DECLARE @r_unresolvable   BIT;

DECLARE @pts_curr_id      INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'POINTS');
DECLARE @usd_curr_id      INT = (SELECT currency_type_id FROM dbo.CurrencyType WHERE currency_code = 'USD');
DECLARE @winning_type_id  INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code = 'WINNING');
DECLARE @commission_type_id INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code = 'COMMISSION');
DECLARE @refund_type_id   INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code = 'REFUND');
DECLARE @penalty_type_id  INT = (SELECT transaction_type_id FROM dbo.TransactionType WHERE type_code = 'PENALTY');

-- Porcentajes de comisión (plataforma y creador)
DECLARE @platform_pts_pct DECIMAL(5,2) = 5.00;
DECLARE @creator_pts_pct  DECIMAL(5,2) = 2.00;
DECLARE @platform_usd_pct DECIMAL(5,2) = 5.00;
DECLARE @creator_usd_pct  DECIMAL(5,2) = 2.00;

-- Variables de distribución
DECLARE @won_dir          BIT;
DECLARE @tot_pts          DECIMAL(18,4);
DECLARE @tot_usd          DECIMAL(18,4);
DECLARE @win_pts          DECIMAL(18,4);
DECLARE @win_usd          DECIMAL(18,4);
DECLARE @lose_pts         DECIMAL(18,4);
DECLARE @lose_usd         DECIMAL(18,4);
DECLARE @net_pts_pool     DECIMAL(18,4);
DECLARE @net_usd_pool     DECIMAL(18,4);

-- Cursor de distribución
DECLARE @d_pred_id        BIGINT;
DECLARE @d_player_id      INT;
DECLARE @d_amount         DECIMAL(18,4);
DECLARE @d_currency_id    INT;
DECLARE @d_direction      BIT;
DECLARE @d_earned         DECIMAL(18,4);
DECLARE @d_run_bal        DECIMAL(18,4);
DECLARE @d_curr_pts       BIGINT;

-- Variables de refund
DECLARE @rf_pred_id       BIGINT;
DECLARE @rf_player_id     INT;
DECLARE @rf_amount        DECIMAL(18,4);
DECLARE @rf_currency_id   INT;
DECLARE @rf_run_bal       DECIMAL(18,4);
DECLARE @rf_curr_pts      BIGINT;

-- Variables de comisión del creador
DECLARE @creator_pts_comm DECIMAL(18,4);
DECLARE @creator_usd_comm DECIMAL(18,4);
DECLARE @creator_curr_pts BIGINT;
DECLARE @creator_run_bal  DECIMAL(18,4);

-- Variables de penalización
DECLARE @pen_pct          DECIMAL(5,2) = 15.00;
DECLARE @pen_amount       BIGINT;
DECLARE @target_curr_pts  BIGINT;

WHILE @ri <= @res_count
BEGIN
    SELECT @r_prop_id = proposition_id, @r_creator_id = creator_id, @r_target_id = target_id
    FROM @resolved_props WHERE seq = @ri;

    -- 5% de las proposiciones RESOLVED se marcan como "no se pudo validar" (caso especial)
    SET @r_unresolvable = CASE WHEN @ri % 20 = 0 THEN 1 ELSE 0 END;

    -- Cargar predicciones pendientes de pago para esta proposición
    DELETE FROM #PredPool;
    INSERT INTO #PredPool (prediction_id, player_id, amount, currency_type_id, direction, result)
        SELECT prediction_id, player_id, amount, currency_type_id, direction, result
        FROM dbo.Prediction
        WHERE proposition_id = @r_prop_id;

    IF @r_unresolvable = 1
    BEGIN
        -- ====================================================================
        -- CASO ESPECIAL: imposible validar el resultado
        -- Todos los participantes recuperan su apuesta (REFUND).
        -- El jugador sujeto (target) pierde un 15% de sus puntos actuales.
        -- ====================================================================
        DECLARE cur_refund CURSOR LOCAL FAST_FORWARD FOR
            SELECT prediction_id, player_id, amount, currency_type_id FROM #PredPool;
        OPEN cur_refund;
        FETCH NEXT FROM cur_refund INTO @rf_pred_id, @rf_player_id, @rf_amount, @rf_currency_id;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @rf_currency_id = @pts_curr_id
            BEGIN
                UPDATE dbo.Player
                SET balance_points  = balance_points + @rf_amount,
                    balance_version = balance_version + 1,
                    last_transaction_date = GETUTCDATE(),
                    updated_at      = GETUTCDATE()
                WHERE player_id = @rf_player_id;

                SELECT @rf_curr_pts = balance_points FROM dbo.Player WHERE player_id = @rf_player_id;
                SET @rf_run_bal = CAST(@rf_curr_pts AS DECIMAL(18,4));
            END
            ELSE
            BEGIN
                SELECT TOP 1 @rf_run_bal = running_balance
                FROM dbo.[Transaction]
                WHERE player_id = @rf_player_id AND currency_type_id = @rf_currency_id
                ORDER BY created_at DESC;
                SET @rf_run_bal = ISNULL(@rf_run_bal, 0) + @rf_amount;
            END

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@rf_player_id, @rf_currency_id, @rf_amount, @rf_run_bal,
                    @refund_type_id, 'PROPOSITION', @r_prop_id,
                    CONCAT('Reembolso por imposibilidad de validar proposición #', @r_prop_id), GETUTCDATE());

            UPDATE dbo.Prediction SET result = 'PENDING', updated_at = GETUTCDATE()
            WHERE prediction_id = @rf_pred_id;

            FETCH NEXT FROM cur_refund INTO @rf_pred_id, @rf_player_id, @rf_amount, @rf_currency_id;
        END
        CLOSE cur_refund; DEALLOCATE cur_refund;

        -- Penalización del 15% sobre los puntos actuales del sujeto (target)
        SELECT @target_curr_pts = balance_points FROM dbo.Player WHERE player_id = @r_target_id;
        SET @pen_amount = FLOOR(@target_curr_pts * (@pen_pct / 100.0));

        IF @pen_amount > 0
        BEGIN
            UPDATE dbo.Player
            SET balance_points  = balance_points - @pen_amount,
                balance_version = balance_version + 1,
                last_transaction_date = GETUTCDATE(),
                updated_at      = GETUTCDATE()
            WHERE player_id = @r_target_id;

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@r_target_id, @pts_curr_id, -@pen_amount,
                    CAST(@target_curr_pts - @pen_amount AS DECIMAL(18,4)),
                    @penalty_type_id, 'PROPOSITION', @r_prop_id,
                    CONCAT('Penalización 15% por proposición no validable #', @r_prop_id), GETUTCDATE());
        END
    END
    ELSE
    BEGIN
        -- ====================================================================
        -- CASO NORMAL: distribución proporcional del pozo perdido entre
        -- ganadores, deduciendo comisión de plataforma y comisión del creador.
        -- ====================================================================

        -- Dirección ganadora: usamos la dirección con más predicciones marcadas como WON
        SELECT TOP 1 @won_dir = direction
        FROM #PredPool
        WHERE result = 'WON'
        GROUP BY direction
        ORDER BY COUNT(1) DESC;

        IF @won_dir IS NULL SET @won_dir = 1; -- fallback si no hay ganadores registrados

        SET @tot_pts  = ISNULL((SELECT SUM(amount) FROM #PredPool WHERE currency_type_id = @pts_curr_id), 0);
        SET @tot_usd  = ISNULL((SELECT SUM(amount) FROM #PredPool WHERE currency_type_id = @usd_curr_id), 0);
        SET @win_pts  = ISNULL((SELECT SUM(amount) FROM #PredPool WHERE currency_type_id = @pts_curr_id AND direction = @won_dir), 0);
        SET @win_usd  = ISNULL((SELECT SUM(amount) FROM #PredPool WHERE currency_type_id = @usd_curr_id AND direction = @won_dir), 0);
        SET @lose_pts = @tot_pts - @win_pts;
        SET @lose_usd = @tot_usd - @win_usd;

        -- Pozo neto perdido tras deducir comisiones (plataforma + creador)
        SET @net_pts_pool = @lose_pts * (1.0 - (@platform_pts_pct + @creator_pts_pct) / 100.0);
        SET @net_usd_pool = @lose_usd * (1.0 - (@platform_usd_pct + @creator_usd_pct) / 100.0);
        IF @net_pts_pool < 0 SET @net_pts_pool = 0;
        IF @net_usd_pool < 0 SET @net_usd_pool = 0;

        -- Distribuir a cada ganador: recupera su apuesta + parte proporcional del pozo neto
        DECLARE cur_dist CURSOR LOCAL FAST_FORWARD FOR
            SELECT prediction_id, player_id, amount, currency_type_id, direction
            FROM #PredPool WHERE result = 'WON';
        OPEN cur_dist;
        FETCH NEXT FROM cur_dist INTO @d_pred_id, @d_player_id, @d_amount, @d_currency_id, @d_direction;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @d_currency_id = @pts_curr_id AND @win_pts > 0
                SET @d_earned = @d_amount + FLOOR(@net_pts_pool * (@d_amount / @win_pts));
            ELSE IF @d_currency_id = @usd_curr_id AND @win_usd > 0
                SET @d_earned = @d_amount + (@net_usd_pool * (@d_amount / @win_usd));
            ELSE
                SET @d_earned = @d_amount; -- sin perdedores: solo recupera lo apostado

            IF @d_currency_id = @pts_curr_id
            BEGIN
                UPDATE dbo.Player
                SET balance_points  = balance_points + @d_earned,
                    balance_version = balance_version + 1,
                    last_transaction_date = GETUTCDATE(),
                    updated_at      = GETUTCDATE()
                WHERE player_id = @d_player_id;

                SELECT @d_curr_pts = balance_points FROM dbo.Player WHERE player_id = @d_player_id;
                SET @d_run_bal = CAST(@d_curr_pts AS DECIMAL(18,4));
            END
            ELSE
            BEGIN
                SELECT TOP 1 @d_run_bal = running_balance
                FROM dbo.[Transaction]
                WHERE player_id = @d_player_id AND currency_type_id = @d_currency_id
                ORDER BY created_at DESC;
                SET @d_run_bal = ISNULL(@d_run_bal, 0) + @d_earned;
            END

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@d_player_id, @d_currency_id, @d_earned, @d_run_bal,
                    @winning_type_id, 'PREDICTION', @d_pred_id,
                    CONCAT('Premio por predicción ganadora en proposición #', @r_prop_id), GETUTCDATE());

            FETCH NEXT FROM cur_dist INTO @d_pred_id, @d_player_id, @d_amount, @d_currency_id, @d_direction;
        END
        CLOSE cur_dist; DEALLOCATE cur_dist;

        -- Comisión del creador de la proposición (en PTS y USD, sobre el pozo perdido)
        SET @creator_pts_comm = FLOOR(@lose_pts * (@creator_pts_pct / 100.0));
        SET @creator_usd_comm = @lose_usd * (@creator_usd_pct / 100.0);

        IF @creator_pts_comm > 0
        BEGIN
            UPDATE dbo.Player
            SET balance_points  = balance_points + @creator_pts_comm,
                balance_version = balance_version + 1,
                last_transaction_date = GETUTCDATE(),
                updated_at      = GETUTCDATE()
            WHERE player_id = @r_creator_id;

            SELECT @creator_curr_pts = balance_points FROM dbo.Player WHERE player_id = @r_creator_id;

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@r_creator_id, @pts_curr_id, @creator_pts_comm,
                    CAST(@creator_curr_pts AS DECIMAL(18,4)),
                    @commission_type_id, 'PROPOSITION', @r_prop_id,
                    CONCAT('Comisión del creador (PTS) por proposición #', @r_prop_id), GETUTCDATE());
        END

        IF @creator_usd_comm > 0
        BEGIN
            SELECT TOP 1 @creator_run_bal = running_balance
            FROM dbo.[Transaction]
            WHERE player_id = @r_creator_id AND currency_type_id = @usd_curr_id
            ORDER BY created_at DESC;
            SET @creator_run_bal = ISNULL(@creator_run_bal, 0) + @creator_usd_comm;

            INSERT INTO dbo.[Transaction] (player_id, currency_type_id, amount, running_balance,
                                           transaction_type_id, reference_type, reference_id,
                                           description, created_at)
            VALUES (@r_creator_id, @usd_curr_id, @creator_usd_comm, @creator_run_bal,
                    @commission_type_id, 'PROPOSITION', @r_prop_id,
                    CONCAT('Comisión del creador (USD) por proposición #', @r_prop_id), GETUTCDATE());
        END

        -- Comisión de la plataforma: registrada como ProcessLog (no tiene wallet propia en este modelo)
        IF @lose_pts > 0 OR @lose_usd > 0
            INSERT INTO dbo.ProcessLog (sp_name, action_description, affected_table, affected_record_id, status, executed_at, executed_by)
            VALUES ('seeding_payouts',
                    CONCAT('Comisión plataforma proposición #', @r_prop_id,
                           ': PTS=', CAST(FLOOR(@lose_pts * (@platform_pts_pct/100.0)) AS NVARCHAR(20)),
                           ', USD=', CAST(@lose_usd * (@platform_usd_pct/100.0) AS NVARCHAR(20))),
                    'Proposition', @r_prop_id, 'SUCCESS', GETUTCDATE(), 'SEEDING');
    END

    SET @ri += 1;
END

IF OBJECT_ID('tempdb..#PredPool') IS NOT NULL DROP TABLE #PredPool;
PRINT CONCAT('Pagos procesados para proposiciones RESOLVED: ', @res_count);
GO

-- ==============================================================================
-- Limpieza de tablas temporales
-- ==============================================================================
IF OBJECT_ID('tempdb..#PlayerMap') IS NOT NULL DROP TABLE #PlayerMap;
IF OBJECT_ID('tempdb..#PropMap')   IS NOT NULL DROP TABLE #PropMap;
GO

-- ==============================================================================
-- VERIFICACIÓN FINAL DE CONTEOS
-- ==============================================================================
SELECT 'Player'               AS Tabla, COUNT(1) AS Total FROM dbo.Player
UNION ALL SELECT 'SocialAccount',         COUNT(1) FROM dbo.SocialAccount
UNION ALL SELECT 'Proposition',           COUNT(1) FROM dbo.Proposition
UNION ALL SELECT 'Vote',                  COUNT(1) FROM dbo.Vote
UNION ALL SELECT 'Prediction',            COUNT(1) FROM dbo.Prediction
UNION ALL SELECT 'PropositionEvidence',   COUNT(1) FROM dbo.PropositionEvidence
UNION ALL SELECT 'Transaction',           COUNT(1) FROM dbo.[Transaction]
UNION ALL SELECT 'GameEvent',             COUNT(1) FROM dbo.GameEvent
UNION ALL SELECT 'AIReviewLog',           COUNT(1) FROM dbo.AIReviewLog
UNION ALL SELECT 'PropositionAudit',      COUNT(1) FROM dbo.PropositionAudit
UNION ALL SELECT 'ProcessLog',            COUNT(1) FROM dbo.ProcessLog
ORDER BY Tabla;
GO

-- Desglose de pagos generados (por tipo de transacción)
SELECT tt.type_code, COUNT(1) AS Total, SUM(t.amount) AS SumaMontos
FROM dbo.[Transaction] t
JOIN dbo.TransactionType tt ON t.transaction_type_id = tt.transaction_type_id
WHERE tt.type_code IN ('WINNING','COMMISSION','REFUND','PENALTY','WAGER')
GROUP BY tt.type_code
ORDER BY tt.type_code;
GO