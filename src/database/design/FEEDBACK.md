# Feedback del Profesor - Diseño de Base de Datos

## Puntos de mejora identificados

### 1. SocialNetwork - Agregar configuración
**Cambio requerido:**
- Agregar `url` (URL del sitio)
- Agregar `api_url` (endpoint de la API)
- Agregar `api_config` (configuración de la API en JSON)

**Razón:** Permitir integración con múltiples redes sociales sin hardcoding de URLs.

---

### 2. SocialAccount - Remover access_token
**Cambio requerido:**
- ❌ REMOVER: `access_token_encrypted` de SocialAccount
- ✅ CREAR: Tabla separada `SocialAccountSession` o `AccessTokenSession` para tokens que rotan

**Razón:** Los access tokens rotan entre sesiones. No deben almacenarse en SocialAccount que es un registro estático.

---

### 3. Transacciones - Usar moneda genérica
**Cambio requerido:**
- ❌ ELIMINAR: Tablas separadas `PointsTransaction` y `MoneyTransaction`
- ✅ CREAR: Tabla única `Transaction` con campo `currency_type` (moneda/fondo)
- Agregar tabla `CurrencyType` para soportar N tipos de fondos/monedas

**Razón:** Permite escalar a N tipos de monedas/fondos sin agregar nuevas tablas. Más mantenible.

---

### 4. AIReviewLog - Mejorar auditoría y detalle
**Cambio requerido:**
- Normalizar `ai_model` (crear tabla AIModel)
- Normalizar `ai_provider` (crear tabla AIProvider)
- ✅ Agregar: `request_payload` (request completo en JSON)
- ✅ Agregar: `response_payload` (response completo en JSON)
- ✅ Agregar: `checksum` (para auditoría)

**Razón:** Facilita debugging, auditoría completa, y análisis posterior de decisiones de IA.

---

### 5. Auditoría general - Checksums en todo
**Cambio requerido:**
- Agregar `checksum` a tablas sensibles:
  - ✅ Proposition (ya tiene)
  - ✅ PointsTransaction / Transaction (ya tiene)
  - ✅ MoneyTransaction / Transaction (ya tiene)
  - ❓ Vote (agregar)
  - ❓ Prediction (agregar)
  - ❓ PropositionEvidence (agregar)
  - ❓ GameEvent (agregar)

**Razón:** Detectar manipulación de datos sensibles. Cumplimiento normativo.

---

### 6. PropositionEvidence - Agregar post_id
**Cambio requerido:**
- Agregar `post_id` (GUID/UUID) que identifique el post en la red social
- Este debe ser el identificador único del post, no la URL

**Razón:** Facilita búsqueda y linkeo con la red social. Más robusto que URLs.

---

### 7. GameEvent - ¿Qué hace exactamente?
**Pregunta del profesor:**
- No queda claro el propósito de GameEvent

**Necesitamos aclarar:**
- ¿Qué eventos se registran? (creación de proposición, voto, predicción, etc.)
- ¿Cómo se diferencia de ProcessLog?
- ¿Se usa para auditoría o para lógica del juego?
- ¿Qué datos debe capturar en `event_data`?

---

## Resumen de cambios

| Tabla | Cambio | Tipo |
|-------|--------|------|
| SocialNetwork | Agregar: url, api_url, api_config | ✏️ Ampliación |
| SocialAccount | Remover: access_token_encrypted | 🗑️ Eliminación |
| NEW: SocialAccountSession | Crear tabla para tokens de sesión | ✨ Nueva |
| PointsTransaction | ❌ Eliminar | 🗑️ Consolidación |
| MoneyTransaction | ❌ Eliminar | 🗑️ Consolidación |
| NEW: Transaction | Tabla única con currency_type | ✨ Nueva |
| NEW: CurrencyType | Catálogo de monedas/fondos | ✨ Nueva |
| AIReviewLog | Agregar: request_payload, response_payload, checksum | ✏️ Ampliación |
| NEW: AIModel | Catálogo de modelos de IA | ✨ Nueva |
| NEW: AIProvider | Catálogo de providers de IA | ✨ Nueva |
| PropositionEvidence | Agregar: post_id (GUID) | ✏️ Ampliación |
| Vote | Agregar: checksum | ✏️ Ampliación |
| Prediction | Agregar: checksum | ✏️ Ampliación |
| GameEvent | ❓ Necesita aclaración | ❓ Revisión |

---

**Próximos pasos:**
1. Aclarar propósito de GameEvent
2. Crear especificación Markdown actualizada
3. Generar DBML actualizado
4. Implementar migraciones SQL
