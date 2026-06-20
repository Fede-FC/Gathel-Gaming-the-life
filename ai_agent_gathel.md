# Documentación del Agente de IA — Auditoría de Arquitectura de Base de Datos

**Proyecto:** Caso #3 — Gathel, Gaming the Life  
**Base de datos:** GathelDB  
**Motor:** SQL Server 2022  

---

## 1. Resumen Ejecutivo

Se configuró e implementó un **Agente de IA Arquitecto** con el objetivo de someter el esquema inicial de GathelDB a una auditoría técnica rigurosa antes de su integración con Flyway. El agente fue instruido para evaluar el diseño desde múltiples dimensiones: normalización, seguridad, economía del juego, integridad transaccional y observabilidad.

| Evaluación | Puntuación | Dictamen |
|---|---|---|
| **Primera revisión** (diseño inicial) | **27 / 100** | ❌ Rechazado |
| **Segunda revisión** (tras correcciones) | **81 / 100** | ✅ Apto para Producción |
| **Mejora neta** | **+54 puntos** | — |

---

## 2. Definición del Agente de IA

### Ficha Técnica

| Campo | Detalle |
|---|---|
| **Nombre** | GathelDB Architect & Compliance Auditor |
| **Patrón** | Agente de revisión iterativa con re-evaluación post-corrección |
| **Rol asignado** | Arquitecto de Bases de Datos Senior con especialización en sistemas OLTP de alta concurrencia, auditoría financiera y cumplimiento de seguridad en plataformas de entretenimiento digital y economías virtuales. |
| **Iteraciones** | 2 (diseño inicial → correcciones aplicadas → re-evaluación final) |

### Prompt de Sistema

```
Actúa como un Arquitecto de Bases de Datos Senior especializado en sistemas OLTP de alta
concurrencia sobre SQL Server 2022. Tu objetivo es auditar el esquema DDL del proyecto
Gathel — una plataforma de predicciones basada en eventos reales. Evalúa numéricamente el
diseño de 1 a 100 considerando: normalización (3NF), integridad referencial, manejo de
saldos económicos virtuales y reales, seguridad de credenciales y tokens OAuth,
trazabilidad de operaciones financieras (patrón Ledger), almacenamiento de logs de IA,
indexación para cargas masivas de INSERT, auditoría reactiva mediante triggers,
escalabilidad y observabilidad del sistema. Para cada hallazgo indica el riesgo operativo
concreto y la corrección arquitectónica recomendada.
```

### Criterios de Evaluación

- Normalización y diseño relacional (3NF, catálogos, dominios)
- Integridad referencial y control de llaves foráneas
- Economía del juego: manejo de puntos y dinero real
- Seguridad de credenciales, tokens OAuth y datos sensibles
- Trazabilidad transaccional (patrón Ledger)
- Auditoría reactiva mediante triggers inmutables
- Almacenamiento y trazabilidad de inferencias de IA
- Indexación optimizada para alto volumen de inserciones
- Escalabilidad y observabilidad del esquema
- Preparación para despliegue colaborativo con Flyway

---

## 3. Primera Evaluación — Hallazgos Críticos (27 / 100)

| # | Hallazgo | Riesgo operativo |
|---|---|---|
| 1 | **Cadenas de texto libre para estados** | Campos NVARCHAR sin restricción de dominio para estados del negocio, permitiendo la inserción de valores inválidos y eliminando la integridad referencial. |
| 2 | **Mutabilidad directa de saldos** | points_balance y money_balance actualizados con UPDATE directo en Player; ante fallos de concurrencia el saldo queda en estado inconsistente sin posibilidad de reconstrucción. |
| 3 | **Ausencia de historial transaccional** | Imposible reconstruir el saldo de un jugador en un punto arbitrario del tiempo o auditar el origen de cada variación económica. |
| 4 | **Tokens OAuth en texto plano** | Credenciales de Instagram y TikTok sin cifrado; una filtración compromete todas las cuentas de redes sociales de los jugadores. |
| 5 | **Nula capacidad de auditoría reactiva** | Sin mecanismo que registre cambios en resultados o estados críticos; imposible detectar manipulaciones retroactivamente. |
| 6 | **Trazabilidad de IA ausente** | Resultados de moderación almacenados dentro de Proposition, sin separar proveedor, versión del modelo ni puntuación de confianza. |
| 7 | **Indexación insuficiente** | Índices limitados a llaves primarias; escaneos completos de tabla en las consultas más frecuentes del backend. |

