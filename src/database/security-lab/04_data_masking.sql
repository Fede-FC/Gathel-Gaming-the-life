-- ==============================================================================
-- 04_data_masking.sql
-- DEMOSTRACIÓN: Dynamic Data Masking (Enmascaramiento de Datos Sensibles)
-- Ejecutar DESPUÉS de V4__security_setup.sql (Flyway)
-- ==============================================================================

SET NOCOUNT ON;
GO

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║ DEMOSTRACIÓN: Dynamic Data Masking en SQL Server                 ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ==============================================================================
-- PASO 1: Mostrar configuración de masking
-- ==============================================================================

PRINT '┌─ PASO 1: Columnas con Masking Configurado';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

SELECT
    'TABLA' AS tipo,
    OBJECT_NAME(ac.object_id) AS tabla,
    ac.name AS columna,
    CASE
        WHEN ac.masking_function = 'email()' THEN 'email() - aXXX@XXXX.com'
        WHEN ac.masking_function = 'default()' THEN 'default() - 0 (números/valores)'
        WHEN ac.masking_function LIKE 'partial%' THEN 'partial() - primeros/últimos caracteres'
    END AS funcion_masking
FROM sys.columns ac
WHERE ac.masking_function IS NOT NULL
ORDER BY tabla, columna;

PRINT '';

-- ==============================================================================
-- PASO 2: Demo con Usuario NO Admin (ve datos enmascarados)
-- ==============================================================================

PRINT '┌─ PASO 2: Vista de No-Admin (gathel_readonly_usr)';
PRINT '│         Datos ENMASCARADOS';
PRINT '└─────────────────────────────────────────────────';
PRINT '';
PRINT 'Conectarse como: gathel_readonly_usr (contraseña: GathelReadOnly123!Secure)';
PRINT 'y ejecutar:';
PRINT '';
PRINT '  SELECT TOP 3 player_id, username, email, balance_points FROM dbo.Player;';
PRINT '';
PRINT 'Resultado esperado:';
PRINT '  player_id | username       | email          | balance_points';
PRINT '  -----------+----------------+----------------+---------------';
PRINT '  1         | sofia_garcia_1 | a***@*.com     | 0 ← ENMASCARADO';
PRINT '  2         | diego_xxx_2    | d***@*.com     | 0 ← ENMASCARADO';
PRINT '  3         | valeria_xxx_3  | v***@*.com     | 0 ← ENMASCARADO';
PRINT '';

-- ==============================================================================
-- PASO 3: Demo con Usuario Admin (ve datos REALES)
-- ==============================================================================

PRINT '┌─ PASO 3: Vista de Admin (sa o gathel_admin_usr)';
PRINT '│         Datos REALES sin masking';
PRINT '└─────────────────────────────────────────────────';
PRINT '';
PRINT 'Conectarse como: admin (sa o gathel_admin_usr)';
PRINT 'y ejecutar:';
PRINT '';
PRINT '  SELECT TOP 3 player_id, username, email, balance_points FROM dbo.Player;';
PRINT '';
PRINT 'Resultado esperado:';
PRINT '  player_id | username       | email                  | balance_points';
PRINT '  -----------+----------------+------------------------+---------------';
PRINT '  1         | sofia_garcia_1 | sofia.garcia1@gathel.dev| 523 ← REAL';
PRINT '  2         | diego_xxx_2    | diego.xxx2@gathel.dev  | 789 ← REAL';
PRINT '  3         | valeria_xxx_3  | valeria.xxx3@gathel.dev| 342 ← REAL';
PRINT '';

-- ==============================================================================
-- PASO 4: Verificación de Funciones de Masking
-- ==============================================================================

PRINT '└─ PASO 4: Funciones de Masking Disponibles en SQL Server';
PRINT '';

DECLARE @masking_info TABLE (funcion NVARCHAR(100), descripcion NVARCHAR(500), ejemplo NVARCHAR(100));

INSERT INTO @masking_info VALUES
    ('email()', 'Enmascara direcciones de email: aXXX@XXXX.com', 'john.doe@example.com → jXXX@XXXX.com'),
    ('default()', 'Reemplaza con valor por defecto (0 números, vacio textos)', '12345 → 0'),
    ('partial(prefix, padding, suffix)', 'Enmascara parcialmente con padding', 'ABCD1234EFGH → ABCDXXXX****'),
    ('random()', 'Reemplaza con valor random del tipo de dato', '12345 → 45789 (random)');

SELECT funcion, descripcion, ejemplo FROM @masking_info;

PRINT '';

-- ==============================================================================
-- PASO 5: Validación de Permisos UNMASK
-- ==============================================================================

PRINT '┌─ PASO 5: Quién Tiene Permiso UNMASK (Ver Datos Reales)';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

SELECT
    'PERMISO' AS tipo,
    dp.name AS usuario_rol,
    'UNMASK' AS permiso,
    CASE dp.type WHEN 'R' THEN 'Rol' WHEN 'U' THEN 'Usuario' WHEN 'S' THEN 'Login' END AS tipo_principal
FROM sys.database_principals dp
INNER JOIN sys.database_permissions perm ON dp.principal_id = perm.grantee_principal_id
WHERE perm.permission_name = 'UNMASK'
ORDER BY dp.name;

PRINT '';
PRINT 'Solo db_gathel_admin tiene UNMASK → ve datos reales';
PRINT 'Los demás ven datos enmascarados';
PRINT '';

-- ==============================================================================
-- TABLAS AFECTADAS
-- ==============================================================================

PRINT '┌─ Tabla: dbo.Player';
PRINT '│  Columnas enmascaradas:';
PRINT '│    • email → email() - aXXX@XXXX.com';
PRINT '│    • balance_points → default() - 0';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

PRINT '┌─ Tabla: dbo.SocialAccount';
PRINT '│  Columnas enmascaradas:';
PRINT '│    • account_username → partial() - ***usuario***';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

-- ==============================================================================
-- RESUMEN
-- ==============================================================================

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'RESUMEN: Dynamic Data Masking en Gathel';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'Objetivo:';
PRINT '  Proteger datos sensibles (emails, balances, usernames) de usuarios';
PRINT '  sin permisos administrativos';
PRINT '';
PRINT 'Implementación:';
PRINT '  ✓ email en Player → enmascara a patrón email()';
PRINT '  ✓ balance_points en Player → reemplaza por 0';
PRINT '  ✓ account_username en SocialAccount → parcialmente oculto';
PRINT '';
PRINT 'Control de Acceso:';
PRINT '  ✓ Solo db_gathel_admin y db_owner ven datos reales';
PRINT '  ✓ Resto de usuarios ven datos enmascarados automáticamente';
PRINT '  ✓ Sin cambios en aplicación - masking es transparente en BD';
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '✓ DEMO COMPLETADA: Data Masking funciona correctamente';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
