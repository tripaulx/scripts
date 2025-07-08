#!/bin/bash
#
# Nome do Arquivo: security_utils.sh
#
# Descrição:
#   Módulo de funções utilitárias para scripts de segurança.
#   Contém funções compartilhadas para logging, tratamento de erros e validações.
#
# Dependências:
#   - Bash 4.0+
#   - Comandos do sistema: date, tput, whoami
#
# Uso:
#   source "$(dirname "$0")/security_utils.sh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-06

# Cores para formatação
declare -r COLOR_RESET="\e[0m"
declare -r COLOR_RED="\e[31m"
declare -r COLOR_GREEN="\e[32m"
declare -r COLOR_YELLOW="\e[33m"
declare -r COLOR_BLUE="\e[34m"

# Níveis de log
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_WARN=2
declare -r LOG_LEVEL_ERROR=3

# Configuração padrão
declare -i LOG_LEVEL=${LOG_LEVEL_INFO}

#
# log
#
# Descrição:
#   Registra uma mensagem de log com nível de severidade.
#
# Parâmetros:
#   $1 - Nível (debug, info, warn, error)
#   $2 - Mensagem de log
#   $3 - Código de saída (opcional, para erros fatais)
#
log() {
    local level="$1"
    local message="$2"
    local exit_code="${3:-0}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Determinar cor e prefixo com base no nível
    case "${level}" in
        "debug")
            if [ ${LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]; then
                echo -e "${COLOR_BLUE}[${timestamp}] [DEBUG] ${message}${COLOR_RESET}"
            fi
            ;;
        "info")
            if [ ${LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]; then
                echo -e "${COLOR_GREEN}[${timestamp}] [INFO] ${message}${COLOR_RESET}"
            fi
            ;;
        "warn")
            if [ ${LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]; then
                echo -e "${COLOR_YELLOW}[${timestamp}] [WARN] ${message}${COLOR_RESET}" >&2
            fi
            ;;
        "error")
            if [ ${LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]; then
                echo -e "${COLOR_RED}[${timestamp}] [ERROR] ${message}${COLOR_RESET}" >&2
                if [ ${exit_code} -ne 0 ]; then
                    exit ${exit_code}
                fi
            fi
            ;;
        *)
            echo -e "${COLOR_RED}[${timestamp}] [ERROR] Nível de log inválido: ${level}${COLOR_RESET}" >&2
            return 1
            ;;
    esac
}

#
# validate_ip
#
# Descrição:
#   Valida um endereço IP no formato IPv4.
#
# Parâmetros:
#   $1 - Endereço IP a ser validado
#
# Retorno:
#   0 - IP válido
#   1 - IP inválido
#
validate_ip() {
    local ip="$1"
    local stat=1

    if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "${ip}"
        [[ ${octets[0]} -le 255 && ${octets[1]} -le 255 &&
           ${octets[2]} -le 255 && ${octets[3]} -le 255 ]]
        stat=$?
    fi
    
    return ${stat}
}

#
# validate_username
#
# Descrição:
#   Valida um nome de usuário do sistema.
#
# Parâmetros:
#   $1 - Nome de usuário a ser validado
#
# Retorno:
#   0 - Nome de usuário válido
#   1 - Nome de usuário inválido
#
validate_username() {
    local username="$1"
    
    # Verificar comprimento
    if [ ${#username} -lt 3 ] || [ ${#username} -gt 32 ]; then
        log "error" "Nome de usuário deve ter entre 3 e 32 caracteres."
        return 1
    fi
    
    # Verificar caracteres válidos (apenas letras, números, hífens e sublinhados)
    if [[ ! "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log "error" "Nome de usuário contém caracteres inválidos. Use apenas letras minúsculas, números, hífens e sublinhados."
        return 1
    fi
    
    # Verificar se o usuário já existe
    if id -u "${username}" &>/dev/null; then
        log "error" "O usuário '${username}' já existe."
        return 1
    fi
    
    return 0
}

#
# is_port_in_use
#
# Descrição:
#   Verifica se uma porta está em uso.
#
# Parâmetros:
#   $1 - Número da porta a ser verificada
#
# Retorno:
#   0 - Porta em uso
#   1 - Porta disponível
#
is_port_in_use() {
    local port="$1"
    
    # Verificar se a porta é um número
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        log "error" "Número de porta inválido: ${port}"
        return 2
    fi
    
    # Verificar se a porta está no intervalo válido
    if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
        log "error" "Número de porta fora do intervalo válido (1-65535): ${port}"
        return 2
    fi
    
    # Verificar se a porta está em uso
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":${port} "; then
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":${port} "; then
            return 0
        fi
    else
        log "warn" "Nem 'ss' nem 'netstat' encontrados. Usando lsof..."
        if command -v lsof &> /dev/null; then
            if lsof -i ":${port}" &> /dev/null; then
                return 0
            fi
        else
            log "error" "Nenhum comando disponível para verificar portas (ss/netstat/lsof)"
            return 2
        fi
    fi
    
    return 1
}

#
# run_cmd
#
# Descrição:
#   Executa um comando com tratamento de erros.
#
# Parâmetros:
#   $@ - Comando e argumentos a serem executados
#
# Retorno:
#   Código de saída do comando
#
run_cmd() {
    local cmd=("$@")
    local output
    local result
    
    # Executar o comando e capturar saída
    if output=$("${cmd[@]}" 2>&1); then
        log "debug" "Comando executado com sucesso: ${cmd[*]}"
        echo "${output}"
        return 0
    else
        result=$?
        log "error" "Falha ao executar o comando (${result}): ${cmd[*]}" "${result}"
        log "debug" "Saída do comando: ${output}"
        return ${result}
    fi
}

#
# check_root
#
# Descrição:
#   Verifica se o script está sendo executado como root.
#
# Retorno:
#   0 - Se for root
#   1 - Se não for root
#
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "error" "Este script deve ser executado como root." 1
        return 1
    fi
    return 0
}

#
# check_dependencies
#
# Descrição:
#   Verifica se as dependências necessárias estão instaladas.
#
# Parâmetros:
#   $@ - Lista de dependências a serem verificadas
#
# Retorno:
#   0 - Todas as dependências estão instaladas
#   1 - Uma ou mais dependências estão faltando
#
check_dependencies() {
    local missing=()
    local dep
    
    for dep in "$@"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "error" "As seguintes dependências não foram encontradas: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f log validate_ip validate_username is_port_in_use run_cmd check_root check_dependencies
