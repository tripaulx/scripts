#!/bin/bash
# ===================================================================
# Módulo: UFW (Uncomplicated Firewall)
# Arquivo: modules/ufw/ufw.sh
# Descrição: Módulo para gerenciar o firewall UFW
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
UFW_BACKUP_DIR="/etc/ufw/backups"

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

# Função para instalar o UFW
install_ufw() {
    log "INFO" "Verificando instalação do UFW..."
    
    if ! check_ufw_installed; then
        log "INFO" "Instalando o UFW (Uncomplicated Firewall)..."
        
        if ! run_command "apt-get update" "Atualizando lista de pacotes" || \
           ! run_command "apt-get install -y ufw" "Instalando o UFW"; then
            error "Falha ao instalar o UFW."
            return 1
        fi
        
        log "SUCCESS" "UFW instalado com sucesso."
    else
        log "INFO" "UFW já está instalado."
    fi
    
    return 0
}

# Função para habilitar o UFW
enable_ufw() {
    log "INFO" "Ativando o UFW..."
    
    # Verificar se o UFW já está ativado
    if ufw status | grep -q "Status: active"; then
        log "INFO" "UFW já está ativado."
        return 0
    fi
    
    # Configurar UFW para iniciar automaticamente na inicialização
    if ! run_command "systemctl enable ufw" "Habilitando inicialização automática do UFW"; then
        error "Falha ao habilitar a inicialização automática do UFW."
        return 1
    fi
    
    # Definir política padrão: negar todo o tráfego de entrada e permitir saída
    if ! run_command "ufw default deny incoming" "Configurando política padrão para tráfego de entrada" || \
       ! run_command "ufw default allow outgoing" "Configurando política padrão para tráfego de saída"; then
        error "Falha ao configurar as políticas padrão do UFW."
        return 1
    fi
    
    # Ativar o UFW
    if ! run_command "yes | ufw --force enable" "Ativando o UFW"; then
        error "Falha ao ativar o UFW."
        return 1
    fi
    
    log "SUCCESS" "UFW ativado com sucesso."
    return 0
}

# Função para fazer backup das regras do UFW
backup_ufw_rules() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="${UFW_BACKUP_DIR}/ufw_backup_${timestamp}"
    
    log "INFO" "Criando backup das regras do UFW em ${backup_dir}..."
    
    # Criar diretório de backup
    if ! mkdir -p "$backup_dir"; then
        error "Falha ao criar diretório de backup: $backup_dir"
        return 1
    fi
    
    # Fazer backup dos arquivos de configuração
    local files_to_backup=(
        "$UFW_CONFIG_FILE"
        "$UFW_BEFORE_RULES_FILE"
        "$UFW_AFTER_RULES_FILE"
        "$UFW_USER_RULES_FILE"
        "/etc/ufw/user6.rules"
        "/etc/ufw/before6.rules"
        "/etc/ufw/after6.rules"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            if ! cp -p "$file" "${backup_dir}/" 2>/dev/null; then
                log "WARN" "Falha ao fazer backup de $file"
            fi
        fi
    done
    
    # Fazer backup do status atual
    ufw status verbose > "${backup_dir}/ufw_status.txt" 2>&1
    
    log "SUCCESS" "Backup das regras do UFW criado em ${backup_dir}"
    return 0
}

# Função para permitir uma porta no UFW
allow_port() {
    local port=$1
    local protocol=${2:-tcp}
    local comment=${3:-""}
    
    # Validar parâmetros
    if ! is_valid_port "$port"; then
        error "Número de porta inválido: $port"
        return 1
    fi
    
    # Verificar se a regra já existe
    if ufw status | grep -q "^${port}/${protocol}"; then
        log "INFO" "A porta ${port}/${protocol} já está configurada no UFW."
        return 0
    fi
    
    # Adicionar comentário se fornecido
    local ufw_cmd="ufw allow ${port}/${protocol}"
    if [ -n "$comment" ]; then
        ufw_cmd+=" comment '${comment}'"
    fi
    
    # Executar comando UFW
    if ! run_command "$ufw_cmd" "Permitindo ${port}/${protocol} no UFW"; then
        error "Falha ao permitir a porta ${port}/${protocol} no UFW."
        return 1
    fi
    
    log "SUCCESS" "Porta ${port}/${protocol} permitida no UFW."
    return 0
}

