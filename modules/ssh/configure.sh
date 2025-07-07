#!/bin/bash
# ===================================================================
# Módulo: SSH
# Arquivo: modules/ssh/configure.sh
# Descrição: Configuração segura do servidor SSH
# ===================================================================

# Carregar funções do core
# shellcheck source=../../core/utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
# shellcheck source=../../core/validations.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/validations.sh"
# shellcheck source=../../core/backup.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/backup.sh"
# shellcheck source=../../core/security.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/security.sh"

# Variáveis de configuração
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_SERVICE="sshd"
DEFAULT_SSH_PORT=22

# Função para configurar a porta SSH
configure_ssh_port() {
    local new_port=$1
    local current_port
    
    log "INFO" "Configurando porta SSH..."
    
    # Obter porta atual
    if grep -q "^\s*Port\s" "$SSH_CONFIG_FILE"; then
        current_port=$(grep "^\s*Port\s" "$SSH_CONFIG_FILE" | awk '{print $2}')
    else
        current_port=$DEFAULT_SSH_PORT
    fi
    
    # Se não foi especificada uma nova porta, usar a atual
    if [ -z "$new_port" ]; then
        new_port=$current_port
    fi
    
    # Validar a porta
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        error "Porta SSH inválida: $new_port. Deve ser um número entre 1 e 65535."
        return 1
    fi
    
    # Se a porta for a mesma, não é necessário fazer nada
    if [ "$new_port" = "$current_port" ]; then
        log "INFO" "A porta SSH já está configurada como $new_port."
        return 0
    fi
    
    # Verificar se a porta já está em uso
    if is_port_in_use "$new_port"; then
        error "A porta $new_port já está em uso por outro serviço."
        return 1
    fi
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Atualizar a porta no arquivo de configuração
    if grep -q "^\s*Port\s" "$SSH_CONFIG_FILE"; then
        # Se já existe uma diretiva Port, atualizar
        sed -i "s/^\s*Port\s.*/Port $new_port/" "$SSH_CONFIG_FILE"
    else
        # Se não existe, adicionar após o comentário #Port
        sed -i "s/^#Port 22/Port $new_port/" "$SSH_CONFIG_FILE"
    fi
    
    # Verificar se a alteração foi bem-sucedida
    if ! grep -q "^\s*Port\s*$new_port\s*$" "$SSH_CONFIG_FILE"; then
        error "Falha ao configurar a porta SSH para $new_port."
        return 1
    fi
    
    log "INFO" "Porta SSH configurada para $new_port."
    
    # Se a porta foi alterada, adicionar ao relatório
    if [ "$new_port" != "$current_port" ]; then
        echo "Porta SSH alterada de $current_port para $new_port" >> "$REPORT_FILE"
    fi
    
    return 0
}

# Função para desabilitar o login root via SSH
disable_root_login() {
    log "INFO" "Desabilitando login root via SSH..."
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Verificar se já está configurado corretamente
    if grep -q "^\s*PermitRootLogin\s*no\s*$" "$SSH_CONFIG_FILE"; then
        log "INFO" "Login root já está desabilitado no SSH."
        return 0
    fi
    
    # Atualizar a configuração
    if grep -q "^\s*PermitRootLogin\s" "$SSH_CONFIG_FILE"; then
        # Se já existe uma diretiva PermitRootLogin, atualizar
        sed -i 's/^\s*PermitRootLogin\s.*/PermitRootLogin no/' "$SSH_CONFIG_FILE"
    else
        # Se não existe, adicionar
        echo "PermitRootLogin no" >> "$SSH_CONFIG_FILE"
    fi
    
    # Verificar se a alteração foi bem-sucedida
    if ! grep -q "^\s*PermitRootLogin\s*no\s*$" "$SSH_CONFIG_FILE"; then
        error "Falha ao desabilitar o login root via SSH."
        return 1
    fi
    
    log "INFO" "Login root via SSH desabilitado com sucesso."
    echo "Login root via SSH desabilitado" >> "$REPORT_FILE"
    return 0
}

# Função para desabilitar a autenticação por senha
disable_password_auth() {
    log "INFO" "Desabilitando autenticação por senha no SSH..."
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Verificar se já está configurado corretamente
    if grep -q "^\s*PasswordAuthentication\s*no\s*$" "$SSH_CONFIG_FILE"; then
        log "INFO" "Autenticação por senha já está desabilitada no SSH."
        return 0
    fi
    
    # Atualizar a configuração
    if grep -q "^\s*PasswordAuthentication\s" "$SSH_CONFIG_FILE"; then
        # Se já existe uma diretiva PasswordAuthentication, atualizar
        sed -i 's/^\s*PasswordAuthentication\s.*/PasswordAuthentication no/' "$SSH_CONFIG_FILE"
    else
        # Se não existe, adicionar
        echo "PasswordAuthentication no" >> "$SSH_CONFIG_FILE"
    fi
    
    # Verificar se a alteração foi bem-sucedida
    if ! grep -q "^\s*PasswordAuthentication\s*no\s*$" "$SSH_CONFIG_FILE"; then
        error "Falha ao desabilitar a autenticação por senha no SSH."
        return 1
    fi
    
    log "INFO" "Autenticação por senha no SSH desabilitada com sucesso."
    echo "Autenticação por senha no SSH desabilitada" >> "$REPORT_FILE"
    return 0
}

