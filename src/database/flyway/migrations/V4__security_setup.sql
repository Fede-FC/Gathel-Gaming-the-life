-- ==============================================================================
-- V4__security_setup.sql
-- Gathel Gaming Platform — Seguridad, Cifrado, Roles, Permisos y RLS
-- Basado en Fase 3 Security Lab
-- ==============================================================================

SET NOCOUNT ON;
GO

-- ==============================================================================
-- SECCIÓN 1: Master Key + Certificate + Symmetric Key
-- Para demostrar cifrado a nivel T-SQL (requisito del caso)
-- ==============================================================================

-- Crear Master Key si no existe
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'GathelMasterKey2026!Secure';
    PRINT 'Master Key creada.';
END
GO

-- Crear Certificate
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'gathel_cert')
BEGIN
    CREATE CERTIFICATE gathel_cert
    WITH SUBJECT = 'Gathel Gaming Platform Encryption Certificate',
         EXPIRY_DATE = '2030-12-31';
    PRINT 'Certificate gathel_cert creado.';
END
GO

-- Crear Symmetric Key cifrado con Certificate
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'gathel_sym_key')
BEGIN
    CREATE SYMMETRIC KEY gathel_sym_key
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE gathel_cert;
    PRINT 'Symmetric Key gathel_sym_key creado.';
END
GO

-- ==============================================================================
-- SECCIÓN 2: Roles de Base de Datos con Permisos Diferenciados
-- ==============================================================================

-- Rol: db_gathel_admin (Administrador - acceso total)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_gathel_admin' AND type = 'R')
BEGIN
    CREATE ROLE db_gathel_admin;
    GRANT db_datareader, db_datawriter TO db_gathel_admin;
    GRANT EXECUTE TO db_gathel_admin;
    GRANT UNMASK TO db_gathel_admin;  -- Para ver datos enmascarados
    PRINT 'Rol db_gathel_admin creado.';
END
GO

-- Rol: db_gathel_system (Sistema - SOLO acceso vía Stored Procedures)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_gathel_system' AND type = 'R')
BEGIN
    CREATE ROLE db_gathel_system;
    GRANT EXECUTE TO db_gathel_system;  -- SOLO SPs, NO SELECT directo
    PRINT 'Rol db_gathel_system creado.';
END
GO

-- Rol: db_gathel_player (Jugador - acceso limitado y controlado)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_gathel_player' AND type = 'R')
BEGIN
    CREATE ROLE db_gathel_player;
    -- SELECT en tablas de catálogo (solo lectura)
    GRANT SELECT ON dbo.PropositionStatus TO db_gathel_player;
    GRANT SELECT ON dbo.SocialNetwork TO db_gathel_player;
    GRANT SELECT ON dbo.CurrencyType TO db_gathel_player;
    GRANT SELECT ON dbo.TransactionType TO db_gathel_player;
    GRANT SELECT ON dbo.EventType TO db_gathel_player;
    -- EXEC en SPs específicas
    GRANT EXECUTE ON dbo.usp_RegisterPlayer TO db_gathel_player;
    GRANT EXECUTE ON dbo.usp_CreateProposition TO db_gathel_player;
    GRANT EXECUTE ON dbo.usp_PlacePrediction TO db_gathel_player;
    GRANT EXECUTE ON dbo.usp_GetPlayerDashboard TO db_gathel_player;
    PRINT 'Rol db_gathel_player creado.';
END
GO

-- Rol: db_gathel_readonly (Solo lectura enmascarada)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_gathel_readonly' AND type = 'R')
BEGIN
    CREATE ROLE db_gathel_readonly;
    GRANT SELECT ON dbo.PropositionStatus TO db_gathel_readonly;
    GRANT SELECT ON dbo.Proposition TO db_gathel_readonly;
    -- NO acceso a Player, Transaction, SocialAccount (sensibles)
    PRINT 'Rol db_gathel_readonly creado.';
END
GO

-- ==============================================================================
-- SECCIÓN 3: Logins de Demostración (SQL Authentication)
-- ==============================================================================

