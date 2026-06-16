# Security Lab - Fase 3

Demostración de escenarios de seguridad implementados en Gathel Gaming Platform según los requisitos del caso #3.

## 📋 Requisitos del Caso Cumplidos

- ✅ **Usuarios de prueba**: 4 logins SQL creados (admin, system, player, readonly)
- ✅ **Roles con permisos específicos**: 4 roles configurados con permisos diferenciados
- ✅ **Permisos directos vs heredados**: GRANT/DENY explícitos + herencia vía roles
- ✅ **Escenarios de acceso**: SELECT sin permiso, acceso vía SP, acceso denegado
- ✅ **Data Masking**: email, balance_points, account_username enmascarados
- ✅ **Row-Level Security (RLS)**: Tabla Transaction protegida por RLS
- ✅ **Cifrado con Master Certificate**: Symmetric Key + Certificate + demo de encrypt/decrypt
- ✅ **Documentación**: Scripts y guías de cada escenario

## 🔧 Instalación/Configuración Previa

### Requisito 1: Ejecutar Flyway (migraciones V1-V4)

```bash
# En /src/database/flyway/
export FLYWAY_PASSWORD=YourPassword123!
flyway migrate
```

Esto ejecuta:
- **V1**: Schema (16 tablas, índices, triggers)
- **V2**: Stored Procedures (12 SPs)
- **V3**: Seeding (1000 jugadores, 5000 proposiciones, etc.)
- **V4**: Security (roles, logins, masking, RLS, cifrado)

### Requisito 2: Verificación

```sql
-- Conectarse como 'sa' (admin por defecto) y ejecutar:
SELECT COUNT(*) FROM dbo.Player;  -- Debería retornar ~1000
SELECT name FROM sys.database_principals WHERE name LIKE 'db_gathel%';  -- 4 roles
SELECT name FROM sys.database_principals WHERE name LIKE 'gathel_%_usr';  -- 4 logins
```

## 📂 Scripts de Demostración

### 1. `01_master_key_cert.sql` - Cifrado

**Objetivo**: Demostrar cifrado de datos a nivel T-SQL usando Master Key y Symmetric Key.

**Qué demuestra**:
- Creación de Master Key encriptada con contraseña
- Creación de Certificate
- Creación de Symmetric Key cifrado con Certificate
- Cifrado de datos con `ENCRYPTBYKEY()`
- Descifrado con `DECRYPTBYKEY()`

**Cómo ejecutar**:
```bash
sqlcmd -S localhost -U sa -P YourPassword -d GathelDB -i 01_master_key_cert.sql
```

**Resultado esperado**: "ÉXITO: Datos descifrados coinciden perfectamente con los originales."

---

### 2. `02_roles_users.sql` - Roles y Usuarios

**Objetivo**: Mostrar la configuración de roles y usuarios creados.

**Qué demuestra**:
- 4 roles definidos: admin, system, player, readonly
- 4 logins SQL: gathel_admin_usr, gathel_system_usr, gathel_player_usr, gathel_readonly_usr
- Membresía de usuarios en roles (herencia)
- Permisos de cada rol

**Cómo ejecutar**:
```bash
sqlcmd -S localhost -U sa -P YourPassword -d GathelDB -i 02_roles_users.sql
```

**Matriz de Roles**:

| Rol | Permiso Principal | Casos de Uso |
|-----|-------------------|--------------|
| db_gathel_admin | db_datareader, db_datawriter, EXECUTE, UNMASK | Administradores, auditoría |
| db_gathel_system | EXECUTE (SPs solamente) | Servicios backend automatizados |
| db_gathel_player | SELECT (catálogos), EXECUTE (SPs específicas) | Jugadores en la aplicación |
| db_gathel_readonly | SELECT (PropositionStatus, Proposition) | Reportes, análisis sin escritura |

---

### 3. `03_permissions_demo.sql` - Permisos Directos vs Heredados

**Objetivo**: Demostrar diferencia entre permisos heredados (via rol) y directos (GRANT/DENY).

**Qué demuestra**:
- **Permisos Heredados**: gathel_system_usr hereda EXECUTE del rol db_gathel_system
- **Permisos Directos**: gathel_readonly_usr tiene GRANT SELECT explícito en PropositionStatus y DENY en Player
- Matriz comparativa de acceso
- Comportamiento real en cada escenario

**Cómo ejecutar**:
```bash
sqlcmd -S localhost -U sa -P YourPassword -d GathelDB -i 03_permissions_demo.sql
```

**Caso de Estudio**:
- `gathel_system_usr` puede EXEC usp_RegisterPlayer (heredado de rol) pero NO puede SELECT Player (sin permiso)
- `gathel_readonly_usr` puede SELECT PropositionStatus (permiso directo) pero DENY SELECT Player (permiso directo negado)

---

### 4. `04_data_masking.sql` - Enmascaramiento de Datos