---

## 4. Correcciones Implementadas — Antes / Después

| Aspecto | Diseño Original (27/100) | Diseño Corregido (81/100) |
|---|---|---|
| **Saldos de jugadores** | UPDATE directo en Player sin historial ni control de versión. | Patrón Ledger Inmutable mediante tabla `Transaction`. Campo en Player protegido con `balance_version` para Optimistic Locking. |
| **Gestión de monedas** | Puntos y dinero real en campos separados con lógicas distintas. | Entidad `CurrencyType` unificada con bandera `is_virtual`. |
| **Estados y tipos** | Campos NVARCHAR(50) libres sin validación de dominio. | Catálogos normalizados: `PropositionStatus`, `TransactionType`, `EventType` con llaves foráneas estrictas. |
| **Seguridad OAuth** | Tokens en texto plano en la entidad de configuración del jugador. | `SocialAccountSession` aislada, preparada para Always Encrypted con contador `rotation_count`. |
| **Integración de IA** | Resultados de moderación dentro de `Proposition`. | Tabla `AIReviewLog` separada con catálogos `AIProvider` y `AIModel`, validación `ISJSON`. |
| **Auditoría** | Sin registro de cambios en estados críticos. | Tabla inmutable `PropositionAudit` alimentada por el trigger `tr_proposition_audit`. |
| **Índices** | Solo llaves primarias; full table scans frecuentes. | Índices filtrados: `WHERE result = 'PENDING'` y `WHERE enabled = 1`. |

---

## 5. Segunda Evaluación — Fortalezas Reconocidas (81 / 100)

- ✅ **Arquitectura inmutable:** Ningún saldo puede variar sin una entrada auditable en `Transaction`.
- ✅ **Catálogos normalizados:** Elimina una clase completa de bugs por estados inválidos.
- ✅ **Alta concurrencia:** Los índices filtrados mantienen baja latencia bajo cargas masivas.
- ✅ **Trazabilidad de IA:** `AIReviewLog` permite auditar la confianza de los modelos a lo largo del tiempo.
- ✅ **Separación de sesiones:** `SocialAccountSession` desacopla autenticación e identidad del jugador.

---

## 6. Recomendaciones Finales del Agente

1. **Temporal Tables:** Evaluar `System-Versioned Temporal Tables` para entidades secundarias que requieran historial nativo.
2. **Stored Procedures transaccionales:** Consolidar la distribución de recompensas en SPs con bloques `TRY...CATCH` robustos.
3. **Monitoreo de fragmentación:** Configurar alertas sobre `idx_transaction_player_currency` por el volumen proyectado de inserciones.
4. **Particionamiento futuro:** Evaluar particionamiento por rango de fechas en `Transaction` y `GameEvent` al superar 100 millones de filas.
5. **Validación de RLS:** Verificar que las políticas de Row-Level Security no degraden el rendimiento en consultas sin filtros de partición.

---

## 7. Conclusión

El agente de IA permitió transformar un diseño inicial con fallas críticas en una **arquitectura de datos robusta, auditable y escalable**. El esquema avanzó de **27/100 a 81/100** — una mejora neta de **+54 puntos** — garantizando la estabilidad operativa del MVP y estableciendo las bases necesarias para su administración con **Flyway** y despliegue colaborativo en entornos locales compartidos.

---

*Proyecto Gathel — Caso #3 | GathelDB | SQL Server 2022*
