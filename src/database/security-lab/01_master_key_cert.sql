-- ==============================================================================
-- 01_master_key_cert.sql
-- DEMOSTRACIÓN: Cifrado con Master Key y Certificate
-- Ejecutar DESPUÉS de V4__security_setup.sql (Flyway)
-- ==============================================================================

SET NOCOUNT ON;
GO

-- ==============================================================================
-- DEMO 1: Abrir la clave simétrica y cifrar/descifrar datos
-- ==============================================================================

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║ DEMOSTRACIÓN: Cifrado con Symmetric Key y Certificate            ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';

-- Abrir la clave simétrica usando el certificate
OPEN SYMMETRIC KEY gathel_sym_key DECRYPTION BY CERTIFICATE gathel_cert;
PRINT '✓ Symmetric Key abierta.';
GO

-- Paso 1: Crear una tabla temporal para demostración
IF OBJECT_ID('tempdb..#EncryptionDemo', 'U') IS NOT NULL
    DROP TABLE #EncryptionDemo;

CREATE TABLE #EncryptionDemo (
    id INT IDENTITY(1,1),
    original_data NVARCHAR(200),
    encrypted_data VARBINARY(MAX),
    decrypted_data NVARCHAR(200)
);

PRINT '';
PRINT '┌─ PASO 1: Datos Originales (SIN cifrar)';
PRINT '└─────────────────────────────────────────────────';

-- Datos de ejemplo a cifrar
DECLARE @original_data NVARCHAR(200) = 'player_password_hash_12345abcde';

INSERT INTO #EncryptionDemo (original_data)
VALUES (@original_data);

SELECT 'ORIGINAL' AS tipo, original_data AS datos FROM #EncryptionDemo;
PRINT '';

-- Paso 2: Cifrar
PRINT '┌─ PASO 2: Cifrando datos...';
PRINT '│ Algoritmo: AES-256';
PRINT '│ Método: Symmetric Key encriptado con Certificate';
PRINT '└─────────────────────────────────────────────────';

UPDATE #EncryptionDemo
SET encrypted_data = ENCRYPTBYKEY(KEY_GUID('gathel_sym_key'), @original_data)
WHERE id = 1;

SELECT 'CIFRADO' AS tipo, CONVERT(NVARCHAR(50), encrypted_data, 2) AS datos_hash FROM #EncryptionDemo;
PRINT '';
PRINT '✓ Datos cifrados exitosamente (hexadecimal ilegible).';
PRINT '';

-- Paso 3: Descifrar
PRINT '┌─ PASO 3: Descifrando datos...';
PRINT '└─────────────────────────────────────────────────';

UPDATE #EncryptionDemo
SET decrypted_data = CONVERT(NVARCHAR(200), DECRYPTBYKEY(encrypted_data))
WHERE id = 1;

SELECT 'DESCIFRADO' AS tipo, decrypted_data AS datos FROM #EncryptionDemo;
PRINT '';
PRINT '✓ Datos descifrados exitosamente.';
PRINT '';

-- Paso 4: Verificación
DECLARE @original NVARCHAR(200) = (SELECT original_data FROM #EncryptionDemo);
DECLARE @decrypted NVARCHAR(200) = (SELECT decrypted_data FROM #EncryptionDemo);

PRINT '┌─ VERIFICACIÓN: ¿Los datos recuperados coinciden con los originales?';
PRINT '└─────────────────────────────────────────────────';

IF @original = @decrypted
    PRINT '✓ ÉXITO: Datos descifrados coinciden perfectamente con los originales.';
ELSE
    PRINT '✗ ERROR: Mismatch en descifrado.';

PRINT '';

-- Cerrar la clave
CLOSE SYMMETRIC KEY gathel_sym_key;
PRINT '✓ Symmetric Key cerrada.';
PRINT '';

-- Limpiar
DROP TABLE #EncryptionDemo;

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '✓ DEMO COMPLETADA: Cifrado en SQL Server funciona correctamente';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
