#!/bin/bash

# docker-setup.sh - Helper script para Gathel con Docker Compose

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Comandos disponibles
case "${1:-help}" in
    up)
        print_header "Iniciando SQL Server + Flyway"
        docker-compose up -d
        print_success "Contenedores levantados"
        echo ""
        echo "SQL Server disponible en: localhost:1433"
        echo "Usuario: sa"
        echo "Contraseña: GathelPassword123!Secure"
        echo ""
        echo "Esperando a que Flyway complete migraciones..."
        sleep 10
        docker-compose logs flyway
        ;;

    down)
        print_header "Deteniendo contenedores"
        docker-compose down
        print_success "Contenedores detenidos"
        ;;

    logs)
        print_header "Mostrando logs"
        docker-compose logs -f
        ;;

    sql)
        print_header "Conectando a SQL Server"
        # Instalar sqlcmd si no existe (macOS)
        if ! command -v sqlcmd &> /dev/null; then
            echo "sqlcmd no encontrado. Instalando..."
            # Para macOS con Homebrew
            if command -v brew &> /dev/null; then
                brew install mssql-tools18
            else
                print_error "sqlcmd no instalado. Instala mssql-tools18"
                exit 1
            fi
        fi

        sqlcmd -S localhost -U sa -P "GathelPassword123!Secure" -d GathelDB
        ;;

    migrate)
        print_header "Ejecutando migraciones Flyway"
        docker-compose run --rm flyway migrate
        print_success "Migraciones completadas"
        ;;

    clean)
        print_header "Limpiando BD (DESTRUCTIVO - elimina todo)"
        read -p "¿Estás seguro? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker-compose run --rm flyway clean
            print_success "BD limpiada"
        else
            print_error "Cancelado"
        fi
        ;;

    rebuild)
        print_header "Reconstruyendo todo (limpia + migra)"
        docker-compose down
        docker volume rm gathel-gaming-the-life_sql-data 2>/dev/null || true
        docker-compose up -d
        sleep 15
        docker-compose logs
        ;;

    status)
        print_header "Estado de los contenedores"
        docker-compose ps
        ;;

    help|*)
        print_header "Comandos Disponibles"
        echo ""
        echo "  ./scripts/docker-setup.sh up          - Iniciar SQL Server + Flyway"
        echo "  ./scripts/docker-setup.sh down        - Detener contenedores"
        echo "  ./scripts/docker-setup.sh logs        - Ver logs en vivo"
        echo "  ./scripts/docker-setup.sh sql         - Conectar a SQL Server (sqlcmd)"
        echo "  ./scripts/docker-setup.sh migrate     - Ejecutar migraciones manualmente"
        echo "  ./scripts/docker-setup.sh clean       - Limpiar BD (DESTRUCTIVO)"
        echo "  ./scripts/docker-setup.sh rebuild     - Reconstruir todo desde cero"
        echo "  ./scripts/docker-setup.sh status      - Ver estado de contenedores"
        echo ""
        echo "Ejemplos:"
        echo "  1. Iniciar: ./scripts/docker-setup.sh up"
        echo "  2. Ver logs: ./scripts/docker-setup.sh logs"
        echo "  3. Conectar BD: ./scripts/docker-setup.sh sql"
        echo ""
        ;;
esac
