-- ==============================================================================
-- V5__concurrency_05_isolation_levels.sql
-- Gathel Gaming Platform — Niveles de Aislamiento
-- Demuestra los 4 niveles y los problemas asociados a cada uno.
-- SQL Server 2022 | Flyway
-- ==============================================================================

-- ==============================================================================
-- TABLA DE REFERENCIA RÁPIDA
-- ╔══════════════════════╦═══════════╦══════════════╦════════════════╦═════════╗
-- ║ Nivel de aislamiento ║ Dirty Read║ Non-Rep. Read║ Phantom Read   ║ Bloq.   ║
-- ╠══════════════════════╬═══════════╬══════════════╬════════════════╬═════════╣
-- ║ READ UNCOMMITTED     ║    SÍ     ║    SÍ        ║    SÍ          ║ Mínimo  ║
-- ║ READ COMMITTED       ║    NO     ║    SÍ        ║    SÍ          ║ Bajo    ║
-- ║ REPEATABLE READ      ║    NO     ║    NO        ║    SÍ          ║ Medio   ║
-- ║ SERIALIZABLE         ║    NO     ║    NO        ║    NO          ║ Máximo  ║
-- ╚══════════════════════╩═══════════╩══════════════╩════════════════╩═════════╝
-- ==============================================================================

GO
-- ==============================================================================
-- HELPERS: SPs de apoyo para las demos
-- ==============================================================================

-- Consultar el balance de un jugador (usado en múltiples demos)
CREATE OR ALTER PROCEDURE dbo.usp_IL_GetBalance
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT player_id, username, balance_points, updated_at
    FROM dbo.Player
    WHERE player_id = @player_id;
END;
GO

-- Modificar el balance de un jugador (usado por el SP "escritor" en las demos)
CREATE OR ALTER PROCEDURE dbo.usp_IL_UpdateBalance
    @player_id   INT,
    @new_balance BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Player
    SET balance_points = @new_balance,
        updated_at     = GETUTCDATE()
    WHERE player_id = @player_id;
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 1: READ UNCOMMITTED                                               ║
-- ║ Problema: DIRTY READ                                                    ║
-- ║ Un lector puede ver datos que aún NO han sido confirmados (committed).  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

-- ESCRITOR: Inicia transacción, modifica balance, no hace commit todavía.
CREATE OR ALTER PROCEDURE dbo.usp_IL_DirtyWrite_Writer
    @player_id   INT,
    @new_balance BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    UPDATE dbo.Player
    SET balance_points = @new_balance,
        updated_at     = GETUTCDATE()
    WHERE player_id = @player_id;
    PRINT 'Escritor: balance actualizado a ' + CAST(@new_balance AS NVARCHAR) + ' (SIN commit aún)';
    -- Simular trabajo largo → el lector leerá el valor no confirmado
    WAITFOR DELAY '00:00:08';
    -- Después de que el lector lo haya leído, revertimos
    ROLLBACK TRANSACTION;
    PRINT 'Escritor: ROLLBACK ejecutado. El valor en BD volvió al original.';
END;
GO

-- LECTOR con READ UNCOMMITTED: puede leer el valor no confirmado
CREATE OR ALTER PROCEDURE dbo.usp_IL_DirtyRead_Reader
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    -- EQUIVALENTE: SELECT ... FROM Player WITH (NOLOCK)
    SELECT 'READ UNCOMMITTED (DIRTY READ)' AS nivel,
           player_id, username, balance_points AS balance_leido,
           'Puede ser un valor NO confirmado!' AS advertencia,
           GETUTCDATE() AS leido_en
    FROM dbo.Player
    WHERE player_id = @player_id;
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 2: READ COMMITTED (nivel por defecto en SQL Server)              ║
-- ║ Previene: Dirty Reads                                                   ║
-- ║ Problema: NON-REPEATABLE READ                                           ║
-- ║ Una segunda lectura dentro de la misma transacción puede devolver       ║
-- ║ un resultado diferente si otro commit ocurrió entre las dos lecturas.   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_NonRepeatableRead
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Primera lectura
        DECLARE @balance1 BIGINT;
        SELECT @balance1 = balance_points FROM dbo.Player WHERE player_id = @player_id;
        PRINT 'READ COMMITTED — Primera lectura: ' + CAST(@balance1 AS NVARCHAR);

        -- Pausa para que otro proceso pueda modificar el registro entre lecturas
        WAITFOR DELAY '00:00:06';

        -- Segunda lectura (dentro de la misma transacción)
        DECLARE @balance2 BIGINT;
        SELECT @balance2 = balance_points FROM dbo.Player WHERE player_id = @player_id;
        PRINT 'READ COMMITTED — Segunda lectura: ' + CAST(@balance2 AS NVARCHAR);

        IF @balance1 <> @balance2
            PRINT 'NON-REPEATABLE READ detectado: los valores son diferentes!';
        ELSE
            PRINT 'Los valores son iguales (no hubo modificación concurrente).';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 3: REPEATABLE READ                                                ║
