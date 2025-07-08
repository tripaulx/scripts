#!/bin/bash
# ===================================================================
# Arquivo: core/security.sh
# Descrição: Funções de segurança compartilhadas
# ===================================================================

# Carregar funções utilitárias
# shellcheck source=utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Função para gerar uma senha forte
generate_strong_password() {
    local length=${1:-20}
    local use_special_chars=${2:-true}
    
    local char_set='A-Za-z0-9'
    if [ "$use_special_chars" = true ]; then
        char_set="${char_set}!@#%^&*()_+{}[]|:;<>,.?/"
    fi
    
    LC_ALL=C tr -dc "$char_set" </dev/urandom | head -c "$length"
    echo  # Nova linha após a senha
}

# Função para verificar a força de uma senha
check_password_strength() {
    local password=$1
    local min_length=12
    local score=0
    local messages=()
    
    # Verificar comprimento mínimo
    if [ ${#password} -ge $min_length ]; then
        score=$((score + 1))
    else
        messages+=("A senha deve ter pelo menos $min_length caracteres")
    fi
    
    # Verificar letras minúsculas
    if [[ "$password" =~ [a-z] ]]; then
        score=$((score + 1))
    else
        messages+=("Adicione pelo menos uma letra minúscula")
    fi
    
    # Verificar letras maiúsculas
    if [[ "$password" =~ [A-Z] ]]; then
        score=$((score + 1))
    else
        messages+=("Adicione pelo menos uma letra maiúscula")
    fi
    
    # Verificar números
    if [[ "$password" =~ [0-9] ]]; then
        score=$((score + 1))
    else
        messages+=("Adicione pelo menos um número")
    fi
    
    # Verificar caracteres especiais
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        score=$((score + 1))
    else
        messages+=("Adicione pelo menos um caractere especial")
    fi
    
    # Avaliar força da senha
    local strength
    if [ $score -le 2 ]; then
        strength="Fraca"
    elif [ $score -eq 3 ]; then
        strength="Média"
    elif [ $score -eq 4 ]; then
        strength="Forte"
    else
        strength="Muito Forte"
    fi
    
    # Retornar resultado
    echo "$strength"
    
    # Mostrar mensagens de melhoria, se houver
    if [ ${#messages[@]} -gt 0 ]; then
        for msg in "${messages[@]}"; do
            echo "  - $msg"
        done
    fi
    
    return 0
}

# Função para verificar configurações de segurança do SSH
check_ssh_security() {
    local sshd_config="${1:-/etc/ssh/sshd_config}"
    local issues=0
    
    log "INFO" "Verificando configurações de segurança do SSH..."
    
    # Verificar se o arquivo de configuração existe
    if [ ! -f "$sshd_config" ]; then
        log "ERROR" "Arquivo de configuração do SSH não encontrado: $sshd_config"
        return 1
    fi
    
    # Verificar configurações de segurança
    local config_vars=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PermitEmptyPasswords no"
        "X11Forwarding no"
        "AllowAgentForwarding no"
        "AllowTcpForwarding no"
        "PermitTunnel no"
        "MaxAuthTries 3"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
    )
    
    for config in "${config_vars[@]}"; do
        local key=${config%% *}
        local expected_value=${config#* }
        
        # Buscar a configuração no arquivo
        local current_value
        current_value=$(grep -i "^\s*${key}\s" "$sshd_config" | tail -1 | awk '{print $2}' | tr -d ' ')
        
        if [ -z "$current_value" ]; then
            log "WARN" "Configuração não encontrada: $key (recomendado: $expected_value)"
            issues=$((issues + 1))
        elif [ "$current_value" != "$expected_value" ]; then
            log "WARN" "Configuração incorreta: $key=$current_value (esperado: $expected_value)"
            issues=$((issues + 1))
        fi
    done
    
    # Verificar porta padrão (22)
    local port
    port=$(grep -i "^\s*Port\s" "$sshd_config" | tail -1 | awk '{print $2}' | tr -d ' ')
    if [ "$port" = "22" ]; then
        log "WARN" "SSH rodando na porta padrão (22). Considere mudar para uma porta não padrão."
        issues=$((issues + 1))
    fi
    
    # Verificar protocolo
    local protocol
    protocol=$(grep -i "^\s*Protocol\s" "$sshd_config" | tail -1 | awk '{print $2}' | tr -d ' ')
    if [ "$protocol" != "2" ]; then
        log "WARN" "Protocolo SSH desatualizado. Use somente SSHv2 (Protocol 2)"
        issues=$((issues + 1))
    fi
    
    # Verificar se o serviço SSH está em execução
    if ! systemctl is-active --quiet sshd; then
        log "WARN" "Serviço SSH não está em execução"
        issues=$((issues + 1))
    fi
    
    # Resumo da verificação
    if [ $issues -eq 0 ]; then
        log "INFO" "Verificação de segurança do SSH concluída sem problemas encontrados."
    else
        log "WARN" "Foram encontrados $issues problemas de segurança na configuração do SSH."
    fi
    
    return $issues
}

# Função para verificar configurações de firewall
check_firewall_status() {
    local ufw_status
    
    # Verificar se o UFW está instalado
    if ! command -v ufw >/dev/null 2>&1; then
        log "WARN" "UFW não está instalado. Recomenda-se instalar e configurar um firewall."
        return 1
    fi
    
    # Verificar status do UFW
    ufw_status=$(ufw status 2>/dev/null | grep -i "status" | awk '{print $2}')
    
    if [ "$ufw_status" != "active" ]; then
        log "WARN" "Firewall (UFW) não está ativo. Ative o firewall para melhorar a segurança."
        return 1
    fi
    
    log "INFO" "Firewall (UFW) está ativo."
    
    # Verificar regras básicas
    local ssh_port
    ssh_port=$(grep -i "^\s*Port\s" /etc/ssh/sshd_config 2>/dev/null | tail -1 | awk '{print $2}' | tr -d ' ')
    ssh_port=${ssh_port:-22}  # Usar porta 22 se não encontrar a configuração
    
    # Verificar se a porta SSH está aberta
    if ! ufw status | grep -q "${ssh_port}/tcp.*ALLOW"; then
        log "WARN" "Porta SSH (${ssh_port}/tcp) não está configurada no firewall."
        return 1
    fi
    
    # Verificar se há regras de entrada muito permissivas
    if ufw status | grep -q "^22.*ALLOW.*Anywhere"; then
        log "WARN" "Regra de firewall muito permissiva para SSH. Considere restringir por IP."
        return 1
    fi
    
    log "INFO" "Configuração básica do firewall verificada com sucesso."
    return 0
}

# Função para verificar atualizações de segurança disponíveis
check_security_updates() {
    log "INFO" "Verificando atualizações de segurança disponíveis..."
    
    if command -v apt-get >/dev/null 2>&1; then
        # Para sistemas baseados em Debian/Ubuntu
        apt-get update >/dev/null 2>&1
        local updates
        updates=$(apt-get -s dist-upgrade | grep -i security | wc -l)
        
        if [ "$updates" -gt 0 ]; then
            log "WARN" "$updates atualizações de segurança disponíveis. Execute 'apt-get upgrade' para instalá-las."
            return 1
        else
            log "INFO" "Nenhuma atualização de segurança pendente."
            return 0
        fi
    elif command -v yum >/dev/null 2>&1; then
        # Para sistemas baseados em RHEL/CentOS
        local updates
        updates=$(yum updateinfo list security all 2>/dev/null | grep -i 'update(s) needed' | wc -l)
        
        if [ "$updates" -gt 0 ]; then
            log "WARN" "$updates atualizações de segurança disponíveis. Execute 'yum update --security' para instalá-las."
            return 1
        else
            log "INFO" "Nenhuma atualização de segurança pendente."
            return 0
        fi
    else
        log "WARN" "Gerenciador de pacotes não suportado. Não foi possível verificar atualizações de segurança."
        return 1
    fi
}

# Função para verificar usuários com privilégios sudo
check_sudo_users() {
    log "INFO" "Verificando usuários com privilégios sudo..."
    
    local sudo_users
    sudo_users=$(getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | sort | uniq)
    
    if [ -z "$sudo_users" ]; then
        log "WARN" "Nenhum usuário com privilégios sudo encontrado."
        return 1
    fi
    
    log "INFO" "Usuários com privilégios sudo:"
    echo "$sudo_users" | while read -r user; do
        local last_login
        last_login=$(last -n 1 "$user" 2>/dev/null | head -n 1 | awk '{print $4" "$5" "$6" "$7" "$8}')
        
        if [ -z "$last_login" ]; then
            last_login="Nunca logou"
        fi
        
        echo "  - $user (último login: $last_login)"
    done
    
    # Verificar se há usuários sem senha
    local no_password
    no_password=$(getent shadow | grep '^[^:]*::' | cut -d: -f1)
    
    if [ -n "$no_password" ]; then
        log "WARN" "Os seguintes usuários não possuem senha definida:"
        echo "$no_password" | while read -r user; do
            echo "  - $user"
        done
        return 1
    fi
    
    return 0
}

# Função para verificar permissões de arquivos sensíveis
check_sensitive_file_permissions() {
    local files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/crontab"
    )
    
    local issues=0
    
    for file in "${files[@]}"; do
        if [ ! -e "$file" ]; then
            log "DEBUG" "Arquivo não encontrado: $file"
            continue
        fi
        
        local perms
        perms=$(stat -c "%a" "$file" 2>/dev/null)
        
        # Verificar permissões para arquivos sensíveis
        case "$file" in
            "/etc/shadow")
                if [ "$perms" != "640" ] && [ "$perms" != "600" ]; then
                    log "WARN" "Permissões inseguras para $file: $perms (deveria ser 640 ou 600)"
                    issues=$((issues + 1))
                fi
                ;;
            "/etc/passwd"|"/etc/group")
                if [ "$perms" != "644" ]; then
                    log "WARN" "Permissões inseguras para $file: $perms (deveria ser 644)"
                    issues=$((issues + 1))
                fi
                ;;
            "/etc/sudoers"|"/etc/ssh/sshd_config"|"/etc/crontab")
                if [ "$perms" -gt 600 ]; then
                    log "WARN" "Permissões muito permissivas para $file: $perms (deveria ser 600 ou menos)"
                    issues=$((issues + 1))
                fi
                ;;
        esac
    done
    
    if [ $issues -eq 0 ]; then
        log "INFO" "Permissões de arquivos sensíveis verificadas com sucesso."
    else
        log "WARN" "Foram encontrados $issues problemas com permissões de arquivos sensíveis."
    fi
    
    return $issues
}

