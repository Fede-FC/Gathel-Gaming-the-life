# Gathel - Relaciones de Tablas y Diagrama Conceptual

**Versión:** 1.0  
**Última actualización:** 12 de Junio de 2026

---

## 📊 Mapa Visual de Relaciones

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CATÁLOGOS (LOOKUP TABLES)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  PropositionStatus  │  SocialNetwork  │  TransactionType  │  EventType      │
│  AIModel            │  AIProvider     │  CurrencyType                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ (FK)
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CORE: JUGADORES Y REDES                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Player ◄──── SocialAccount ◄──── SocialAccountSession                      │
│    ▲                 │                                                       │
│    │                 ▼                                                       │
│    │            SocialNetwork                                               │
│    │                                                                         │
│    └────────────────────────────────────────────────────────────────────┐   │
└─────────────────────────────────────────────────────────────────────────┼───┘
                                                                           │
┌──────────────────────────────────────────────────────────────────────────┘
│
│  PROPOSICIONES Y PREDICCIONES
│  
│    ┌────────────────────────────────────────────────────────────────┐
│    │  Proposition                                                   │
│    │  • Creator: Player (FK)                                        │
│    │  • Target: Player (FK)                                         │
│    │  • Status: PropositionStatus (FK)                              │
│    └────────────────────────────────────────────────────────────────┘
│                   │
│         ┌─────────┼─────────┬────────────────┐
│         ▼         ▼         ▼                ▼
│      Vote    Prediction  GameEvent    PropositionEvidence
│      • Player(FK)  • Player(FK)  • Actor: Player(FK)  • SocialNetwork(FK)
│                    • Direction   • EventType(FK)
│
├─────────────────────────────────────────────────────────────────────────────┤
│                         TRANSACCIONES
│
│    Transaction
│    • Player (FK)
│    • CurrencyType (FK) ──► POINTS, USD, EUR, etc.
│    • TransactionType (FK) ──► DEPOSIT, WITHDRAWAL, COMMISSION, etc.
│    • reference_type + reference_id ──► Apunta a Proposition, Prediction, etc.
│
├─────────────────────────────────────────────────────────────────────────────┤
│                         AUDITORÍA E IA
│
│    AIReviewLog
│    • Proposition (FK)
│    • AIModel (FK)
│    • AIProvider (FK)
│    • Contiene: request_payload, response_payload
│
│    ProcessLog
│    • Registro de SPs ejecutados
│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Tabla de Relaciones Detalladas

### **Relaciones de Player**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| Player → SocialAccount | 1:M | player_id | 1:M | CASCADE | Un jugador puede tener múltiples cuentas sociales |
| Player ← Vote | 1:M | player_id | M:1 | RESTRICT | Votos hacia un jugador |
| Player ← Prediction | 1:M | player_id | M:1 | RESTRICT | Predicciones de un jugador |
| Player ← Transaction | 1:M | player_id | M:1 | RESTRICT | Transacciones de un jugador |
| Player ← GameEvent | 1:M | actor_player_id | M:1 | RESTRICT | Eventos causados por un jugador |
| Player ← Proposition (creator) | 1:M | creator_player_id | M:1 | RESTRICT | Proposiciones creadas |
| Player ← Proposition (target) | 1:M | target_player_id | M:1 | RESTRICT | Proposiciones dirigidas |

---

### **Relaciones de SocialAccount**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| SocialAccount → Player | M:1 | player_id | M:1 | (parent) | Pertenece a un jugador |
| SocialAccount → SocialNetwork | M:1 | social_network_id | M:1 | RESTRICT | De una red social |
| SocialAccount ← SocialAccountSession | 1:M | social_account_id | 1:M | CASCADE | Múltiples sesiones/tokens |

---

