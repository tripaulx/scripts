#!/bin/bash
#
# Nome do Arquivo: configure_ssh.sh
#
# Descrição:
#   Script para configuração segura do servidor SSH.
#   Implementa as melhores práticas de segurança para servidores SSH.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - ssh_utils.sh (funções auxiliares de SSH)
#
# Uso:
#   source "$(dirname "$0")/configure_ssh.sh"
#   configure_ssh_security [opções]
#
# Opções:
#   --port=PORTA    Configura uma porta SSH personalizada
#   --no-root       Desativa o login root via SSH
#   --no-password   Desativa a autenticação por senha
#   --key-only      Habilita apenas autenticação por chave
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar funções utilitárias
if [ -f "$(dirname "$0")/../../core/security_utils.sh" ]; then
    source "$(dirname "$0")/../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

# Carregar funções utilitárias do SSH
if [ -f "$(dirname "$0")/ssh_utils.sh" ]; then
    source "$(dirname "$0")/ssh_utils.sh"
else
    log "error" "Não foi possível carregar ssh_utils.sh"
    exit 1
fi

#
# configure_ssh_security
#
# Descrição:
#   Função principal para configurar a segurança do SSH.
#   Aplica as configurações de segurança recomendadas.
#
# Parâmetros:
#   $@ - Argumentos de linha de comando
#
configure_ssh_security() {
    local port=""
    local disable_root=false
    local disable_password_auth=false
    local key_only=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port=*)
                port="${1#*=}"
                shift
                ;;
            --no-root)
                disable_root=true
                shift
                ;;
            --no-password)
                disable_password_auth=true
                shift
                ;;
            --key-only)
                key_only=true
                shift
                ;;
            *)
                log "warn" "Opção desconhecida: $1"
                shift
                ;;
        esac
    done
    
    log "info" "Iniciando configuração segura do SSH..."
    
    # 1. Fazer backup do arquivo de configuração
    if ! backup_ssh_config; then
        log "error" "Falha ao criar backup do arquivo de configuração SSH"
        return 1
    fi
    
    # 2. Configurar porta SSH
    if [ -n "${port}" ]; then
        if ! configure_ssh_port "${port}"; then
            log "error" "Falha ao configurar a porta SSH"
            return 1
        fi
    fi
    
    # 3. Configurações de segurança recomendadas
    log "info" "Aplicando configurações de segurança recomendadas..."
    
    # Desativar protocolo SSHv1
    update_ssh_setting "Protocol" "2"
    
    # Configurar tempo de login
    update_ssh_setting "LoginGraceTime" "60"
    update_ssh_setting "ClientAliveInterval" "300"
    update_ssh_setting "ClientAliveCountMax" "2"
    
    # Configurar autenticação
    if ${disable_root} || ${key_only}; then
        update_ssh_setting "PermitRootLogin" "no"
    else
        update_ssh_setting "PermitRootLogin" "prohibit-password"
    fi
    
    if ${disable_password_auth} || ${key_only}; then
        update_ssh_setting "PasswordAuthentication" "no"
        update_ssh_setting "ChallengeResponseAuthentication" "no"
        update_ssh_setting "UsePAM" "no"
    else
        update_ssh_setting "PasswordAuthentication" "yes"
        update_ssh_setting "ChallengeResponseAuthentication" "no"
        update_ssh_setting "UsePAM" "yes"
    fi
    
    # Configurações de criptografia
    update_ssh_setting "HostKey" "/etc/ssh/ssh_host_ed25519_key"
    update_ssh_setting "HostKey" "/etc/ssh/ssh_host_rsa_key"
    update_ssh_setting "HostKeyAlgorithms" "ssh-ed25519,rsa-sha2-512,rsa-sha2-256"
    update_ssh_setting "KexAlgorithms" "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256"
    update_ssh_setting "Ciphers" "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
    update_ssh_setting "MACs" "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com"
    
    # Outras configurações de segurança
    update_ssh_setting "X11Forwarding" "no"
    update_ssh_setting "PrintMotd" "no"
    update_ssh_setting "PrintLastLog" "yes"
    update_ssh_setting "TCPKeepAlive" "yes"
    update_ssh_setting "IgnoreRhosts" "yes"
    update_ssh_setting "HostbasedAuthentication" "no"
    update_ssh_setting "PermitEmptyPasswords" "no"
    update_ssh_setting "MaxAuthTries" "3"
    update_ssh_setting "MaxSessions" "5"
    update_ssh_setting "AllowTcpForwarding" "no"
    update_ssh_setting "AllowAgentForwarding" "no"
    update_ssh_setting "PermitTunnel" "no"
    
    # Configurações de usuário e grupo
    update_ssh_setting "AllowUsers" "*"
    update_ssh_setting "DenyUsers" "root"
    update_ssh_setting "AllowGroups" "ssh-users"
    
    log "info" "Configuração de segurança do SSH concluída com sucesso."
    
    # Reiniciar o serviço SSH para aplicar as alterações
    if command -v systemctl &> /dev/null; then
        log "info" "Reiniciando o serviço SSH..."
        if ! systemctl restart sshd; then
            log "error" "Falha ao reiniciar o serviço SSH"
            return 1
        fi
    else
        log "warn" "Não foi possível reiniciar o serviço SSH. Reinicie manualmente."
    fi
    
    return 0
}

#
# generate_ssh_key_for_user
#
# Descrição:
#   Gera um par de chaves SSH para um usuário e configura o acesso.
#
# Parâmetros:
#   $1 - Nome do usuário
#   $2 - Tipo de chave (opcional, padrão: ed25519)
#
# Retorno:
#   0 - Chave gerada com sucesso
#   1 - Falha ao gerar a chave
#
generate_ssh_key_for_user() {
    local username="$1"
    local key_type="${2:-ed25519}"
    
    # Verificar se o usuário existe
    if ! id -u "${username}" &> /dev/null; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    log "info" "Gerando chave SSH do tipo ${key_type} para o usuário ${username}..."
    
    # Gerar chave SSH
    if ! public_key=$(generate_ssh_key "${username}" "${key_type}"); then
        log "error" "Falha ao gerar chave SSH para o usuário ${username}"
        return 1
    fi
    
    # Adicionar chave ao authorized_keys
    local ssh_dir="/home/${username}/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"
    
    # Criar arquivo authorized_keys se não existir
    if [ ! -f "${auth_keys}" ]; then
        touch "${auth_keys}"
        chmod 600 "${auth_keys}"
        chown "${username}:${username}" "${auth_keys}"
    fi
    
    # Adicionar chave pública se ainda não estiver lá
    local pubkey_value
    pubkey_value=$(cut -d' ' -f2 < "${public_key}")
    if ! grep -q "$pubkey_value" "${auth_keys}" 2>/dev/null; then
        cat "${public_key}" >> "${auth_keys}"
        log "info" "Chave pública adicionada ao arquivo authorized_keys"
    else
        log "info" "A chave pública já está configurada para este usuário"
    fi
    
    log "info" "Chave SSH gerada com sucesso para o usuário ${username}"
    log "info" "Chave pública: ${public_key}"
    
    return 0
}

# Se o script for executado diretamente, não apenas incluído
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ssh_security "$@"
fi

# Exportar funções que serão usadas em outros módulos
export -f configure_ssh_security generate_ssh_key_for_user
