# Prompts de Análisis de IA - Diseño de Base de Datos Gathel

**Propósito:** Documentar prompts de IA para revisar el diseño de BD desde múltiples ángulos

**Cómo usarlos:**
1. Copiar el prompt completo
2. Enviarlo a Claude/ChatGPT/Copilot
3. Pegar la respuesta en el archivo correspondiente en `/ai-analysis/`

---

## 🔐 PROMPT 1: Análisis de Seguridad

```
Eres un experto en seguridad de bases de datos y sistemas financieros. 
Analiza el siguiente diseño de BD para una plataforma de predicciones con 
transacciones monetarias reales.

**Tabla: Player**
- Fields: player_id (PK), username, email, password_hash, display_name, balance_points, balance_real (REMOVED), enabled, created_at, updated_at, updated_by, checksum
- Relaciones: 1:M a SocialAccount, Proposition (creator/target), Vote, Prediction, Transaction, GameEvent

**Tabla: SocialAccount** (MODIFICADO)
- Fields: social_account_id, player_id (FK), social_network_id (FK), account_username, is_verified, enabled, created_at, updated_at
- Cambio importante: access_token_encrypted REMOVIDO (ver SocialAccountSession)

**Tabla: SocialAccountSession** (NUEVA)
- Fields: session_id, social_account_id (FK), access_token_encrypted, refresh_token_encrypted, token_expires_at, is_active, created_at, invalidated_at
- Propósito: Guardar tokens que rotan entre sesiones

**Tabla: Transaction**
- Fields: transaction_id, player_id (FK), currency_type_id (FK), amount, running_balance, transaction_type_id (FK), reference_type, reference_id, description, created_at, checksum
- Propósito: Registro unificado de transacciones (reemplaza PointsTransaction + MoneyTransaction)

**Tabla: Proposition**
- Fields: proposition_id, creator_player_id (FK), target_player_id (FK), title, description, status_id (FK), ai_review_result, ai_review_detail, rejection_reason, voting_ends_at, prediction_ends_at, is_accepted_by_target, is_fulfilled, resolved_at, enabled, created_at, updated_at, checksum
- Validación: creator_player_id ≠ target_player_id

**Tabla: AIReviewLog** (MEJORADO)
- Fields: review_id, proposition_id (FK), ai_model_id (FK), ai_provider_id (FK), review_result, confidence_score, rejection_categories, request_payload (NVARCHAR(MAX)), response_payload (NVARCHAR(MAX)), review_details, reviewed_at, checksum
- Cambios: Normalizado con AIModel y AIProvider, request/response completos en JSON

**Tabla: GameEvent**
- Fields: event_id, proposition_id (FK, nullable), event_type_id (FK), actor_player_id (FK), event_data (NVARCHAR(MAX) - JSON), created_at, checksum
- Propósito: Historial completo de eventos del juego para auditoría

**Contexto del Negocio:**
- Plataforma de predicciones sobre eventos reales en vidas de personas
- Transacciones con dinero real (USD, etc.) y monedas virtuales (POINTS)
- Múltiples redes sociales integradas (Instagram, TikTok, etc.)
- Validación de resultados mediante IA analizando evidencia multimedia
- Alta sensibilidad: datos personales, transacciones monetarias, contenido sensible

**Analiza y proporciona:**

1. **Vulnerabilidades de seguridad identificadas:**
   - ¿Hay riesgos en el almacenamiento de tokens? (Separación en SocialAccountSession)
   - ¿Es seguro el almacenamiento de password_hash? (Recomendaciones de algoritmo)
   - ¿Hay riesgos de inyección SQL en los JSONs (event_data, request_payload, response_payload)?
   - ¿Es suficiente la auditoría con checksums?
   - ¿Hay riesgos en las transacciones (race conditions)?

2. **Controles de acceso y permiso necesarios:**
   - ¿Qué roles y permisos debería haber? (Admin, Player, System)
   - ¿Qué campos deben ser enmascarados? (password_hash, tokens, datos personales)
   - ¿Debería implementarse RLS (Row-Level Security)?
   - ¿Cómo proteger que un jugador solo vea sus datos?

3. **Datos sensibles que requieren protección especial:**
   - ¿Cuáles son más críticos?
   - ¿Necesitan cifrado adicional más allá del password_hash?
   - ¿Cómo se deberían auditar cambios a estos datos?

4. **Validaciones en la aplicación vs BD:**
   - ¿Qué debería validarse en BD (constraints)?
   - ¿Qué debería validarse en aplicación?
   - ¿Hay validaciones faltantes?

5. **Recomendaciones específicas:**
   - TOP 5 mejoras de seguridad prioritarias
   - Cambios en el esquema (si son necesarios)
   - Políticas de auditoría
   - Enmascaramiento de datos (qué campos)

**Formato de respuesta:**
Organiza como:
- Vulnerabilidades Críticas (Alto riesgo)
- Vulnerabilidades Medias (Riesgo moderado)
- Recomendaciones de mejora
- Cambios recomendados al esquema
```