### **Relaciones de Proposition**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| Proposition → Player (creator) | M:1 | creator_player_id | M:1 | RESTRICT | Creador es un jugador |
| Proposition → Player (target) | M:1 | target_player_id | M:1 | RESTRICT | Target es un jugador |
| Proposition → PropositionStatus | M:1 | status_id | M:1 | RESTRICT | Un estado |
| Proposition ← Vote | 1:M | proposition_id | 1:M | CASCADE | Múltiples votos |
| Proposition ← Prediction | 1:M | proposition_id | 1:M | CASCADE | Múltiples predicciones |
| Proposition ← PropositionEvidence | 1:M | proposition_id | 1:M | CASCADE | Múltiples evidencias |
| Proposition ← GameEvent | 1:M | proposition_id | 1:M | CASCADE | Múltiples eventos |
| Proposition ← AIReviewLog | 1:M | proposition_id | 1:M | CASCADE | Múltiples revisiones de IA |

---

### **Relaciones de Transaction**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| Transaction → Player | M:1 | player_id | M:1 | RESTRICT | Transacción de un jugador |
| Transaction → CurrencyType | M:1 | currency_type_id | M:1 | RESTRICT | Tipo de moneda (POINTS, USD, etc.) |
| Transaction → TransactionType | M:1 | transaction_type_id | M:1 | RESTRICT | Tipo de transacción |
| Transaction → * | M:1 | reference_type + reference_id | M:1 | N/A | Puede referenciar Proposition, Prediction, etc. |

---

### **Relaciones de GameEvent**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| GameEvent → Proposition | M:1 | proposition_id | M:1 | CASCADE | Evento de una proposición (nullable) |
| GameEvent → EventType | M:1 | event_type_id | M:1 | RESTRICT | Tipo de evento |
| GameEvent → Player | M:1 | actor_player_id | M:1 | RESTRICT | Jugador que causó evento |

---

### **Relaciones de AIReviewLog**

| Tabla | Relación | Campo | Cardinalidad | Acción | Descripción |
|-------|----------|-------|--------------|--------|-------------|
| AIReviewLog → Proposition | M:1 | proposition_id | M:1 | CASCADE | Proposición revisada |
| AIReviewLog → AIModel | M:1 | ai_model_id | M:1 | RESTRICT | Modelo de IA usado |
| AIReviewLog → AIProvider | M:1 | ai_provider_id | M:1 | RESTRICT | Proveedor de IA |

---

## 📋 Matriz de Cardinalidad

```
                      │ 1:1 │ 1:M │ M:1 │ M:M │
───────────────────────────────────────────────────
Player               │     │  ✓  │     │     │
  → SocialAccount    │     │  ✓  │     │     │
  ← SocialAccount    │     │     │  ✓  │     │
  → Proposition      │     │  ✓  │     │     │ (creator y target)
  ← Proposition      │     │  ✓  │     │     │
  ← Vote             │     │  ✓  │     │     │
  ← Prediction       │     │  ✓  │     │     │
  ← Transaction      │     │  ✓  │     │     │
  ← GameEvent        │     │  ✓  │     │     │
───────────────────────────────────────────────────
Proposition          │     │  ✓  │     │     │
  → PropositionStatus│     │     │  ✓  │     │
  ← Vote             │     │  ✓  │     │     │
  ← Prediction       │     │  ✓  │     │     │
  ← PropositionEvid. │     │  ✓  │     │     │
  ← GameEvent        │     │  ✓  │     │     │
  ← AIReviewLog      │     │  ✓  │     │     │
───────────────────────────────────────────────────
Vote                 │     │     │     │  ✓  │ (Proposition, Player)
Prediction           │     │     │     │  ✓  │ (Proposition, Player)
───────────────────────────────────────────────────
Transaction          │     │  ✓  │     │     │
  → CurrencyType     │     │     │  ✓  │     │
  → TransactionType  │     │     │  ✓  │     │
───────────────────────────────────────────────────
```

---

## 🏛️ Descripción de Cada Tabla

### **CATÁLOGOS (Lookup Tables)**

#### **PropositionStatus**
- **Propósito:** Enumerar estados posibles de proposiciones
- **Registros típicos:** PENDING, ACTIVE, PREDICTION_CLOSED, RESOLVED, REJECTED, CANCELLED
- **Tamaño:** ~10 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en Proposition

#### **SocialNetwork** ⭐
- **Propósito:** Configurar redes sociales integradas
- **Registros típicos:** INSTAGRAM, TIKTOK, TWITTER, FACEBOOK
- **Campos clave:** url, api_url, api_config (JSON)
- **Tamaño:** ~5-10 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en SocialAccount, PropositionEvidence

