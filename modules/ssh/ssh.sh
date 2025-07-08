#!/bin/bash
# ===================================================================
# Módulo: SSH
# Arquivo: modules/ssh/ssh.sh
# Descrição: Módulo para gerenciar a configuração e segurança do SSH
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
SSH_BAK_FILE="$SSH_CONFIG_FILE.bak"
SSH_BANNER_FILE="/etc/issue.net"
DEFAULT_SSH_PORT=22

# Função para instalar o servidor SSH
install_ssh() {
    log "INFO" "Verificando instalação do servidor SSH..."
    
    if ! check_ssh_installed; then
        log "INFO" "Instalando o servidor OpenSSH..."
        
        if ! run_command "apt-get update" "Atualizando lista de pacotes" || \
           ! run_command "apt-get install -y openssh-server" "Instalando o servidor OpenSSH"; then
            error "Falha ao instalar o servidor OpenSSH."
            return 1
        fi
        
        log "SUCCESS" "Servidor OpenSSH instalado com sucesso."
    else
        log "INFO" "Servidor OpenSSH já está instalado."
    fi
    
    return 0
}

# Função para configurar a porta SSH
configure_ssh_port() {
    local new_port=$1
    
    # Validar a porta
    if ! is_valid_port "$new_port"; then
        error "Porta SSH inválida: $new_port"
        return 1
    fi
    
    log "INFO" "Configurando a porta SSH para $new_port..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Configurar a nova porta
    if ! update_config_file "$SSH_CONFIG_FILE" "^\s*Port\s" "Port $new_port"; then
        error "Falha ao configurar a porta SSH."
        return 1
    fi
    
    log "SUCCESS" "Porta SSH configurada para $new_port."
    return 0
}

# Função para desabilitar o login root via SSH
disable_root_login() {
    log "INFO" "Desabilitando login root via SSH..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Desabilitar login root
    if ! update_config_file "$SSH_CONFIG_FILE" "^\s*PermitRootLogin\s" "PermitRootLogin no"; then
        error "Falha ao desabilitar o login root via SSH."
        return 1
    fi
    
    log "SUCCESS" "Login root via SSH desabilitado com sucesso."
    return 0
}

# Função para desabilitar a autenticação por senha
disable_password_auth() {
    log "INFO" "Desabilitando autenticação por senha no SSH..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Desabilitar autenticação por senha
    if ! update_config_file "$SSH_CONFIG_FILE" "^\s*PasswordAuthentication\s" "PasswordAuthentication no" || \
       ! update_config_file "$SSH_CONFIG_FILE" "^\s*ChallengeResponseAuthentication\s" "ChallengeResponseAuthentication no" || \
       ! update_config_file "$SSH_CONFIG_FILE" "^\s*UsePAM\s" "UsePAM no"; then
        error "Falha ao desabilitar a autenticação por senha no SSH."
        return 1
    fi
    
    log "SUCCESS" "Autenticação por senha no SSH desabilitada com sucesso."
    return 0
}

# Função para habilitar a autenticação por chave pública
enable_public_key_auth() {
    log "INFO" "Habilitando autenticação por chave pública no SSH..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Habilitar autenticação por chave pública
    if ! update_config_file "$SSH_CONFIG_FILE" "^\s*PubkeyAuthentication\s" "PubkeyAuthentication yes"; then
        error "Falha ao habilitar a autenticação por chave pública no SSH."
        return 1
    fi
    
    log "SUCCESS" "Autenticação por chave pública no SSH habilitada com sucesso."
    return 0
}

# Função para configurar o banner do SSH
setup_ssh_banner() {
    local banner_content
    banner_content="\n==================================================\n\tAcesso Autorizado Apenas\n\tData: $(date +"%d/%m/%Y %H:%M:%S")\n==================================================\n\nAviso de Segurança:\nEste é um sistema de computador privado. O acesso não autorizado é proibido por lei.\nTodas as atividades neste sistema são monitoradas e registradas.\n"
    
    log "INFO" "Configurando banner do SSH..."
    
    # Criar o arquivo de banner
    if ! echo -e "$banner_content" > "$SSH_BANNER_FILE"; then
        error "Falha ao criar o arquivo de banner do SSH."
        return 1
    fi
    
    # Definir permissões seguras
    if ! chmod 644 "$SSH_BANNER_FILE" || ! chown root:root "$SSH_BANNER_FILE"; then
        error "Falha ao definir permissões no arquivo de banner do SSH."
        return 1
    fi
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Configurar o banner no SSH
    if ! update_config_file "$SSH_CONFIG_FILE" "^\s*Banner\s" "Banner $SSH_BANNER_FILE"; then
        error "Falha ao configurar o banner no SSH."
        return 1
    fi
    
    log "SUCCESS" "Banner do SSH configurado com sucesso em $SSH_BANNER_FILE."
    return 0
}

