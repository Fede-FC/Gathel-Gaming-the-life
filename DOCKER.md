# Gathel Gaming - Setup con Docker Compose

Guía rápida para ejecutar Gathel con Docker (sin instalar SQL Server ni Flyway localmente).

## 🚀 Quick Start (2 pasos)

### Paso 1: Tener Docker instalado

```bash
# Verificar que Docker está instalado
docker --version
# Debería mostrar: Docker version 20.x.x o superior

# Si no lo tienes:
# Windows/Mac: https://www.docker.com/products/docker-desktop
# Linux: sudo apt-get install docker.io docker-compose
```

### Paso 2: Ejecutar Gathel

```bash
# En la raíz del proyecto
./scripts/docker-setup.sh up

# Espera ~30 segundos mientras se inician los contenedores
# Verás los logs de Flyway ejecutando las migraciones V1-V4
```

**¡Listo!** SQL Server + Base de datos + Datos + Seguridad todo funcionando.

---

## 📋 Qué Está Pasando Internamente

```
Tu máquina (localhost)
    ↓
docker-compose.yml
    ├─ Contenedor: sql-server
    │   ├─ Imagen: mcr.microsoft.com/mssql/server:2022-latest
    │   ├─ Puerto: 1433
    │   └─ Volumen: sql-data (persiste datos)
    │
    └─ Contenedor: flyway
        ├─ Imagen: flyway/flyway:9.22.3-alpine
        ├─ Monta: ./src/database/flyway/migrations
        └─ Ejecuta: V1, V2, V3, V4 automáticamente
```

**Lo importante**: 
- Flyway está **DENTRO** del contenedor Docker, no en tu máquina
- SQL Server está **DENTRO** de otro contenedor
- Tu máquina solo tiene el código del proyecto y Docker

---

## 🛠️ Comandos Útiles

### Ver estado
```bash
./scripts/docker-setup.sh status
```

**Salida esperada**:
```
NAME              STATUS
gathel-sql-server  Up 2 minutes (healthy)
gathel-flyway      Exited (0)
```

✓ `sql-server`: Debe estar `Up` y `healthy`
✓ `flyway`: Puede estar `Exited (0)` (completó y terminó)

---

### Ver logs
```bash
./scripts/docker-setup.sh logs
```

Verás algo como:
```
flyway    | Flyway 9.22.3
flyway    | Successfully applied 4 migrations to schema version 4.0.0
flyway    | (execution time 45.234s)
```

---

### Conectarse a SQL Server
```bash
./scripts/docker-setup.sh sql

# O manualmente con sqlcmd:
sqlcmd -S localhost -U sa -P GathelPassword123!Secure -d GathelDB

# Luego ejecutar queries SQL:
> SELECT COUNT(*) FROM dbo.Player;
> GO
```

---

### Ejecutar migraciones manualmente
```bash
./scripts/docker-setup.sh migrate
```

(Normalmente ya se ejecutan automáticamente con `up`)

---

### Detener los contenedores
```bash
./scripts/docker-setup.sh down

# Los datos persisten en el volumen sql-data
# Si ejecutas `./scripts/docker-setup.sh up` de nuevo, verás los mismos datos
```

---

### Limpiar todo (DESTRUCTIVO)
```bash
./scripts/docker-setup.sh clean
# Elimina datos de la BD

./scripts/docker-setup.sh rebuild
# Detiene, elimina volumen, reinicia, migra todo de nuevo
```

---

## 🔍 Verificación Completa

Después de `./scripts/docker-setup.sh up`:

### 1. Verificar que SQL Server está corriendo
```bash
docker ps
```

Deberías ver:
```
IMAGE                                   STATUS
mcr.microsoft.com/mssql/server:2022...  Up X minutes (healthy)
```

### 2. Conectar a BD y verificar datos
```bash
./scripts/docker-setup.sh sql

# Dentro de sqlcmd:
SELECT COUNT(*) FROM dbo.Player;          -- ~1000
SELECT COUNT(*) FROM dbo.Proposition;     -- ~5000
SELECT COUNT(*) FROM dbo.[Transaction];   -- ~5000+
SELECT COUNT(*) FROM dbo.GameEvent;       -- ~250,000

-- Ver roles
SELECT name FROM sys.database_principals WHERE name LIKE 'db_gathel%';

-- Ver si Flyway registró migraciones
SELECT version, description FROM flyway_schema_history;

EXIT
```

