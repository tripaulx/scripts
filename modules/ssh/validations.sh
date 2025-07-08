#!/bin/bash
# ===================================================================
# Módulo: SSH - Validações
# Arquivo: modules/ssh/validations.sh
# Descrição: Funções de validação para o servidor SSH
# ===================================================================

# Carregar funções do core
# Carregar utilitários padronizados
if [ -f "$(dirname "${BASH_SOURCE[0]}")/../../../src/security/core/security_utils.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../../src/security/core/security_utils.sh"
else
    echo "[CI][ERRO] Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

if [ -f "$(dirname "${BASH_SOURCE[0]}")/../../../src/security/modules/ssh/ssh_utils.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../../../src/security/modules/ssh/ssh_utils.sh"
fi

# Variáveis de configuração
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_SERVICE="sshd"

# Função para verificar se o SSH está instalado
check_ssh_installed() {
    if ! command -v sshd &>/dev/null; then
        log "ERROR" "O servidor OpenSSH não está instalado."
        return 1
    fi
    
    log "INFO" "OpenSSH está instalado."
    return 0
}

# Função para verificar se o serviço SSH está em execução
check_ssh_service_running() {
    if ! systemctl is-active --quiet "$SSH_SERVICE"; then
        log "ERROR" "O serviço SSH não está em execução."
        return 1
    fi
    
    log "INFO" "Serviço SSH está em execução."
    return 0
}

# Função para verificar a porta SSH atual
get_current_ssh_port() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local port
    port=$(grep -i "^\s*Port\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    
    if [ -z "$port" ]; then
        # Se não encontrar a diretiva Port, usar a porta padrão (22)
        port=22
    fi
    
    echo "$port"
    return 0
}

# Função para verificar se o login root está desabilitado
check_root_login_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local permit_root
    permit_root=$(grep -i "^\s*PermitRootLogin\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$permit_root" ] || [ "$permit_root" = "yes" ] || [ "$permit_root" = "prohibit-password" ]; then
        log "WARN" "Login root via SSH está habilitado (PermitRootLogin: ${permit_root:-yes})"
        return 1
    fi
    
    log "INFO" "Login root via SSH está desabilitado."
    return 0
}

# Função para verificar se a autenticação por senha está desabilitada
check_password_auth_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local password_auth
    password_auth=$(grep -i "^\s*PasswordAuthentication\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$password_auth" ] || [ "$password_auth" = "yes" ]; then
        log "WARN" "Autenticação por senha está habilitada (PasswordAuthentication: ${password_auth:-yes})"
        return 1
    fi
    
    log "INFO" "Autenticação por senha está desabilitada."
    return 0
}

# Função para verificar se a autenticação por chave pública está habilitada
check_public_key_auth_enabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local pubkey_auth
    pubkey_auth=$(grep -i "^\s*PubkeyAuthentication\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$pubkey_auth" ] || [ "$pubkey_auth" = "yes" ]; then
        log "INFO" "Autenticação por chave pública está habilitada (PubkeyAuthentication: ${pubkey_auth:-yes})"
        return 0
    fi
    
    log "WARN" "Autenticação por chave pública está desabilitada (PubkeyAuthentication: $pubkey_auth)"
    return 1
}

# Função para verificar se o protocolo 1 está desabilitado
check_ssh_protocol_v1_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local protocol
    protocol=$(grep -i "^\s*Protocol\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [[ "$protocol" == *"1"* ]]; then
        log "WARN" "Protocolo SSH 1 está habilitado (Protocol: $protocol)"
        return 1
    fi
    
    log "INFO" "Protocolo SSH 1 está desabilitado."
    return 0
}

# Função para verificar se o X11Forwarding está desabilitado
check_x11_forwarding_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local x11_forwarding
    x11_forwarding=$(grep -i "^\s*X11Forwarding\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$x11_forwarding" ] || [ "$x11_forwarding" = "yes" ]; then
        log "WARN" "X11Forwarding está habilitado (X11Forwarding: ${x11_forwarding:-yes})"
        return 1
    fi
    
    log "INFO" "X11Forwarding está desabilitado."
    return 0
}

# Função para verificar se o encaminhamento de porta TCP está desabilitado
check_tcp_forwarding_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local tcp_forwarding
    tcp_forwarding=$(grep -i "^\s*AllowTcpForwarding\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$tcp_forwarding" ] || [ "$tcp_forwarding" = "yes" ]; then
        log "WARN" "Encaminhamento de porta TCP está habilitado (AllowTcpForwarding: ${tcp_forwarding:-yes})"
        return 1
    fi
    
    log "INFO" "Encaminhamento de porta TCP está desabilitado."
    return 0
}

# Função para verificar se o encaminhamento de agente está desabilitado
check_agent_forwarding_disabled() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local agent_forwarding
    agent_forwarding=$(grep -i "^\s*AllowAgentForwarding\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$agent_forwarding" ] || [ "$agent_forwarding" = "yes" ]; then
        log "WARN" "Encaminhamento de agente está habilitado (AllowAgentForwarding: ${agent_forwarding:-yes})"
        return 1
    fi
    
    log "INFO" "Encaminhamento de agente está desabilitado."
    return 0
}

# Função para verificar se o banner está configurado
check_ssh_banner() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local banner
    banner=$(grep -i "^\s*Banner\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$banner" ]; then
        log "WARN" "Banner do SSH não está configurado."
        return 1
    fi
    
    if [ ! -f "$banner" ]; then
        log "WARN" "Arquivo de banner configurado não encontrado: $banner"
        return 1
    fi
    
    log "INFO" "Banner do SSH está configurado corretamente: $banner"
    return 0
}