# Função para configurar parâmetros de segurança avançados
configure_ssh_security_params() {
    log "INFO" "Configurando parâmetros avançados de segurança do SSH..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Configurar parâmetros de segurança
    local params=(
        "Protocol 2"
        "X11Forwarding no"
        "AllowTcpForwarding no"
        "AllowAgentForwarding no"
        "MaxAuthTries 3"
        "LoginGraceTime 60"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
        "MaxStartups 10:30:60"
        "TCPKeepAlive no"
        "UsePrivilegeSeparation sandbox"
        "Compression no"
        "PermitTunnel no"
        "AllowUsers"
    )
    
    # Aplicar cada parâmetro
    for param in "${params[@]}"; do
        local key="${param%% *}"
        if ! update_config_file "$SSH_CONFIG_FILE" "^\s*${key}\s" "$param"; then
            log "WARN" "Falha ao configurar o parâmetro: $key"
        fi
    done
    
    log "SUCCESS" "Parâmetros avançados de segurança do SSH configurados com sucesso."
    return 0
}

# Função para adicionar um usuário à lista de usuários permitidos
add_allowed_user() {
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
    
    log "INFO" "Adicionando usuário $username à lista de usuários permitidos no SSH..."
    
    # Fazer backup do arquivo de configuração atual
    if ! backup_file "$SSH_CONFIG_FILE" "$SSH_BAK_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Obter a lista atual de usuários permitidos
    local allowed_users
    allowed_users=$(grep -i "^\s*AllowUsers\s" "$SSH_CONFIG_FILE" 2>/dev/null | cut -d' ' -f2-)
    
    # Verificar se o usuário já está na lista
    if echo "$allowed_users" | grep -q "\b$username\b"; then
        log "INFO" "O usuário $username já está na lista de usuários permitidos."
        return 0
    fi
    
    # Adicionar o usuário à lista
    if [ -z "$allowed_users" ]; then
        # Se não houver usuários na lista, adicionar o AllowUsers
        if ! echo "AllowUsers $username" >> "$SSH_CONFIG_FILE"; then
            error "Falha ao adicionar o usuário $username à lista de usuários permitidos."
            return 1
        fi
    else
        # Se já houver usuários na lista, adicionar o novo usuário
        if ! sed -i "s/^\s*AllowUsers\s.*/& $username/" "$SSH_CONFIG_FILE"; then
            error "Falha ao adicionar o usuário $username à lista de usuários permitidos."
            return 1
        fi
    fi
    
    log "SUCCESS" "Usuário $username adicionado à lista de usuários permitidos no SSH."
    return 0
}

# Função para reiniciar o serviço SSH
restart_ssh_service() {
    local current_port
    current_port=$(get_current_ssh_port)
    
    log "INFO" "Reiniciando o serviço SSH (porta atual: $current_port)..."
    
    # Verificar se o serviço está em execução
    if ! systemctl is-active --quiet "$SSH_SERVICE"; then
        log "WARN" "O serviço SSH não está em execução. Iniciando..."
        if ! run_command "systemctl start $SSH_SERVICE" "Iniciando o serviço SSH"; then
            error "Falha ao iniciar o serviço SSH."
            return 1
        fi
    else
        # Reiniciar o serviço
        if ! run_command "systemctl restart $SSH_SERVICE" "Reiniciando o serviço SSH"; then
            error "Falha ao reiniciar o serviço SSH."
            return 1
        fi
    fi
    
    # Verificar se o serviço está em execução após a reinicialização
    if ! systemctl is-active --quiet "$SSH_SERVICE"; then
        error "O serviço SSH não está em execução após a reinicialização."
        return 1
    fi
    
    log "SUCCESS" "Serviço SSH reiniciado com sucesso na porta $current_port."
    return 0
}

