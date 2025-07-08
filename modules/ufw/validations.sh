#!/bin/bash
# ===================================================================
# Módulo: UFW - Validações
# Arquivo: modules/ufw/validations.sh
# Descrição: Funções de validação para o UFW (Uncomplicated Firewall)
# ===================================================================

# Carregar funções do core
# shellcheck source=../../core/utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
# shellcheck source=../../core/validations.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/validations.sh"
# shellcheck source=../../core/security.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/security.sh"

# Variáveis de configuração
UFW_CONFIG_FILE="/etc/default/ufw"
UFW_SERVICE="ufw"
UFW_BEFORE_RULES_FILE="/etc/ufw/before.rules"
UFW_AFTER_RULES_FILE="/etc/ufw/after.rules"
UFW_USER_RULES_FILE="/etc/ufw/user.rules"

# Função para verificar se o UFW está instalado
check_ufw_installed() {
    if ! command -v ufw &>/dev/null; then
        log "ERROR" "O UFW (Uncomplicated Firewall) não está instalado."
        return 1
    fi
    
    log "INFO" "UFW (Uncomplicated Firewall) está instalado."
    return 0
}

# Função para verificar se o serviço UFW está em execução
check_ufw_service_running() {
    if ! systemctl is-active --quiet "$UFW_SERVICE"; then
        log "ERROR" "O serviço UFW não está em execução."
        return 1
    fi
    
    log "INFO" "Serviço UFW está em execução."
    return 0
}

# Função para verificar se o UFW está ativado
check_ufw_enabled() {
    if ! ufw status | grep -q "Status: active"; then
        log "ERROR" "O UFW não está ativado."
        return 1
    fi
    
    log "INFO" "UFW está ativado."
    return 0
}

# Função para verificar se o logging do UFW está ativado
check_ufw_logging_enabled() {
    if ! ufw status verbose | grep -q "Logging: on"; then
        log "WARN" "Logging do UFW está desabilitado (recomendado habilitar)."
        return 1
    fi
    
    log "INFO" "Logging do UFW está habilitado."
    return 0
}

# Função para verificar se a política padrão está configurada corretamente
check_ufw_default_policies() {
    local default_in
    local default_out
    
    # Obter políticas padrão
    default_in=$(ufw status verbose | grep "Default:" | grep -oP 'incoming \K\w+')
    default_out=$(ufw status verbose | grep "Default:" | grep -oP 'outgoing \K\w+')
    
    # Verificar política de entrada
    if [ "$default_in" != "deny" ] && [ "$default_in" != "reject" ]; then
        log "WARN" "Política padrão de entrada está como '$default_in' (recomendado: 'deny' ou 'reject')."
        return 1
    fi
    
    # Verificar política de saída
    if [ "$default_out" != "allow" ]; then
        log "WARN" "Política padrão de saída está como '$default_out' (recomendado: 'allow')."
        return 1
    fi
    
    log "INFO" "Políticas padrão do UFW configuradas corretamente (incoming: $default_in, outgoing: $default_out)."
    return 0
}

# Função para verificar se uma porta específica está aberta
check_port_open() {
    local port=$1
    local protocol=${2:-tcp}
    
    # Validar parâmetros
    if ! is_valid_port "$port"; then
        error "Número de porta inválido: $port"
        return 1
    }
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        return 1
    fi
    
    # Verificar se a porta está aberta
    if ufw status | grep -q "^${port}/${protocol}\s.*ALLOW"; then
        log "INFO" "Porta ${port}/${protocol} está aberta no UFW."
        return 0
    else
        log "WARN" "Porta ${port}/${protocol} não está aberta no UFW."
        return 1
    fi
}

# Função para verificar se uma porta específica está fechada
check_port_closed() {
    local port=$1
    local protocol=${2:-tcp}
    
    # Validar parâmetros
    if ! is_valid_port "$port"; then
        error "Número de porta inválido: $port"
        return 1
    }
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        return 1
    fi
    
    # Verificar se a porta está fechada
    if ufw status | grep -q "^${port}/${protocol}\s.*DENY"; then
        log "INFO" "Porta ${port}/${protocol} está explicitamente negada no UFW."
        return 0
    elif ! ufw status | grep -q "^${port}/${protocol}"; then
        log "INFO" "Porta ${port}/${protocol} não está nas regras do UFW (será bloqueada pela política padrão)."
        return 0
    else
        log "WARN" "Porta ${port}/${protocol} está aberta no UFW."
        return 1
    fi
}