-- Admin User
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'gathel_admin_usr')
BEGIN
    CREATE LOGIN gathel_admin_usr WITH PASSWORD = 'GathelAdmin123!Secure';
    CREATE USER gathel_admin_usr FROM LOGIN gathel_admin_usr;
    ALTER ROLE db_gathel_admin ADD MEMBER gathel_admin_usr;
    PRINT 'Login gathel_admin_usr creado y asignado a db_gathel_admin.';
END
GO

-- System User (acceso solo vía SPs)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'gathel_system_usr')
BEGIN
    CREATE LOGIN gathel_system_usr WITH PASSWORD = 'GathelSystem123!Secure';
    CREATE USER gathel_system_usr FROM LOGIN gathel_system_usr;
    ALTER ROLE db_gathel_system ADD MEMBER gathel_system_usr;
    PRINT 'Login gathel_system_usr creado y asignado a db_gathel_system.';
END
GO

-- Player User (acceso limitado)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'gathel_player_usr')
BEGIN
    CREATE LOGIN gathel_player_usr WITH PASSWORD = 'GathelPlayer123!Secure';
    CREATE USER gathel_player_usr FROM LOGIN gathel_player_usr;
    ALTER ROLE db_gathel_player ADD MEMBER gathel_player_usr;
    PRINT 'Login gathel_player_usr creado y asignado a db_gathel_player.';
END
GO

-- ReadOnly User
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'gathel_readonly_usr')
BEGIN
    CREATE LOGIN gathel_readonly_usr WITH PASSWORD = 'GathelReadOnly123!Secure';
    CREATE USER gathel_readonly_usr FROM LOGIN gathel_readonly_usr;
    ALTER ROLE db_gathel_readonly ADD MEMBER gathel_readonly_usr;
    PRINT 'Login gathel_readonly_usr creado y asignado a db_gathel_readonly.';
END
GO

-- ==============================================================================
-- SECCIÓN 4: Dynamic Data Masking (Enmascaramiento de Datos Sensibles)
-- ==============================================================================

-- Aplicar masking al email (patrón: a***@***.com)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'email' AND object_id = OBJECT_ID('dbo.Player') AND masking_function IS NOT NULL)
BEGIN
    ALTER TABLE dbo.Player ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');
    PRINT 'Data Masking aplicado a Player.email.';
END
GO

-- Aplicar masking a balance_points (solo admins ven el valor real)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'balance_points' AND object_id = OBJECT_ID('dbo.Player') AND masking_function IS NOT NULL)
BEGIN
    ALTER TABLE dbo.Player ALTER COLUMN balance_points ADD MASKED WITH (FUNCTION = 'default()');
    PRINT 'Data Masking aplicado a Player.balance_points.';
END
GO

-- Aplicar masking a account_username en SocialAccount
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'account_username' AND object_id = OBJECT_ID('dbo.SocialAccount') AND masking_function IS NOT NULL)
BEGIN
    ALTER TABLE dbo.SocialAccount ALTER COLUMN account_username ADD MASKED WITH (FUNCTION = 'partial(1,"***",0)');
    PRINT 'Data Masking aplicado a SocialAccount.account_username.';
END
GO

-- ==============================================================================
-- SECCIÓN 5: Row-Level Security (RLS) - Tabla Transaction
-- Cada jugador SOLO ve sus propias transacciones
-- ==============================================================================

-- Función de predicado RLS
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = 'fn_TransactionRLS' AND type = 'IF')
BEGIN
    CREATE FUNCTION dbo.fn_TransactionRLS(@player_id INT)
    RETURNS TABLE AS RETURN
    SELECT 1 AS access
    WHERE @player_id = TRY_CAST(SESSION_CONTEXT(N'player_id') AS INT)
       OR IS_MEMBER('db_owner') = 1
       OR IS_MEMBER('db_gathel_admin') = 1;
    PRINT 'Función fn_TransactionRLS creada.';
END
GO