# Função para configurar o SSH com as melhores práticas de segurança
secure_ssh() {
    local new_port=$1
    local username=$2
    
    log "HEADER" "CONFIGURAÇÃO DE SEGURANÇA DO SSH"
    
    # Instalar o servidor SSH, se necessário
    if ! install_ssh; then
        error "Falha na instalação/configuração do servidor SSH."
        return 1
    fi
    
    # Configurar a porta SSH, se fornecida
    if [ -n "$new_port" ]; then
        if ! configure_ssh_port "$new_port"; then
            error "Falha ao configurar a porta SSH."
            return 1
        fi
    fi
    
    # Configurar parâmetros de segurança
    if ! configure_ssh_security_params; then
        error "Falha ao configurar os parâmetros de segurança do SSH."
        return 1
    fi
    
    # Desabilitar login root
    if ! disable_root_login; then
        error "Falha ao desabilitar o login root via SSH."
        return 1
    fi
    
    # Desabilitar autenticação por senha
    if ! disable_password_auth; then
        error "Falha ao desabilitar a autenticação por senha no SSH."
        return 1
    fi
    
    # Habilitar autenticação por chave pública
    if ! enable_public_key_auth; then
        error "Falha ao habilitar a autenticação por chave pública no SSH."
        return 1
    fi
    
    # Configurar banner
    if ! setup_ssh_banner; then
        error "Falha ao configurar o banner do SSH."
        return 1
    fi
    
    # Adicionar usuário à lista de usuários permitidos, se fornecido
    if [ -n "$username" ]; then
        if ! add_allowed_user "$username"; then
            error "Falha ao adicionar o usuário à lista de usuários permitidos."
            return 1
        fi
    fi
    
    # Reiniciar o serviço SSH para aplicar as alterações
    if ! restart_ssh_service; then
        error "Falha ao reiniciar o serviço SSH."
        return 1
    fi
    
    log "SUCCESS" "Configuração de segurança do SSH concluída com sucesso!"
    return 0
}

# Função para gerar um relatório de segurança do SSH
generate_ssh_security_report() {
    log "HEADER" "RELATÓRIO DE SEGURANÇA DO SSH"
    
    # Verificar instalação do SSH
    if ! check_ssh_installed; then
        log "WARN" "O servidor OpenSSH não está instalado."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_ssh_service_running; then
        log "WARN" "O serviço SSH não está em execução."
    fi
    
    # Obter a porta atual
    local current_port
    current_port=$(get_current_ssh_port)
    log "INFO" "Porta SSH atual: $current_port"
    
    # Verificar configurações de segurança
    log "INFO" "Verificando configurações de segurança..."
    
    # Verificar login root
    if check_root_login_disabled; then
        log "PASS" "Login root via SSH está desabilitado."
    else
        log "WARN" "Login root via SSH está habilitado (risco de segurança)."
    fi
    
    # Verificar autenticação por senha
    if check_password_auth_disabled; then
        log "PASS" "Autenticação por senha está desabilitada."
    else
        log "WARN" "Autenticação por senha está habilitada (risco de segurança)."
    fi
    
    # Verificar autenticação por chave pública
    if check_public_key_auth_enabled; then
        log "PASS" "Autenticação por chave pública está habilitada."
    else
        log "WARN" "Autenticação por chave pública está desabilitada (recomendado habilitar)."
    fi
    
    # Verificar protocolo 1
    if check_ssh_protocol_v1_disabled; then
        log "PASS" "Protocolo SSH 1 está desabilitado."
    else
        log "WARN" "Protocolo SSH 1 está habilitado (vulnerável, desative-o)."
    fi
    
    # Verificar X11Forwarding
    if check_x11_forwarding_disabled; then
        log "PASS" "X11Forwarding está desabilitado."
    else
        log "WARN" "X11Forwarding está habilitado (desative se não for necessário)."
    fi
    
    # Verificar banner
    if check_ssh_banner; then
        log "PASS" "Banner do SSH está configurado corretamente."
    else
        log "WARN" "Banner do SSH não está configurado (recomendado configurar)."
    fi
    
    # Verificar MaxAuthTries
    if check_max_auth_tries; then
        log "PASS" "MaxAuthTries está configurado corretamente."
    else
        log "WARN" "MaxAuthTries está muito alto ou não configurado (recomendado: 3 ou menos)."
    fi
    
    log "INFO" "Relatório de segurança do SSH concluído."
    return 0
}

# Função principal do módulo SSH
ssh_main() {
    local action=$1
    local param1=$2
    local param2=$3
    
    case "$action" in
        "secure")
            secure_ssh "$param1" "$param2"
            ;;
        "report")
            generate_ssh_security_report
            ;;
        "restart")
            restart_ssh_service
            ;;
        "check")
            check_ssh_security
            ;;
        *)
            log "ERROR" "Ação inválida. Uso: ssh_main <secure|report|restart|check> [port] [username]"
            return 1
            ;;
    esac
    
    return $?
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f ssh_main secure_ssh generate_ssh_security_report restart_ssh_service
