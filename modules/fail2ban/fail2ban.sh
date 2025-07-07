#!/bin/bash
# ===================================================================
# Módulo: Fail2Ban
# Arquivo: modules/fail2ban/fail2ban.sh
# Descrição: Módulo para gerenciar o Fail2Ban
# ===================================================================

# Carregar funções do core
# shellcheck source=../../core/utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
# shellcheck source=../../core/validations.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/validations.sh"
# shellcheck source=../../core/security.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../core/security.sh"
# shellcheck source=./validations.sh
source "$(dirname "${BASH_SOURCE[0]}")/validations.sh"

# Variáveis de configuração
FAIL2BAN_CONFIG_DIR="/etc/fail2ban"
FAIL2BAN_JAIL_LOCAL="${FAIL2BAN_CONFIG_DIR}/jail.local"
FAIL2BAN_JAIL_DEFAULT="${FAIL2BAN_CONFIG_DIR}/jail.d/defaults-debian.conf"
FAIL2BAN_FILTER_DIR="${FAIL2BAN_CONFIG_DIR}/filter.d"
FAIL2BAN_ACTION_DIR="${FAIL2BAN_CONFIG_DIR}/action.d"
FAIL2BAN_SERVICE="fail2ban"
FAIL2BAN_LOGFILE="/var/log/fail2ban.log"

# Função para instalar o Fail2Ban
install_fail2ban() {
    log "INFO" "Verificando instalação do Fail2Ban..."
    
    if ! check_fail2ban_installed; then
        log "INFO" "Instalando o Fail2Ban..."
        
        if ! run_command "apt-get update" "Atualizando lista de pacotes" || \
           ! run_command "apt-get install -y fail2ban" "Instalando o Fail2Ban"; then
            error "Falha ao instalar o Fail2Ban."
            return 1
        fi
        
        log "SUCCESS" "Fail2Ban instalado com sucesso."
    else
        log "INFO" "Fail2Ban já está instalado."
    fi
    
    return 0
}

# Função para configurar parâmetros básicos do Fail2Ban
configure_fail2ban_basic() {
    local ignore_ip=${1:-''}
    
    log "INFO" "Configurando parâmetros básicos do Fail2Ban..."
    
    # Criar arquivo de configuração local se não existir
    if [ ! -f "$FAIL2BAN_JAIL_LOCAL" ]; then
        log "INFO" "Criando arquivo de configuração local do Fail2Ban..."
        
        # Criar cabeçalho do arquivo de configuração
        local config="# Configuração personalizada do Fail2Ban\n"
        config+="# Gerado automaticamente em $(date)\n"
        config+="#\n"
        config+="# ATENÇÃO: Este arquivo é gerado automaticamente.\n"
        config+="#          Modificações manuais podem ser sobrescritas.\n\n"
        
        # Escrever configuração básica
        config+="[DEFAULT]\n"
        config+="# Ignorar localhost e IPs confiáveis\n"
        config+="ignoreip = 127.0.0.1/8 ::1 ${ignore_ip}\n"
        config+="bantime = 1h\n"
        config+="findtime = 10m\n"
        config+="maxretry = 5\n\n"
        
        # Escrever configuração para o serviço sshd
        config+="[sshd]\n"
        config+="enabled = true\n"
        config+="port = ssh\n"
        config+="filter = sshd\n"
        config+="logpath = %(sshd_log)s\n"
        config+="maxretry = 3\n"
        config+="bantime = 24h\n"
        # Escrever configuração no arquivo
        if ! echo -e "$config" > "$FAIL2BAN_JAIL_LOCAL"; then
            error "Falha ao criar o arquivo de configuração do Fail2Ban."
            return 1
        fi
        
        log "SUCCESS" "Arquivo de configuração do Fail2Ban criado em $FAIL2BAN_JAIL_LOCAL"
    else
        log "INFO" "Arquivo de configuração local do Fail2Ban já existe em $FAIL2BAN_JAIL_LOCAL"
    fi
    
    return 0
}

