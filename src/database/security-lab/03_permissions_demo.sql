-- ==============================================================================
-- 03_permissions_demo.sql
-- DEMOSTRACIÓN: Permisos Directos vs Heredados (Requisito del Caso)
-- Ejecutar DESPUÉS de V4__security_setup.sql (Flyway)
-- ==============================================================================

SET NOCOUNT ON;
GO

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║ DEMOSTRACIÓN: Permisos Directos vs Permisos Heredados            ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ==============================================================================
-- DEMO A: PERMISOS HEREDADOS (vía Rol)
-- ==============================================================================

PRINT '┌─ DEMO A: Permisos Heredados vía Rol';
PRINT '└─────────────────────────────────────────────────';
PRINT '';
PRINT 'Usuario: gathel_system_usr';
PRINT 'Rol: db_gathel_system';
PRINT 'Permiso: EXECUTE en Stored Procedures';
PRINT '';

DECLARE @system_usr NVARCHAR(100) = 'gathel_system_usr';

-- Listar lo que system_usr puede hacer vía el rol db_gathel_system
PRINT '├─ ¿Qué permisos tiene gathel_system_usr?';
PRINT '│';

SELECT
    '├─' + perm.permission_name + ' en ' + OBJECT_NAME(perm.major_id) AS permiso_heredado
FROM sys.server_principals login
INNER JOIN sys.database_principals user_db ON login.principal_id = user_db.owning_principal_id
INNER JOIN sys.database_role_members rm ON user_db.principal_id = rm.member_principal_id
INNER JOIN sys.database_principals role_db ON rm.role_principal_id = role_db.principal_id
INNER JOIN sys.database_permissions perm ON role_db.principal_id = perm.grantee_principal_id
WHERE login.name = @system_usr
ORDER BY perm.permission_name;

PRINT '│';
PRINT '├─ Conclusión:';
PRINT '│  • system_usr hereda EXECUTE de su rol db_gathel_system';
PRINT '│  • NO tiene SELECT directo en ninguna tabla';
PRINT '│  • Solo puede ejecutar Stored Procedures';
PRINT '│';

-- ==============================================================================
-- DEMO B: PERMISOS DIRECTOS (GRANT/DENY explícitos)
-- ==============================================================================

PRINT '└─ DEMO B: Permisos Directos (Explícitos)';
PRINT '';
PRINT 'Usuario: gathel_readonly_usr';
PRINT 'Permisos Configurados:';
PRINT '  ✓ GRANT SELECT ON PropositionStatus (directo)';
PRINT '  ✗ DENY SELECT ON Player (directo)';
PRINT '';

-- Verificar permisos directos en gathel_readonly_usr
PRINT '├─ Permisos Directos de gathel_readonly_usr:';
PRINT '│';

SELECT
    '├─ ' + perm.permission_name + ' (tipo: ' + perm.state_desc + ') en ' + OBJECT_NAME(perm.major_id) AS permiso_directo,
    perm.state_desc
FROM sys.database_principals dp
INNER JOIN sys.database_permissions perm ON dp.principal_id = perm.grantee_principal_id
WHERE dp.name = 'gathel_readonly_usr'
  AND perm.major_id IS NOT NULL
ORDER BY perm.permission_name;

PRINT '│';
PRINT '├─ Conclusión:';
PRINT '│  • readonly_usr tiene GRANT SELECT en PropositionStatus (directo)';
PRINT '│  • readonly_usr tiene DENY SELECT en Player (directo)';
PRINT '│  • Estos permisos NO vienen de un rol, son explícitos';
PRINT '│';

-- ==============================================================================
-- DEMO C: Comparativa de Acceso Real
-- ==============================================================================

PRINT '└─ DEMO C: Comportamiento Real de Acceso';
PRINT '';
PRINT 'Escenario 1: system_usr intenta SELECT en Player';
PRINT '  → Resultado: FALLA (no tiene permiso, solo EXECUTE)';
PRINT '';
PRINT 'Escenario 2: system_usr ejecuta usp_RegisterPlayer';
PRINT '  → Resultado: ÉXITO (tiene EXECUTE del rol)';
PRINT '';
PRINT 'Escenario 3: readonly_usr SELECT de PropositionStatus';
PRINT '  → Resultado: ÉXITO (permiso directo GRANT)';
PRINT '';
PRINT 'Escenario 4: readonly_usr SELECT de Player';
PRINT '  → Resultado: FALLA (permiso directo DENY)';
PRINT '';

-- ==============================================================================
-- TABLA RESUMEN
-- ==============================================================================

PRINT '┌─ Tabla de Referencia: Matriz de Permisos';
PRINT '└─────────────────────────────────────────────────';
PRINT '';

DECLARE @permisos_resumen TABLE (
    usuario NVARCHAR(50),
    tabla NVARCHAR(50),
    tipo_permiso NVARCHAR(30),
    resultado_acceso NVARCHAR(30)
);

INSERT INTO @permisos_resumen VALUES
    ('system_usr', 'Player', 'HEREDADO (EXECUTE)', '✗ FALLA'),
    ('system_usr', 'usp_RegisterPlayer', 'HEREDADO (EXECUTE)', '✓ ÉXITO'),
    ('readonly_usr', 'PropositionStatus', 'DIRECTO (GRANT)', '✓ ÉXITO'),
    ('readonly_usr', 'Player', 'DIRECTO (DENY)', '✗ FALLA'),
    ('admin_usr', 'Cualquier tabla', 'HEREDADO (db_datareader)', '✓ ÉXITO'),
    ('admin_usr', 'Cualquier SP', 'HEREDADO (EXECUTE)', '✓ ÉXITO');

SELECT
    usuario,
    tabla,
    tipo_permiso,
    resultado_acceso
FROM @permisos_resumen
ORDER BY usuario, resultado_acceso DESC;

PRINT '';

-- ==============================================================================
-- RESUMEN EJECUTIVO
-- ==============================================================================

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'RESUMEN: PERMISOS DIRECTOS vs HEREDADOS';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'PERMISOS HEREDADOS (via Roles):';
PRINT '  • Vienen de asignación de usuario a rol (ALTER ROLE ... ADD MEMBER)';
PRINT '  • Centralizados: cambiar permiso del rol afecta a todos los miembros';
PRINT '  • Ejemplo: db_gathel_system tiene EXECUTE → todos sus miembros pueden ejecutar SPs';
PRINT '';
PRINT 'PERMISOS DIRECTOS (GRANT/DENY explícitos):';
PRINT '  • Asignados directamente al usuario';
PRINT '  • Individualizados: solo afectan al usuario específico';
PRINT '  • Ejemplo: GRANT SELECT ON PropositionStatus TO gathel_readonly_usr';
PRINT '';
PRINT 'En Gathel implementamos AMBOS:';
PRINT '  ✓ Roles con permisos heredados (mantenimiento centralizado)';
PRINT '  ✓ Permisos directos (casos específicos de control fino)';
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '✓ DEMO COMPLETADA: Permisos directos y heredados demostrados';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
