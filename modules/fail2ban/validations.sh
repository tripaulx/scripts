#!/bin/bash
# ===================================================================
# Módulo: Fail2Ban - Validações
# Arquivo: modules/fail2ban/validations.sh
# Descrição: Funções de validação para o Fail2Ban
# ===================================================================

# Carregar funções do core
# shellcheck source=../../core/utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
# shellcheck source=../../core/validations.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/validations.sh"
# shellcheck source=../../core/security.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/security.sh"

# Variáveis de configuração
FAIL2BAN_CONFIG_DIR="/etc/fail2ban"
FAIL2BAN_JAIL_LOCAL="${FAIL2BAN_CONFIG_DIR}/jail.local"
FAIL2BAN_JAIL_DEFAULT="${FAIL2BAN_CONFIG_DIR}/jail.d/defaults-debian.conf"
FAIL2BAN_FILTER_DIR="${FAIL2BAN_CONFIG_DIR}/filter.d"
FAIL2BAN_ACTION_DIR="${FAIL2BAN_CONFIG_DIR}/action.d"
FAIL2BAN_SERVICE="fail2ban"
FAIL2BAN_LOGFILE="/var/log/fail2ban.log"

# Função para verificar se o Fail2Ban está instalado
check_fail2ban_installed() {
    if ! command -v fail2ban-client &>/dev/null; then
        log "ERROR" "O Fail2Ban não está instalado."
        return 1
    fi
    
    log "INFO" "Fail2Ban está instalado."
    return 0
}

# Função para verificar se o serviço Fail2Ban está em execução
check_fail2ban_service_running() {
    if ! systemctl is-active --quiet "$FAIL2BAN_SERVICE"; then
        log "ERROR" "O serviço Fail2Ban não está em execução."
        return 1
    fi
    
    log "INFO" "Serviço Fail2Ban está em execução."
    return 0
}

# Função para verificar se o Fail2Ban está habilitado para inicialização automática
check_fail2ban_enabled() {
    if ! systemctl is-enabled --quiet "$FAIL2BAN_SERVICE" 2>/dev/null; then
        log "WARN" "O serviço Fail2Ban não está configurado para iniciar automaticamente."
        return 1
    fi
    
    log "INFO" "Serviço Fail2Ban está configurado para iniciar automaticamente."
    return 0
}

# Função para verificar se o arquivo de configuração local existe
check_fail2ban_config_exists() {
    if [ ! -f "$FAIL2BAN_JAIL_LOCAL" ]; then
        log "WARN" "Arquivo de configuração local do Fail2Ban não encontrado: $FAIL2BAN_JAIL_LOCAL"
        return 1
    fi
    
    log "INFO" "Arquivo de configuração local do Fail2Ban encontrado: $FAIL2BAN_JAIL_LOCAL"
    return 0
}