#### **CurrencyType** ✨
- **Propósito:** Soportar N tipos de monedas/fondos sin nuevas tablas
- **Registros típicos:** POINTS (virtual), USD, EUR, ARS, etc.
- **Campos clave:** currency_code, is_virtual, decimal_places, exchange_rate_to_usd
- **Tamaño:** ~20-50 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en Transaction
- **Ventaja:** Permite agregar nuevas monedas sin modificar schema

#### **TransactionType**
- **Propósito:** Categorizar tipos de transacciones
- **Registros típicos:** DEPOSIT, WITHDRAWAL, COMMISSION, WINNING, PENALTY, REFUND
- **Campos clave:** applies_to (POINTS, MONEY, BOTH)
- **Tamaño:** ~15 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en Transaction

#### **EventType**
- **Propósito:** Enumerar tipos de eventos del juego
- **Registros típicos:** PROPOSITION_CREATED, VOTE_CAST, PREDICTION_MADE, PROPOSITION_RESOLVED, REWARDS_DISTRIBUTED
- **Tamaño:** ~15 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en GameEvent

#### **AIModel** ✨
- **Propósito:** Normalizar modelos de IA para auditoría
- **Registros típicos:** GPT4, CLAUDE3, VISION_V2
- **Campos clave:** model_code, model_name, version
- **Tamaño:** ~20 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en AIReviewLog

#### **AIProvider** ✨
- **Propósito:** Normalizar proveedores de IA
- **Registros típicos:** OPENAI, ANTHROPIC, GOOGLE
- **Tamaño:** ~5 registros
- **Acceso:** Lectura frecuente, cambios raros
- **Relación:** FK en AIReviewLog

---

### **AUTENTICACIÓN Y REDES SOCIALES**

#### **Player**
- **Propósito:** Usuarios de la plataforma
- **Campos clave:** username, email, password_hash, balance_points
- **Tamaño esperado:** 1,000 (caso de estudio)
- **Acceso:** Lectura muy frecuente, escritura en transacciones
- **Índices:** username (UNIQUE), email (UNIQUE), created_at
- **Auditoría:** checksum, updated_at, updated_by
- **Relaciones:** 
  - Crea proposiciones (creator_player_id)
  - Es target de proposiciones (target_player_id)
  - Realiza votos
  - Realiza predicciones
  - Realiza transacciones
  - Causa eventos del juego

#### **SocialAccount** ⭐
- **Propósito:** Vincular cuentas de redes sociales a jugadores
- **Campos clave:** player_id, social_network_id, account_username, is_verified
- **Tamaño esperado:** 1,000-3,000 (múltiples por jugador)
- **Cambios:** ❌ REMOVIDO `access_token_encrypted` (ver SocialAccountSession)
- **Acceso:** Lectura frecuente, escritura en login
- **Índices:** (player_id, social_network_id) UNIQUE
- **Relaciones:** FK a Player, SocialNetwork, SocialAccountSession

#### **SocialAccountSession** ✨
- **Propósito:** Guardar tokens que rotan entre sesiones
- **Campos clave:** access_token_encrypted, refresh_token_encrypted, token_expires_at
- **Tamaño esperado:** 5,000-10,000 (múltiples sesiones por cuenta)
- **Acceso:** Lectura/escritura en cada refresh
- **Índices:** social_account_id, is_active, token_expires_at
- **Reglas:** Se invalidan al expirar, se crean nuevas en cada login
- **Relaciones:** FK a SocialAccount

---

### **PROPOSICIONES Y PREDICCIONES**

#### **Proposition**
- **Propósito:** Proposiciones/predicciones que crean los jugadores
- **Campos clave:** creator_player_id, target_player_id, title, status_id, is_fulfilled
- **Tamaño esperado:** 5,000 (caso de estudio)
- **Acceso:** Lectura muy frecuente, escritura moderada
- **Índices:** creator_player_id, target_player_id, status_id, created_at, prediction_ends_at
- **Auditoría:** checksum, created_at, updated_at
- **Relaciones:**
  - FK a Player (creator y target)
  - FK a PropositionStatus
  - 1:M con Vote, Prediction, PropositionEvidence, GameEvent, AIReviewLog
