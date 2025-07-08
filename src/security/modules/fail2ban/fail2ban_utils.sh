#!/bin/bash
#
# Nome do Arquivo: fail2ban_utils.sh
#
# Descrição:
#   Módulo de funções utilitárias para configuração e gerenciamento do Fail2Ban.
#   Contém funções auxiliares para manipulação de configurações do Fail2Ban.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/fail2ban_utils.sh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar funções utilitárias de segurança
if [ -f "$(dirname "$0")/../../core/security_utils.sh" ]; then
    source "$(dirname "$0")/../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

# Caminhos de configuração do Fail2Ban
readonly FAIL2BAN_DIR="/etc/fail2ban"
readonly FAIL2BAN_JAIL_LOCAL="${FAIL2BAN_DIR}/jail.local"
readonly FAIL2BAN_JAIL_DEFAULT="${FAIL2BAN_DIR}/jail.d/defaults-debian.conf"
readonly FAIL2BAN_FILTER_DIR="${FAIL2BAN_DIR}/filter.d"
readonly FAIL2BAN_ACTION_DIR="${FAIL2BAN_DIR}/action.d"

#
# is_fail2ban_installed
#
# Descrição:
#   Verifica se o Fail2Ban está instalado no sistema.
#
# Retorno:
#   0 - Fail2Ban está instalado
#   1 - Fail2Ban não está instalado
#
is_fail2ban_installed() {
    if command -v fail2ban-client &> /dev/null; then
        return 0
    else
        return 1
    fi
}

#
# install_fail2ban
#
# Descrição:
#   Instala o Fail2Ban se não estiver instalado.
#
# Retorno:
#   0 - Fail2Ban instalado com sucesso ou já estava instalado
#   1 - Falha ao instalar o Fail2Ban
#
install_fail2ban() {
    if is_fail2ban_installed; then
        log "info" "Fail2Ban já está instalado."
        return 0
    fi
    
    log "info" "Instalando Fail2Ban..."
    
    # Detectar gerenciador de pacotes
    if command -v apt-get &> /dev/null; then
        if ! apt-get update || ! apt-get install -y fail2ban; then
            log "error" "Falha ao instalar o Fail2Ban via apt-get"
            return 1
        fi
    elif command -v yum &> /dev/null; then
        if ! yum install -y fail2ban; then
            log "error" "Falha ao instalar o Fail2Ban via yum"
            return 1
        fi
    elif command -v dnf &> /dev/null; then
        if ! dnf install -y fail2ban; then
            log "error" "Falha ao instalar o Fail2Ban via dnf"
            return 1
        fi
    else
        log "error" "Gerenciador de pacotes não suportado. Instale o Fail2Ban manualmente."
        return 1
    fi
    
    # Habilitar inicialização automática
    if command -v systemctl &> /dev/null; then
        systemctl enable fail2ban
    fi
    
    log "info" "Fail2Ban instalado com sucesso."
    return 0
}

#
# backup_fail2ban_config
#
# Descrição:
#   Cria um backup dos arquivos de configuração do Fail2Ban.
#
# Parâmetros:
#   $1 - Diretório de backup (opcional, padrão: /etc/fail2ban/backup_YYYYMMDD_HHMMSS)
#
# Retorno:
#   0 - Backup realizado com sucesso
#   1 - Falha ao criar backup
#
backup_fail2ban_config() {
    local backup_dir="${1:-/etc/fail2ban/backup_$(date +%Y%m%d_%H%M%S)}"
    local fail2ban_files=(
        "${FAIL2BAN_JAIL_LOCAL}"
        "${FAIL2BAN_JAIL_DEFAULT}"
        "${FAIL2BAN_FILTER_DIR}"
        "${FAIL2BAN_ACTION_DIR}"
    )
    
    # Criar diretório de backup se não existir
    if [ ! -d "${backup_dir}" ]; then
        if ! mkdir -p "${backup_dir}"; then
            log "error" "Falha ao criar diretório de backup: ${backup_dir}"
            return 1
        fi
    fi
    
    # Fazer backup dos arquivos
    for item in "${fail2ban_files[@]}"; do
        if [ -e "${item}" ]; then
            local dest
            dest="${backup_dir}/$(basename "${item}")"
            
            if [ -d "${item}" ]; then
                if ! cp -r "${item}" "${backup_dir}/"; then
                    log "warn" "Falha ao fazer backup do diretório: ${item}"
                else
                    log "debug" "Backup do diretório criado: ${item}"
                fi
            else
                if ! cp "${item}" "${dest}"; then
                    log "warn" "Falha ao fazer backup do arquivo: ${item}"
                else
                    log "debug" "Backup do arquivo criado: ${item}"
                fi
            fi
        fi
    done
    
    log "info" "Backup dos arquivos de configuração do Fail2Ban criado em: ${backup_dir}"
    echo "${backup_dir}"
    return 0
}