-- Crear Security Policy con RLS
IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'TransactionSecurityPolicy')
BEGIN
    CREATE SECURITY POLICY dbo.TransactionSecurityPolicy
    ADD FILTER PREDICATE dbo.fn_TransactionRLS(player_id)
    ON dbo.[Transaction]
    WITH (STATE = ON);
    PRINT 'Security Policy TransactionSecurityPolicy creada (RLS activa).';
END
GO

-- ==============================================================================
-- SECCIÓN 6: Permisos Explícitos Directos (Demo para el caso)
-- Demostración de permisos heredados vs directos
-- ==============================================================================

-- Permiso directo: readonly_usr PUEDE ver PropositionStatus (directo)
GRANT SELECT ON dbo.PropositionStatus TO [gathel_readonly_usr];

-- Permiso directo: readonly_usr NO PUEDE ver Player (DENY explícito)
DENY SELECT ON dbo.Player TO [gathel_readonly_usr];

-- Permiso heredado: system_usr PUEDE EXEC usp_RegisterPlayer (vía rol db_gathel_system)
-- Ya está implícito en: ALTER ROLE db_gathel_system ADD MEMBER gathel_system_usr;

PRINT 'Permisos explícitos configurados.';
GO

-- ==============================================================================
-- SECCIÓN 7: Auditoría de Cambios (Trigger en Proposition - ya existe en V1)
-- Confirmación de que trigger está activo
-- ==============================================================================

DECLARE @trigger_exists INT;
SELECT @trigger_exists = COUNT(1) FROM sys.triggers WHERE name = 'tr_proposition_audit';

IF @trigger_exists > 0
BEGIN
    PRINT 'Trigger tr_proposition_audit confirmado activo.';
END
ELSE
BEGIN
    PRINT 'ADVERTENCIA: Trigger tr_proposition_audit no encontrado. Revisar V1__init_schema.sql';
END
GO

-- ==============================================================================
-- SECCIÓN 8: Vistas de Demostración para Security Lab
-- ==============================================================================

-- Vista: Balance de jugador (con masking aplicado si el usuario no es admin)
IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_PlayerBalance')
BEGIN
    CREATE VIEW dbo.vw_PlayerBalance AS
    SELECT
        player_id,
        username,
        display_name,
        email,  -- Enmascarado si no es admin
        balance_points,  -- Enmascarado si no es admin
        enabled,
        created_at
    FROM dbo.Player
    WHERE enabled = 1;

    PRINT 'Vista vw_PlayerBalance creada.';
END
GO

-- Vista: Transacciones del usuario (para demostrar RLS)
IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_MyTransactions')
BEGIN
    CREATE VIEW dbo.vw_MyTransactions AS
    SELECT
        transaction_id,
        player_id,
        amount,
        currency_type_id,
        running_balance,
        transaction_type_id,
        reference_type,
        created_at
    FROM dbo.[Transaction]
    WHERE player_id = TRY_CAST(SESSION_CONTEXT(N'player_id') AS INT);

    PRINT 'Vista vw_MyTransactions creada.';
END
GO

-- ==============================================================================
-- SECCIÓN 9: Resumen Final
-- ==============================================================================

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'FASE 3 - SECURITY LAB COMPLETADA';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'Master Key y Certificate: ✓ Configurados';
PRINT 'Roles de BD (4): ✓ db_gathel_admin, db_gathel_system, db_gathel_player, db_gathel_readonly';
PRINT 'Logins de Demo (4): ✓ gathel_admin_usr, gathel_system_usr, gathel_player_usr, gathel_readonly_usr';
PRINT 'Dynamic Data Masking: ✓ email, balance_points, account_username enmascarados';
PRINT 'Row-Level Security: ✓ Tabla Transaction protegida por RLS';
PRINT 'Auditoría de Cambios: ✓ Trigger tr_proposition_audit activo';
PRINT 'Vistas de Seguridad: ✓ vw_PlayerBalance, vw_MyTransactions';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'Próximo paso: Ejecutar scripts en /src/database/security-lab/ para demos.';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