# Função para verificar se o MaxAuthTries está configurado corretamente
check_max_auth_tries() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local max_auth_tries
    max_auth_tries=$(grep -i "^\s*MaxAuthTries\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$max_auth_tries" ] || [ "$max_auth_tries" -gt 3 ]; then
        log "WARN" "MaxAuthTries está muito alto ou não configurado (MaxAuthTries: ${max_auth_tries:-6})"
        return 1
    fi
    
    log "INFO" "MaxAuthTries está configurado corretamente: $max_auth_tries"
    return 0
}

# Função para verificar se o LoginGraceTime está configurado corretamente
check_login_grace_time() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local login_grace_time
    login_grace_time=$(grep -i "^\s*LoginGraceTime\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$login_grace_time" ] || [ "${login_grace_time%?}" -gt 60 ]; then
        log "WARN" "LoginGraceTime está muito alto ou não configurado (LoginGraceTime: ${login_grace_time:-120s})"
        return 1
    fi
    
    log "INFO" "LoginGraceTime está configurado corretamente: $login_grace_time"
    return 0
}

# Função para verificar se o ClientAliveInterval está configurado corretamente
check_client_alive_interval() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local client_alive_interval
    client_alive_interval=$(grep -i "^\s*ClientAliveInterval\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$client_alive_interval" ] || [ "$client_alive_interval" -gt 300 ]; then
        log "WARN" "ClientAliveInterval está muito alto ou não configurado (ClientAliveInterval: ${client_alive_interval:-0})"
        return 1
    fi
    
    log "INFO" "ClientAliveInterval está configurado corretamente: $client_alive_interval"
    return 0
}

# Função para verificar se o ClientAliveCountMax está configurado corretamente
check_client_alive_count_max() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local client_alive_count_max
    client_alive_count_max=$(grep -i "^\s*ClientAliveCountMax\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$client_alive_count_max" ] || [ "$client_alive_count_max" -gt 3 ]; then
        log "WARN" "ClientAliveCountMax está muito alto ou não configurado (ClientAliveCountMax: ${client_alive_count_max:-3})"
        return 1
    fi
    
    log "INFO" "ClientAliveCountMax está configurado corretamente: $client_alive_count_max"
    return 0
}

# Função para verificar se o MaxStartups está configurado corretamente
check_max_startups() {
    if [ ! -f "$SSH_CONFIG_FILE" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $SSH_CONFIG_FILE"
        return 1
    fi
    
    local max_startups
    max_startups=$(grep -i "^\s*MaxStartups\s" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d ' ')
    
    if [ -z "$max_startups" ] || [ "${max_startups%%:*}" -gt 10 ]; then
        log "WARN" "MaxStartups está muito alto ou não configurado (MaxStartups: ${max_startups:-10:30:100})"
        return 1
    fi
    
    log "INFO" "MaxStartups está configurado corretamente: $max_startups"
    return 0
}

# Função para verificar se o SSH está configurado de forma segura
check_ssh_security() {
    local result=0
    
    log "INFO" "Verificando configurações de segurança do SSH..."
    
    # Verificar instalação do SSH
    if ! check_ssh_installed; then
        result=1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_ssh_service_running; then
        result=1
    fi
    
    # Verificar configurações de segurança
    if ! check_root_login_disabled; then
        result=1
    fi
    
    if ! check_password_auth_disabled; then
        result=1
    fi
    
    if ! check_public_key_auth_enabled; then
        result=1
    fi
    
    if ! check_ssh_protocol_v1_disabled; then
        result=1
    fi
    
    if ! check_x11_forwarding_disabled; then
        result=1
    fi
    
    if ! check_tcp_forwarding_disabled; then
        result=1
    fi
    
    if ! check_agent_forwarding_disabled; then
        result=1
    fi
    
    if ! check_ssh_banner; then
        result=1
    fi
    
    if ! check_max_auth_tries; then
        result=1
    fi
    
    if ! check_login_grace_time; then
        result=1
    fi
    
    if ! check_client_alive_interval; then
        result=1
    fi
    
    if ! check_client_alive_count_max; then
        result=1
    fi
    
    if ! check_max_startups; then
        result=1
    fi
    
    if [ "$result" -eq 0 ]; then
        log "INFO" "Todas as verificações de segurança do SSH foram aprovadas."
    else
        log "WARN" "Algumas verificações de segurança do SSH falharam. Recomenda-se corrigi-las."
    fi
    
    return $result
}

# Função para verificar se um usuário tem chaves SSH configuradas
check_user_ssh_keys() {
    local username=$1
    
    # Validar parâmetro
    if [ -z "$username" ]; then
        error "Nome de usuário é obrigatório."
        return 1
    fi
    
    # Verificar se o usuário existe
    if ! id "$username" &>/dev/null; then
        error "O usuário $username não existe."
        return 1
    fi
    
    # Obter o diretório home do usuário
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    local auth_keys="$user_home/.ssh/authorized_keys"
    
    # Verificar se o arquivo authorized_keys existe
    if [ ! -f "$auth_keys" ]; then
        log "WARN" "Nenhuma chave SSH configurada para o usuário $username."
        return 1
    fi
    
    # Contar o número de chaves
    local key_count
    key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null)
    
    if [ "$key_count" -eq 0 ]; then
        log "WARN" "Nenhuma chave SSH válida encontrada para o usuário $username."
        return 1
    fi
    
    log "INFO" "$key_count chave(s) SSH configurada(s) para o usuário $username."
    return 0
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f check_ssh_security check_user_ssh_keys