#
# is_fail2ban_running
#
# Descrição:
#   Verifica se o serviço Fail2Ban está em execução.
#
# Retorno:
#   0 - Fail2Ban está em execução
#   1 - Fail2Ban não está em execução
#
is_fail2ban_running() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet fail2ban; then
            return 0
        fi
    elif command -v service &> /dev/null; then
        if service fail2ban status &> /dev/null; then
            return 0
        fi
    elif pgrep -x "fail2ban-server" &> /dev/null; then
        return 0
    fi
    
    return 1
}

#
# restart_fail2ban
#
# Descrição:
#   Reinicia o serviço Fail2Ban.
#
# Retorno:
#   0 - Serviço reiniciado com sucesso
#   1 - Falha ao reiniciar o serviço
#
restart_fail2ban() {
    log "info" "Reiniciando o serviço Fail2Ban..."
    
    if command -v systemctl &> /dev/null; then
        if ! systemctl restart fail2ban; then
            log "error" "Falha ao reiniciar o serviço Fail2Ban via systemctl"
            return 1
        fi
    elif command -v service &> /dev/null; then
        if ! service fail2ban restart; then
            log "error" "Falha ao reiniciar o serviço Fail2Ban via service"
            return 1
        fi
    else
        if ! /etc/init.d/fail2ban restart; then
            log "error" "Falha ao reiniciar o serviço Fail2Ban via init.d"
            return 1
        fi
    fi
    
    # Verificar se o serviço está em execução
    if ! is_fail2ban_running; then
        log "error" "O serviço Fail2Ban não está em execução após a reinicialização"
        return 1
    fi
    
    log "info" "Serviço Fail2Ban reiniciado com sucesso."
    return 0
}

