#!/bin/bash
#
# Nome do Arquivo: ufw_utils.sh
#
# Descrição:
#   Módulo de funções utilitárias para configuração e gerenciamento do UFW.
#   Contém funções auxiliares para manipulação de regras de firewall.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/ufw_utils.sh"
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

# Caminho para o arquivo de configuração do UFW
readonly UFW_BEFORE_RULES="/etc/ufw/before.rules"
readonly UFW_DEFAULT="/etc/default/ufw"

#
# is_ufw_installed
#
# Descrição:
#   Verifica se o UFW está instalado no sistema.
#
# Retorno:
#   0 - UFW está instalado
#   1 - UFW não está instalado
#
is_ufw_installed() {
    if command -v ufw &> /dev/null; then
        return 0
    else
        return 1
    fi
}

#
# install_ufw
#
# Descrição:
#   Instala o UFW se não estiver instalado.
#
# Retorno:
#   0 - UFW instalado com sucesso ou já estava instalado
#   1 - Falha ao instalar o UFW
#
install_ufw() {
    if is_ufw_installed; then
        log "info" "UFW já está instalado."
        return 0
    fi
    
    log "info" "Instalando UFW..."
    
    # Detectar gerenciador de pacotes
    if command -v apt-get &> /dev/null; then
        if ! apt-get update || ! apt-get install -y ufw; then
            log "error" "Falha ao instalar o UFW via apt-get"
            return 1
        fi
    elif command -v yum &> /dev/null; then
        if ! yum install -y ufw; then
            log "error" "Falha ao instalar o UFW via yum"
            return 1
        fi
    elif command -v dnf &> /dev/null; then
        if ! dnf install -y ufw; then
            log "error" "Falha ao instalar o UFW via dnf"
            return 1
        fi
    else
        log "error" "Gerenciador de pacotes não suportado. Instale o UFW manualmente."
        return 1
    fi
    
    # Habilitar inicialização automática
    if command -v systemctl &> /dev/null; then
        systemctl enable ufw
    fi
    
    log "info" "UFW instalado com sucesso."
    return 0
}

#
# backup_ufw_config
#
# Descrição:
#   Cria um backup dos arquivos de configuração do UFW.
#
# Parâmetros:
#   $1 - Diretório de backup (opcional, padrão: /etc/ufw/backup_YYYYMMDD_HHMMSS)
#
# Retorno:
#   0 - Backup realizado com sucesso
#   1 - Falha ao criar backup
#
backup_ufw_config() {
    local backup_dir="${1:-/etc/ufw/backup_$(date +%Y%m%d_%H%M%S)}"
    local ufw_files=(
        "/etc/ufw/before.rules"
        "/etc/ufw/before6.rules"
        "/etc/ufw/after.rules"
        "/etc/ufw/after6.rules"
        "/etc/ufw/user.rules"
        "/etc/ufw/user6.rules"
        "/etc/default/ufw"
    )
    
    # Criar diretório de backup se não existir
    if [ ! -d "${backup_dir}" ]; then
        if ! mkdir -p "${backup_dir}"; then
            log "error" "Falha ao criar diretório de backup: ${backup_dir}"
            return 1
        fi
    fi
    
    # Fazer backup dos arquivos
    for file in "${ufw_files[@]}"; do
        if [ -f "${file}" ]; then
            if ! cp "${file}" "${backup_dir}/" 2>/dev/null; then
                log "warn" "Falha ao fazer backup de ${file}"
            else
                log "debug" "Backup de ${file} criado em ${backup_dir}/"
            fi
        fi
    done
    
    log "info" "Backup dos arquivos de configuração do UFW criado em: ${backup_dir}"
    echo "${backup_dir}"
    return 0
}

#
# is_ufw_active
#
# Descrição:
#   Verifica se o UFW está ativo.
#
# Retorno:
#   0 - UFW está ativo
#   1 - UFW está inativo
#
is_ufw_active() {
    if ufw status | grep -q 'Status: active'; then
        return 0
    else
        return 1
    fi
}

#
# enable_ufw
#
# Descrição:
#   Habilita o UFW com configurações padrão.
#
# Parâmetros:
#   $1 - Se definido como "noninteractive", não solicita confirmação
#
# Retorno:
#   0 - UFW habilitado com sucesso
#   1 - Falha ao habilitar o UFW
#
enable_ufw() {
    local noninteractive="$1"
    
    if is_ufw_active; then
        log "info" "UFW já está ativo."
        return 0
    fi
    
    log "info" "Habilitando UFW..."
    
    # Definir modo não interativo se solicitado
    local ufw_cmd="ufw --force"
    if [ "${noninteractive}" = "noninteractive" ]; then
        ufw_cmd="ufw --force --non-interactive"
    fi
    
    # Resetar todas as configurações
    if ! ${ufw_cmd} reset; then
        log "error" "Falha ao redefinir as configurações do UFW"
        return 1
    fi
    
    # Habilitar modo não interativo para comandos subsequentes
    export UFW_MANAGED_NOCONFIRM=1
    
    # Definir política padrão
    if ! ${ufw_cmd} default deny incoming; then
        log "error" "Falha ao definir política padrão de entrada"
        return 1
    fi
    
    if ! ${ufw_cmd} default allow outgoing; then
        log "error" "Falha ao definir política padrão de saída"
        return 1
    fi
    
    # Habilitar o UFW
    if ! ${ufw_cmd} enable; then
        log "error" "Falha ao habilitar o UFW"
        return 1
    fi
    
    log "info" "UFW habilitado com sucesso."
    return 0
}