# Função para habilitar a autenticação por chave pública
enable_public_key_auth() {
    log "INFO" "Habilitando autenticação por chave pública no SSH..."
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Verificar se já está configurado corretamente
    if grep -q "^\s*PubkeyAuthentication\s*yes\s*$" "$SSH_CONFIG_FILE"; then
        log "INFO" "Autenticação por chave pública já está habilitada no SSH."
    else
        # Atualizar a configuração
        if grep -q "^\s*PubkeyAuthentication\s" "$SSH_CONFIG_FILE"; then
            # Se já existe uma diretiva PubkeyAuthentication, atualizar
            sed -i 's/^\s*PubkeyAuthentication\s.*/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
        else
            # Se não existe, adicionar
            echo "PubkeyAuthentication yes" >> "$SSH_CONFIG_FILE"
        fi
        
        # Verificar se a alteração foi bem-sucedida
        if ! grep -q "^\s*PubkeyAuthentication\s*yes\s*$" "$SSH_CONFIG_FILE"; then
            error "Falha ao habilitar a autenticação por chave pública no SSH."
            return 1
        fi
        
        log "INFO" "Autenticação por chave pública no SSH habilitada com sucesso."
        echo "Autenticação por chave pública no SSH habilitada" >> "$REPORT_FILE"
    fi
    
    # Verificar se o diretório .ssh do root existe
    local ssh_dir="/root/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    if [ ! -d "$ssh_dir" ]; then
        log "INFO" "Criando diretório .ssh para o usuário root..."
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    # Verificar se já existem chaves autorizadas
    if [ ! -f "$auth_keys" ]; then
        log "WARN" "Nenhuma chave SSH autorizada encontrada para o usuário root."
        log "WARN" "Crie o arquivo $auth_keys e adicione suas chaves públicas antes de desabilitar a autenticação por senha."
        return 1
    fi
    
    # Verificar permissões do arquivo authorized_keys
    chmod 600 "$auth_keys"
    
    return 0
}

# Função para configurar opções de segurança adicionais
configure_security_options() {
    log "INFO" "Configurando opções adicionais de segurança do SSH..."
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH."
        return 1
    fi
    
    # Array com as configurações de segurança
    local security_options=(
        "Protocol 2"
        "X11Forwarding no"
        "AllowTcpForwarding no"
        "PermitTunnel no"
        "AllowAgentForwarding no"
        "PermitEmptyPasswords no"
        "MaxAuthTries 3"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
        "LoginGraceTime 60"
        "MaxStartups 2"
        "Banner /etc/issue.net"
    )
    
    # Aplicar cada configuração
    for option in "${security_options[@]}"; do
        local key
        key=$(echo "$option" | awk '{print $1}')
        
        # Se a opção já existe, atualizar, senão adicionar
        if grep -q "^\s*$key\s" "$SSH_CONFIG_FILE"; then
            sed -i "s|^\s*$key\s.*|$option|" "$SSH_CONFIG_FILE"
        else
            echo "$option" >> "$SSH_CONFIG_FILE"
        fi
        
        # Verificar se a alteração foi bem-sucedida
        if ! grep -q "^\s*$option\s*$" "$SSH_CONFIG_FILE"; then
            log "WARN" "Falha ao configurar a opção: $option"
        else
            log "DEBUG" "Configuração aplicada: $option"
            echo "Configuração de segurança aplicada: $option" >> "$REPORT_FILE"
        fi
    done
    
    log "INFO" "Configurações adicionais de segurança do SSH aplicadas com sucesso."
    return 0
}

# Função para reiniciar o serviço SSH
restart_ssh_service() {
    log "INFO" "Reiniciando o serviço SSH..."
    
    # Verificar se o serviço está ativo
    if ! systemctl is-active --quiet "$SSH_SERVICE"; then
        log "WARN" "O serviço SSH não está em execução. Tentando iniciar..."
        if ! systemctl start "$SSH_SERVICE"; then
            error "Falha ao iniciar o serviço SSH."
            return 1
        fi
        log "INFO" "Serviço SSH iniciado com sucesso."
        return 0
    fi
    
    # Testar a configuração antes de reiniciar
    if ! sshd -t -f "$SSH_CONFIG_FILE"; then
        error "Erro na configuração do SSH. Corrija os erros antes de reiniciar o serviço."
        return 1
    fi
    
    # Reiniciar o serviço
    if ! systemctl restart "$SSH_SERVICE"; then
        error "Falha ao reiniciar o serviço SSH."
        return 1
    fi
    
    log "INFO" "Serviço SSH reiniciado com sucesso."
    return 0
}