# Função para negar uma porta no UFW
deny_port() {
    local port=$1
    local protocol=${2:-tcp}
    
    # Validar parâmetros
    if ! is_valid_port "$port"; then
        error "Número de porta inválido: $port"
        return 1
    }
    
    # Verificar se a regra já existe
    if ufw status | grep -q "^${port}/${protocol}.*DENY"; then
        log "INFO" "A porta ${port}/${protocol} já está configurada para ser negada no UFW."
        return 0
    fi
    
    # Executar comando UFW
    if ! run_command "ufw deny ${port}/${protocol}" "Negando ${port}/${protocol} no UFW"; then
        error "Falha ao negar a porta ${port}/${protocol} no UFW."
        return 1
    fi
    
    log "SUCCESS" "Porta ${port}/${protocol} negada no UFW."
    return 0
}

# Função para permitir tráfego de um endereço IP específico
allow_ip() {
    local ip=$1
    local port=${2:-""}
    local protocol=${3:-tcp}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Construir o comando UFW
    local ufw_cmd="ufw allow from ${ip}"
    
    # Adicionar porta se fornecida
    if [ -n "$port" ]; then
        if ! is_valid_port "$port"; then
            error "Número de porta inválido: $port"
            return 1
        fi
        ufw_cmd+=" to any port ${port} proto ${protocol}"
    fi
    
    # Verificar se a regra já existe
    if ufw status | grep -q "^${ip}.*ALLOW"; then
        if [ -n "$port" ]; then
            if ufw status | grep -q "^${ip}.*${port}/${protocol}.*ALLOW"; then
                log "INFO" "A regra para o IP ${ip} na porta ${port}/${protocol} já existe no UFW."
                return 0
            fi
        else
            log "INFO" "O IP ${ip} já tem permissão total no UFW."
            return 0
        fi
    fi
    
    # Executar comando UFW
    if ! run_command "$ufw_cmd" "Permitindo tráfego de ${ip}"; then
        error "Falha ao permitir tráfego do IP ${ip}."
        return 1
    fi
    
    log "SUCCESS" "Tráfego de ${ip} permitido no UFW."
    return 0
}

# Função para negar tráfego de um endereço IP específico
deny_ip() {
    local ip=$1
    local port=${2:-""}
    local protocol=${3:-tcp}
    
    # Validar endereço IP
    if ! is_valid_ip "$ip"; then
        error "Endereço IP inválido: $ip"
        return 1
    fi
    
    # Construir o comando UFW
    local ufw_cmd="ufw deny from ${ip}"
    
    # Adicionar porta se fornecida
    if [ -n "$port" ]; then
        if ! is_valid_port "$port"; then
            error "Número de porta inválido: $port"
            return 1
        fi
        ufw_cmd+=" to any port ${port} proto ${protocol}"
    fi
    
    # Verificar se a regra já existe
    if ufw status | grep -q "^${ip}.*DENY"; then
        if [ -n "$port" ]; then
            if ufw status | grep -q "^${ip}.*${port}/${protocol}.*DENY"; then
                log "INFO" "A regra para negar o IP ${ip} na porta ${port}/${protocol} já existe no UFW."
                return 0
            fi
        else
            log "INFO" "O IP ${ip} já está bloqueado no UFW."
            return 0
        fi
    fi
    
    # Executar comando UFW
    if ! run_command "$ufw_cmd" "Negando tráfego de ${ip}"; then
        error "Falha ao negar tráfego do IP ${ip}."
        return 1
    fi
    
    log "SUCCESS" "Tráfego de ${ip} negado no UFW."
    return 0
}

