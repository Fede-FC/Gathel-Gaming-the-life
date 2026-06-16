# Gathel — Gaming the life

**Caso #3 — Bases de Datos (Primer Semestre 2026)**

Gathel es una plataforma digital de predicciones basada en acciones y eventos de la vida real de las personas, validados mediante redes sociales e inteligencia artificial. Cada jugador inicia con 100 puntos virtuales y puede crear proposiciones, votar, predecir (con puntos o dinero real) y recibir recompensas según los resultados validados por IA.

> Especificación completa del caso: [`caso #3.md`](./caso%20%233.md)

---

## 📊 Estado del proyecto

| Fase | Descripción | Estado | Entregas |
|------|-------------|--------|----------|
| **1. Diseño de BD** | Especificación, análisis de IA, DBML | ✅ Completada | specification.md, design.dbml, 4 análisis IA |
| **2. Flyway** | Migraciones versionadas + seeding | ✅ Completada | V1-V4, Docker Compose, flyway.conf, docs |
| **3. Security Lab** | Roles, permisos, RLS, Data Masking, cifrado | ✅ Completada | 5 demos, README.md, Master Key, 4 roles |
| **4. Transacciones y concurrencia** | SPs anidados, deadlocks, aislamiento | ⏳ EN PROGRESO | (scripts en desarrollo) |
| **5. Backend MVP** | REST API (ORM lectura + SP escritura) | ❌ Pendiente | - |
| **6. Frontend MVP** | UI web/Android | ❌ Pendiente | - |
| **7. Docker** | `docker-compose` | ✅ Completada | docker-compose.yml, DOCKER.md |
| **8. Documentación** | README, API, DEPLOYMENT | ⏳ EN PROGRESO | CLAUDE.md actualizado |

**Progreso: 4/8 completadas (50%), 3 en progreso (37.5%), 1 pendiente (12.5%)**

Detalle de fases y cronograma: [`CLAUDE.md`](./CLAUDE.md)

---

## 🗂️ Estructura del repositorio

```
Gathel-Gaming-the-life/
├── README.md                       # Este archivo
├── CLAUDE.md                       # Plan de desarrollo y cronograma
├── caso #3.md                      # Especificación original del caso
└── src/
    └── database/
        └── design/                 # Diseño de la base de datos (Fase 1)
            ├── specification.md    # Especificación del modelo (fuente de verdad)
            ├── design.dbml         # Diagrama DBML (generado desde la spec)
            ├── relaciones.md       # Mapa conceptual de relaciones
            ├── casos-uso.md        # Validación del diseño contra el caso
            ├── FEEDBACK.md         # Feedback del profesor incorporado
            └── ai-analysis/        # Revisión del diseño por agentes de IA
                ├── PROMPTS.md
                ├── 01_seguridad_analisis.md
                ├── 02_indices_performance.md
                ├── 03_normalizacion_diseno.md
                ├── 04_escalabilidad.md
                └── RESUMEN_MEJORAS.md
```

---

## 🚀 Quick Start (Docker Compose)

```bash
# 1. Iniciar SQL Server + Flyway automáticamente
./scripts/docker-setup.sh up

# 2. Esperar ~2 minutos a que se inicialicen y ejecuten migraciones

# 3. Conectarse a SQL Server
./scripts/docker-setup.sh sql

# Dentro de sqlcmd:
SELECT COUNT(*) FROM dbo.Player;           -- ~1000
SELECT COUNT(*) FROM dbo.Proposition;      -- ~5000
SELECT COUNT(*) FROM dbo.[Transaction];    -- ~107k
GO
EXIT
```

**Ver logs:** `./scripts/docker-setup.sh logs`  
**Detener:** `./scripts/docker-setup.sh down`

Guía completa: [`DOCKER.md`](./DOCKER.md)

---

## 🏛️ Fase 1 — Diseño de la base de datos

### Documentos principales

