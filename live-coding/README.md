# Live Coding — Guía de Defensa

## Antes de entrar a la sala (10 min antes)

```bash
# 1. Levantar el stack completo
docker compose up -d

# 2. Verificar que todo está corriendo
docker compose ps
# Deben aparecer 5 servicios: sql-server, db-init, flyway, backend, frontend

# 3. Verificar el frontend
# Abrir http://localhost:3000 → login con demo_admin / Password123!
```

## Configuración de SSMS

### Conexión al Docker SQL Server
| Campo | Valor |
|-------|-------|
| Server | `localhost,1433` |
| Auth | SQL Server Authentication |
| Login | `sa` |
| Password | `YourStrong!Passw0rd` |

### Pestañas a abrir (en este orden)

| Tab SSMS | Archivo | Propósito |
|----------|---------|-----------|
| Tab 1 | `00_startup.sql` | Ejecutar primero, verificar datos |
| Tab 2 | `01_cheatsheet.sql` | **SIEMPRE VISIBLE** — columnas y firmas de SP |
| Tab 3 | `02_queries_exploracion.sql` | Rankings, distribuciones, análisis |
| Tab 4 | `03_flujo_demo.sql` | Demo completo paso a paso |
| Tab 5 | `04_seguridad_demo.sql` | RLS, masking, cifrado |
| Tab 6 | `05_concurrencia_demo.sql` | Transacciones anidadas, aislamiento |
| Tab 7 | `06_queries_ad_hoc.sql` | Plantillas para preguntas en vivo |

## Durante la defensa

### Si el profesor pide un query que no tienes listo
1. Ir a `06_queries_ad_hoc.sql` — ahí están plantillas para JOIN, GROUP BY, CTE, PIVOT, window functions
2. Copiar la plantilla más cercana, modificar tabla/columna/filtro
3. Si olvidás el nombre de una columna exacto → `SELECT TOP 1 * FROM NombreTabla`

### Si el profesor pide ejecutar un SP
```sql
-- Ver todos los SPs disponibles
SELECT name FROM sys.procedures WHERE name LIKE 'usp_%' ORDER BY name;

-- Ejecutar cualquier SP con parámetros explícitos
EXEC dbo.usp_GetPlayerDashboard @player_id = 1;
```

### Red de seguridad: Object Explorer
- Click derecho en tabla → **Select Top 1000 Rows** → genera el SELECT automático
- Click derecho en SP → **Execute Stored Procedure** → UI gráfica para parámetros

## Flujo demo recomendado para la defensa

```
1. [Frontend] Registro → auto-login → Dashboard con 100 pts
2. [Frontend] Billetera → depositar USD 100
3. [Frontend] Proposiciones → crear (autocomplete usuario)
4. [SSMS 03_flujo_demo.sql] EXEC usp_RecordAIReview → APPROVED
5. [Frontend] La proposición aparece como ACTIVE para el sujeto
6. [Frontend] Sujeto acepta → aparece en lista activa para predecir
7. [Frontend] Otra cuenta predice → ver balance descontado
8. [SSMS 03_flujo_demo.sql] usp_ClosePropositionPredictions → usp_ResolveProposition
9. [SSMS 02_queries_exploracion.sql] Mostrar auditoría (PropositionAudit) generada por trigger
```

## Archivos de referencia complementarios

```
src/database/security-lab/README.md   → guía demos de seguridad
src/database/concurrency/README.md    → guía deadlocks (2 sesiones SSMS)
```
