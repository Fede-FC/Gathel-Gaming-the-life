# Gathel — Gaming the life

**Caso #3 — Bases de Datos (Primer Semestre 2026)**

Gathel es una plataforma digital de predicciones basada en acciones y eventos de la vida real de las personas, validados mediante redes sociales e inteligencia artificial. Cada jugador inicia con 100 puntos virtuales y puede crear proposiciones, votar, predecir (con puntos o dinero real) y recibir recompensas según los resultados validados por IA.

> Especificación completa del caso: [`caso #3.md`](./caso%20%233.md)

---

## 📊 Estado del proyecto

| Fase | Descripción | Estado | Entregas |
|------|-------------|--------|----------|
| **1. Diseño de BD** | Especificación, análisis de IA, DBML | ✅ Completada | specification.md, design.dbml, 4 análisis IA |
| **2. Flyway** | Migraciones versionadas + seeding | ✅ Completada | V1-V6, Docker Compose, flyway.conf, docs |
| **3. Security Lab** | Roles, permisos, RLS, Data Masking, cifrado | ✅ Completada | 5 demos, README.md, Master Key, 4 roles |
| **4. Transacciones y concurrencia** | SPs anidados, deadlocks, aislamiento | ✅ Completada | 5 scripts, 18 SPs, 4 niveles de aislamiento |
| **5. Backend MVP** | REST API (ORM lectura + SP escritura) | ✅ Completada | FastAPI, 5 endpoints, JWT, connection pool |
| **6. Frontend MVP** | UI web | ✅ Completada | React + Vite, 4 páginas, nginx |
| **7. Docker** | `docker-compose` completo | ✅ Completada | 5 servicios, build automático |
| **8. Documentación** | README, DOCKER, FLYWAY, CLAUDE | ✅ Completada | Todos los docs actualizados |

**Progreso: 8/8 fases completadas (100%)**

Detalle de fases y cronograma: [`CLAUDE.md`](./CLAUDE.md)

---

## 🚀 Quick Start

```bash
# Levantar todo (SQL Server + Migraciones + Backend + Frontend)
docker compose up --build -d

# Esperar ~3-4 minutos a que Flyway termine las migraciones
docker compose logs flyway --follow

# Una vez que flyway muestre "Successfully applied 6 migrations":
# Frontend → http://localhost:3000
# Backend  → http://localhost:8000/docs  (Swagger UI)
# SQL Server → localhost:1433  (sa / GathelPassword123!Secure / GathelDB)
```

**Credenciales demo:**
- Usuario: `demo_admin` — Contraseña: `Password123!`
- Cualquier jugador del seeding también usa `Password123!`

Guía completa: [`DOCKER.md`](./DOCKER.md)

---

## 🗂️ Estructura del repositorio

```
Gathel-Gaming-the-life/
├── README.md
├── CLAUDE.md                           # Plan de desarrollo y cronograma
├── DOCKER.md                           # Guía Docker Compose
├── docker-compose.yml                  # 5 servicios: sql-server, db-init, flyway, backend, frontend
├── caso #3.md                          # Especificación original del caso
├── scripts/
│   └── docker-setup.sh                 # Helper para comandos Docker
├── src/
│   ├── database/
│   │   ├── design/                     # Fase 1 — Diseño de BD
│   │   │   ├── specification.md
│   │   │   ├── design.dbml
│   │   │   └── ai-analysis/
│   │   ├── flyway/
│   │   │   └── migrations/             # Fase 2 — Migraciones V1-V6
│   │   │       ├── V1__init_schema.sql
│   │   │       ├── V2__stored_procedures.sql
│   │   │       ├── V3__seeding.sql
│   │   │       ├── V4__security_setup.sql
│   │   │       ├── V5__concurrency_transactions.sql
│   │   │       └── V6__demo_passwords.sql
│   │   ├── security-lab/               # Fase 3 — Demos de seguridad
│   │   │   ├── 01_master_key_cert.sql
│   │   │   ├── 02_roles_users.sql
│   │   │   ├── 03_permissions_demo.sql
│   │   │   ├── 04_data_masking.sql
│   │   │   ├── 05_rls.sql
│   │   │   └── README.md
│   │   └── concurrency/                # Fase 4 — Demos de concurrencia
│   │       ├── 01_nested_transactions.sql
│   │       ├── 02_deadlock_writes.sql
│   │       ├── 03_deadlock_read_write.sql
│   │       ├── 04_deadlock_cyclic.sql
│   │       ├── 05_isolation_levels.sql
│   │       └── README.md
│   ├── backend/                        # Fase 5 — REST API (FastAPI)
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── app/
│   │       ├── main.py
│   │       ├── database.py
│   │       ├── models.py
│   │       ├── schemas.py
│   │       ├── auth.py
│   │       └── routers/
│   │           ├── auth.py
│   │           ├── players.py
│   │           ├── propositions.py
│   │           └── predictions.py
│   └── frontend/                       # Fase 6 — UI (React + Vite)
│       ├── Dockerfile
│       ├── nginx.conf
│       ├── vite.config.js
│       └── src/
│           ├── App.jsx
│           ├── index.css
│           ├── api/client.js
│           ├── context/AuthContext.jsx
│           ├── components/Navbar.jsx
│           └── pages/
│               ├── Login.jsx
│               ├── Dashboard.jsx
│               ├── Propositions.jsx
│               └── Results.jsx
└── docs/
    └── FLYWAY.md
```

