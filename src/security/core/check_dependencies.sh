#!/bin/bash
#
# Nome do Arquivo: check_dependencies.sh
#
# Descrição:
#   Verifica e instala automaticamente dependências necessárias para execução
#   dos scripts de segurança em sistemas Debian/Ubuntu.
#
# Dependências:
#   - Sistema operacional: Debian/Ubuntu
#   - Acesso root ou permissão de sudo
#
# Exit codes:
#   0 - Todas as dependências estão instaladas
#   1 - Erro ao instalar dependências
#   2 - Sistema operacional não suportado
#
# Uso:
#   sudo ./check_dependencies.sh [--install]
#
# Opções:
#   --install - Instala automaticamente as dependências faltantes
#   --list    - Apenas lista as dependências sem instalar
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-06

set -euo pipefail

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
INSTALL_MODE=false

MISSING_DEPS=()
INSTALLED_DEPS=()
FAILED_DEPS=()

# Dependências agrupadas por funcionalidade
declare -A DEPENDENCIES=(
    ["core"]="apt-get apt-utils sudo curl wget gnupg2 ca-certificates lsb-release"
    ["ssh"]="openssh-server"
    ["firewall"]="ufw"
    ["fail2ban"]="fail2ban"
    ["monitor"]="htop iotop iftop nethogs"
    ["network"]="net-tools iproute2 dnsutils"
    ["security"]="unattended-upgrades apt-listchanges"
    ["caprover"]="docker.io nodejs npm"
)

#
# log
#
# Descrição:
#   Exibe mensagens de log formatadas.
#
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "${level}" in
        info)    echo -e "[${timestamp}] [INFO] ${message}" ;;
        success) echo -e "[${timestamp}] ${GREEN}[SUCCESS]${NC} ${message}" ;;
        warning) echo -e "[${timestamp}] ${YELLOW}[WARNING]${NC} ${message}" >&2 ;;
        error)   echo -e "[${timestamp}] ${RED}[ERROR]${NC} ${message}" >&2 ;;
        *)       echo -e "[${timestamp}] [${level^^}] ${message}" >&2 ;;
    esac
}

#
# check_os
#
# Descrição:
#   Verifica se o sistema operacional é suportado.
#
check_os() {
    if [ ! -f "/etc/os-release" ]; then
        log "error" "Não foi possível detectar o sistema operacional"
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    
    if [[ "$ID" != "debian" && "$ID_LIKE" != *"debian"* ]]; then
        log "error" "Este script é compatível apenas com sistemas baseados em Debian"
        return 1
    fi
    
    log "info" "Sistema operacional detectado: $PRETTY_NAME"
    return 0
}

#
# check_root
#
# Descrição:
#   Verifica se o script está sendo executado como root.
#
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "error" "Este script deve ser executado como root"
        return 1
    fi
    return 0
}

#
# check_package
#
# Descrição:
#   Verifica se um pacote está instalado.
#
check_package() {
    local pkg="$1"
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "installed"; then
        return 0
    else
        return 1
    fi
}

#
# install_package
#
# Descrição:
#   Instala um pacote usando apt-get.
#
install_package() {
    local pkg="$1"
    
    log "info" "Instalando pacote: $pkg"
    
    if ! apt-get install -y --no-install-recommends "$pkg" > /dev/null 2>&1; then
        log "error" "Falha ao instalar o pacote: $pkg"
        return 1
    fi
    
    log "success" "Pacote instalado com sucesso: $pkg"
    return 0
}

#
# check_npm_package
#
# Descrição:
#   Verifica se um pacote npm global está instalado.
#
check_npm_package() {
    local pkg="$1"
    npm list -g --depth=0 "$pkg" >/dev/null 2>&1
}

#
# install_npm_package
#
# Descrição:
#   Instala um pacote npm globalmente.
#
install_npm_package() {
    local pkg="$1"
    log "info" "Instalando pacote npm: $pkg"
    if npm install -g "$pkg" >/dev/null 2>&1; then
        log "success" "Pacote npm instalado: $pkg"
        return 0
    fi
    log "error" "Falha ao instalar pacote npm: $pkg"
    return 1
}

#
# update_package_list
#
# Descrição:
#   Atualiza a lista de pacotes disponíveis.
#
update_package_list() {
    log "info" "Atualizando lista de pacotes..."
    
    if ! apt-get update > /dev/null 2>&1; then
        log "error" "Falha ao atualizar a lista de pacotes"
        return 1
    fi
    
    log "success" "Lista de pacotes atualizada com sucesso"
    return 0
}

