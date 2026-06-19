# /docs — Documentación General del Proyecto

Contiene las guías operativas principales del proyecto: cómo correr el stack con Docker y cómo funciona Flyway.

---

## DOCKER.md

Guía completa para levantar y operar el stack con Docker Compose.

**Contenido:**
- Requisitos previos (Docker Desktop, puertos disponibles)
- Descripción de los 5 servicios del `docker-compose.yml`:
  - `sql-server` — SQL Server 2022 en contenedor, expone puerto 1433
  - `db-init` — contenedor auxiliar que espera a que SQL Server esté listo y crea la base `GathelDB`
  - `flyway` — corre las 6 migraciones en orden (V1 → V6) y termina
  - `backend` — FastAPI en Python, expone puerto 8000
  - `frontend` — React compilado servido por nginx, expone puerto 3000
- Comando principal: `docker compose up --build -d`
- Cómo verificar que todo levantó correctamente (`docker compose ps`, `docker compose logs`)
- Credenciales de cada servicio
- Cómo detener y limpiar el entorno

**Cuándo usarlo:** antes de la defensa para verificar que el stack completo funciona de punta a punta.

---

## FLYWAY.md

Guía detallada de la gestión de migraciones con Flyway.

**Contenido:**
- Qué es Flyway y por qué se usa (control de versiones de esquema SQL)
- Cómo Flyway ejecuta las migraciones en orden y las marca en la tabla `flyway_schema_history`
- Descripción de cada migración:
  - `V1__init_schema.sql` — creación de las 20 tablas y el trigger de auditoría
  - `V2__stored_procedures.sql` — los 12 stored procedures del MVP
  - `V3__seeding.sql` — datos de prueba: 1001 jugadores, 5000 proposiciones, 107K+ transacciones
  - `V4__security_setup.sql` — Master Key, certificado, clave simétrica, 4 roles, 4 logins, Data Masking, RLS
  - `V5__concurrency_transactions.sql` — SPs de deadlock y niveles de aislamiento
  - `V6__demo_passwords.sql` — normalización de contraseñas para el usuario demo
- Archivo de configuración `flyway.conf` y sus parámetros
- Cómo ejecutar migraciones manualmente fuera de Docker

**Cuándo usarlo:** si necesitás agregar una nueva migración (ej. V7) o entender por qué Flyway falló.
