-- ==============================================================================
-- 04_seguridad_demo.sql  |  Gathel — Demos de Seguridad
-- Roles, permisos, Data Masking, Row-Level Security, cifrado simétrico.
-- Ejecutar por sección (seleccionar + F5).
-- ==============================================================================

USE GathelDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: Roles y usuarios
-- ══════════════════════════════════════════════════════════════════════════════

-- Ver los 4 roles creados
SELECT name AS rol, type_desc
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'db_gathel%'
ORDER BY name;
GO

-- Ver qué usuarios pertenecen a cada rol
SELECT
    r.name AS rol,
    m.name AS miembro
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE r.name LIKE 'db_gathel%'
ORDER BY r.name, m.name;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: Demostrar permisos — acceso denegado
-- ══════════════════════════════════════════════════════════════════════════════

-- Como readonly: puede ver jugadores (SELECT), NO puede insertar (INSERT denegado)
EXECUTE AS USER = 'gathel_readonly_usr';

    SELECT TOP 3 player_id, username FROM Player;  -- debe funcionar

REVERT;
GO

-- Intentar INSERT como readonly (debe fallar con error de permiso)
EXECUTE AS USER = 'gathel_readonly_usr';
BEGIN TRY
    INSERT INTO Player (username, email, password_hash, balance_points, balance_version, enabled, created_at, updated_at)
    VALUES ('intento_hacker', 'hack@test.com', 'hash', 0, 1, 1, GETUTCDATE(), GETUTCDATE());
    PRINT 'ERROR: se permitió el INSERT (no debería pasar)';
END TRY
BEGIN CATCH
    PRINT 'CORRECTO: INSERT bloqueado — ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- Como player_usr: puede ejecutar SPs pero NO hacer SELECT directo a Transaction
EXECUTE AS USER = 'gathel_player_usr';
BEGIN TRY
    SELECT TOP 3 * FROM [Transaction];
    PRINT 'ERROR: se permitió SELECT directo (no debería pasar)';
END TRY
BEGIN CATCH
    PRINT 'CORRECTO: SELECT directo bloqueado — ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: Data Masking
-- Los campos email, balance_points y account_username tienen máscara dinámica.
-- ══════════════════════════════════════════════════════════════════════════════

-- Como admin (sin máscara): ve datos reales
EXECUTE AS USER = 'gathel_admin_usr';
    SELECT TOP 5 player_id, username, email, balance_points FROM Player;
REVERT;
GO

-- Como readonly (con máscara): email y balance se ocultan
EXECUTE AS USER = 'gathel_readonly_usr';
    SELECT TOP 5 player_id, username, email, balance_points FROM Player;
REVERT;
GO

-- Ver columnas que tienen máscara configurada
SELECT
    t.name AS tabla,
    c.name AS columna,
    c.masking_function
FROM sys.masked_columns c
JOIN sys.tables t ON c.object_id = t.object_id
ORDER BY t.name, c.name;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: Row-Level Security (RLS)
-- La tabla [Transaction] filtra filas según el usuario.
-- Cada jugador solo ve sus propias transacciones.
-- ══════════════════════════════════════════════════════════════════════════════

-- Ver política RLS activa
SELECT
    p.name      AS politica,
    t.name      AS tabla,
    p.is_enabled,
    p.type_desc
FROM sys.security_policies p
JOIN sys.tables t ON p.object_id = t.object_id;
GO

-- Como system (sin filtro RLS): ve todas las transacciones
EXECUTE AS USER = 'gathel_system_usr';
    SELECT COUNT(*) AS total_transacciones_visibles FROM [Transaction];
REVERT;
GO

-- Como player_usr (con RLS): solo ve las suyas (0 si no es un jugador real)
EXECUTE AS USER = 'gathel_player_usr';
    SELECT COUNT(*) AS transacciones_visibles_para_este_user FROM [Transaction];
REVERT;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: Cifrado con Symmetric Key
-- Demostrar apertura de clave, cifrado y descifrado de un valor.
-- ══════════════════════════════════════════════════════════════════════════════

-- Verificar que la Master Key y el certificado existen
SELECT name, symmetric_key_id, key_algorithm FROM sys.symmetric_keys WHERE name LIKE 'gathel%';
SELECT name, certificate_id FROM sys.certificates WHERE name LIKE 'gathel%';
GO

-- Abrir la clave, cifrar un valor y descifrarlo
OPEN SYMMETRIC KEY gathel_sym_key
    DECRYPTION BY CERTIFICATE gathel_cert;

DECLARE @token NVARCHAR(200) = N'access_token_secreto_1234';
DECLARE @cifrado VARBINARY(256);

SET @cifrado = EncryptByKey(Key_GUID('gathel_sym_key'), @token);

SELECT
    @token                                                         AS valor_original,
    @cifrado                                                       AS valor_cifrado,
    CAST(DecryptByKey(@cifrado) AS NVARCHAR(200))                  AS valor_descifrado;

CLOSE SYMMETRIC KEY gathel_sym_key;
GO