#
# check_dependencies
#
# Descrição:
#   Verifica e instala as dependências necessárias.
#
check_dependencies() {
    local category
    local pkg
    local missing_count=0
    
    # Atualizar lista de pacotes primeiro
    if ! update_package_list; then
        return 1
    fi
    
    # Verificar cada categoria de dependências
    for category in "${!DEPENDENCIES[@]}"; do
        log "info" "Verificando dependências da categoria: $category"
        
        for pkg in ${DEPENDENCIES[$category]}; do
            if check_package "$pkg"; then
                INSTALLED_DEPS+=("$pkg")
                log "info" "  [✓] $pkg (já instalado)"
            else
                MISSING_DEPS+=("$pkg")
                ((missing_count++))
                log "warning" "  [ ] $pkg (não instalado)"
                
                # Instalar automaticamente se solicitado
                if [ "$INSTALL_MODE" = true ]; then
                    if install_package "$pkg"; then
                        INSTALLED_DEPS+=("$pkg")
                        MISSING_DEPS=("${MISSING_DEPS[@]/$pkg}")
                        ((missing_count--))
                    else
                        FAILED_DEPS+=("$pkg")
                    fi
                fi
            fi
        done
    done

    # Verificar CapRover CLI
    log "info" "Verificando dependência adicional: caprover CLI"
    if check_npm_package caprover && command -v caprover >/dev/null 2>&1; then
        INSTALLED_DEPS+=("caprover-cli")
        log "info" "  [✓] caprover-cli (já instalado)"
    else
        MISSING_DEPS+=("caprover-cli")
        ((missing_count++))
        log "warning" "  [ ] caprover-cli (não instalado)"
        if [ "$INSTALL_MODE" = true ]; then
            if install_npm_package caprover; then
                INSTALLED_DEPS+=("caprover-cli")
                MISSING_DEPS=("${MISSING_DEPS[@]/caprover-cli}")
                ((missing_count--))
            else
                FAILED_DEPS+=("caprover-cli")
            fi
        fi
    fi
    
    # Resumo
    log "info" "\n=== Resumo da Verificação de Dependências ==="
    log "info" "Total de pacotes verificados: ${#INSTALLED_DEPS[@]}"
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log "warning" "Pacotes ausentes (${#MISSING_DEPS[@]}):"
        for pkg in "${MISSING_DEPS[@]}"; do
            if [ -n "$pkg" ]; then
                log "warning" "  - $pkg"
            fi
        done
        
        if [ "$INSTALL_MODE" = false ]; then
            log "info" "\nExecute com '--install' para instalar automaticamente os pacotes ausentes"
        fi
    fi
    
    if [ ${#FAILED_DEPS[@]} -gt 0 ]; then
        log "error" "Falha ao instalar (${#FAILED_DEPS[@]}):"
        for pkg in "${FAILED_DEPS[@]}"; do
            log "error" "  - $pkg"
        done
        return 1
    fi
    
    if [ $missing_count -eq 0 ]; then
        log "success" "Todas as dependências estão instaladas"
        return 0
    else
        return 1
    fi
}

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo "Verifica e instala dependências necessárias para os scripts de segurança."
    echo
    echo "Opções:"
    echo "  --install   Instala automaticamente as dependências faltantes"
    echo "  --list      Apenas lista as dependências sem instalar"
    echo "  --help      Mostra esta mensagem de ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 --list           # Apenas verifica as dependências"
    echo "  $0 --install        # Instala as dependências faltantes"
    echo "  sudo $0 --install   # Executar como root para instalação"
}

#
# main
#
# Descrição:
#   Função principal do script.
#
main() {
    # Processar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --install)
                INSTALL_MODE=true
                shift
                ;;

            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log "error" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar sistema operacional
    if ! check_os; then
        exit 2
    fi
    
    # Verificar privilégios de root se for instalar
    if [ "$INSTALL_MODE" = true ] && ! check_root; then
        exit 1
    fi
    
    # Executar verificação de dependências
    if ! check_dependencies; then
        if [ "$INSTALL_MODE" = false ] && [ ${#MISSING_DEPS[@]} -gt 0 ]; then
            log "error" "Dependências ausentes. Execute com '--install' para instalar"
            exit 1
        elif [ ${#FAILED_DEPS[@]} -gt 0 ]; then
            log "error" "Falha ao instalar algumas dependências"
            exit 1
        fi
    fi
    
    exit 0
}

# Executar a função principal
main "$@"