# Função para remover uma regra do UFW
delete_rule() {
    local rule_num=$1
    
    # Validar parâmetro
    if [ -z "$rule_num" ] || ! [[ "$rule_num" =~ ^[0-9]+$ ]]; then
        error "Número de regra inválido: $rule_num"
        return 1
    fi
    
    # Verificar se a regra existe
    if ! ufw status numbered | grep -q "^\[ *${rule_num}\]"; then
        error "Regra número ${rule_num} não encontrada no UFW."
        return 1
    fi
    
    # Remover a regra
    if ! run_command "yes | ufw delete ${rule_num}" "Removendo regra número ${rule_num}"; then
        error "Falha ao remover a regra número ${rule_num} do UFW."
        return 1
    fi
    
    log "SUCCESS" "Regra número ${rule_num} removida do UFW."
    return 0
}

# Função para listar as regras do UFW
list_rules() {
    log "INFO" "Listando regras do UFW:"
    
    if ! run_command "ufw status verbose" "Listando regras do UFW"; then
        error "Falha ao listar as regras do UFW."
        return 1
    fi
    
    return 0
}

# Função para reiniciar o UFW
restart_ufw() {
    log "INFO" "Reiniciando o UFW..."
    
    # Verificar se o UFW está instalado
    if ! check_ufw_installed; then
        error "O UFW não está instalado. Instale-o primeiro."
        return 1
    fi
    
    # Verificar se o UFW está ativado
    if ! ufw status | grep -q "Status: active"; then
        log "WARN" "O UFW não está ativado. Ativando..."
        if ! enable_ufw; then
            error "Falha ao ativar o UFW."
            return 1
        fi
    fi
    
    # Recarregar as regras do UFW
    if ! run_command "ufw reload" "Recarregando as regras do UFW"; then
        error "Falha ao recarregar as regras do UFW."
        return 1
    fi
    
    log "SUCCESS" "UFW reiniciado com sucesso."
    return 0
}

# Função para configurar o UFW com as melhores práticas de segurança
secure_ufw() {
    local ssh_port=${1:-22}
    
    log "HEADER" "CONFIGURAÇÃO DE SEGURANÇA DO UFW"
    
    # Instalar o UFW, se necessário
    if ! install_ufw; then
        error "Falha na instalação/configuração do UFW."
        return 1
    fi
    
    # Fazer backup das regras atuais
    if ! backup_ufw_rules; then
        log "WARN" "Não foi possível fazer backup das regras atuais do UFW. Continuando..."
    fi
    
    # Habilitar o UFW
    if ! enable_ufw; then
        error "Falha ao ativar o UFW."
        return 1
    fi
    
    # Permitir conexões SSH (na porta especificada)
    if ! allow_port "$ssh_port" "tcp" "SSH"; then
        error "Falha ao permitir a porta SSH (${ssh_port}/tcp) no UFW."
        return 1
    fi
    
    # Permitir tráfego HTTP (80/tcp)
    if ! allow_port 80 tcp "HTTP"; then
        error "Falha ao permitir a porta HTTP (80/tcp) no UFW."
        return 1
    fi
    
    # Permitir tráfego HTTPS (443/tcp)
    if ! allow_port 443 tcp "HTTPS"; then
        error "Falha ao permitir a porta HTTPS (443/tcp) no UFW."
        return 1
    end
    
    # Habilitar proteção contra ataques de força bruta
    if ! configure_ufw_bruteforce_protection; then
        log "WARN" "Não foi possível configurar a proteção contra força bruta no UFW."
    fi
    
    # Habilitar logging
    if ! run_command "ufw logging on" "Habilitando logs do UFW"; then
        log "WARN" "Não foi possível habilitar os logs do UFW."
    fi
    
    # Recarregar as regras do UFW
    if ! restart_ufw; then
        error "Falha ao recarregar as regras do UFW."
        return 1
    end
    
    log "SUCCESS" "Configuração de segurança do UFW concluída com sucesso!"
    return 0
}

