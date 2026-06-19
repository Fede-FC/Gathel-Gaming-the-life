# /scripts — Scripts de Utilidad

Contiene helpers de línea de comandos para operar el proyecto sin tener que recordar comandos de Docker largos.

---

## docker-setup.sh

Script Bash con comandos abreviados para gestionar el stack Docker del proyecto.

**Uso:**
```bash
./scripts/docker-setup.sh <comando>
```

**Comandos disponibles:**

| Comando | Qué hace |
|---------|----------|
| `up` | Levanta todos los contenedores en segundo plano (`docker compose up -d`) y muestra los logs de Flyway al terminar |
| `down` | Detiene y elimina los contenedores (`docker compose down`) |
| `logs` | Muestra los logs en tiempo real de todos los servicios (`docker compose logs -f`) |
| `sql` | Abre una sesión interactiva de `sqlcmd` contra el SQL Server local. Si `sqlcmd` no está instalado, lo instala vía Homebrew (macOS) |
| `migrate` | Corre las migraciones Flyway manualmente sin reiniciar todo el stack |
| `clean` | Limpia completamente la base de datos. **Destructivo** — pide confirmación antes de ejecutar |
| `rebuild` | Destruye volúmenes, baja contenedores y levanta todo de cero. Útil cuando el schema cambió |
| `status` | Muestra el estado de cada contenedor (`docker compose ps`) |
| `help` | Lista todos los comandos disponibles con ejemplos |

**Detalles técnicos:**
- Usa `set -e` para abortar ante cualquier error
- Detecta la ruta del proyecto automáticamente con `$(dirname "${BASH_SOURCE[0]}")`
- Imprime con colores (verde = éxito, rojo = error, azul = encabezados)

**Cuándo usarlo:** en el día a día de desarrollo para no tener que recordar los comandos exactos de Docker. Para la defensa, el comando más importante es `./scripts/docker-setup.sh up`.