# Função para configurar proteção SSH
configure_ssh_protection() {
    local max_retry=${1:-3}
    local bantime=${2:-'24h'}
    local findtime=${3:-'10m'}
    
    log "INFO" "Configurando proteção SSH no Fail2Ban..."
    
    # Verificar se a seção [sshd] já existe no arquivo de configuração
    if grep -q '^\[sshd\]' "$FAIL2BAN_JAIL_LOCAL"; then
        log "INFO" "Atualizando configuração existente do serviço SSH..."
        
        # Atualizar configurações existentes
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*enabled\s*=" "enabled = true"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*port\s*=" "port = ssh"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*filter\s*=" "filter = sshd"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*logpath\s*=" "logpath = %(sshd_log)s"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*maxretry\s*=" "maxretry = $max_retry"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*bantime\s*=" "bantime = $bantime"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*findtime\s*=" "findtime = $findtime"
    else
        log "INFO" "Adicionando nova configuração para o serviço SSH..."
        
        # Adicionar nova seção [sshd]
        local config="\n[sshd]\n"
        config+="enabled = true\n"
        config+="port = ssh\n"
        config+="filter = sshd\n"
        config+="logpath = %(sshd_log)s\n"
        config+="maxretry = $max_retry\n"
        config+="bantime = $bantime\n"
        config+="findtime = $findtime\n"
        
        # Adicionar ao final do arquivo
        if ! echo -e "$config" >> "$FAIL2BAN_JAIL_LOCAL"; then
            error "Falha ao adicionar configuração do SSH ao arquivo do Fail2Ban."
            return 1
        fi
    fi
    
    log "SUCCESS" "Proteção SSH configurada com sucesso no Fail2Ban."
    return 0
}

# Função para configurar proteção para outros serviços
configure_service_protection() {
    local service=$1
    local log_path=$2
    local max_retry=${3:-5}
    local bantime=${4:-'24h'}
    local findtime=${5:-'10m'}
    local port=${6:-''}
    
    # Validar parâmetros obrigatórios
    if [ -z "$service" ] || [ -z "$log_path" ]; then
        error "Nome do serviço e caminho do log são obrigatórios."
        return 1
    fi
    
    log "INFO" "Configurando proteção para o serviço $service no Fail2Ban..."
    
    # Verificar se a seção já existe no arquivo de configuração
    if grep -q "^\[$service\]" "$FAIL2BAN_JAIL_LOCAL"; then
        log "INFO" "Atualizando configuração existente para o serviço $service..."
        
        # Atualizar configurações existentes
        update_config_file "$FAIL2AN_JAIL_LOCAL" "^\s*enabled\s*=\" "enabled = true"
        
        if [ -n "$port" ]; then
            update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*port\s*=" "port = $port"
        fi
        
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*filter\s*=" "filter = $service"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*logpath\s*=" "logpath = $log_path"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*maxretry\s*=" "maxretry = $max_retry"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*bantime\s*=" "bantime = $bantime"
        update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*findtime\s*=" "findtime = $findtime"
    else
        log "INFO" "Adicionando nova configuração para o serviço $service..."
        
        # Adicionar nova seção
        local config="\n[$service]\n"
        config+="enabled = true\n"
        
        if [ -n "$port" ]; then
            config+="port = $port\n"
        fi
        
        config+="filter = $service\n"
        config+="logpath = $log_path\n"
        config+="maxretry = $max_retry\n"
        config+="bantime = $bantime\n"
        config+="findtime = $findtime\n"
        
        # Adicionar ao final do arquivo
        if ! echo -e "$config" >> "$FAIL2BAN_JAIL_LOCAL"; then
            error "Falha ao adicionar configuração do serviço $service ao arquivo do Fail2Ban."
            return 1
        fi
    fi
    
    log "SUCCESS" "Proteção para o serviço $service configurada com sucesso no Fail2Ban."
    return 0
}

# Função para adicionar um IP à whitelist
add_whitelist_ip() {
    local ip=$1
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    log "INFO" "Adicionando IP $ip à whitelist do Fail2Ban..."
    
    # Verificar se o IP já está na whitelist
    if grep -q "^ignoreip.*\b${ip}\b" "$FAIL2BAN_JAIL_LOCAL"; then
        log "INFO" "O IP $ip já está na whitelist do Fail2Ban."
        return 0
    fi
    
    # Adicionar o IP à whitelist
    if sed -i "s/^\(\s*ignoreip\s*=\s*\(.*\)\)/\1 ${ip}/" "$FAIL2BAN_JAIL_LOCAL"; then
        log "SUCCESS" "IP $ip adicionado à whitelist do Fail2Ban com sucesso."
        return 0
    else
        error "Falha ao adicionar o IP $ip à whitelist do Fail2Ban."
        return 1
    fi
}