# Função principal de configuração do SSH
configure_ssh() {
    local port=$1
    local disable_root=$2
    local disable_password_auth=$3
    
    log "INFO" "Iniciando configuração segura do SSH..."
    
    # Verificar se o SSH está instalado
    if ! command_exists sshd; then
        log "ERROR" "O servidor SSH (OpenSSH) não está instalado."
        return 1
    fi
    
    # Configurar porta SSH
    if [ -n "$port" ]; then
        if ! configure_ssh_port "$port"; then
            log "ERROR" "Falha ao configurar a porta SSH."
            return 1
        fi
    fi
    
    # Desabilitar login root se solicitado
    if [ "$disable_root" = true ]; then
        if ! disable_root_login; then
            log "ERROR" "Falha ao desabilitar o login root."
            return 1
        fi
    fi
    
    # Habilitar autenticação por chave pública
    if ! enable_public_key_auth; then
        log "WARN" "Problemas ao configurar autenticação por chave pública."
    fi
    
    # Desabilitar autenticação por senha se solicitado
    if [ "$disable_password_auth" = true ]; then
        if ! disable_password_auth; then
            log "ERROR" "Falha ao desabilitar a autenticação por senha."
            return 1
        fi
    fi
    
    # Configurar opções adicionais de segurança
    if ! configure_security_options; then
        log "WARN" "Algumas opções de segurança não puderam ser configuradas."
    fi
    
    # Reiniciar o serviço SSH para aplicar as alterações
    if ! restart_ssh_service; then
        log "ERROR" "Falha ao reiniciar o serviço SSH. As alterações podem não ter sido aplicadas."
        return 1
    fi
    
    log "INFO" "Configuração segura do SSH concluída com sucesso!"
    return 0
}

# Função para adicionar uma chave SSH para um usuário
add_ssh_key() {
    local username=$1
    local ssh_key=$2
    
    # Validar parâmetros
    if [ -z "$username" ] || [ -z "$ssh_key" ]; then
        error "Nome de usuário e chave SSH são obrigatórios."
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
    local ssh_dir="$user_home/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    # Criar diretório .ssh se não existir
    if [ ! -d "$ssh_dir" ]; then
        log "INFO" "Criando diretório .ssh para o usuário $username..."
        mkdir -p "$ssh_dir"
        chown "$username:$username" "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    # Adicionar chave ao arquivo authorized_keys
    log "INFO" "Adicionando chave SSH para o usuário $username..."
    
    # Verificar se a chave já existe
    if [ -f "$auth_keys" ] && grep -q "$ssh_key" "$auth_keys"; then
        log "INFO" "A chave SSH já está configurada para o usuário $username."
        return 0
    fi
    
    # Adicionar a chave ao arquivo
    echo "$ssh_key" >> "$auth_keys"
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
    
    log "INFO" "Chave SSH adicionada com sucesso para o usuário $username."
    return 0
}

# Função para remover uma chave SSH de um usuário
remove_ssh_key() {
    local username=$1
    local ssh_key=$2
    
    # Validar parâmetros
    if [ -z "$username" ] || [ -z "$ssh_key" ]; then
        error "Nome de usuário e chave SSH são obrigatórios."
        return 1
    }
    
    # Verificar se o usuário existe
    if ! id "$username" &>/dev/null; then
        error "O usuário $username não existe."
        return 1
    }
    
    # Obter o diretório home do usuário
    local user_home
    user_home=$(getent passwd "$username" | cut -d: -f6)
    local auth_keys="$user_home/.ssh/authorized_keys"
    
    # Verificar se o arquivo authorized_keys existe
    if [ ! -f "$auth_keys" ]; then
        log "INFO" "Nenhuma chave SSH configurada para o usuário $username."
        return 0
    fi
    
    # Remover a chave do arquivo
    log "INFO" "Removendo chave SSH do usuário $username..."
    
    # Fazer backup do arquivo
    if ! backup_file "$auth_keys"; then
        error "Falha ao fazer backup do arquivo authorized_keys."
        return 1
    fi
    
    # Remover a chave específica
    if ! sed -i "\|$(echo "$ssh_key" | sed 's/[\/&]/\\&/g')|d" "$auth_keys"; then
        error "Falha ao remover a chave SSH do arquivo authorized_keys."
        return 1
    fi
    
    log "INFO" "Chave SSH removida com sucesso do usuário $username."
    return 0
}

# Função para listar as chaves SSH de um usu
list_ssh_keys() {
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
        log "INFO" "Nenhuma chave SSH configurada para o usuário $username."
        return 0
    fi
    
    # Listar as chaves
    log "INFO" "Chaves SSH configuradas para o usuário $username:"
    cat "$auth_keys"
    return 0
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f configure_ssh add_ssh_key remove_ssh_key list_ssh_keys
