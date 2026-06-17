# Gathel Gaming — Setup con Docker Compose

Guía para levantar el stack completo de Gathel con Docker: SQL Server, Flyway, Backend (FastAPI) y Frontend (React).

---

## 🚀 Quick Start (2 pasos)

### Paso 1: Verificar Docker

```bash
docker --version        # Docker 20.x o superior
docker compose version  # v2.x (incluido en Docker Desktop)
```

### Paso 2: Levantar todo

```bash
# En la raíz del proyecto
docker compose up --build -d

# Seguir las migraciones de Flyway (tarda ~3-4 min)
docker compose logs flyway --follow
```

Cuando Flyway muestre `Successfully applied 6 migrations`, el stack está listo:

| Servicio | URL |
|----------|-----|
| **Frontend** | http://localhost:3000 |
| **Backend (Swagger)** | http://localhost:8000/docs |
| **SQL Server** | localhost:1433 |

**Credenciales demo:**  
Usuario: `demo_admin` — Contraseña: `Password123!`  
(Cualquier jugador del seeding también usa `Password123!`)

---

## 📋 Qué está pasando internamente

```
Tu máquina (localhost)
    ↓
docker-compose.yml
    ├─ sql-server       (mcr.microsoft.com/mssql/server:2022-latest)
    │   ├─ Puerto: 1433
    │   └─ Volumen: sql-data (persiste datos)
    │
    ├─ db-init          (mssql-tools — se ejecuta una sola vez)
    │   └─ Crea la BD GathelDB si no existe (idempotente)
    │
    ├─ flyway           (flyway/flyway:9.22.3-alpine — se ejecuta una sola vez)
    │   └─ Aplica V1 → V6 automáticamente (~3-4 min)
    │
    ├─ backend          (Python 3.11 + FastAPI + pymssql)
    │   └─ Puerto: 8000
    │
    └─ frontend         (node:20 build → nginx:alpine serve)
        └─ Puerto: 3000 → nginx proxea /api/* a backend:8000
```

### Orden de arranque

```
sql-server (healthy) → db-init → flyway → backend → frontend
```

Todos los servicios después de `flyway` esperan que las migraciones terminen antes de iniciar.

---

## 🛠️ Comandos útiles

### Ver estado de los contenedores

```bash
docker compose ps
```

Salida esperada (cuando todo está corriendo):

```
NAME                STATUS
gathel-sql-server   Up X minutes (healthy)
gathel-db-init      Exited (0)
gathel-flyway       Exited (0)
gathel-backend      Up X minutes
gathel-frontend     Up X minutes
```

- `sql-server`: debe estar `Up` y `(healthy)`
- `db-init` y `flyway`: `Exited (0)` es correcto (terminaron su trabajo)
- `backend` y `frontend`: deben estar `Up`

### Ver logs

```bash
# Todos los servicios
docker compose logs

# Un servicio específico (en vivo)
docker compose logs backend --follow
docker compose logs flyway --follow
```

### Conectarse a SQL Server

```bash
# Con el helper
./scripts/docker-setup.sh sql

# O directamente con sqlcmd
sqlcmd -S localhost,1433 -U sa -P "GathelPassword123!Secure" -d GathelDB
```

### Detener sin borrar datos

```bash
docker compose down
# El volumen sql-data persiste; al hacer "up" de nuevo los datos siguen ahí
```

### Limpiar todo y reiniciar desde cero

```bash
docker compose down -v    # borra el volumen sql-data
docker compose up --build -d
```

---

## 🔍 Verificación completa

### 1. Base de datos

```bash
./scripts/docker-setup.sh sql

-- Verificar datos del seeding
SELECT COUNT(*) FROM dbo.Player;          -- 1001
SELECT COUNT(*) FROM dbo.Proposition;     -- 5000
SELECT COUNT(*) FROM dbo.[Transaction];   -- ~107,000+
SELECT COUNT(*) FROM dbo.GameEvent;       -- ~250,000

-- Verificar migraciones de Flyway
SELECT version, description, success FROM dbo.flyway_schema_history ORDER BY installed_rank;

EXIT
```

