#!/bin/bash
# ===================================================================
# Arquivo: core/utils.sh
# Descrição: Funções utilitárias compartilhadas pelos scripts
# ===================================================================

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Nível de log (0=erro, 1=aviso, 2=info, 3=debug)
LOG_LEVEL=${LOG_LEVEL:-2}

# Função para registrar mensagens de log
log() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            if [ $LOG_LEVEL -ge 0 ]; then
                echo -e "[${RED}ERRO${NC}] $timestamp - $message"
            fi
            ;;
        "WARN")
            if [ $LOG_LEVEL -ge 1 ]; then
                echo -e "[${YELLOW}AVISO${NC}] $timestamp - $message"
            fi
            ;;
        "INFO")
            if [ $LOG_LEVEL -ge 2 ]; then
                echo -e "[${BLUE}INFO${NC}] $timestamp - $message"
            fi
            ;;
        "DEBUG")
            if [ $LOG_LEVEL -ge 3 ]; then
                echo -e "[${GREEN}DEBUG${NC}] $timestamp - $message"
            fi
            ;;
        *)
            echo -e "[${BLUE}INFO${NC}] $timestamp - $message"
            ;;
    esac
}

# Função para exibir mensagem de sucesso
success() {
    log "INFO" "✅ ${GREEN}$1${NC}"
}

# Função para exibir mensagem de aviso
warn() {
    log "WARN" "⚠️ ${YELLOW}$1${NC}"
}

# Função para exibir mensagem de erro e sair
error() {
    log "ERROR" "❌ ${RED}$1${NC}"
    exit 1
}

# Função para confirmar uma ação com o usuário
confirm_action() {
    local prompt=$1
    local default=${2:-n}  # Padrão para 'n' (não)
    local response
    
    # Se estiver no modo não interativo, retorna o valor padrão
    if [ "$NON_INTERACTIVE" = true ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    
    # Se a resposta padrão for 's', mostra [S/n], senão [s/N]
    if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
        prompt="$prompt [S/n] "
    else
        prompt="$prompt [s/N] "
    fi
    
    # Loop até receber uma resposta válida
    while true; do
        read -r -p "$prompt" response
        case $response in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            '' ) # Enter pressionado sem resposta
                if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
            * ) echo "Por favor, responda sim (s) ou não (n).";;
        esac
    done
}

# Função para executar comandos com tratamento de erro
run_cmd() {
    local cmd=$1
    local error_msg=${2:-"Falha ao executar o comando: $cmd"}
    
    log "DEBUG" "Executando: $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[SIMULAÇÃO] $cmd"
        return 0
    fi
    
    if ! eval "$cmd"; then
        error "$error_msg"
        return 1
    fi
    
    return 0
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para carregar um módulo
load_module() {
    local module=$1
    local module_path="./modules/$module/configure.sh"
    
    if [ -f "$module_path" ]; then
        log "DEBUG" "Carregando módulo: $module"
        # shellcheck source=/dev/null
        source "$module_path"
    else
        log "WARN" "Módulo não encontrado: $module"
        return 1
    fi
}

# Função para validar se o script está sendo executado como root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Este script deve ser executado como root. Use 'sudo $0' ou faça login como root."
    fi
}

# Função para validar endereço IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Função para validar nome de usuário
validate_username() {
    local username=$1
    
    # Verifica se o nome de usuário está vazio
    if [ -z "$username" ]; then
        return 1
    fi
    
    # Verifica se o nome de usuário começa com letra
    if ! [[ "$username" =~ ^[a-zA-Z] ]]; then
        return 1
    fi
    
    # Verifica se contém apenas letras, números, hífens e sublinhados
    if ! [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    # Verifica o comprimento (3-32 caracteres)
    local len=${#username}
    if [ "$len" -lt 3 ] || [ "$len" -gt 32 ]; then
        return 1
    fi
    
    return 0
}

# Função para verificar se uma porta está em uso
is_port_in_use() {
    local port=$1
    
    if command_exists lsof; then
        if lsof -i ":$port" -sTCP:LISTEN -t >/dev/null; then
            return 0
        fi
    elif command_exists netstat; then
        if netstat -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command_exists ss; then
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    fi
    
    return 1
}

# Função para gerar uma senha aleatória
generate_random_password() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9!@#$%^&*()_+?><~' </dev/urandom | head -c "$length"
}

# Função para carregar configurações do arquivo de configuração
load_config() {
    local config_file=${1:-'config.sh'}
    
    if [ -f "$config_file" ]; then
        log "DEBUG" "Carregando configurações de $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log "WARN" "Arquivo de configuração não encontrado: $config_file"
    fi
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f log success warn error confirm_action run_cmd command_exists
