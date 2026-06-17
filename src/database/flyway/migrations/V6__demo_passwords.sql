-- ==============================================================================
-- V6 — Demo Passwords
-- Resetea todos los passwords de jugadores seeded a "Password123!" usando
-- SHA2-256 sobre UTF-16LE, que es exactamente lo que FastAPI computa con
-- hashlib.sha256(password.encode('utf-16-le')).hexdigest().upper()
-- ==============================================================================

UPDATE dbo.Player
SET password_hash = CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'Password123!'), 2),
    updated_at    = GETUTCDATE()
WHERE enabled = 1;

PRINT 'Passwords actualizados. Credenciales demo: cualquier_username / Password123!';

-- Jugador admin de prueba con credentials conocidas
IF NOT EXISTS (SELECT 1 FROM dbo.Player WHERE username = 'demo_admin')
BEGIN
    INSERT INTO dbo.Player (username, email, password_hash, display_name,
                             balance_points, balance_version, enabled, created_at, updated_at)
    VALUES (
        'demo_admin',
        'demo@gathel.dev',
        CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', N'Password123!'), 2),
        'Demo Admin',
        5000, 1, 1,
        GETUTCDATE(), GETUTCDATE()
    );
    PRINT 'Jugador demo_admin creado con 5000 pts.';
END
GO