-- ║ Previene: Dirty Reads + Non-Repeatable Reads                           ║
-- ║ Problema: PHANTOM READ                                                  ║
-- ║ Una segunda consulta con el mismo WHERE puede retornar FILAS NUEVAS    ║
-- ║ que no estaban en la primera lectura (insertadas por otro proceso).     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_PhantomRead
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Primera lectura: contar predicciones activas de la proposición
        DECLARE @count1 INT;
        SELECT @count1 = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;
        PRINT 'REPEATABLE READ — Primera lectura: ' + CAST(@count1 AS NVARCHAR) + ' predicciones';

        -- Pausa para que otro proceso inserte una predicción nueva
        WAITFOR DELAY '00:00:06';

        -- Segunda lectura (misma condición, puede haber nuevas filas)
        DECLARE @count2 INT;
        SELECT @count2 = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;
        PRINT 'REPEATABLE READ — Segunda lectura: ' + CAST(@count2 AS NVARCHAR) + ' predicciones';

        IF @count2 > @count1
            PRINT 'PHANTOM READ detectado: aparecieron ' + CAST(@count2 - @count1 AS NVARCHAR) + ' fila(s) nueva(s)!';
        ELSE
            PRINT 'No hubo phantom read en esta ejecución.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ NIVEL 4: SERIALIZABLE                                                   ║
-- ║ Previene: Dirty Reads + Non-Repeatable Reads + Phantom Reads           ║
-- ║ Problema: ALTA CONTENCIÓN (bloqueo de rangos con key-range locks)      ║
-- ║ Las inserciones concurrentes dentro del rango WHERE son BLOQUEADAS.     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_IL_Serializable_Reader
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- SQL Server pone un key-range lock sobre todas las filas del WHERE
        -- y sobre el "gap" vacío, impidiendo que otro proceso inserte
        -- predicciones nuevas dentro de este rango hasta que hagamos COMMIT.
        DECLARE @count INT;
        SELECT @count = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;

        PRINT 'SERIALIZABLE — Predicciones leídas: ' + CAST(@count AS NVARCHAR);
        PRINT 'Ningún INSERT nuevo puede completarse para esta proposición mientras esta TX esté abierta.';

        -- Pausa larga para demostrar el bloqueo del escritor concurrente
        WAITFOR DELAY '00:00:08';

        -- Segunda lectura: garantizado el mismo resultado (no hay phantoms)
        SELECT @count = COUNT(*)
        FROM dbo.Prediction
        WHERE proposition_id = @proposition_id;

        PRINT 'SERIALIZABLE — Segunda lectura: ' + CAST(@count AS NVARCHAR) + ' (debe ser igual a la primera)';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP escritor que intenta insertar una predicción (quedará bloqueado con SERIALIZABLE)
CREATE OR ALTER PROCEDURE dbo.usp_IL_Serializable_Writer
    @player_id      INT,
    @proposition_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @predicted_outcome BIT = 1;

        -- Este INSERT quedará BLOQUEADO mientras usp_IL_Serializable_Reader
        -- tenga abierta su transacción SERIALIZABLE con key-range locks.
        INSERT INTO dbo.Prediction
            (player_id, proposition_id, predicted_outcome, amount_points, created_at, updated_at)
        VALUES
            (@player_id, @proposition_id, @predicted_outcome, 1, GETUTCDATE(), GETUTCDATE());

        COMMIT TRANSACTION;
        PRINT 'Escritor: INSERT completado (el lector ya hizo COMMIT).';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Escritor: error al insertar — ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ==============================================================================
-- RESUMEN DE DEMOS Y CÓMO EJECUTARLAS
-- ==============================================================================
/*
── DEMO 1: DIRTY READ (READ UNCOMMITTED) ──────────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_DirtyWrite_Writer @player_id = 1, @new_balance = 999999;
  Ventana 2: EXEC dbo.usp_IL_DirtyRead_Reader  @player_id = 1;
  Resultado: La ventana 2 ve 999999. La ventana 1 hace ROLLBACK → ese valor nunca existió.

── DEMO 2: NON-REPEATABLE READ (READ COMMITTED) ──────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_NonRepeatableRead @player_id = 1;
  Ventana 2 (durante los 6 s de espera):
             EXEC dbo.usp_IL_UpdateBalance @player_id = 1, @new_balance = 50;
             COMMIT;
  Resultado: Ventana 1 imprime dos valores distintos.

── DEMO 3: PHANTOM READ (REPEATABLE READ) ─────────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_PhantomRead @proposition_id = 1;
  Ventana 2 (durante los 6 s de espera):
             INSERT INTO dbo.Prediction (player_id, proposition_id, predicted_outcome,
                         amount_points, created_at, updated_at)
             VALUES (3, 1, 0, 1, GETUTCDATE(), GETUTCDATE());
             COMMIT;
  Resultado: La segunda lectura de ventana 1 muestra una fila más.

── DEMO 4: SERIALIZABLE BLOQUEA AL ESCRITOR ──────────────────────────────────
  Ventana 1: EXEC dbo.usp_IL_Serializable_Reader @proposition_id = 1;
  Ventana 2 (inmediatamente):
             EXEC dbo.usp_IL_Serializable_Writer @player_id = 3, @proposition_id = 1;
  Resultado: Ventana 2 ESPERA hasta que ventana 1 haga COMMIT (8 s).
             No hay phantom, pero hay alta contención.

── MITIGACIÓN PARA READ COMMITTED → READ_COMMITTED_SNAPSHOT ──────────────────
  Con RCSI, los lectores ven la última versión COMMITTED de la fila (row version)
  sin adquirir S-locks. Elimina dirty reads, reduce non-repeatable reads en la
  mayoría de casos y evita que lectores bloqueen escritores y viceversa.

  ALTER DATABASE GathelDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
*/
GO