- **Regla crítica:** creator_player_id ≠ target_player_id

#### **Vote**
- **Propósito:** Votos de jugadores sobre proposiciones
- **Campos clave:** proposition_id, player_id
- **Tamaño esperado:** 50,000+ (5,000 props × 10+ votos)
- **Acceso:** Lectura frecuente, escritura durante votación
- **Índices:** (proposition_id, player_id) UNIQUE, proposition_id, player_id
- **Auditoría:** checksum, created_at
- **Relaciones:** FK a Proposition, Player
- **Regla crítica:** Un jugador vota máximo una vez por proposición

#### **Prediction**
- **Propósito:** Predicciones de jugadores sobre proposiciones
- **Campos clave:** proposition_id, player_id, direction, amount_points, amount_real, result
- **Tamaño esperado:** 250,000+ (50 predicciones × 5,000 proposiciones)
- **Acceso:** Lectura muy frecuente, escritura durante predicción
- **Índices:** (proposition_id, player_id), proposition_id, player_id
- **Auditoría:** checksum, created_at, updated_at
- **Relaciones:** FK a Proposition, Player
- **Reglas críticas:**
  - Si prediction_type = POINTS: amount_points ≤ 1
  - Si prediction_type = MONEY: amount_real > 0
  - No se puede modificar después de prediction_ends_at

#### **PropositionEvidence** ⭐
- **Propósito:** Evidencia multimedia para validar proposiciones
- **Campos clave:** proposition_id, post_id (GUID), evidence_url, evidence_type
- **Tamaño esperado:** 5,000-10,000 (múltiples por proposición)
- **Acceso:** Lectura durante validación, escritura en resolución
- **Índices:** proposition_id, post_id, created_at
- **Auditoría:** checksum, created_at
- **Cambios:** ✨ AGREGADO `post_id` (GUID del post en la red social)
- **Relaciones:** FK a Proposition, SocialNetwork

---

### **TRANSACCIONES**

#### **Transaction** ✨ (REEMPLAZA PointsTransaction y MoneyTransaction)
- **Propósito:** Registro unificado de transacciones de cualquier moneda
- **Campos clave:** player_id, currency_type_id, amount, running_balance, transaction_type_id
- **Tamaño esperado:** 100,000+ (múltiples por predicción/proposición)
- **Acceso:** Lectura frecuente, escritura en cada transacción
- **Índices:** (player_id, created_at), (player_id, currency_type_id), (reference_type, reference_id)
- **Auditoría:** checksum, created_at
- **Campos clave:** 
  - `amount`: positivo (ingreso), negativo (egreso)
  - `running_balance`: balance total después de la transacción
  - `reference_type` + `reference_id`: permite rastrear origen (PROPOSITION, PREDICTION, etc.)
- **Relaciones:** FK a Player, CurrencyType, TransactionType
- **Ventaja principal:** Soporta N monedas sin agregar tablas
- **Ejemplo:**
  ```
  Jugador apuesta 1 POINT en predicción:
  → Transaction(player_id=1, currency_type='POINTS', amount=-1, running_balance=99, ref_type='PREDICTION', ref_id=123)
  
  Jugador gana 50 POINTS de comisión:
  → Transaction(player_id=1, currency_type='POINTS', amount=50, running_balance=149, ref_type='PROPOSITION', ref_id=456)
  ```

---

### **AUDITORÍA E IA**

#### **AIReviewLog** ⭐
- **Propósito:** Registro completo de revisiones de IA de proposiciones
- **Campos clave:** proposition_id, ai_model_id, ai_provider_id, review_result, request_payload, response_payload
- **Tamaño esperado:** 5,000 (una revisión por proposición aproximadamente)
- **Acceso:** Lectura durante debugging/análisis, escritura en cada revisión
- **Índices:** proposition_id, ai_provider_id, reviewed_at
- **Auditoría:** checksum, reviewed_at
- **Cambios:** ✨ AGREGADO request_payload y response_payload (JSON completos)
- **Relaciones:** FK a Proposition, AIModel, AIProvider
- **Propósito de payloads:**
  - Debugging: saber exactamente qué se envió y qué respondió
  - Auditoría: cumplimiento regulatorio
  - Análisis: entender decisiones de IA
  - Reentrenamiento: datos para mejorar modelos