#
# configure_jail
#
# Descrição:
#   Configura uma seção de jail no arquivo de configuração do Fail2Ban.
#
# Parâmetros:
#   $1 - Nome do jail
#   $2 - Seção de configuração no formato "chave = valor" (uma por linha)
#
# Retorno:
#   0 - Configuração aplicada com sucesso
#   1 - Falha ao aplicar a configuração
#
configure_jail() {
    local jail_name="$1"
    local config_section="$2"
    local temp_file
    
    # Verificar se o arquivo jail.local existe, se não, criar a partir do padrão
    if [ ! -f "${FAIL2BAN_JAIL_LOCAL}" ]; then
        if [ -f "${FAIL2BAN_JAIL_DEFAULT}" ]; then
            cp "${FAIL2BAN_JAIL_DEFAULT}" "${FAIL2BAN_JAIL_LOCAL}"
        else
            touch "${FAIL2BAN_JAIL_LOCAL}"
        fi
    fi
    
    # Criar arquivo temporário
    temp_file=$(mktemp)
    
    # Verificar se a seção já existe
    if grep -q "^\[${jail_name}\]" "${FAIL2BAN_JAIL_LOCAL}"; then
        # Atualizar seção existente
        awk -v jail="[${jail_name}]" -v new_config="${config_section}" '
            BEGIN { in_section = 0; printed = 0 }
            /^\[.*\]/ { 
                if (in_section) { 
                    print new_config; 
                    printed = 1; 
                    in_section = 0 
                } 
                if ($0 == jail) { in_section = 1 } 
            } 
            !in_section { print } 
            END { if (!printed) print jail "\n" new_config }
        ' "${FAIL2BAN_JAIL_LOCAL}" > "${temp_file}" || {
            log "error" "Falha ao processar o arquivo de configuração"
            rm -f "${temp_file}"
            return 1
        }
    else
        # Adicionar nova seção
        cp "${FAIL2BAN_JAIL_LOCAL}" "${temp_file}"
        echo -e "\n[${jail_name}]\n${config_section}" >> "${temp_file}"
    fi
    
    # Verificar se o arquivo temporário está vazio
    if [ ! -s "${temp_file}" ]; then
        log "error" "O arquivo temporário está vazio após a atualização"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Fazer backup do arquivo original
    if ! cp "${FAIL2BAN_JAIL_LOCAL}" "${FAIL2BAN_JAIL_LOCAL}.bak.$(date +%s)"; then
        log "error" "Falha ao criar backup do arquivo de configuração"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Substituir o arquivo original
    if ! mv "${temp_file}" "${FAIL2BAN_JAIL_LOCAL}"; then
        log "error" "Falha ao atualizar o arquivo de configuração"
        rm -f "${temp_file}"
        return 1
    fi
    
    log "info" "Configuração do jail '${jail_name}' atualizada com sucesso."
    return 0
}

#
# unban_ip
#
# Descrição:
#   Remove um IP da lista de banidos do Fail2Ban.
#
# Parâmetros:
#   $1 - Endereço IP a ser desbanido
#
# Retorno:
#   0 - IP desbanido com sucesso
#   1 - Falha ao desbanir o IP
#
unban_ip() {
    local ip="$1"
    
    # Validar endereço IP
    if ! validate_ip "${ip}"; then
        log "error" "Endereço IP inválido: ${ip}"
        return 1
    fi
    
    # Verificar se o IP está banido
    if ! fail2ban-client status | grep -q "${ip}"; then
        log "info" "O IP ${ip} não está na lista de banidos."
        return 0
    fi
    
    # Desbanir o IP
    if ! fail2ban-client set sshd unbanip "${ip}"; then
        log "error" "Falha ao desbanir o IP ${ip}"
        return 1
    fi
    
    log "info" "IP ${ip} desbanido com sucesso."
    return 0
}

#
# get_banned_ips
#
# Descrição:
#   Obtém a lista de IPs atualmente banidos pelo Fail2Ban.
#
# Retorno:
#   Lista de IPs banidos, um por linha
#
get_banned_ips() {
    if ! is_fail2ban_installed; then
        log "error" "Fail2Ban não está instalado"
        return 1
    fi
    
    if ! is_fail2ban_running; then
        log "error" "O serviço Fail2Ban não está em execução"
        return 1
    fi
    
    # Obter lista de jails ativos
    local jails
    jails=$(fail2ban-client status | grep 'Jail list:' | sed 's/^[^:]*:[\t ]*//' | sed 's/,//g')
    
    if [ -z "${jails}" ]; then
        log "warn" "Nenhum jail ativo encontrado"
        return 0
    fi
    
    # Obter IPs banidos de cada jail
    local ip_list=""
    for jail in ${jails}; do
        local banned_ips
        banned_ips=$(fail2ban-client status "${jail}" | grep 'Banned IP list:' | sed 's/^[^:]*:[\t ]*//')
        
        if [ -n "${banned_ips}" ]; then
            ip_list="${ip_list}${ip_list:+ }${banned_ips}"
        fi
    done
    
    # Remover duplicados e formatar saída
    echo "${ip_list}" | tr ' ' '\n' | sort -u
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f is_fail2ban_installed install_fail2ban backup_fail2ban_config \
         is_fail2ban_running restart_fail2ban configure_jail unban_ip get_banned_ips