| Documento | Descripción |
|-----------|-------------|
| [`specification.md`](./src/database/design/specification.md) | **Fuente de verdad.** Especificación en Markdown de todas las tablas, campos, restricciones, índices, vistas, estrategia de seguridad y reglas de negocio. |
| [`design.dbml`](./src/database/design/design.dbml) | Diagrama en formato DBML generado a partir de la especificación. Importable en [dbdiagram.io](https://dbdiagram.io). |
| [`relaciones.md`](./src/database/design/relaciones.md) | Mapa visual/conceptual de las relaciones entre tablas. |
| [`casos-uso.md`](./src/database/design/casos-uso.md) | Casos de uso que validan que el diseño cubre el caso sin ambigüedades. |
| [`FEEDBACK.md`](./src/database/design/FEEDBACK.md) | Puntos de mejora del profesor y cómo se incorporaron. |

### Modelo de datos (resumen)

20 tablas organizadas en cinco grupos:

- **Catálogos:** `PropositionStatus`, `SocialNetwork`, `CurrencyType`, `ExchangeRate`, `TransactionType`, `EventType`, `AIModel`, `AIProvider`
- **Autenticación y redes sociales:** `Player`, `SocialAccount`, `SocialAccountSession`
- **Proposiciones y predicciones:** `Proposition`, `Vote`, `Prediction`, `PropositionEvidence`
- **Transacciones:** `Transaction`
- **Auditoría e IA:** `AIReviewLog`, `GameEvent`, `ProcessLog`, `PropositionAudit`

### Decisiones de diseño destacadas

- **Transacciones unificadas:** una sola tabla `Transaction` + catálogo `CurrencyType` soporta N monedas (puntos, USD, etc.) sin agregar tablas.
- **Tasas de cambio con histórico:** `ExchangeRate` guarda la tasa por fecha (la tasa no es propiedad estática de la moneda).
- **Un monto, una moneda:** `Prediction` usa `amount` + `currency_type_id` en lugar de campos paralelos; predecir con "ambos" = dos filas.
- **Tokens en tabla aparte:** `SocialAccountSession` aísla los tokens que rotan, protegidos con Always Encrypted.
- **Sin hardcoding:** tasas, configuraciones y constantes viven en catálogos/tablas, no en código.

---

## 🤖 Revisión por agentes de IA

El diseño fue auditado por agentes de IA especializados desde múltiples ángulos. Los prompts utilizados están documentados para reproducibilidad.

| Documento | Enfoque | Hallazgos clave |
|-----------|---------|-----------------|
| [`PROMPTS.md`](./src/database/design/ai-analysis/PROMPTS.md) | Definición de los agentes | Prompts de cada experto de IA |
| [`01_seguridad_analisis.md`](./src/database/design/ai-analysis/01_seguridad_analisis.md) | Seguridad | Cifrado de tokens, auditoría de proposiciones, RLS, validación JSON, race conditions |
| [`02_indices_performance.md`](./src/database/design/ai-analysis/02_indices_performance.md) | Índices y rendimiento | Índices covering/filtrados para las queries críticas |
| [`03_normalizacion_diseno.md`](./src/database/design/ai-analysis/03_normalizacion_diseno.md) | Normalización | 3NF/BCNF; desnormalizaciones intencionales justificadas; anomalías mitigadas |
| [`04_escalabilidad.md`](./src/database/design/ai-analysis/04_escalabilidad.md) | Escalabilidad | Proyecciones de crecimiento; particionamiento/sharding como roadmap futuro |
| [`RESUMEN_MEJORAS.md`](./src/database/design/ai-analysis/RESUMEN_MEJORAS.md) | Síntesis | Consolidación de las cuatro revisiones |

### Mejoras incorporadas al diseño a partir del análisis

A partir de las recomendaciones se aplicaron, entre otros, los siguientes cambios sobre la especificación (de v1.0 a v2.0):

---

## 📦 Fase 2 — Gestión de Migraciones (Flyway)

### Migraciones SQL versionadas

4 migraciones automáticas que crean y populan la base de datos:

| Migración | Contenido | Líneas |
|-----------|-----------|--------|
| **V1__init_schema.sql** | 16 tablas, 11+ índices covering/filtrados, constraints, 1 trigger | 443 |
| **V2__stored_procedures.sql** | 12 SPs transaccionales (registro, proposiciones, predicciones, resoluciones) | 1,091 |
| **V3__seeding.sql** | 1000 jugadores, 5000 proposiciones, ~250k GameEvents, 107k+ transacciones | 1,150 |
| **V4__security_setup.sql** | Master Key, Certificate, Symmetric Key, 4 roles, 4 logins, RLS, Data Masking | 550+ |

**Total: ~3,200 líneas de SQL**

### Datos de demo en BD

```
┌─────────────────────┬────────┐
│ Tabla               │ Filas  │
├─────────────────────┼────────┤
│ Player              │ 1,000  │
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

### Ejecución automática

- `docker-compose.yml` descarga SQL Server + Flyway automáticamente
- `flyway.conf` parametrizado para local o Docker
- `scripts/docker-setup.sh` simplifica comandos

Guía: [`docs/FLYWAY.md`](./docs/FLYWAY.md)

---

## 🔒 Fase 3 — Security Lab

### Implementación de seguridad

Todos los requisitos del caso cumplidos:

| Requisito | Implementación |
|-----------|----------------|
| **Usuarios de prueba** | 4 logins SQL (admin, system, player, readonly) |
| **Roles con permisos** | 4 roles con permisos diferenciados por nivel de acceso |
| **Permisos directos vs heredados** | GRANT/DENY explícitos + herencia vía roles |
| **Escenarios de acceso** | SELECT sin permiso, acceso via SP, acceso denegado |
| **Data Masking** | email, balance_points, account_username enmascarados |
| **Row-Level Security (RLS)** | Tabla Transaction protegida; jugadores solo ven sus filas |
| **Cifrado con Master Key** | Symmetric Key + Certificate + demo encrypt/decrypt |
| **Documentación** | 5 scripts de demostración + README.md |

### Scripts de demostración

Ejecutar manualmente después de Flyway:

```bash
# Desde la BD GathelDB:
sqlcmd -U sa -P 'GathelPassword123!Secure' -d GathelDB -i src/database/security-lab/01_master_key_cert.sql
sqlcmd -U sa -P 'GathelPassword123!Secure' -d GathelDB -i src/database/security-lab/02_roles_users.sql
sqlcmd -U sa -P 'GathelPassword123!Secure' -d GathelDB -i src/database/security-lab/03_permissions_demo.sql
sqlcmd -U sa -P 'GathelPassword123!Secure' -d GathelDB -i src/database/security-lab/04_data_masking.sql
sqlcmd -U sa -P 'GathelPassword123!Secure' -d GathelDB -i src/database/security-lab/05_rls.sql
```

Guía: [`src/database/security-lab/README.md`](./src/database/security-lab/README.md)

---

## 🐳 Fase 7 — Docker & Fase 2/3 Integration

### Docker Compose (automatización completa)

```yaml
services:
  sql-server:
    image: mcr.microsoft.com/mssql/server:2022-latest
    ports: 1433
    healthcheck: verifica puerto TCP

  flyway:
    image: flyway/flyway:9.22.3
    depends_on: sql-server (healthy)
    comando: migrate (V1 → V4 automáticamente)
```

### Herramientas helper

```bash
./scripts/docker-setup.sh up          # Iniciar todo
./scripts/docker-setup.sh down        # Detener
./scripts/docker-setup.sh sql         # Conectar a BD
./scripts/docker-setup.sh logs        # Ver logs en vivo
./scripts/docker-setup.sh rebuild     # Limpiar y reiniciar
```

Guía: [`DOCKER.md`](./DOCKER.md)

- **Seguridad:** nueva tabla `PropositionAudit` (auditoría campo por campo vía trigger); campos `encryption_key_id`, `last_used_at`, `rotation_count` en `SocialAccountSession`; `balance_version` (optimistic locking) en `Player`; `checksum_timestamp` en `Proposition`; políticas RLS sobre `Transaction` y `Vote`; Data Masking en campos sensibles; CHECK `ISJSON()` en `GameEvent` y `AIReviewLog`.
- **Normalización:** validaciones CHECK (`creator <> target`, `amount > 0`); triggers de sincronización de balance; `ON DELETE RESTRICT` donde corresponde.
- **Rendimiento:** 17 índices covering/filtrados para las queries críticas del MVP.
- **Escalabilidad:** se documenta como **fuera de alcance** para el MVP académico (particionamiento, sharding, archivamiento); pensado como roadmap a >500K jugadores.

> **Alcance:** por tratarse de un MVP académico con bajo volumen de datos, no se implementa particionamiento ni sharding. El foco está en diseño correcto, seguridad y cumplimiento del caso.

---

## 🔐 Regla de negocio destacada — visibilidad de votos

El caso establece que **ningún jugador puede ver cuántos votos tiene una proposición; sólo el jugador objetivo (target) puede**. Esto se implementa con **Row-Level Security sobre `Vote`**: cada jugador ve únicamente su propio voto (necesario para la validación de unicidad), el target ve todos los votos de sus proposiciones, y el rol Admin ve todo. El conteo real sólo se expone vía la vista `vw_proposition_vote_counts`, protegida por esa RLS.

---

## 🚀 Próximos pasos

1. Generar el **PDF** del diagrama desde `design.dbml` para revisión con el profesor.
2. Iniciar **Fase 2 (Flyway):** instalación/configuración y migración `V1` del esquema.

---

**Última actualización:** 13 de Junio de 2026