---

## 🔑 PROMPT 2: Análisis de Índices y Performance

```
Eres un experto en optimización de bases de datos SQL Server.
Analiza el diseño de BD para una plataforma de predicciones con 
alto volumen de transacciones.

**Volumen esperado:**
- Player: 1,000
- Proposition: 5,000
- Vote: 50,000+
- Prediction: 250,000+
- Transaction: 100,000+
- GameEvent: 250,000+
- SocialAccountSession: 10,000+

**Tablas críticas y patrones de consulta:**

Tabla: Proposition
- Consultas frecuentes:
  - SELECT * FROM Proposition WHERE status_id = @activeStatus
  - SELECT * FROM Proposition WHERE created_at > @date ORDER BY created_at DESC
  - SELECT * FROM Proposition WHERE creator_player_id = @playerId
  - SELECT * FROM Proposition WHERE target_player_id = @playerId
  - SELECT * FROM Proposition WHERE prediction_ends_at <= @now (para cerrar)

Tabla: Transaction
- Consultas frecuentes:
  - SELECT SUM(amount) FROM Transaction WHERE player_id = @playerId AND currency_type_id = @currency
  - SELECT * FROM Transaction WHERE player_id = @playerId ORDER BY created_at DESC
  - SELECT * FROM Transaction WHERE reference_type = @type AND reference_id = @id
  - SELECT running_balance FROM Transaction WHERE player_id = @playerId AND created_at <= @date ORDER BY created_at DESC LIMIT 1

Tabla: Prediction
- Consultas frecuentes:
  - SELECT * FROM Prediction WHERE proposition_id = @propId
  - SELECT * FROM Prediction WHERE player_id = @playerId
  - SELECT * FROM Prediction WHERE result = 'PENDING' (para actualizar)
  - SELECT SUM(amount_points) FROM Prediction WHERE proposition_id = @propId AND direction = 1

Tabla: GameEvent
- Consultas frecuentes:
  - SELECT * FROM GameEvent WHERE proposition_id = @propId ORDER BY created_at DESC
  - SELECT * FROM GameEvent WHERE event_type_id = @typeId AND created_at > @date
  - SELECT * FROM GameEvent WHERE actor_player_id = @playerId

Tabla: Vote
- Consultas frecuentes:
  - SELECT COUNT(*) FROM Vote WHERE proposition_id = @propId
  - SELECT * FROM Vote WHERE player_id = @playerId AND proposition_id = @propId (validar unicidad)

**Analiza y proporciona:**

1. **Índices recomendados por tabla:**
   - Índices simples (columna única)
   - Índices compuestos (múltiples columnas)
   - Índices filtrados (con WHERE clause)
   - Índices covering (para evitar lookups)
   - Orden de columnas en índices compuestos

2. **Particionamiento:**
   - ¿Debería particionarse alguna tabla? ¿Por qué?
   - Estrategia de particionamiento (por fecha, rango, etc.)
   - Beneficios y costos

3. **Estadísticas y mantenimiento:**
   - Estrategia de actualización de estadísticas
   - Reorganización vs Reconstrucción de índices
   - Frecuencia de mantenimiento

4. **Problemas potenciales de performance:**
   - ¿Hay queries que podrían ser lentas?
   - ¿Hay riesgo de table scans en operaciones críticas?
   - ¿Hay índices redundantes o innecesarios?

5. **Recomendaciones de optimización:**
   - TOP 5 índices a crear primero (prioridad)
   - Campos candidatos para índices que faltan
   - Cambios en la estructura para mejorar queries
   - Vistas indexadas si aplica

6. **Script SQL de índices:**
   - Proporciona CREATE INDEX statements para los índices recomendados
   - Incluye orden de creación si hay dependencias

**Formato de respuesta:**
Organiza como:
- Análisis por tabla (Proposition, Transaction, Prediction, GameEvent, Vote)
- Índices Críticos (crear primero)
- Índices Importantes (crear después)
- Índices Opcionales (evaluar impacto)
- Script SQL de índices
- Estrategia de mantenimiento
```