# Função para remover um IP da whitelist
remove_whitelist_ip() {
    local ip=$1
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    log "INFO" "Removendo IP $ip da whitelist do Fail2Ban..."
    
    # Verificar se o IP está na whitelist
    if ! grep -q "^ignoreip.*\b${ip}\b" "$FAIL2BAN_JAIL_LOCAL"; then
        log "INFO" "O IP $ip não está na whitelist do Fail2Ban."
        return 0
    fi
    
    # Remover o IP da whitelist
    if sed -i "s/\b${ip}\b//g" "$FAIL2BAN_JAIL_LOCAL" && \
       sed -i 's/  */ /g' "$FAIL2BAN_JAIL_LOCAL" && \
       sed -i 's/ = /=/g' "$FAIL2BAN_JAIL_LOCAL"; then
        log "SUCCESS" "IP $ip removido da whitelist do Fail2Ban com sucesso."
        return 0
    else
        error "Falha ao remover o IP $ip da whitelist do Fail2Ban."
        return 1
    fi
}

# Função para listar IPs banidos
list_banned_ips() {
    log "INFO" "Listando IPs atualmente banidos pelo Fail2Ban:"
    
    if ! run_command "fail2ban-client status" "Obtendo status do Fail2Ban"; then
        error "Falha ao obter o status do Fail2Ban."
        return 1
    fi
    
    # Obter lista de serviços ativos
    local services
    services=$(fail2ban-client status | grep -i 'Jail list' | sed 's/^[^:]*://' | tr ',' ' ' | xargs)
    
    if [ -z "$services" ]; then
        log "INFO" "Nenhum serviço ativo encontrado no Fail2Ban."
        return 0
    fi
    
    # Para cada serviço, listar IPs banidos
    for service in $services; do
        log "INFO" "\nIPs banidos para o serviço $service:"
        if ! run_command "fail2ban-client status $service" "Obtendo status para $service"; then
            log "WARN" "Falha ao obter status para o serviço $service"
        fi
    done
    
    return 0
}

# Função para desbanir um IP
unban_ip() {
    local ip=$1
    local service=${2:-""}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Se o serviço não for especificado, desbanir de todos os serviços
    if [ -z "$service" ]; then
        log "INFO" "Desbanindo IP $ip de todos os serviços..."
        
        # Obter lista de serviços ativos
        local services
        services=$(fail2ban-client status | grep -i 'Jail list' | sed 's/^[^:]*://' | tr ',' ' ' | xargs)
        
        if [ -z "$services" ]; then
            log "WARN" "Nenhum serviço ativo encontrado no Fail2Ban."
            return 1
        fi
        
        # Desbanir o IP de cada serviço
        local success=0
        for s in $services; do
            if fail2ban-client set "$s" unbanip "$ip" >/dev/null 2>&1; then
                log "INFO" "IP $ip desbanido com sucesso do serviço $s."
                success=1
            fi
        done
        
        if [ "$success" -eq 1 ]; then
            log "SUCCESS" "IP $ip desbanido com sucesso dos serviços ativos."
            return 0
        else
            error "Falha ao desbanir o IP $ip dos serviços ativos."
            return 1
        fi
    else
        # Desbanir o IP do serviço específico
        log "INFO" "Desbanindo IP $ip do serviço $service..."
        
        if fail2ban-client set "$service" unbanip "$ip"; then
            log "SUCCESS" "IP $ip desbanido com sucesso do serviço $service."
            return 0
        else
            error "Falha ao desbanir o IP $ip do serviço $service."
            return 1
        fi
    fi
}

