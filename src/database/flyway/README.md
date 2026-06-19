# /src/database/flyway — Gestión de Migraciones

Contiene la configuración de Flyway y todas las migraciones versionadas del proyecto. Flyway garantiza que el schema de la base de datos evolucione de forma controlada y reproducible.

---

## flyway.conf

Archivo de configuración de Flyway. Define cómo conectarse a SQL Server y dónde buscar los scripts de migración.

**Parámetros clave:**

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `flyway.url` | `jdbc:sqlserver://sql-server:1433;databaseName=GathelDB;...` | Conexión JDBC al SQL Server en Docker |
| `flyway.user` | `sa` | Usuario de conexión |
| `flyway.password` | `GathelPassword123!Secure` | Contraseña del usuario `sa` |
| `flyway.locations` | `filesystem:/flyway/sql` | Carpeta donde Flyway busca los archivos `V*.sql` |
| `flyway.baselineOnMigrate` | `true` | Permite correr sobre una BD que ya tiene datos |
| `flyway.validateOnMigrate` | `true` | Verifica checksums de migraciones ya aplicadas (detecta si alguien editó un archivo ya corrido) |

**Cómo funciona Flyway:** al arrancar, lee la tabla `flyway_schema_history` en la BD y ejecuta solo las migraciones que aún no están registradas ahí, en orden de número de versión.

---

## migrations/

Carpeta con las 6 migraciones en orden de ejecución. Ver el README dentro de esa carpeta para el detalle de cada archivo.

### Resumen rápido

| Archivo | Qué hace | Tablas/Objetos creados |
|---------|----------|------------------------|
| `V1__init_schema.sql` | Schema completo | 20 tablas, 11+ índices, 1 trigger |
| `V2__stored_procedures.sql` | Lógica de negocio | 12 stored procedures |
| `V3__seeding.sql` | Datos de prueba | 1001 jugadores, 5000 props, 107K+ transacciones |
| `V4__security_setup.sql` | Seguridad | Master Key, cert, sym key, 4 roles, 4 logins, masking, RLS |
| `V5__concurrency_transactions.sql` | Concurrencia | SPs de deadlock y aislamiento |
| `V6__demo_passwords.sql` | Demo | Normalización de contraseñas del usuario demo |