---

## 📐 PROMPT 3: Análisis de Normalización y Diseño

```
Eres un experto en modelado de datos y normalización relacional.
Analiza el diseño de BD para una plataforma de predicciones.

**Estructura del diseño:**

Catálogos (Lookup tables): PropositionStatus, SocialNetwork, CurrencyType, TransactionType, EventType, AIModel, AIProvider

Core: Player, SocialAccount, SocialAccountSession

Proposiciones: Proposition, Vote, Prediction, PropositionEvidence

Transacciones: Transaction (unificada para múltiples monedas)

Auditoría: AIReviewLog, GameEvent, ProcessLog

**Cambios importantes realizados:**
1. PointsTransaction + MoneyTransaction → Transaction (unificada) + CurrencyType
2. access_token_encrypted removido de SocialAccount → SocialAccountSession (separado)
3. Normalización de IA: ai_model_version string → AIModel (tabla FK)
4. Normalización de IA: ai_provider string → AIProvider (tabla FK)

**Analiza y proporciona:**

1. **Forma normal alcanzada:**
   - ¿Está en 1NF, 2NF, 3NF, BCNF?
   - ¿Por qué?
   - ¿Hay violaciones?

2. **Dependencias funcionales:**
   - ¿Son claras y sin redundancia?
   - ¿Hay atributos que dependen de otros atributos no-clave?
   - ¿Hay anomalías de actualización, inserción o eliminación?

3. **Decisiones de desnormalización (si las hay):**
   - ¿Hay datos duplicados intencionalmente? ¿Por qué?
   - ¿Son necesarios para performance?
   - ¿Son auditoría (timestamps, checksums)?

4. **Evaluación de la unificación de transacciones:**
   - ¿Es correcto mergear PointsTransaction + MoneyTransaction en Transaction?
   - Ventajas: Soporta N monedas sin nuevas tablas
   - Desventajas: ¿Las hay?
   - ¿Hay riesgos de integridad?

5. **Evaluación de la separación de tokens:**
   - ¿Es correcto separar access_token_encrypted a SocialAccountSession?
   - Ventajas: Tokens que rotan sin afectar SocialAccount
   - Desventajas: ¿Las hay?
   - ¿Hay riesgos de integridad?

6. **Campos JSON y su normalización:**
   - GameEvent.event_data (JSON)
   - AIReviewLog.request_payload, response_payload (JSON)
   - ¿Deberían separarse en tablas?
   - ¿Son aceptables como JSON?
   - Impacto en queries

7. **Cambios recomendados:**
   - ¿Debería desnormalizarse algo para performance?
   - ¿Debería normalizarse más?
   - ¿Hay atributos faltantes?
   - ¿Hay tablas redundantes?

8. **Validación de restricciones:**
   - creator_player_id ≠ target_player_id ✓
   - Otras restricciones necesarias
   - ¿Están todas en la BD o deben estar en aplicación?

**Formato de respuesta:**
Organiza como:
- Análisis de forma normal por tabla
- Evaluación de decisiones de unificación/separación
- Evaluación de JSON
- Cambios recomendados (si hay)
- Riesgos de integridad identificados
- Validación de restricciones
```

---

## 📈 PROMPT 4: Análisis de Escalabilidad