### 2. Backend

```bash
# Healthcheck
curl http://localhost:8000/api/health
# → {"status":"ok","service":"gathel-backend"}

# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo_admin","password":"Password123!"}'
# → {"access_token":"...","player_id":1001,"username":"demo_admin",...}
```

### 3. Frontend

Abrir `http://localhost:3000` en el navegador → aparece la pantalla de login.  
Ingresar `demo_admin` / `Password123!` → redirige al Dashboard.

### 4. Seguridad (RLS y Masking)

```sql
-- Desde sqlcmd como sa (ve datos reales)
SELECT TOP 1 email FROM dbo.Player;         -- email real
SELECT name FROM sys.security_policies;     -- TransactionSecurityPolicy
SELECT name FROM sys.database_principals WHERE name LIKE 'db_gathel%';
```

---

## ⚙️ Configuración

Las credenciales y variables de entorno están en `docker-compose.yml`:

| Variable | Valor por defecto | Servicio |
|----------|-------------------|----------|
| `MSSQL_SA_PASSWORD` | `GathelPassword123!Secure` | sql-server |
| `DB_HOST` | `sql-server` | backend |
| `DB_PORT` | `1433` | backend |
| `DB_NAME` | `GathelDB` | backend |
| `DB_USER` | `sa` | backend |
| `DB_PASSWORD` | `GathelPassword123!Secure` | backend |
| `JWT_SECRET` | `gathel-jwt-secret-change-in-production` | backend |

Para cambiar el password: actualizarlo en todas las variables de `docker-compose.yml` y en `src/database/flyway/flyway.conf`.

---

## 🔗 Conectarse desde fuera de Docker

### Backend (desde tu máquina o Postman)

```
Base URL: http://localhost:8000
Swagger:  http://localhost:8000/docs
```

### SQL Server (desde SSMS, Azure Data Studio, etc.)

```
Server:   localhost,1433
Login:    sa
Password: GathelPassword123!Secure
Database: GathelDB
Encrypt:  opcional (trustServerCertificate=true)
```

---

## ❓ Troubleshooting

### Flyway falla con "Migration checksum mismatch"

Los archivos de migración cambiaron después de ser aplicados. Solución:

```bash
docker compose down -v
docker compose up --build -d
```

### El backend no conecta a SQL Server

Verificar que Flyway terminó exitosamente antes de que el backend intente conectar:

```bash
docker compose logs flyway | tail -5
# Debe mostrar: "Successfully applied 6 migrations"
```

Si el backend arrancó antes que Flyway termine, reiniciarlo:

```bash
docker compose restart backend
```

### Error "Port 1433/8000/3000 already in use"

Otra aplicación usa el puerto. Cambiar el puerto externo en `docker-compose.yml`:

```yaml
ports:
  - "1434:1433"   # usar 1434 en lugar de 1433
```

### El frontend muestra errores de red (`ERR_CONNECTION_REFUSED`)

El backend no está corriendo. Verificar:

```bash
docker compose ps backend   # debe estar "Up"
docker compose logs backend --follow
```

---

## 📊 Scripts helper

```bash
./scripts/docker-setup.sh up        # Iniciar todo
./scripts/docker-setup.sh down      # Detener (conserva datos)
./scripts/docker-setup.sh sql       # Conectar a BD via sqlcmd
./scripts/docker-setup.sh logs      # Ver logs en vivo
./scripts/docker-setup.sh rebuild   # Limpiar y reiniciar desde cero
./scripts/docker-setup.sh status    # Estado de los contenedores
```

---

**Versión**: 2.0  
**Fecha**: 17 Junio 2026  
**Status**: ✅ Stack completo — V1-V6 (Fases 1-8) completadas
