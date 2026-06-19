# /src/database/design — Diseño de la Base de Datos

Contiene todos los artefactos del diseño del modelo relacional de Gathel: especificación, diagrama, casos de uso, relaciones y el feedback recibido.

---

## specification.md

Especificación completa del modelo de datos en formato Markdown (v2.0).

**Contenido:**
- Descripción de cada una de las 20 tablas, sus columnas con tipos de dato, restricciones (PK, FK, UNIQUE, CHECK) y propósito
- Catálogos independientes: `PropositionStatus`, `SocialNetwork`, `CurrencyType`, `TransactionType`, `EventType`, `AIProvider`, `AIModel`
- Tablas de negocio: `Player`, `SocialAccount`, `SocialAccountSession`, `Proposition`, `Vote`, `Prediction`, `PropositionEvidence`
- Tablas de soporte: `[Transaction]`, `AIReviewLog`, `GameEvent`, `ProcessLog`, `PropositionAudit`
- Justificación de decisiones de diseño: por qué `balance_points` está desnormalizado en `Player`, por qué se usa `balance_version` para optimistic locking, por qué `[Transaction]` necesita corchetes
- Lista de los 11+ índices con su justificación de performance

**Es el documento de referencia principal del diseño.** Si hay duda sobre qué hace una columna, buscar aquí primero.

---

## design.dbml

Diagrama del modelo en formato DBML (Database Markup Language), compatible con [dbdiagram.io](https://dbdiagram.io).

**Contenido:** define las 20 tablas con sus columnas, tipos, referencias (FK) y notas. Se puede pegar directamente en dbdiagram.io para visualizar el diagrama entidad-relación de forma gráfica.

**Por qué DBML:** es texto plano, se versiona en Git, y genera diagramas visuales profesionales automáticamente. Más práctico que mantener una imagen PNG que se desactualiza.

---

## casos-uso.md

Describe los casos de uso principales de la plataforma desde la perspectiva del usuario.

**Escenarios documentados:**
- Registro de jugador y asociación de redes sociales
- Creación de una proposición (quién puede crearla, sobre quién)
- Flujo de revisión por IA (PENDING → APPROVED/REJECTED)
- Ciclo de vida de una proposición: ACTIVE → PREDICTION_CLOSED → RESOLVED
- Realización de una predicción (límites de puntos, reglas de dinero real)
- Resolución y distribución de ganancias (comisión plataforma 5% + comisión creador 2%)
- Escenario de proposición irresoluble (reembolso + penalización 15% al sujeto)

---

## relaciones.md

Documenta todas las relaciones entre tablas: cardinalidad, tipo de relación y restricciones de integridad referencial.

**Contenido:**
- Diagrama textual de las relaciones clave
- Explicación de relaciones complejas: por qué `Proposition` tiene dos FK a `Player` (`creator_player_id` y `target_player_id`) con el CHECK `creator <> target`
- Relaciones de CASCADE DELETE (ej. al eliminar una Proposition se eliminan sus Predictions, Votes, GameEvents y PropositionAudit automáticamente)
- Relaciones de catálogo (sin CASCADE): `CurrencyType`, `TransactionType`, `EventType`

---

## FEEDBACK.md

Registro del feedback recibido durante la Fase 1 (revisión con el profesor).

**Contenido:**
- Observaciones sobre el diseño inicial
- Cambios realizados en respuesta al feedback
- Decisiones que se mantuvieron con su justificación

---

## ai-analysis/

Subcarpeta con los 4 análisis de IA realizados sobre el diseño (ver README dentro de esa carpeta).
