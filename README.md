# Gathel — Gaming the life

**Caso #3 — Bases de Datos (Primer Semestre 2026)**

Gathel es una plataforma digital de predicciones basada en acciones y eventos de la vida real de las personas, validados mediante redes sociales e inteligencia artificial. Cada jugador inicia con 100 puntos virtuales y puede crear proposiciones, votar, predecir (con puntos o dinero real) y recibir recompensas según los resultados validados por IA.

> Especificación completa del caso: [`caso #3.md`](./caso%20%233.md)

---

## 📊 Estado del proyecto

| Fase | Descripción | Estado |
|------|-------------|--------|
| **1. Diseño de BD** | Especificación, análisis de IA, DBML | ✅ Completada |
| **2. Flyway** | Migraciones versionadas + seeding | ⏳ Por iniciar |
| **3. Security Lab** | Roles, permisos, RLS, Data Masking, cifrado | ⏳ Por iniciar |
| **4. Transacciones y concurrencia** | SPs anidados, deadlocks, aislamiento | ⏳ Por iniciar |
| **5. Backend MVP** | REST API (ORM lectura + SP escritura) | ⏳ Por iniciar |
| **6. Frontend MVP** | UI web/Android | ⏳ Por iniciar |
| **7. Docker** | `docker-compose` | ⏳ Por iniciar |

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
