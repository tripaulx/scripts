#!/bin/bash
#
# Nome do Arquivo: init_environment.sh
#
# Descrição:
#   Script de inicialização do ambiente de segurança.
#   Verifica e configura o ambiente antes da execução dos scripts principais.
#
# Dependências:
#   - Bash 4.0+
#   - Comandos básicos do sistema (ls, grep, awk, etc.)
#
# Exit codes:
#   0 - Ambiente inicializado com sucesso
#   1 - Falha na verificação de pré-requisitos
#   2 - Sistema operacional não suportado
#   3 - Falha na configuração do ambiente
#
# Uso:
#   source init_environment.sh [--verbose] [--force]
#
# Opções:
#   --verbose  Exibe informações detalhadas durante a execução
#   --force    Força a execução mesmo com avisos
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

set -euo pipefail

# Cores para formatação
readonly COLOR_RESET="\e[0m"
readonly COLOR_RED="\e[31m"
readonly COLOR_GREEN="\e[32m"
readonly COLOR_YELLOW="\e[33m"


# Variáveis de controle
VERBOSE=false
FORCE=false
HAS_WARNINGS=false
HAS_ERRORS=false

# Caminhos importantes
readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/security_setup"
readonly CACHE_DIR="/var/cache/security_setup"

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
        debug)
            ${VERBOSE} && echo -e "[${timestamp}] [DEBUG] ${message}" >&2
            ;;
        info)
            echo -e "[${timestamp}] [INFO] ${message}"
            ;;
        success)
            echo -e "[${timestamp}] ${COLOR_GREEN}[SUCCESS]${COLOR_RESET} ${message}"
            ;;
        warning)
            echo -e "[${timestamp}] ${COLOR_YELLOW}[WARNING]${COLOR_RESET} ${message}" >&2
            HAS_WARNINGS=true
            ;;
        error)
            echo -e "[${timestamp}] ${COLOR_RED}[ERROR]${COLOR_RESET} ${message}" >&2
            HAS_ERRORS=true
            ;;
        *)
            echo -e "[${timestamp}] [${level^^}] ${message}" >&2
            ;;
    esac
}

#
# check_os
#
# Descrição:
#   Verifica se o sistema operacional é suportado.
#
check_os() {
    log "info" "Verificando sistema operacional..."
    
    if [ ! -f "/etc/os-release" ]; then
        log "error" "Não foi possível detectar o sistema operacional"
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    
    if [[ "$ID" != "debian" && "$ID_LIKE" != *"debian"* ]]; then
        log "error" "Este script é compatível apenas com sistemas baseados em Debian"
        log "info" "Sistema detectado: $PRETTY_NAME"
        return 1
    fi
    
    log "success" "Sistema operacional suportado: $PRETTY_NAME"
    return 0
}