### 3. Verificar RLS y Masking
```bash
./scripts/docker-setup.sh sql

-- Data Masking
SELECT TOP 1 email FROM dbo.Player;  -- Como admin, ve email real
-- Resultado: sofia.garcia1@gathel.dev

-- RLS
SELECT name FROM sys.security_policies;  -- Debería ver TransactionSecurityPolicy

EXIT
```

---

## ⚙️ Configuración (si necesitas cambiar credenciales)

Edita `docker-compose.yml`:

```yaml
sql-server:
  environment:
    MSSQL_SA_PASSWORD: "TU_PASSWORD_AQUI"  # Cambiar aquí
```

También en `scripts/docker-setup.sh` y `src/database/flyway/flyway.conf`:

```properties
flyway.password=${FLYWAY_PASSWORD:TU_PASSWORD_AQUI}
```

---

## 🔗 Conectar desde tu Aplicación (Backend)

### Si tu app está en Docker también

En `docker-compose.yml`, usa el nombre del servicio como host:

```javascript
// Node.js
const connection = new sql.Connection({
  server: 'sql-server',        // nombre del servicio en docker-compose
  authentication: { type: 'default', options: { userName: 'sa', password: 'GathelPassword123!Secure' } },
  options: { database: 'GathelDB', encrypt: false }
});
```

### Si tu app está en tu máquina (local)

```javascript
// Node.js
const connection = new sql.Connection({
  server: 'localhost',         // en tu máquina
  authentication: { type: 'default', options: { userName: 'sa', password: 'GathelPassword123!Secure' } },
  options: { database: 'GathelDB', encrypt: false }
});
```

---

## ❓ Troubleshooting

### Error: "Cannot find docker"
```
Instala Docker Desktop: https://www.docker.com/products/docker-desktop
```

### Error: "docker-compose: command not found"
```bash
# Instalar docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Error: "Port 1433 is already in use"
```bash
# Otra app usa el puerto. Opciones:

# A) Detener la otra app
# B) Cambiar puerto en docker-compose.yml:
#    ports:
#      - "1434:1433"  ← usar puerto 1434

# C) Listar qué usa el puerto
lsof -i :1433  # macOS/Linux
netstat -ano | findstr :1433  # Windows
```

### Error: "Flyway migration failed"
```bash
# Ver logs detallados
docker-compose logs flyway

# Si hay problema con los scripts SQL:
# 1. Verificar sintaxis en src/database/flyway/migrations/
# 2. Limpiar y reintentar:
./scripts/docker-setup.sh rebuild
```

### Error: "Database already exists"
```bash
# Cleanar BD y reintentar
./scripts/docker-setup.sh clean
./scripts/docker-setup.sh up
```

---

## 📊 Diferencia: Docker vs Local

| Aspecto | Docker Compose | Local |
|---------|---|---|
| **Instalaciones** | Solo Docker | SQL Server + Flyway + sqlcmd |
| **Configuración** | Un archivo (docker-compose.yml) | Variables de entorno + PATH |
| **Datos** | Volumen Docker (persisten) | Carpeta local |
| **Portabilidad** | 100% (funciona en cualquier PC con Docker) | Depende del SO |
| **Seguridad** | Aislado en contenedor | Sistema abierto |
| **Velocidad** | Más lenta (virtualización) | Más rápida (nativa) |

---

## 🚀 Próximos Pasos

Una vez que `./scripts/docker-setup.sh up` funcione:

1. **Verifica datos**:
   ```bash
   ./scripts/docker-setup.sh sql
   SELECT COUNT(*) FROM dbo.Player;
   ```

2. **Ejecuta demos de Security Lab**:
   ```bash
   docker exec gathel-sql-server sqlcmd -U sa -P GathelPassword123!Secure -d GathelDB -i /path/to/01_master_key_cert.sql
   ```

3. **Continúa con Fase 4** (Transacciones y Concurrencia)

---

**Versión**: 1.0  
**Fecha**: 15 Junio 2026  
**Status**: ✅ Docker Compose configurado y listo