# Função para verificar se o SSH está configurado para usar autenticação por chave
check_ssh_key_auth() {
    local sshd_config="${1:-/etc/ssh/sshd_config}"
    local auth_keys_file="${2:-/root/.ssh/authorized_keys}"
    
    # Verificar se a autenticação por senha está desativada
    if ! grep -q '^\s*PasswordAuthentication\s*no' "$sshd_config"; then
        log "WARN" "A autenticação por senha está habilitada no SSH. Considere desativá-la."
        return 1
    fi
    
    # Verificar se a autenticação por chave está habilitada
    if ! grep -q '^\s*PubkeyAuthentication\s*yes' "$sshd_config"; then
        log "WARN" "A autenticação por chave não está habilitada no SSH."
        return 1
    fi
    
    # Verificar se existem chaves autorizadas
    if [ ! -f "$auth_keys_file" ] || [ ! -s "$auth_keys_file" ]; then
        log "WARN" "Nenhuma chave SSH autorizada encontrada em $auth_keys_file"
        return 1
    fi
    
    log "INFO" "Autenticação por chave SSH configurada corretamente."
    return 0
}

# Função para verificar se o Fail2Ban está instalado e configurado
check_fail2ban_status() {
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log "WARN" "Fail2Ban não está instalado. Recomenda-se instalar para proteção contra ataques de força bruta."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! systemctl is-active --quiet fail2ban; then
        log "WARN" "O serviço Fail2Ban não está em execução. Ative-o com 'systemctl start fail2ban'"
        return 1
    fi
    
    # Verificar se há jails ativas
    local jails
    jails=$(fail2ban-client status 2>/dev/null | grep -i 'Jail list' | cut -d: -f2 | sed 's/\s//g')
    
    if [ -z "$jails" ]; then
        log "WARN" "Nenhuma jail ativa no Fail2Ban. Configure pelo menos uma jail para proteção básica."
        return 1
    fi
    
    log "INFO" "Fail2Ban está ativo com as seguintes jails: $jails"
    
    # Verificar se a jail do SSH está ativa
    if ! echo "$jails" | grep -q '\bsshd\b'; then
        log "WARN" "A jail do SSH (sshd) não está ativa no Fail2Ban. Recomenda-se ativá-la."
        return 1
    fi
    
    return 0
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f generate_strong_password check_password_strength check_ssh_security