# Função para verificar as configurações de segurança do Fail2Ban
check_fail2ban_security_settings() {
    local result=0
    
    # Verificar se o arquivo de configuração existe
    if [ ! -f "$FAIL2BAN_JAIL_LOCAL" ]; then
        log "WARN" "Arquivo de configuração local do Fail2Ban não encontrado. Usando configurações padrão."
        return 1
    fi
    
    log "INFO" "Verificando configurações de segurança do Fail2Ban..."
    
    # Verificar ignoreip (IPs na whitelist)
    local ignore_ips
    ignore_ips=$(grep -i "^\s*ignoreip\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | cut -d'=' -f2- | sed 's/^[ \t]*//')
    
    if [ -z "$ignore_ips" ]; then
        log "WARN" "Nenhum IP na whitelist do Fail2Ban (ignoreip). Adicione IPs confiáveis."
        result=1
    else
        log "INFO" "IPs na whitelist do Fail2Ban: $ignore_ips"
    fi
    
    # Verificar bantime (tempo de banimento)
    local bantime
    bantime=$(grep -i "^\s*bantime\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[ \t]*//')
    
    if [ -z "$bantime" ]; then
        log "WARN" "Tempo de banimento (bantime) não configurado. Usando padrão do sistema."
    else
        log "INFO" "Tempo de banimento configurado: $bantime"
    fi
    
    # Verificar findtime (janela de tempo para contagem de tentativas)
    local findtime
    findtime=$(grep -i "^\s*findtime\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[ \t]*//')
    
    if [ -z "$findtime" ]; then
        log "WARN" "Janela de tempo para contagem de tentativas (findtime) não configurada. Usando padrão do sistema."
    else
        log "INFO" "Janela de tempo para contagem de tentativas: $findtime"
    fi
    
    # Verificar maxretry (número máximo de tentativas antes do banimento)
    local maxretry
    maxretry=$(grep -i "^\s*maxretry\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[ \t]*//')
    
    if [ -z "$maxretry" ]; then
        log "WARN" "Número máximo de tentativas (maxretry) não configurado. Usando padrão do sistema."
    else
        log "INFO" "Número máximo de tentativas antes do banimento: $maxretry"
    fi
    
    # Verificar se o serviço SSH está configurado
    if ! grep -q '^\[sshd\]' "$FAIL2BAN_JAIL_LOCAL"; then
        log "WARN" "Proteção SSH não configurada no Fail2Ban. Recomendado habilitar."
        result=1
    else
        log "INFO" "Proteção SSH está configurada no Fail2Ban."
    fi
    
    # Verificar se o serviço recidive está configurado (para banir reincidentes)
    if ! grep -q '^\[recidive\]' "$FAIL2BAN_JAIL_LOCAL"; then
        log "INFO" "Proteção contra reincidentes (recidive) não configurada. Considere habilitar para maior segurança."
    else
        log "INFO" "Proteção contra reincidentes (recidive) está configurada."
    fi
    
    # Verificar se o log está habilitado
    local loglevel
    loglevel=$(grep -i "^\s*loglevel\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[ \t]*//')
    
    if [ -z "$loglevel" ] || [ "$loglevel" = "ERROR" ] || [ "$loglevel" = "CRITICAL" ]; then
        log "WARN" "Nível de log do Fail2Ban está configurado como '$loglevel'. Considere usar 'INFO' para melhor monitoramento."
        result=1
    else
        log "INFO" "Nível de log do Fail2Ban: $loglevel"
    fi
    
    if [ "$result" -eq 0 ]; then
        log "INFO" "Todas as verificações de segurança do Fail2Ban foram aprovadas."
    else
        log "WARN" "Algumas verificações de segurança do Fail2Ban falharam. Considere revisar as configurações."
    fi
    
    return $result
}

# Função para verificar se um serviço específico está protegido pelo Fail2Ban
check_service_protected() {
    local service=$1
    
    if [ -z "$service" ]; then
        error "Nome do serviço não fornecido."
        return 1
    fi
    
    # Verificar se o serviço está na lista de jails ativos
    if fail2ban-client status | grep -q "$service"; then
        log "INFO" "Serviço '$service' está protegido pelo Fail2Ban."
        return 0
    else
        log "WARN" "Serviço '$service' NÃO está protegido pelo Fail2Ban."
        return 1
    fi
}

# Função para verificar se um IP específico está na whitelist do Fail2Ban
check_ip_in_whitelist() {
    local ip=$1
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Verificar se o IP está na whitelist
    if grep -q "^\s*ignoreip\s*=\s*.*\b${ip}\b" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null; then
        log "INFO" "O IP $ip está na whitelist do Fail2Ban."
        return 0
    else
        log "WARN" "O IP $ip NÃO está na whitelist do Fail2Ban."
        return 1
    fi
}

# Função para verificar se um IP está atualmente banido
check_ip_banned() {
    local ip=$1
    local service=${2:-""}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Se o serviço for especificado, verificar apenas naquele serviço
    if [ -n "$service" ]; then
        if fail2ban-client status "$service" | grep -q "$ip"; then
            log "INFO" "O IP $ip está banido no serviço $service."
            return 0
        else
            log "INFO" "O IP $ip NÃO está banido no serviço $service."
            return 1
        fi
    fi
    
    # Verificar em todos os serviços
    local services
    services=$(fail2ban-client status | grep -i 'Jail list' | sed 's/^[^:]*://' | tr ',' ' ' | xargs)
    
    if [ -z "$services" ]; then
        log "WARN" "Nenhum serviço ativo encontrado no Fail2Ban."
        return 1
    fi
    
    local banned_in=()
    
    for s in $services; do
        if fail2ban-client status "$s" 2>/dev/null | grep -q "$ip"; then
            banned_in+=("$s")
        fi
    done
    
    if [ ${#banned_in[@]} -gt 0 ]; then
        log "INFO" "O IP $ip está banido nos seguintes serviços: ${banned_in[*]}"
        return 0
    else
        log "INFO" "O IP $ip NÃO está banido em nenhum serviço do Fail2Ban."
        return 1
    fi
}

# Função para verificar se o Fail2Ban está configurado de forma segura
check_fail2ban_security() {
    local result=0
    
    log "INFO" "Verificando configurações de segurança do Fail2Ban..."
    
    # Verificar instalação do Fail2Ban
    if ! check_fail2ban_installed; then
        log "WARN" "O Fail2Ban não está instalado."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_fail2ban_service_running; then
        log "WARN" "O serviço Fail2Ban não está em execução."
        result=1
    fi
    
    # Verificar se está configurado para iniciar automaticamente
    if ! check_fail2ban_enabled; then
        log "WARN" "O serviço Fail2Ban não está configurado para iniciar automaticamente."
        result=1
    fi
    
    # Verificar configurações de segurança
    if ! check_fail2ban_security_settings; then
        result=1
    }
    
    # Verificar se os serviços críticos estão protegidos
    local critical_services=("sshd" "recidive")
    
    for service in "${critical_services[@]}"; do
        if ! check_service_protected "$service"; then
            result=1
        fi
    done
    
    if [ "$result" -eq 0 ]; then
        log "INFO" "Todas as verificações de segurança do Fail2Ban foram aprovadas."
    else
        log "WARN" "Algumas verificações de segurança do Fail2Ban falharam. Recomenda-se corrigi-las."
    fi
    
    return $result
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f check_fail2ban_security check_fail2ban_installed check_fail2ban_service_running check_service_protected