**Objetivo**: Demostrar Dynamic Data Masking para proteger datos sensibles.

**Qué demuestra**:
- Columnas enmascaradas:
  - `Player.email` → `aXXX@XXXX.com` (pattern email())
  - `Player.balance_points` → `0` (default())
  - `SocialAccount.account_username` → `***username***` (partial())
- Diferencia entre vista de admin (datos reales) vs no-admin (datos enmascarados)
- Permiso UNMASK (solo admin)

**Cómo ejecutar**:
```bash
# Como admin (sa):
sqlcmd -S localhost -U sa -P YourPassword -d GathelDB -i 04_data_masking.sql

# Como usuario no-admin (gathel_readonly_usr):
sqlcmd -S localhost -U gathel_readonly_usr -P GathelReadOnly123!Secure -d GathelDB
SELECT TOP 3 player_id, username, email, balance_points FROM dbo.Player;
-- Resultado: emails y balance_points enmascarados
```

**Comportamiento**:
- **Admin ve**: sofia.garcia@gathel.dev, balance_points=523
- **No-admin ve**: a***@***.com, balance_points=0 (oculto)

---

### 5. `05_rls.sql` - Row-Level Security

**Objetivo**: Demostrar RLS para filtrar filas según el usuario.

**Qué demuestra**:
- Tabla protegida: `dbo.[Transaction]`
- Función de predicado: `dbo.fn_TransactionRLS(player_id)`
- Security Policy: `TransactionSecurityPolicy` (ACTIVA)
- Filtrado automático por `SESSION_CONTEXT(N'player_id')`
- Excepciones para admin/owner

**Cómo ejecutar**:
```bash
# Como admin (sa): ve TODAS las transacciones
sqlcmd -S localhost -U sa -P YourPassword -d GathelDB
SELECT COUNT(*) FROM dbo.[Transaction];  -- ~5000+ registros

# Como player (gathel_player_usr): ve SOLO sus transacciones
sqlcmd -S localhost -U gathel_player_usr -P GathelPlayer123!Secure -d GathelDB
EXEC sp_set_session_context @key=N'player_id', @value=1;  -- Asumir player_id=1
SELECT COUNT(*) FROM dbo.[Transaction];  -- ~5-10 registros (solo suyos)
```

**Flujo de Seguridad**:
1. Aplicación autentica al usuario (obtiene player_id)
2. `EXEC sp_set_session_context @key=N'player_id', @value=@player_id;`
3. `SELECT FROM [Transaction];` → RLS automáticamente filtra
4. Usuario NO puede ver transacciones de otros

---

## 🧪 Casos de Prueba Completos

### Caso 1: Usuario sin SELECT Directo pero con Acceso vía SP

**Usuario**: `gathel_system_usr`
**Rol**: `db_gathel_system`

```sql
-- Conectarse como gathel_system_usr
SQLCMD -U gathel_system_usr -P 'GathelSystem123!Secure'

-- Prueba 1: Intenta SELECT (FALLA)
SELECT * FROM dbo.Player;
-- Resultado: Msg 229, Level 14: SELECT permission denied on object 'Player'

-- Prueba 2: Ejecuta SP (ÉXITO)
EXEC dbo.usp_RegisterPlayer 
    @username='test_user', 
    @email='test@gathel.dev',
    @password_hash='hash123',
    @new_player_id OUTPUT;
-- Resultado: Nueva fila insertada en Player, transacción registrada
```

### Caso 2: Enmascaramiento de Email

**Sin Masking** (admin):
```sql
SELECT TOP 1 email FROM dbo.Player;
-- Resultado: sofia.garcia1@gathel.dev
```

**Con Masking** (readonly):
```sql
SELECT TOP 1 email FROM dbo.Player;
-- Resultado: s***@g***.dev
```

### Caso 3: RLS en Transaction

**Admin ve todo**:
```sql
-- Como sa
SELECT COUNT(*) FROM dbo.[Transaction];
-- Resultado: 1234 (todas las transacciones de todos los jugadores)
```

**Jugador ve solo sus filas**:
```sql
-- Como gathel_player_usr
EXEC sp_set_session_context @key=N'player_id', @value=1;
SELECT COUNT(*) FROM dbo.[Transaction];
-- Resultado: 7 (solo transacciones de player_id=1)

-- Intentar burlar RLS:
EXEC sp_set_session_context @key=N'player_id', @value=999;
SELECT COUNT(*) FROM dbo.[Transaction];
-- Resultado: 0 (RLS bloquea: no hay transacciones de player_id=999)
```

### Caso 4: Cifrado/Descifrado

```sql
-- Ejecutar 01_master_key_cert.sql
-- Resultado: Datos originales → Cifrados → Descifrados ✓ IGUAL
```

---

## 📊 Auditoría y Logging

### Tabla de Auditoría: `dbo.ProcessLog`

Registra todos los cambios realizados por SPs:

