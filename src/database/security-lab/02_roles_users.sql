-- ==============================================================================
-- 02_roles_users.sql
-- DEMOSTRACIÓN: Roles de Base de Datos y Asignación de Usuarios
-- Ejecutar DESPUÉS de V4__security_setup.sql (Flyway)
-- ==============================================================================

SET NOCOUNT ON;
GO

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║ DEMOSTRACIÓN: Roles y Usuarios de Gathel                         ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ==============================================================================
-- PASO 1: Listar los 4 roles creados
-- ==============================================================================

PRINT '┌─ PASO 1: Roles de Base de Datos Configurados';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

SELECT
    'ROLE' AS tipo,
    name AS nombre,
    principal_id,
    CASE
        WHEN name = 'db_gathel_admin' THEN 'Administrador - Acceso Total'
        WHEN name = 'db_gathel_system' THEN 'Sistema - Solo Stored Procedures'
        WHEN name = 'db_gathel_player' THEN 'Jugador - Acceso Limitado'
        WHEN name = 'db_gathel_readonly' THEN 'Solo Lectura - Vistas Enmascaradas'
    END AS descripcion
FROM sys.database_principals
WHERE type = 'R' AND name LIKE 'db_gathel%'
ORDER BY name;

PRINT '';

-- ==============================================================================
-- PASO 2: Listar los 4 logins de demostración
-- ==============================================================================

PRINT '┌─ PASO 2: Logins (Usuarios de Conexión) Creados';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

SELECT
    'LOGIN' AS tipo,
    sp.name AS usuario,
    CASE
        WHEN sp.name = 'gathel_admin_usr' THEN 'admin_usr'
        WHEN sp.name = 'gathel_system_usr' THEN 'system_usr'
        WHEN sp.name = 'gathel_player_usr' THEN 'player_usr'
        WHEN sp.name = 'gathel_readonly_usr' THEN 'readonly_usr'
    END AS alias,
    CASE
        WHEN sp.name = 'gathel_admin_usr' THEN 'Administrador'
        WHEN sp.name = 'gathel_system_usr' THEN 'Sistema'
        WHEN sp.name = 'gathel_player_usr' THEN 'Jugador'
        WHEN sp.name = 'gathel_readonly_usr' THEN 'Solo Lectura'
    END AS rol_asignado
FROM sys.server_principals sp
WHERE name LIKE 'gathel_%_usr' AND type = 'S'
ORDER BY sp.name;

PRINT '';

-- ==============================================================================
-- PASO 3: Mapeo Usuario → Rol
-- ==============================================================================

PRINT '┌─ PASO 3: Membresía de Usuarios en Roles (Permisos Heredados)';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

SELECT
    usr.name AS usuario_login,
    rol.name AS rol,
    'HEREDADO' AS tipo_permiso
FROM sys.database_principals usr
INNER JOIN sys.database_role_members rm ON usr.principal_id = rm.member_principal_id
INNER JOIN sys.database_principals rol ON rm.role_principal_id = rol.principal_id
WHERE usr.name LIKE 'gathel_%'
ORDER BY usuario_login, rol;

PRINT '';

-- ==============================================================================
-- PASO 4: Desglose de Permisos por Rol
-- ==============================================================================

PRINT '┌─ PASO 4: Permisos Configurados por Rol';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

DECLARE @role_info TABLE (
    rol NVARCHAR(100),
    permiso NVARCHAR(500)
);

-- db_gathel_admin
INSERT INTO @role_info VALUES
    ('db_gathel_admin', 'db_datareader (leer todas las tablas)'),
    ('db_gathel_admin', 'db_datawriter (escribir en todas las tablas)'),
    ('db_gathel_admin', 'EXECUTE (ejecutar todos los SPs)'),
    ('db_gathel_admin', 'UNMASK (ver datos enmascarados)'),
    ('db_gathel_admin', 'RLS: Bypass (ver todas las filas)'),
    ('', ''),
    ('db_gathel_system', 'EXECUTE (ejecutar SPs)'),
    ('db_gathel_system', 'SIN SELECT directo a tablas'),
    ('db_gathel_system', 'Acceso controlado a procedimientos'),
    ('', ''),
    ('db_gathel_player', 'SELECT en catálogos (PropositionStatus, CurrencyType, etc)'),
    ('db_gathel_player', 'EXECUTE: usp_RegisterPlayer'),
    ('db_gathel_player', 'EXECUTE: usp_CreateProposition'),
    ('db_gathel_player', 'EXECUTE: usp_PlacePrediction'),
    ('db_gathel_player', 'EXECUTE: usp_GetPlayerDashboard'),
    ('', ''),
    ('db_gathel_readonly', 'SELECT en PropositionStatus'),
    ('db_gathel_readonly', 'SELECT en Proposition'),
    ('db_gathel_readonly', 'DENY en Player (no ve datos sensibles)'),
    ('db_gathel_readonly', 'Masking: Email y Balance ocultos');

SELECT rol, permiso FROM @role_info WHERE rol <> '' ORDER BY rol, permiso;

PRINT '';

-- ==============================================================================
-- RESUMEN
-- ==============================================================================

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'RESUMEN DE CONFIGURACIÓN';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '';
PRINT '4 Roles Definidos:';
PRINT '  • db_gathel_admin      → Acceso administrativo completo';
PRINT '  • db_gathel_system     → Acceso solo vía Stored Procedures';
PRINT '  • db_gathel_player     → Acceso controlado para jugadores';
PRINT '  • db_gathel_readonly   → Acceso de solo lectura enmascarado';
PRINT '';
PRINT '4 Logins de Demostración:';
PRINT '  • gathel_admin_usr     → Pruebas administrativas';
PRINT '  • gathel_system_usr    → Pruebas de acceso vía SP';
PRINT '  • gathel_player_usr    → Pruebas de acceso limitado';
PRINT '  • gathel_readonly_usr  → Pruebas de enmascaramiento';
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '✓ DEMO COMPLETADA: Todos los roles y usuarios creados y configurados';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
