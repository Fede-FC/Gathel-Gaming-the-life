# Guía de Flyway - Gathel Gaming Platform

Gestión de migraciones de base de datos SQL Server usando Flyway.

## 📋 Tabla de Contenidos

1. [¿Qué es Flyway?](#qué-es-flyway)
2. [Instalación](#instalación)
3. [Estructura de Carpetas](#estructura-de-carpetas)
4. [Configuración](#configuración)
5. [Migraciones en Gathel](#migraciones-en-gathel)
6. [Comandos Principales](#comandos-principales)
7. [Convenciones de Nombrado](#convenciones-de-nombrado)
8. [Troubleshooting](#troubleshooting)

---

## ¿Qué es Flyway?

**Flyway** es una herramienta de control de versiones para bases de datos. Permite:

- **Versionado de scripts SQL** (como Git, pero para BD)
- **Migraciones automáticas** en orden (V1, V2, V3...)
- **Rastreo de cambios** (tabla `flyway_schema_history`)
- **Rollback manual** (no hay undo automático en SQL Server, pero sí se pueden crear migraciones compensatorias)

### Flujo Típico

```
Inicial (vacío)
    ↓
Ejecutar V1__init_schema.sql (crea tablas)
    ↓ Registrado en flyway_schema_history
Ejecutar V2__stored_procedures.sql (crea SPs)
    ↓ Registrado en flyway_schema_history
Ejecutar V3__seeding.sql (carga datos)
    ↓ Registrado en flyway_schema_history
Ejecutar V4__security_setup.sql (configura seguridad)
    ↓ Registrado en flyway_schema_history
Ejecutar V5__concurrency_transactions.sql (SPs de concurrencia)
    ↓ Registrado en flyway_schema_history
BD Lista (v1.5)
```

---

## Instalación

### 1. Descargar Flyway

```bash
# Linux/Mac
cd /usr/local/bin
sudo wget -qO- https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/9.22.3/flyway-commandline-9.22.3-linux-x64.tar.gz | tar xvz
sudo ln -s flyway-9.22.3/flyway flyway

# Windows (Chocolatey)
choco install flyway

# Windows (Descarga manual)
# https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/
```

### 2. Verificar Instalación

```bash
flyway --version
# Debería retornar: Flyway 9.22.3 by Redgate
```

### 3. Instalar JDBC Driver para SQL Server

Flyway necesita el driver JDBC de Microsoft:

```bash
# Descargar
cd /usr/local/bin/flyway-9.22.3/jars/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.2.0.jre11/mssql-jdbc-12.2.0.jre11.jar

# O usar Maven/Gradle (recomendado)
# Incluir en pom.xml:
# <dependency>
#   <groupId>com.microsoft.sqlserver</groupId>
#   <artifactId>mssql-jdbc</artifactId>
#   <version>12.2.0.jre11</version>
# </dependency>
```

---

## Estructura de Carpetas

```
Gathel-Gaming-the-life/
├── src/database/flyway/
│   ├── flyway.conf              ← Configuración (variables de entorno)
│   └── migrations/
│       ├── V1__init_schema.sql                    ← Creación de tablas
│       ├── V2__stored_procedures.sql              ← Stored Procedures
│       ├── V3__seeding.sql                        ← Datos iniciales
│       ├── V4__security_setup.sql                 ← Seguridad, roles, RLS
│       └── V5__concurrency_transactions.sql       ← SPs de concurrencia y demos
│
├── src/database/security-lab/
│   ├── 01_master_key_cert.sql               ← Demo: Cifrado
│   ├── 02_roles_users.sql                   ← Demo: Roles
│   ├── 03_permissions_demo.sql              ← Demo: Permisos
│   ├── 04_data_masking.sql                  ← Demo: Masking
│   ├── 05_rls.sql                           ← Demo: RLS
│   └── README.md
│
└── src/database/concurrency/
    ├── 01_nested_transactions.sql           ← Demo: Transacciones anidadas (3 niveles)
    ├── 02_deadlock_writes.sql               ← Demo: Deadlock entre escrituras
    ├── 03_deadlock_read_write.sql           ← Demo: Deadlock lectura/escritura
    ├── 04_deadlock_cyclic.sql               ← Demo: Deadlock cíclico T1→T2→T3→T1
    ├── 05_isolation_levels.sql              ← Demo: 4 niveles de aislamiento
    └── README.md
```

**Notas**:
- Los scripts en `security-lab/` y `concurrency/` NO están versionados con Flyway
- Son scripts de **demostración** que se ejecutan manualmente desde SSMS después de Flyway
- Las migraciones reales en `migrations/` siguen la convención `V#__description.sql`

---

## Configuración

### flyway.conf

Ubicación: `src/database/flyway/flyway.conf`

```properties
# Conexión a BD (sobrescribible con env vars)
flyway.url=${FLYWAY_URL:jdbc:sqlserver://localhost:1433;databaseName=GathelDB;encrypt=true;trustServerCertificate=true}
flyway.user=${FLYWAY_USER:sa}
flyway.password=${FLYWAY_PASSWORD}

# Esquema
flyway.schemas=dbo

# Ubicación de migraciones
flyway.locations=filesystem:./migrations

# Convención de nombres
flyway.sqlMigrationPrefix=V
flyway.sqlMigrationSeparator=__
flyway.sqlMigrationSuffixes=.sql

# Comportamiento
flyway.baselineOnMigrate=true     # Crear baseline si BD existe
flyway.outOfOrder=false            # No permitir migraciones fuera de orden
flyway.validateOnMigrate=true      # Validar integridad antes de ejecutar
```

### Variables de Entorno

```bash
# Archivo: .env (NO commitear a Git)
export FLYWAY_URL="jdbc:sqlserver://localhost:1433;databaseName=GathelDB;encrypt=true;trustServerCertificate=true"
export FLYWAY_USER="sa"
export FLYWAY_PASSWORD="YourPassword123!Secure"
```

O sobrescribir en línea de comandos:

```bash
flyway -url=jdbc:sqlserver://... -user=sa -password=... migrate
```

---

## Migraciones en Gathel

### V1: init_schema.sql

**Contenido**: Creación de 16 tablas, índices, constraints, triggers

```sql
CREATE TABLE Player (
    player_id INT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50) UNIQUE NOT NULL,
    email NVARCHAR(150) UNIQUE NOT NULL,
    password_hash NVARCHAR(256) NOT NULL,
    balance_points BIGINT DEFAULT 100,
    balance_version INT DEFAULT 1,
    enabled BIT DEFAULT 1,
    created_at DATETIME2 DEFAULT GETUTCDATE()
);
```

**Índices**: 11+ covering indexes en Proposition, Transaction, Prediction, Vote, GameEvent

**Trigger**: `tr_proposition_audit` (registra cambios en PropositionAudit)

### V2: stored_procedures.sql

**Contenido**: 12 Stored Procedures transaccionales

- `usp_RegisterPlayer` - Registra jugador con puntos iniciales
- `usp_CreateProposition` - Crea proposición
- `usp_RecordAIReview` - Registra revisión AI
- `usp_AcceptProposition` - Jugador acepta proposición
- `usp_RejectProposition` - Jugador rechaza (penalización -1 pt)
- `usp_PlacePrediction` - Registra predicción
- `usp_ClosePropositionPredictions` - Cierra período de predicciones
- `usp_ResolveProposition` - Resuelve proposición y distribuye premios
- `usp_DepositMoney` - Registra depósito de dinero real
- `usp_GetPlayerDashboard` - Retorna balance y proposiciones activas
- `usp_GetActivePropositions` - Lista proposiciones con paginación
- `usp_GetPropositionResults` - Proposiciones resueltas del jugador

### V3: seeding.sql

**Contenido**: Datos de demo

- **1,000 jugadores**: Nombres hispanohablantes realistas
- **5,000 proposiciones**: Distribución realista de estados
- **~250,000 GameEvents**: Eventos de ciclo de vida
- **Votos, Predicciones, Transacciones**: Correlacionados con proposiciones

**Idempotente**: Verifica existencia antes de insertar

```sql
IF NOT EXISTS (SELECT 1 FROM dbo.PropositionStatus WHERE status_code = 'PENDING')
BEGIN
    INSERT INTO dbo.PropositionStatus VALUES ('PENDING', '...', 1);
END
```

### V4: security_setup.sql

**Contenido**: Seguridad de Fase 3

- **Master Key + Certificate + Symmetric Key**: Cifrado
- **4 Roles**: admin, system, player, readonly
- **4 Logins**: gathel_admin_usr, gathel_system_usr, gathel_player_usr, gathel_readonly_usr
- **Dynamic Data Masking**: email, balance_points, account_username
- **Row-Level Security**: Tabla Transaction protegida
- **Vistas de Seguridad**: vw_PlayerBalance, vw_MyTransactions

### V5: concurrency_transactions.sql

**Contenido**: Transacciones y Concurrencia de Fase 4

- **Transacciones anidadas (3 niveles)**: `usp_Nested_L1/L2/L3` usando savepoints
- **Deadlocks con escrituras**: `usp_DL_Write_SessionA/B` — orden inverso de locks
- **Deadlock lectura/escritura**: `usp_DL_Read_PlayerSummary` + `usp_DL_Write_PredictionProcess`
- **Deadlock cíclico**: `usp_DL_Cyclic_T1/T2/T3` — ciclo T1→T2→T3→T1
- **Niveles de aislamiento**: 8 SPs (`usp_IL_*`) demostrando dirty read, non-repeatable read, phantom read y serializable
- **Demos inline**: ejecuta Demo 1 (éxito) y Demo 2 (fallo en L3) durante la migración

**Scripts de demo manual** (en `src/database/concurrency/`): ejecutar cada `.sql` desde SSMS abriendo múltiples ventanas según el README.md de la carpeta.

---

## Comandos Principales

### 1. Ver Estado de Migraciones

```bash
cd src/database/flyway
flyway info
```

**Salida esperada**:
```
Flyway Report
┌────────────────────────────────────────────────────────────────────────┐
│ Schema: dbo                                                             │
├─────┬──────────────────────────────┬──────┬─────────┬─────────────────┤
│ Ver │ Description                  │ Type │ Status  │ Installed       │
├─────┼──────────────────────────────┼──────┼─────────┼─────────────────┤
│ 1   │ init schema                  │ SQL  │ Success │ 2026-06-17      │
│ 2   │ stored procedures            │ SQL  │ Success │ 2026-06-17      │
│ 3   │ seeding                      │ SQL  │ Success │ 2026-06-17      │
│ 4   │ security setup               │ SQL  │ Success │ 2026-06-17      │
│ 5   │ concurrency transactions     │ SQL  │ Success │ 2026-06-17      │
└─────┴──────────────────────────────┴──────┴─────────┴─────────────────┘
```

### 2. Ejecutar Migraciones

```bash
flyway migrate
```

**Salida**:
```
Flyway 9.22.3 by Redgate
Successfully validated 5 migrations (execution time 00:00.XXXs)
Migrating schema [dbo] to version "1 - init schema"
Migrating schema [dbo] to version "2 - stored procedures"
Migrating schema [dbo] to version "3 - seeding"
Migrating schema [dbo] to version "4 - security setup"
Migrating schema [dbo] to version "5 - concurrency transactions"
Successfully applied 5 migrations to schema [dbo], now at version v5
```

### 3. Validar Integridad

```bash
flyway validate
```

Verifica que los scripts no hayan sido modificados después de ejecutados.

### 4. Limpiar BD (⚠️ DESTRUCTIVO)

```bash
flyway clean
```

**ADVERTENCIA**: Elimina TODAS las tablas y el historial. Solo para desarrollo local.

### 5. Baseline para BD Existente

```bash
# Si ya tienes una BD con datos y quieres trackear cambios futuros
flyway baseline -baselineVersion=0 -baselineDescription="BD existente"
```

---

## Convenciones de Nombrado

### Formato de Migración

```
V<VERSION>__<DESCRIPTION>.sql
```

**Ejemplos**:
- `V1__init_schema.sql` ✓
- `V2__stored_procedures.sql` ✓
- `V3__seeding.sql` ✓
- `V4__security_setup.sql` ✓
- `V5__concurrency_transactions.sql` ✓
- `V6__add_audit_logging.sql` ✓

### Reglas

- **Versión**: Número entero o decimal (1, 2, 2.1, 3)
- **Separador**: Dos guiones bajos (`__`)
- **Descripción**: CamelCase o snake_case, descriptiva
- **Extensión**: `.sql`
- **No reordenar**: V1, V2, V3... deben ejecutarse en orden
- **Inmutables**: Una vez ejecutada, la migración NO debe modificarse

---

## Troubleshooting

### Error: "Password is missing"

```
Error: Unable to connect to database at
```

**Solución**:

```bash
export FLYWAY_PASSWORD="YourPassword"
flyway migrate
```

O en el comando:

```bash
flyway -password=YourPassword migrate
```

### Error: "Cannot create a login for MSSQL Driver"

Está usando la URL incorrecta. SQL Server JDBC usa:

```
jdbc:sqlserver://HOST:PORT;databaseName=DB;encrypt=true;trustServerCertificate=true
```

**NO**:
```
jdbc:sqlserver://HOST:PORT/DB   ← INCORRECTO
```

### Error: "Validate failed"

Una migración fue modificada después de ejecutarla.

```bash
# Verificar qué cambió
git diff src/database/flyway/migrations/V3__seeding.sql
```

**Solución**: Revertir cambios o crear nueva migración (V5) con los cambios.

### Error: "Out of order"

Intentó ejecutar V5 antes de V4.

```bash
# Ver estado
flyway info

# Asegurar que todas las versiones están en orden
ls src/database/flyway/migrations/ | sort
```

### Base de datos no se crea automáticamente

Flyway NO crea la BD, solo el schema. Crear manualmente:

```sql
CREATE DATABASE GathelDB;
```

Luego:

```bash
flyway migrate
```

### Error: "Timeout" en seeding

El seeding de 1000 jugadores + 5000 proposiciones es lento.

```bash
# Aumentar timeout (segundos)
flyway -placeholders.timeout=300 migrate
```

O en flyway.conf:

```properties
flyway.connectRetries=3
```

---

## Workflow Recomendado

### Desarrollo Local

```bash
# 1. Clonar repo
git clone https://github.com/Fede-FC/Gathel-Gaming-the-life.git
cd Gathel-Gaming-the-life

# 2. Crear BD (SQL Server Management Studio o sqlcmd)
sqlcmd -S localhost -U sa
> CREATE DATABASE GathelDB;
> GO

# 3. Configurar variables de entorno
cp .env.example .env
# Editar .env con credenciales locales

# 4. Ejecutar migraciones
cd src/database/flyway
source ../../.env  # o export en PowerShell
flyway migrate

# 5. Verificar
flyway info

# 6. Ejecutar demos del Security Lab (opcional)
cd ../security-lab
sqlcmd -U sa -P YourPassword -d GathelDB -i 01_master_key_cert.sql
sqlcmd -U sa -P YourPassword -d GathelDB -i 02_roles_users.sql
# ... etc
```

### CI/CD (Producción)

```yaml
# .github/workflows/migrate.yml
name: Flyway Migration
on: [push]

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Flyway
        run: |
          cd src/database/flyway
          flyway -url=${{ secrets.DB_URL }} \
                 -user=${{ secrets.DB_USER }} \
                 -password=${{ secrets.DB_PASSWORD }} \
                 migrate
```

---

## Tabla de Referencia

| Comando | Función |
|---------|---------|
| `flyway info` | Ver estado de migraciones |
| `flyway migrate` | Ejecutar migraciones pendientes |
| `flyway validate` | Validar integridad de scripts |
| `flyway baseline` | Marcar BD existente como v0 |
| `flyway clean` | Eliminar TODO (⚠️ destructivo) |
| `flyway undo` | Deshacer última migración (Enterprise) |

---

## Recursos

- [Documentación oficial de Flyway](https://flywaydb.org/documentation/database/sqlserver)
- [SQL Server JDBC Driver](https://learn.microsoft.com/en-us/sql/connect/jdbc/microsoft-jdbc-driver-for-sql-server)
- [Flyway - Best Practices](https://flywaydb.org/documentation/guides/database-setup)

---

**Versión**: 1.0  
**Última actualización**: 15 Junio 2026  
**Estado**: ✅ Completado