#### **GameEvent** ⭐
- **Propósito:** Historial completo de eventos del juego (auditoría operacional)
- **Campos clave:** proposition_id, event_type_id, actor_player_id, event_data
- **Tamaño esperado:** 250,000+ (múltiples eventos por proposición)
- **Acceso:** Lectura frecuente (análisis, debugging), escritura en cada acción
- **Índices:** (proposition_id, created_at), (event_type_id, created_at), actor_player_id
- **Auditoría:** checksum, created_at
- **Relaciones:** FK a Proposition (nullable), EventType, Player
- **event_data:** JSON con contexto del evento (ej: monto apostado, categoría rechazo)
- **Usos:**
  - Reconstruir estado de proposición en cualquier momento
  - Detectar anomalías
  - Análisis de patrones
  - Auditoría regulatoria

#### **ProcessLog**
- **Propósito:** Registro de ejecución de Stored Procedures
- **Campos clave:** sp_name, action_description, status, error_detail, executed_at
- **Tamaño esperado:** 100,000+ (log de SPs complejos)
- **Acceso:** Lectura durante debugging, escritura en cada SP
- **Índices:** executed_at, sp_name
- **Usos:**
  - Debugging de procesos
  - Auditoría de cambios críticos
  - Performance analysis

---

## 🔑 Puntos Críticos de Diseño

### **1. Constraints de Integridad**
- Todas las FKs tienen `ON DELETE` definida (CASCADE o RESTRICT)
- Evita orfandad de registros
- CASCADE en datos dependientes (Vote, Prediction, GameEvent)
- RESTRICT en datos maestros (Player, Status, monedas)

### **2. Auditoría**
- **checksum:** SHA-256 de campos clave para detectar manipulación
- **created_at:** Timestamp inmutable
- **updated_at:** Para tracking de cambios
- **updated_by:** Quién hizo el cambio (usuario o sistema)
- **Tablas auditadas:** Proposition, Vote, Prediction, Transaction, GameEvent, AIReviewLog

### **3. Normalización de Monedas**
- **Antes:** PointsTransaction + MoneyTransaction (2 tablas)
- **Ahora:** Transaction + CurrencyType (1 tabla + 1 catálogo)
- **Ventaja:** Agregar EUR, ARS, GOLD_COINS, etc. sin cambiar schema

### **4. Normalización de IA**
- **Antes:** ai_model_version (string)
- **Ahora:** AIModel + AIProvider (FKs normalizadas)
- **Ventaja:** Análisis por proveedor/modelo, menos duplicación

### **5. Tokens de Sesión Separados**
- **Antes:** access_token_encrypted en SocialAccount
- **Ahora:** SocialAccountSession con tokens que rotan
- **Ventaja:** Manejo correcto de sesiones y refreshes

---

## 📈 Volumen Estimado de Datos

| Tabla | Registros | Crecimiento | Notas |
|-------|-----------|-------------|-------|
| Player | 1,000 | Lento | Nuevos usuarios |
| SocialAccount | 1,500-3,000 | Lento | 1-3 cuentas/jugador |
| SocialAccountSession | 10,000+ | Rápido | Expira/renueva |
| Proposition | 5,000 | Controlado | 5 props/jugador |
| Vote | 50,000+ | Rápido | 10+ votos/prop |
| Prediction | 250,000+ | Muy rápido | 50+ pred/prop |
| Transaction | 100,000+ | Muy rápido | Múltiples por predicción |
| GameEvent | 250,000+ | Muy rápido | Múltiples eventos/prop |
| AIReviewLog | 5,000 | Lento | Una/prop |

**Tamaño estimado de BD:** 500 MB - 2 GB (dependiendo de tamaño de JSON en GameEvent y AIReviewLog)

---

**Fin del documento de relaciones**