```
Eres un experto en escalabilidad y diseño de sistemas distribuidos.
Analiza el diseño de BD para una plataforma de predicciones con 
potencial de crecimiento exponencial.

**Volumen proyectado:**

Fase 1 (Caso de estudio actual):
- 1,000 jugadores
- 5,000 proposiciones
- 250,000 eventos

Fase 2 (Si crece a 100,000 jugadores):
- 100,000 jugadores
- 500,000 proposiciones
- 25,000,000 eventos
- 2,500,000 predicciones
- 10,000,000 transacciones

**Contexto:**
- Múltiples redes sociales integradas
- Validación de IA en tiempo real o async
- Transacciones con dinero real
- Alto volumen de escrituras (predicciones, eventos)
- Pocas actualizaciones (los registros son inmutables)

**Analiza y proporciona:**

1. **Crecimiento de datos:**
   - Proyección de tamaño de BD en diferentes escenarios
   - ¿Cuál es la tabla que crecerá más rápido?
   - Tiempo de vida de los datos (¿cuándo archivar?)

2. **Cuello de botella esperado:**
   - ¿Cuál es la tabla más crítica?
   - ¿Dónde ocurrirán los cuellos de botella?
   - ¿Será suficiente una sola BD?

3. **Particionamiento:**
   - ¿Debería particionarse GameEvent por fecha?
   - ¿Debería particionarse Transaction por player_id?
   - Estrategia de particionamiento

4. **Sharding/Distribución:**
   - ¿Necesitará sharding en algún momento?
   - ¿Cómo particionar datos entre servidores?
   - Player-based sharding, proposition-based, otros?

5. **Archivamiento:**
   - ¿Qué datos pueden archivarse?
   - Política de retención
   - Impacto en performance

6. **Read replicas:**
   - ¿Necesitarán read replicas?
   - Para qué queries
   - Estrategia de replicación

7. **Cambios al esquema para escalabilidad:**
   - ¿Debería cambiar algo ahora para prepararse?
   - ¿Hay decisiones de desnormalización?
   - ¿Hay triggers o denormalización necesarios?

8. **Predicción de crecimiento de índices:**
   - ¿Cuánto crecerán los índices?
   - ¿Hay índices que se vuelvan ineficientes?
   - Necesidad de reorganización

9. **Recomendaciones de infraestructura:**
   - ¿Qué tipo de servidor SQL Server?
   - Storage necesario
   - CPU/Memoria estimada

10. **Riesgos escalabilidad:**
    - Qué puede romper a gran escala
    - Cómo mitigarlos ahora

**Formato de respuesta:**
Organiza como:
- Proyecciones de crecimiento
- Cuellos de botella identificados
- Estrategia de particionamiento
- Estrategia de archivamiento
- Necesidad de read replicas
- Cambios recomendados al esquema
- Recomendaciones de infraestructura
- Riesgos y mitigaciones
```

---

## 📝 Cómo Ejecutar Estos Prompts

### **Opción 1: Manual (recomendado para exploración)**
```bash
1. Abre Claude, ChatGPT o Copilot
2. Copia uno de los prompts arriba
3. Pega en el chat y presiona enter
4. Espera la respuesta
5. Guarda en archivo correspondiente en /ai-analysis/
```

### **Opción 2: Automático (si usas API)**
```python
import anthropic

client = anthropic.Anthropic()

prompt = """[Pega el prompt aquí]"""

response = client.messages.create(
    model="claude-opus-4-1",
    max_tokens=4000,
    messages=[
        {"role": "user", "content": prompt}
    ]
)

print(response.content[0].text)
```

---

## 📂 Estructura de Respuestas

Después de ejecutar cada prompt, guardar respuesta en:

```
/src/database/design/ai-analysis/
├── 01_seguridad_analisis.md          ← Response de PROMPT 1
├── 02_indices_performance.md          ← Response de PROMPT 2
├── 03_normalizacion_diseno.md         ← Response de PROMPT 3
├── 04_escalabilidad.md                ← Response de PROMPT 4
└── RESUMEN_MEJORAS.md                 ← Síntesis de cambios a implementar
```

---

**Próximos pasos después de ejecutar prompts:**
1. Revisar cada análisis
2. Documentar cambios recomendados
3. Priorizar qué cambios hacer ahora vs después
4. Actualizar especificación.md si hay cambios
5. Crear DBML con versión final