# Função para reiniciar o serviço Fail2Ban
restart_fail2ban() {
    log "INFO" "Reiniciando o serviço Fail2Ban..."
    
    # Verificar se o Fail2Ban está instalado
    if ! check_fail2ban_installed; then
        error "O Fail2Ban não está instalado. Instale-o primeiro."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! systemctl is-active --quiet "$FAIL2BAN_SERVICE"; then
        log "WARN" "O serviço Fail2Ban não está em execução. Iniciando..."
        if ! run_command "systemctl start $FAIL2BAN_SERVICE" "Iniciando o serviço Fail2Ban"; then
            error "Falha ao iniciar o serviço Fail2Ban."
            return 1
        fi
    else
        # Recarregar configuração
        if ! run_command "fail2ban-client reload" "Recarregando configuração do Fail2Ban"; then
            error "Falha ao recarregar a configuração do Fail2Ban."
            return 1
        fi
    fi
    
    # Verificar se o serviço está em execução após a reinicialização
    if ! systemctl is-active --quiet "$FAIL2BAN_SERVICE"; then
        error "O serviço Fail2Ban não está em execução após a reinicialização."
        return 1
    fi
    
    log "SUCCESS" "Serviço Fail2Ban reiniciado com sucesso."
    return 0
}

# Função para configurar o Fail2Ban com as melhores práticas de segurança
secure_fail2ban() {
    local ignore_ips=${1:-''}
    
    log "HEADER" "CONFIGURAÇÃO DE SEGURANÇA DO FAIL2BAN"
    
    # Instalar o Fail2Ban, se necessário
    if ! install_fail2ban; then
        error "Falha na instalação/configuração do Fail2Ban."
        return 1
    fi
    
    # Configurar parâmetros básicos
    if ! configure_fail2ban_basic "$ignore_ips"; then
        error "Falha ao configurar parâmetros básicos do Fail2Ban."
        return 1
    fi
    
    # Configurar proteção SSH
    if ! configure_ssh_protection; then
        error "Falha ao configurar proteção SSH no Fail2Ban."
        return 1
    }
    
    # Configurar proteção para serviços comuns
    local common_services=(
        # Formato: "servico" "/caminho/para/log" "max_retry" "bantime" "findtime" "porta"
        "apache-auth" "/var/log/apache2/error.log" "3" "24h" "10m" "http,https"
        "nginx-http-auth" "/var/log/nginx/error.log" "3" "24h" "10m" "http,https"
        "postfix" "/var/log/mail.log" "5" "12h" "10m" "smtp,ssmtp,submission,imap2,imap3,imaps,pop3,pop3s"
        "dovecot" "/var/log/mail.log" "5" "12h" "10m" "pop3,pop3s,imap,imaps,submission,submission-465,sieve"
        "mysql" "/var/log/mysql/error.log" "3" "24h" "10m" "3306"
        "vsftpd" "/var/log/vsftpd.log" "3" "24h" "10m" "ftp,ftp-data,ftps,ftps-data"
        "recidive" "/var/log/fail2ban.log" "5" "1w" "1d" ""
    )
    
    # Configurar proteção para serviços comuns
    for ((i=0; i<${#common_services[@]}; i+=6)); do
        local service="${common_services[$i]}"
        local log_path="${common_services[$i+1]}"
        local max_retry="${common_services[$i+2]}"
        local bantime="${common_services[$i+3]}"
        local findtime="${common_services[$i+4]}"
        local port="${common_services[$i+5]}"
        
        # Verificar se o arquivo de log existe
        if [ -f "$log_path" ]; then
            if ! configure_service_protection "$service" "$log_path" "$max_retry" "$bantime" "$findtime" "$port"; then
                log "WARN" "Falha ao configurar proteção para $service. Continuando..."
            fi
        fi
    done
    
    # Configurar proteção para o SSH em portas não padrão
    local ssh_port
    ssh_port=$(grep -i "^\s*port\s" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    
    if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
        log "INFO" "Detectada porta SSH personalizada: $ssh_port"
        
        # Atualizar a porta na configuração do Fail2Ban
        if ! update_config_file "$FAIL2BAN_JAIL_LOCAL" "^\s*port\s*=\s*ssh" "port = $ssh_port"; then
            log "WARN" "Falha ao atualizar a porta SSH no Fail2Ban para $ssh_port."
        fi
    fi
    
    # Reiniciar o serviço Fail2Ban para aplicar as alterações
    if ! restart_fail2ban; then
        error "Falha ao reiniciar o serviço Fail2Ban."
        return 1
    fi
    
    log "SUCCESS" "Configuração de segurança do Fail2Ban concluída com sucesso!"
    return 0
}

# Função para gerar um relatório de segurança do Fail2Ban
generate_fail2ban_security_report() {
    log "HEADER" "RELATÓRIO DE SEGURANÇA DO FAIL2BAN"
    
    # Verificar instalação do Fail2Ban
    if ! check_fail2ban_installed; then
        log "WARN" "O Fail2Ban não está instalado."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_fail2ban_service_running; then
        log "WARN" "O serviço Fail2Ban não está em execução."
    else
        log "INFO" "Serviço Fail2Ban está em execução."
        
        # Exibir status detalhado
        log "INFO" "Status detalhado do Fail2Ban:"
        if ! run_command "fail2ban-client status"; then
            log "WARN" "Não foi possível obter o status detalhado do Fail2Ban."
        fi
        
        # Listar serviços ativos e seus status
        log "INFO" "\nServiços ativos no Fail2Ban:"
        local services
        services=$(fail2ban-client status | grep -i 'Jail list' | sed 's/^[^:]*://' | tr ',' ' ' | xargs)
        
        if [ -z "$services" ]; then
            log "WARN" "Nenhum serviço ativo encontrado no Fail2Ban."
        else
            for service in $services; do
                log "INFO" "\nStatus do serviço $service:"
                if ! run_command "fail2ban-client status $service"; then
                    log "WARN" "Falha ao obter status para o serviço $service"
                fi
            done
        fi
    fi
    
    # Verificar configurações de segurança
    log "INFO" "\nVerificando configurações de segurança do Fail2Ban..."
    
    # Verificar se o arquivo de configuração local existe
    if [ -f "$FAIL2BAN_JAIL_LOCAL" ]; then
        log "INFO" "Arquivo de configuração local encontrado: $FAIL2BAN_JAIL_LOCAL"
        
        # Verificar configurações importantes
        local ignore_ips
        ignore_ips=$(grep -i "^\s*ignoreip\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null || echo "")
        
        if [ -n "$ignore_ips" ]; then
            log "INFO" "IPs na whitelist: $ignore_ips"
        else
            log "WARN" "Nenhum IP na whitelist (recomendado adicionar IPs confiáveis)."
        fi
        
        # Verificar configurações de banimento
        local bantime
        bantime=$(grep -i "^\s*bantime\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 || echo "")
        
        if [ -n "$bantime" ]; then
            log "INFO" "Tempo de banimento padrão: $bantime"
        fi
        
        local findtime
        findtime=$(grep -i "^\s*findtime\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 || echo "")
        
        if [ -n "$findtime" ]; then
            log "INFO" "Janela de tempo para contagem de tentativas: $findtime"
        fi
        
        local maxretry
        maxretry=$(grep -i "^\s*maxretry\s*=" "$FAIL2BAN_JAIL_LOCAL" 2>/dev/null | head -1 || echo "")
        
        if [ -n "$maxretry" ]; then
            log "INFO" "Número máximo de tentativas antes do banimento: $maxretry"
        fi
    else
        log "WARN" "Arquivo de configuração local não encontrado: $FAIL2BAN_JAIL_LOCAL"
    fi
    
    log "INFO" "Relatório de segurança do Fail2Ban concluído."
    return 0
}

# Função principal do módulo Fail2Ban
fail2ban_main() {
    local action=$1
    local param1=$2
    local param2=$3
    
    case "$action" in
        "secure")
            secure_fail2ban "$param1"
            ;;
        "report")
            generate_fail2ban_security_report
            ;;
        "restart")
            restart_fail2ban
            ;;
        "unban")
            unban_ip "$param1" "$param2"
            ;;
        "whitelist")
            add_whitelist_ip "$param1"
            ;;
        "list-banned")
            list_banned_ips
            ;;
        *)
            log "ERROR" "Ação inválida. Uso: fail2ban_main <secure|report|restart|unban|whitelist|list-banned> [ip] [service]"
            return 1
            ;;
    esac
    
    return $?
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f fail2ban_main secure_fail2ban generate_fail2ban_security_report restart_fail2ban