#
# check_dependencies
#
# Descrição:
#   Verifica as dependências básicas do sistema.
#
check_dependencies() {
    log "info" "Verificando dependências do sistema..."
    
    local -a required_commands=(
        "bash" "grep" "awk" "sed" "cut" "tr"
        "mkdir" "rm" "cp" "mv" "chmod" "chown"
        "id" "whoami" "sudo" "curl" "wget"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log "warning" "Comando não encontrado: ${cmd}"
            missing_commands+=("${cmd}")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log "error" "Faltam comandos essenciais: ${missing_commands[*]}"
        log "info" "Execute 'apt-get update && apt-get install -y ${missing_commands[*]}' para instalar"
        return 1
    fi
    
    log "success" "Todas as dependências básicas estão instaladas"
    return 0
}

#
# setup_directories
#
# Descrição:
#   Cria os diretórios necessários para o funcionamento dos scripts.
#
setup_directories() {
    log "info" "Configurando diretórios..."
    
    local -a required_dirs=(
        "${LOG_DIR}"
        "${CACHE_DIR}"
        "${SCRIPT_DIR}/backups"
        "${SCRIPT_DIR}/tmp"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${dir}" ]; then
            if ! mkdir -p "${dir}"; then
                log "error" "Falha ao criar diretório: ${dir}"
                return 1
            fi
            log "debug" "Diretório criado: ${dir}"
        fi
    done
    
    # Definir permissões seguras
    chmod 750 "${LOG_DIR}" "${CACHE_DIR}" "${SCRIPT_DIR}/backups"
    
    log "success" "Diretórios configurados com sucesso"
    return 0
}

#
# check_privileges
#
# Descrição:
#   Verifica se o script está sendo executado com privilégios suficientes.
#
check_privileges() {
    log "info" "Verificando privilégios..."
    
    if [ "$(id -u)" -ne 0 ]; then
        log "warning" "Este script deve ser executado como root"
        log "info" "Execute com 'sudo' ou como usuário root"
        
        if [ "${FORCE}" = false ]; then
            log "error" "Execução interrompida por falta de privilégios"
            return 1
        else
            log "warning" "Continuando apesar da falta de privilégios (--force ativado)"
        fi
    else
        log "success" "Privilégios de root confirmados"
    fi
    
    return 0
}

#
# parse_arguments
#
# Descrição:
#   Processa os argumentos da linha de comando.
#
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --force|-f)
                FORCE=true
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
}

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo "Inicializa o ambiente para execução dos scripts de segurança."
    echo
    echo "Opções:"
    echo "  -v, --verbose  Exibe informações detalhadas durante a execução"
    echo "  -f, --force    Força a execução mesmo com avisos"
    echo "  -h, --help     Exibe esta ajuda"
    echo
    echo "Exemplos:"
    echo "  # Inicialização normal"
    echo "  source $0"
    echo
    echo "  # Modo verboso"
    echo "  source $0 --verbose"
    echo
    echo "  # Forçar execução apesar de avisos"
    echo "  source $0 --force"
    echo
    echo "Para mais informações, consulte a documentação em docs/."
}

#
# main
#
# Descrição:
#   Função principal do script.
#
main() {
    # Processar argumentos
    parse_arguments "$@"
    
    log "info" "Iniciando inicialização do ambiente de segurança"
    
    # Verificar sistema operacional
    if ! check_os; then
        log "error" "Sistema operacional não suportado"
        return 2
    fi
    
    # Verificar privilégios
    if ! check_privileges; then
        return 3
    fi
    
    # Verificar dependências
    if ! check_dependencies; then
        if [ "${FORCE}" = false ]; then
            log "error" "Dependências não atendidas"
            return 3
        else
            log "warning" "Continuando apesar de dependências não atendidas (--force ativado)"
        fi
    fi
    
    # Configurar diretórios
    if ! setup_directories; then
        log "error" "Falha na configuração dos diretórios"
        return 3
    fi
    
    # Resumo da inicialização
    log "info" "\n=== Resumo da Inicialização ==="
    
    if [ "${HAS_ERRORS}" = true ]; then
        log "error" "Falha na inicialização do ambiente"
        return 1
    elif [ "${HAS_WARNINGS}" = true ]; then
        if [ "${FORCE}" = true ]; then
            log "warning" "Inicialização concluída com avisos (--force ativado)"
            return 0
        else
            log "error" "Inicialização interrompida devido a avisos"
            log "info" "Use --force para continuar apesar dos avisos"
            return 1
        fi
    else
        log "success" "Ambiente inicializado com sucesso"
        return 0
    fi
}

# Executar a função principal
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    # Script sendo executado diretamente
    main "$@"
    exit $?
else
    # Script sendo carregado com 'source'
    log "debug" "Script carregado com 'source', executando inicialização..."
    if ! main "$@"; then
        log "error" "Falha na inicialização do ambiente"
        return 1
    fi
    
    # Exportar variáveis de ambiente
    export SECURITY_SCRIPT_DIR="${SCRIPT_DIR}"
    export SECURITY_LOG_DIR="${LOG_DIR}"
    export SECURITY_CACHE_DIR="${CACHE_DIR}"
    
    # Adicionar diretório de binários ao PATH se não estiver presente
    if [[ ":${PATH}:" != *":${SCRIPT_DIR}/bin:"* ]]; then
        export PATH="${SCRIPT_DIR}/bin:${PATH}"
    fi
    
    log "debug" "Variáveis de ambiente configuradas"
    return 0
fi