---

## 🏛️ Fase 1 — Diseño de la base de datos

### Documentos principales

| Documento | Descripción |
|-----------|-------------|
| [`specification.md`](./src/database/design/specification.md) | **Fuente de verdad.** Especificación en Markdown de todas las tablas, campos, restricciones, índices, vistas, estrategia de seguridad y reglas de negocio. |
| [`design.dbml`](./src/database/design/design.dbml) | Diagrama en formato DBML. Importable en [dbdiagram.io](https://dbdiagram.io). |

### Modelo de datos (resumen)

20 tablas organizadas en cinco grupos:

- **Catálogos:** `PropositionStatus`, `SocialNetwork`, `CurrencyType`, `ExchangeRate`, `TransactionType`, `EventType`, `AIModel`, `AIProvider`
- **Autenticación y redes sociales:** `Player`, `SocialAccount`, `SocialAccountSession`
- **Proposiciones y predicciones:** `Proposition`, `Vote`, `Prediction`, `PropositionEvidence`
- **Transacciones:** `Transaction`
- **Auditoría e IA:** `AIReviewLog`, `GameEvent`, `ProcessLog`, `PropositionAudit`

### Decisiones de diseño destacadas

- **Transacciones unificadas:** una sola tabla `Transaction` + catálogo `CurrencyType` soporta N monedas (puntos, USD, etc.) sin agregar tablas.
- **Tasas de cambio con histórico:** `ExchangeRate` guarda la tasa por fecha.
- **Un monto, una moneda:** `Prediction` usa `amount` + `currency_type_id`; predecir con "ambos" = dos filas.
- **Tokens en tabla aparte:** `SocialAccountSession` aísla los tokens con Always Encrypted.
- **Sin hardcoding:** tasas, configuraciones y constantes viven en catálogos/tablas.

### Revisión por agentes de IA

| Documento | Enfoque |
|-----------|---------|
| [`01_seguridad_analisis.md`](./src/database/design/ai-analysis/01_seguridad_analisis.md) | Cifrado, auditoría, RLS, race conditions |
| [`02_indices_performance.md`](./src/database/design/ai-analysis/02_indices_performance.md) | Índices covering/filtrados para queries críticas |
| [`03_normalizacion_diseno.md`](./src/database/design/ai-analysis/03_normalizacion_diseno.md) | 3NF/BCNF; desnormalizaciones justificadas |
| [`04_escalabilidad.md`](./src/database/design/ai-analysis/04_escalabilidad.md) | Proyecciones de crecimiento; roadmap futuro |

---

## 📦 Fase 2 — Gestión de Migraciones (Flyway)

### Migraciones SQL versionadas

| Migración | Contenido |
|-----------|-----------|
| **V1__init_schema.sql** | 16 tablas, 11+ índices covering/filtrados, constraints, 1 trigger |
| **V2__stored_procedures.sql** | 12 SPs transaccionales (registro, proposiciones, predicciones, resoluciones) |
| **V3__seeding.sql** | 1,000 jugadores, 5,000 proposiciones, ~250K GameEvents, 107K+ transacciones |
| **V4__security_setup.sql** | Master Key, Certificate, Symmetric Key, 4 roles, 4 logins, RLS, Data Masking |
| **V5__concurrency_transactions.sql** | 18 SPs para demos de transacciones anidadas, deadlocks y niveles de aislamiento |
| **V6__demo_passwords.sql** | Resetea passwords a `Password123!`; crea jugador `demo_admin` con 5,000 pts |

**Total: ~4,500 líneas de SQL**

### Datos en BD

```
┌─────────────────────┬────────┐
│ Tabla               │ Filas  │
├─────────────────────┼────────┤
│ Player              │ 1,001  │
│ Proposition         │ 5,000  │
│ GameEvent           │ ~250K  │
│ Transaction         │ ~107K  │
│ Prediction          │ ~83K   │
│ Vote                │ ~34K   │
│ AIReviewLog         │ 4,250  │
│ PropositionEvidence │ 2,000  │
│ SocialAccount       │ 1,000  │
└─────────────────────┴────────┘
```

Guía: [`docs/FLYWAY.md`](./docs/FLYWAY.md)

---

## 🔒 Fase 3 — Security Lab

| Requisito | Implementación |
|-----------|----------------|
| **Usuarios de prueba** | 4 logins SQL (admin, system, player, readonly) |
| **Roles con permisos** | 4 roles con permisos diferenciados por nivel de acceso |
| **Permisos directos vs heredados** | GRANT/DENY explícitos + herencia vía roles |
| **Escenarios de acceso** | SELECT sin permiso, acceso via SP, acceso denegado |
| **Data Masking** | email, balance_points, account_username enmascarados |
| **Row-Level Security (RLS)** | Tabla Transaction protegida; jugadores solo ven sus filas |
| **Cifrado con Master Key** | Symmetric Key + Certificate + demo encrypt/decrypt |

Scripts de demo: [`src/database/security-lab/`](./src/database/security-lab/)

---

## ⚡ Fase 4 — Transacciones y Concurrencia

| Script | Demostración |
|--------|--------------|
| `01_nested_transactions.sql` | SPs anidados L1→L2→L3 con savepoints; flujo exitoso y rollback en cascada |
| `02_deadlock_writes.sql` | Deadlock por escrituras concurrentes en orden inverso |
| `03_deadlock_read_write.sql` | Deadlock lectura + escritura con HOLDLOCK |
| `04_deadlock_cyclic.sql` | Deadlock cíclico T1→T2→T3→T1 |
| `05_isolation_levels.sql` | READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE |

Documentación completa con análisis de mitigaciones: [`src/database/concurrency/README.md`](./src/database/concurrency/README.md)

---

## 🖥️ Fase 5 — Backend MVP (FastAPI)

### Stack

- **Lenguaje:** Python 3.11
- **Framework:** FastAPI + Uvicorn
- **BD driver:** pymssql (FreeTDS — sin instalación de ODBC)
- **ORM:** SQLAlchemy 2.0 (solo para lecturas)
- **Escrituras:** Stored Procedures vía `text()` (cumple requisito del caso)
- **Autenticación:** JWT con `python-jose`
- **Pool:** fijo `pool_size=5, max_overflow=0` (cumple requisito del caso)

### Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/api/auth/login` | Login → JWT |
| `POST` | `/api/auth/logout` | Logout (stateless) |
| `GET` | `/api/players/me` | Balance y actividad del jugador |
| `GET` | `/api/propositions/active` | Proposiciones activas (paginadas) |
| `GET` | `/api/propositions/results` | Resultados de proposiciones del jugador |
| `POST` | `/api/propositions` | Crear proposición |
| `POST` | `/api/predictions` | Realizar predicción |
| `GET` | `/api/health` | Healthcheck |

**Swagger UI:** `http://localhost:8000/docs`

---

## 🌐 Fase 6 — Frontend MVP (React)

### Stack

- **Framework:** React 18 + Vite
- **Routing:** React Router DOM v7
- **HTTP:** Axios con interceptor de Bearer token
- **Servidor:** nginx (multi-stage Docker build)

### Páginas

| Ruta | Página | Función |
|------|--------|---------|
| `/login` | Login | Formulario de acceso con hint de credenciales demo |
| `/` | Dashboard | Balance de puntos y última actividad |
| `/propositions` | Proposiciones | Lista activas, crear nueva, realizar predicción |
| `/results` | Resultados | Historial de proposiciones finalizadas |

---

## 🐳 Fase 7 — Docker Compose

### Servicios

```
localhost
  ├── :3000  → Frontend (React + nginx)
  │               └── /api/* → proxy a backend:8000
  ├── :8000  → Backend (FastAPI)
  │               └── pymssql → sql-server:1433
  └── :1433  → SQL Server 2022
```

### Flujo de arranque

```
sql-server (healthy)
    └── db-init (crea GathelDB)
            └── flyway (V1 → V6, ~3-4 min)
                    └── backend (FastAPI)
                            └── frontend (nginx)
```

Guía completa: [`DOCKER.md`](./DOCKER.md)

---

**Última actualización:** 17 de Junio de 2026
