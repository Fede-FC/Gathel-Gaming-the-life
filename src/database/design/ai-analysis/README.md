# /src/database/design/ai-analysis — Análisis de IA del Diseño

Contiene los 4 análisis realizados con IA sobre el modelo de base de datos, más los prompts utilizados y el resumen consolidado de mejoras aplicadas. Estos documentos forman parte del requisito del caso de usar IA como herramienta de revisión del diseño.

---

## 01_seguridad_analisis.md

Análisis de seguridad del modelo de datos.

**Temas cubiertos:**
- Identificación de datos sensibles: `password_hash`, `email`, `access_token_encrypted`, `balance_points`
- Recomendaciones de cifrado: qué campos cifrar con Always Encrypted vs Symmetric Key
- Análisis de superficie de ataque: qué tablas son más vulnerables a inyección SQL
- Revisión de la política de contraseñas (hash con SHA2-256 + salting implícito vía UTF-16-LE)
- Recomendaciones sobre Row-Level Security para `[Transaction]`
- Riesgos identificados en `SocialAccountSession` (tokens OAuth almacenados)

**Mejoras aplicadas al diseño como resultado de este análisis:**
- Columnas `access_token_encrypted` y `refresh_token_encrypted` en `SocialAccountSession`
- Implementación de Data Masking en `email` y `balance_points`
- RLS sobre `[Transaction]`

---

## 02_indices_performance.md

Análisis de performance e índices del modelo.

**Temas cubiertos:**
- Identificación de queries frecuentes que necesitan índices (listar proposiciones activas, historial de transacciones por jugador, feed de eventos)
- Recomendación de índices filtrados (índice parcial sobre `Proposition` donde `enabled = 1`)
- Índices con INCLUDE para cubrir columnas adicionales sin expandir la clave del índice
- Análisis de cardinalidad por tabla (qué tablas van a crecer más rápido)
- Detección de columnas con bajo selectivity que no conviene indexar

**Resultado:** 11+ índices implementados en `V1__init_schema.sql`, documentados en `specification.md`.

---

## 03_normalizacion_diseno.md

Análisis de normalización del modelo (3NF/BCNF).

**Temas cubiertos:**
- Verificación de Primera Forma Normal (1NF): sin grupos repetidos ni campos multivalor
- Verificación de Segunda Forma Normal (2NF): sin dependencias parciales
- Verificación de Tercera Forma Normal (3NF): sin dependencias transitivas
- Verificación de BCNF para casos borde
- Análisis de la desnormalización justificada: `balance_points` en `Player` (desnormalización controlada por performance, sincronizada vía SP con `balance_version`)
- Justificación de los catálogos separados como tablas de lookup

---

## 04_escalabilidad.md

Análisis de escalabilidad para crecimiento a 100K+ jugadores.

**Temas cubiertos:**
- Proyección de crecimiento de filas por tabla a 12 meses
- Cuellos de botella identificados: tabla `GameEvent` (crece rápido), `[Transaction]` (append-only)
- Estrategia de particionamiento horizontal para `[Transaction]` y `GameEvent` por fecha
- Recomendaciones de archivado de datos históricos
- Plan de réplicas de lectura para los endpoints más consultados (dashboard, feed)
- Análisis de connection pooling bajo carga concurrente

---

## PROMPTS.md

Registro de los prompts exactos utilizados para generar los 4 análisis anteriores.

**Contenido:**
- Prompt de contexto base (descripción del proyecto + schema completo enviado a la IA)
- Prompt específico para cada análisis (seguridad, performance, normalización, escalabilidad)
- Modelo de IA utilizado en cada caso

**Por qué se documenta:** el caso requiere evidencia de cómo se usó la IA como herramienta. Estos prompts demuestran que los análisis fueron dirigidos y revisados, no generados ciegamente.

---

## RESUMEN_MEJORAS.md

Documento de cierre de la Fase 1. Consolida todas las mejoras aplicadas al diseño original como resultado de los 4 análisis de IA.

**Contenido:**
- Tabla comparativa: problema identificado → análisis que lo detectó → cambio aplicado
- Lista de campos y tablas que se agregaron o modificaron post-análisis
- Decisiones de diseño que se evaluaron y no se cambiaron (con justificación)
- Estado final del modelo tras incorporar todas las mejoras