#
# allow_port
#
# Descrição:
#   Adiciona uma regra para permitir tráfego em uma porta específica.
#
# Parâmetros:
#   $1 - Número da porta ou intervalo (ex: 80, 3000:4000)
#   $2 - Protocolo (opcional, padrão: tcp)
#   $3 - Descrição da regra (opcional)
#
# Retorno:
#   0 - Regra adicionada com sucesso
#   1 - Falha ao adicionar a regra
#
allow_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-}"
    local rule="allow"
    
    # Validar parâmetros
    if [ -z "${port}" ]; then
        log "error" "Número da porta não especificado"
        return 1
    fi
    
    # Adicionar comentário se fornecido
    if [ -n "${comment}" ]; then
        rule="${rule} comment '${comment}'"
    fi
    
    # Adicionar regra
    if ! ufw allow "${port}/${protocol}" ${rule}; then
        log "error" "Falha ao adicionar regra para a porta ${port}/${protocol}"
        return 1
    fi
    
    log "info" "Regra adicionada: permissão para ${port}/${protocol}${comment:+ (${comment})}"
    return 0
}

#
# deny_port
#
# Descrição:
#   Adiciona uma regra para negar tráfego em uma porta específica.
#
# Parâmetros:
#   $1 - Número da porta ou intervalo (ex: 80, 3000:4000)
#   $2 - Protocolo (opcional, padrão: tcp)
#   $3 - Descrição da regra (opcional)
#
# Retorno:
#   0 - Regra adicionada com sucesso
#   1 - Falha ao adicionar a regra
#
deny_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-}"
    local rule="deny"
    
    # Validar parâmetros
    if [ -z "${port}" ]; then
        log "error" "Número da porta não especificado"
        return 1
    fi
    
    # Adicionar comentário se fornecido
    if [ -n "${comment}" ]; then
        rule="${rule} comment '${comment}'"
    fi
    
    # Adicionar regra
    if ! ufw deny "${port}/${protocol}" ${rule}; then
        log "error" "Falha ao adicionar regra de negação para a porta ${port}/${protocol}"
        return 1
    fi
    
    log "info" "Regra de negação adicionada: ${port}/${protocol}${comment:+ (${comment})}"
    return 0
}

#
# allow_ip
#
# Descrição:
#   Permite o acesso a partir de um endereço IP específico.
#
# Parâmetros:
#   $1 - Endereço IP ou rede (ex: 192.168.1.1 ou 192.168.1.0/24)
#   $2 - Porta (opcional, se não fornecido, permite todo o tráfego)
#   $3 - Protocolo (opcional, padrão: tcp)
#
# Retorno:
#   0 - Regra adicionada com sucesso
#   1 - Falha ao adicionar a regra
#
allow_ip() {
    local ip="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    local rule="allow from ${ip}"
    
    # Validar parâmetros
    if [ -z "${ip}" ]; then
        log "error" "Endereço IP não especificado"
        return 1
    fi
    
    # Adicionar porta se fornecida
    if [ -n "${port}" ]; then
        rule="${rule} to any port ${port} proto ${protocol}"
    fi
    
    # Adicionar regra
    if ! ufw ${rule}; then
        log "error" "Falha ao adicionar regra para o IP ${ip}"
        return 1
    fi
    
    log "info" "Regra adicionada: permissão para ${ip}${port:+ na porta ${port}/${protocol}}"
    return 0
}

#
# deny_ip
#
# Descrição:
#   Nega o acesso a partir de um endereço IP específico.
#
# Parâmetros:
#   $1 - Endereço IP ou rede (ex: 192.168.1.1 ou 192.168.1.0/24)
#   $2 - Porta (opcional, se não fornecido, nega todo o tráfego)
#   $3 - Protocolo (opcional, padrão: tcp)
#
# Retorno:
#   0 - Regra adicionada com sucesso
#   1 - Falha ao adicionar a regra
#
deny_ip() {
    local ip="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    local rule="deny from ${ip}"
    
    # Validar parâmetros
    if [ -z "${ip}" ]; then
        log "error" "Endereço IP não especificado"
        return 1
    fi
    
    # Adicionar porta se fornecida
    if [ -n "${port}" ]; then
        rule="${rule} to any port ${port} proto ${protocol}"
    fi
    
    # Adicionar regra
    if ! ufw ${rule}; then
        log "error" "Falha ao adicionar regra de negação para o IP ${ip}"
        return 1
    fi
    
    log "info" "Regra de negação adicionada: ${ip}${port:+ na porta ${port}/${protocol}}"
    return 0
}

#
# enable_logging
#
# Descrição:
#   Habilita o registro de logs do UFW.
#
# Parâmetros:
#   $1 - Nível de log (low, medium, high, full, off, default: medium)
#
# Retorno:
#   0 - Log configurado com sucesso
#   1 - Falha ao configurar o log
#
enable_logging() {
    local level="${1:-medium}"
    
    # Validar nível de log
    case "${level}" in
        low|medium|high|full|off)
            # Nível válido, continuar
            ;;
        *)
            log "error" "Nível de log inválido: ${level}. Use: low, medium, high, full ou off"
            return 1
            ;;
    esac
    
    # Configurar nível de log
    if ! ufw logging "${level}"; then
        log "error" "Falha ao configurar o nível de log para ${level}"
        return 1
    fi
    
    log "info" "Log do UFW configurado para o nível: ${level}"
    return 0
}

#
# show_status
#
# Descrição:
#   Exibe o status atual do UFW.
#
# Retorno:
#   0 - Sucesso
#   1 - Falha ao obter o status
#
show_status() {
    log "info" "Status atual do UFW:"
    if ! ufw status verbose; then
        log "error" "Falha ao obter o status do UFW"
        return 1
    fi
    
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f is_ufw_installed install_ufw backup_ufw_config is_ufw_active enable_ufw \
         allow_port deny_port allow_ip deny_ip enable_logging show_status