# Função para configurar proteção contra força bruta no UFW
configure_ufw_bruteforce_protection() {
    log "INFO" "Configurando proteção contra força bruta no UFW..."
    
    # Verificar se o UFW está instalado
    if ! check_ufw_installed; then
        error "O UFW não está instalado. Instale-o primeiro."
        return 1
    fi
    
    # Verificar se o arquivo de configuração do UFW existe
    if [ ! -f "$UFW_BEFORE_RULES_FILE" ]; then
        error "Arquivo de regras do UFW não encontrado: $UFW_BEFORE_RULES_FILE"
        return 1
    fi
    
    # Fazer backup do arquivo de regras
    if ! backup_file "$UFW_BEFORE_RULES_FILE" "${UFW_BEFORE_RULES_FILE}.bak"; then
        error "Falha ao fazer backup do arquivo de regras do UFW."
        return 1
    fi
    
    # Adicionar regras para proteção contra força bruta
    local rules="# Proteção contra força bruta SSH\n"
    rules+=":ufw-http - [0:0]\n"
    rules+=":ufw-http-logdrop - [0:0]\n\n"
    
    # Regras para limitar tentativas de conexão
    rules+="# Limitar tentativas de conexão SSH\n"
    rules+="-A ufw-before-input -p tcp --dport 22 -m state --state NEW -m recent --name SSH --set\n"
    rules+="-A ufw-before-input -p tcp --dport 22 -m state --state NEW -m recent --name SSH --update --seconds 60 --hitcount 4 -j ufw-http-logdrop\n\n"
    
    # Aplicar as regras
    if ! echo -e "$rules" | tee -a "$UFW_BEFORE_RULES_FILE" > /dev/null; then
        error "Falha ao adicionar as regras de proteção contra força bruta."
        return 1
    fi
    
    log "SUCCESS" "Proteção contra força bruta configurada com sucesso no UFW."
    return 0
}

# Função para gerar um relatório de segurança do UFW
generate_ufw_security_report() {
    log "HEADER" "RELATÓRIO DE SEGURANÇA DO UFW"
    
    # Verificar instalação do UFW
    if ! check_ufw_installed; then
        log "WARN" "O UFW (Uncomplicated Firewall) não está instalado."
        return 1
    fi
    
    # Verificar se o serviço está em execução
    if ! check_ufw_service_running; then
        log "WARN" "O serviço UFW não está em execução."
    fi
    
    # Verificar se o UFW está ativado
    if ! check_ufw_enabled; then
        log "WARN" "O UFW não está ativado."
    else
        log "INFO" "UFW está ativado."
        
        # Exibir status detalhado
        log "INFO" "Status detalhado do UFW:"
        if ! run_command "ufw status verbose"; then
            log "WARN" "Não foi possível obter o status detalhado do UFW."
        fi
        
        # Verificar portas abertas
        log "INFO" "Portas abertas no UFW:"
        if ! run_command "ufw status | grep -E '^[0-9]' | sort -n"; then
            log "WARN" "Não foi possível listar as portas abertas no UFW."
        fi
    fi
    
    # Verificar se o logging está habilitado
    if ufw status verbose | grep -q "Logging: on"; then
        log "PASS" "Logging do UFW está habilitado."
    else
        log "WARN" "Logging do UFW está desabilitado (recomendado habilitar)."
    fi
    
    log "INFO" "Relatório de segurança do UFW concluído."
    return 0
}

# Função principal do módulo UFW
ufw_main() {
    local action=$1
    local param1=$2
    local param2=$3
    
    case "$action" in
        "secure")
            secure_ufw "$param1"
            ;;
        "report")
            generate_ufw_security_report
            ;;
        "restart")
            restart_ufw
            ;;
        "allow")
            allow_port "$param1" "$param2"
            ;;
        "deny")
            deny_port "$param1" "$param2"
            ;;
        "allow-ip")
            allow_ip "$param1" "$param2"
            ;;
        "deny-ip")
            deny_ip "$param1" "$param2"
            ;;
        "delete")
            delete_rule "$param1"
            ;;
        "list")
            list_rules
            ;;
        *)
            log "ERROR" "Ação inválida. Uso: ufw_main <secure|report|restart|allow|deny|allow-ip|deny-ip|delete|list> [port] [protocol]"
            return 1
            ;;
    esac
    
    return $?
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f ufw_main secure_ufw generate_ufw_security_report restart_ufw