# Função para verificar se um IP está na lista de permissões
check_ip_allowed() {
    local ip=$1
    local port=${2:-""}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        return 1
    fi
    
    # Verificar se o IP está na lista de permissões
    if [ -z "$port" ]; then
        # Verificar permissão geral do IP
        if ufw status | grep -q "^${ip}\s.*ALLOW"; then
            log "INFO" "IP ${ip} tem permissão total no UFW."
            return 0
        else
            log "WARN" "IP ${ip} não tem permissão total no UFW."
            return 1
        fi
    else
        # Verificar permissão do IP para uma porta específica
        if ufw status | grep -q "^${port}/.*\s${ip}\s.*ALLOW"; then
            log "INFO" "IP ${ip} tem permissão na porta ${port} no UFW."
            return 0
        else
            log "WARN" "IP ${ip} não tem permissão na porta ${port} no UFW."
            return 1
        fi
    fi
}

# Função para verificar se um IP está na lista de negação
check_ip_denied() {
    local ip=$1
    local port=${2:-""}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        return 1
    fi
    
    # Verificar se o IP está na lista de negação
    if [ -z "$port" ]; then
        # Verificar negação geral do IP
        if ufw status | grep -q "^${ip}\s.*DENY"; then
            log "INFO" "IP ${ip} está explicitamente negado no UFW."
            return 0
        else
            log "INFO" "IP ${ip} não está explicitamente negado no UFW."
            return 1
        fi
    else
        # Verificar negação do IP para uma porta específica
        if ufw status | grep -q "^${port}/.*\s${ip}\s.*DENY"; then
            log "INFO" "IP ${ip} está negado na porta ${port} no UFW."
            return 0
        else
            log "INFO" "IP ${ip} não está negado na porta ${port} no UFW."
            return 1
        fi
    fi
}

# Função para verificar se as regras de proteção contra força bruta estão configuradas
check_bruteforce_protection() {
    # Verificar se o UFW está instalado
    if ! check_ufw_installed; then
        return 1
    fi
    
    # Verificar se o arquivo de regras before.rules existe
    if [ ! -f "$UFW_BEFORE_RULES_FILE" ]; then
        log "WARN" "Arquivo de regras before.rules não encontrado."
        return 1
    fi
    
    # Verificar se as regras de proteção contra força bruta estão presentes
    if grep -q "ufw-http" "$UFW_BEFORE_RULES_FILE" && \
       grep -q "--update --seconds 60 --hitcount 4" "$UFW_BEFORE_RULES_FILE"; then
        log "INFO" "Proteção contra força bruta está configurada no UFW."
        return 0
    else
        log "WARN" "Proteção contra força bruta não está configurada no UFW."
        return 1
    fi
}

# Função para verificar se o UFW está configurado de forma segura
check_ufw_security() {
    local result=0
    
    log "INFO" "Verificando configurações de segurança do UFW..."
    
    # Verificar instalação do UFW
    if ! check_ufw_installed; then
        log "WARN" "O UFW (Uncomplicated Firewall) não está instalado."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_ufw_service_running; then
        log "WARN" "O serviço UFW não está em execução."
        result=1
    fi
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        log "WARN" "O UFW não está ativado."
        result=1
    else
        # Verificar políticas padrão
        if ! check_ufw_default_policies; then
            result=1
        fi
        
        # Verificar logging
        if ! check_ufw_logging_enabled; then
            result=1
        fi
        
        # Verificar proteção contra força bruta
        if ! check_bruteforce_protection; then
            log "INFO" "Recomendado configurar proteção contra força bruta no UFW."
        }
    fi
    
    if [ "$result" -eq 0 ]; then
        log "INFO" "Todas as verificações de segurança do UFW foram aprovadas."
    else
        log "WARN" "Algumas verificações de segurança do UFW falharam. Recomenda-se corrigi-las."
    fi
    
    return $result
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f check_ufw_security check_ufw_installed check_ufw_enabled check_port_open check_port_closed