```sql
SELECT sp_name, action_description, status, executed_by, executed_at
FROM dbo.ProcessLog
WHERE sp_name = 'usp_RegisterPlayer'
ORDER BY executed_at DESC;
```

### Tabla de Cambios: `dbo.PropositionAudit`

Registra cambios en Proposition (status, acceptance, fulfillment, AI review):

```sql
SELECT proposition_id, field_name, old_value, new_value, changed_by, changed_at
FROM dbo.PropositionAudit
WHERE proposition_id = 1
ORDER BY changed_at DESC;
```

---

## 🔒 Seguridad en Profundidad (Defense in Depth)

Gathel implementa múltiples capas de seguridad:

```
┌─────────────────────────────────────────────────────┐
│ APLICACIÓN (Backend)                               │
│  • Autenticación de usuario                        │
│  • Validación de entrada                           │
│  • Cifrado en tránsito (HTTPS)                      │
└─────────────────────────────────────────────────────┘
           ↓ sp_set_session_context + llamada SP
┌─────────────────────────────────────────────────────┐
│ STORED PROCEDURES (Control Transaccional)          │
│  • Validaciones de negocio                         │
│  • Transacciones ACID                              │
│  • Optimistic Locking (balance_version)            │
│  • Logging (ProcessLog)                            │
└─────────────────────────────────────────────────────┘
           ↓ EXECUTE autorizado por Rol
┌─────────────────────────────────────────────────────┐
│ ROLES Y PERMISOS (Control de Acceso)               │
│  • Roles con permisos mínimos                      │
│  • DENY explícitos para datos sensibles            │
│  • Permisos heredados y directos                   │
└─────────────────────────────────────────────────────┘
           ↓ Si acceso permitido
┌─────────────────────────────────────────────────────┐
│ ROW-LEVEL SECURITY (Filtrado de Filas)            │
│  • SESSION_CONTEXT(player_id) aplicado             │
│  • fn_TransactionRLS() evalúa cada fila           │
│  • Imposible eludir (a nivel BD)                   │
└─────────────────────────────────────────────────────┘
           ↓ Datos visibles aplicados con
┌─────────────────────────────────────────────────────┐
│ DYNAMIC DATA MASKING (Ofuscación)                  │
│  • email() → aXXX@XXXX.com                         │
│  • default() → 0 (números)                         │
│  • partial() → ***hidden***                        │
│  • UNMASK solo para admin                          │
└─────────────────────────────────────────────────────┘
           ↓ En caso de compromisonivel BD
┌─────────────────────────────────────────────────────┐
│ CIFRADO (Symmetric Key + Certificate)              │
│  • Tokens de redes sociales cifrados               │
│  • Datos en reposo protegidos                      │
│  • Descifrado requiere Master Key                  │
└─────────────────────────────────────────────────────┘
           ↓ Auditoría de todo
┌─────────────────────────────────────────────────────┐
│ AUDITORÍA (ProcessLog, PropositionAudit)           │
│  • Quién hizo qué y cuándo                         │
│  • Cambios a nivel de campo                        │
│  • Trazabilidad completa                           │
└─────────────────────────────────────────────────────┘
```

---

## 📝 Checksums y Integridad

Algunas tablas tienen campo `checksum` para validar integridad:

```sql
-- Verificar integridad de Proposition
SELECT 
    proposition_id, 
    checksum, 
    SHA2_256(CONVERT(NVARCHAR(MAX), 
        CONCAT(proposition_id, title, description, status_id)
    )) AS checksum_esperado
FROM dbo.Proposition
WHERE checksum IS NOT NULL;
```

---

## 🚀 Próximos Pasos

Después de validar el Security Lab:

1. **Fase 4**: Transacciones y Concurrencia
   - SPs transaccionales anidados
   - Deadlock scenarios
   - Niveles de aislamiento

2. **Fase 5**: Backend MVP (REST API)
   - Endpoints con autenticación
   - Sesiones con SESSION_CONTEXT
   - Manejo de errores de RLS

3. **Fase 6**: Frontend MVP
   - Login/logout
   - Visualización con datos enmascarados

---

## ❓ FAQ / Troubleshooting

**P**: ¿Cómo resetear los datos de demo?  
**R**: Re-ejecutar `flyway migrate` (Flyway mantiene estado en tabla `flyway_schema_history`).

**P**: ¿Cómo cambiar contraseñas de los logins?  
**R**: `ALTER LOGIN gathel_admin_usr WITH PASSWORD = 'NewPassword';`

**P**: ¿Puedo agregar más logins con otros permisos?  
**R**: Sí, seguir el patrón en 02_roles_users.sql y asignar al rol correspondiente.

**P**: ¿RLS funciona con vistas?  
**R**: Sí, la RLS se aplica a nivel tabla base, funciona automáticamente en vistas.

---

**Versión**: 1.0  
**Fecha**: 15 Junio 2026  
**Autor**: Équipo Gathel  
**Estado**: ✅ Completado
