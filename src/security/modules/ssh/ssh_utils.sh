#!/bin/bash
#
# Nome do Arquivo: ssh_utils.sh
#
# Descrição:
#   Módulo de funções utilitárias para configuração e gerenciamento do SSH.
#   Contém funções auxiliares para manipulação de configurações SSH.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/ssh_utils.sh"
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

# Caminho para o arquivo de configuração do SSH
readonly SSHD_CONFIG="/etc/ssh/sshd_config"

#
# backup_ssh_config
#
# Descrição:
#   Cria um backup do arquivo de configuração do SSH.
#
# Parâmetros:
#   $1 - Diretório de backup (opcional, padrão: /etc/ssh/backup_YYYYMMDD_HHMMSS)
#
# Retorno:
#   0 - Backup realizado com sucesso
#   1 - Falha ao criar backup
#
backup_ssh_config() {
    local backup_dir="${1:-/etc/ssh/backup_$(date +%Y%m%d_%H%M%S)}"
    
    # Criar diretório de backup se não existir
    if [ ! -d "${backup_dir}" ]; then
        if ! mkdir -p "${backup_dir}"; then
            log "error" "Falha ao criar diretório de backup: ${backup_dir}"
            return 1
        fi
    fi
    
    # Criar backup do arquivo de configuração
    if [ -f "${SSHD_CONFIG}" ]; then
        local backup_file
        backup_file="${backup_dir}/sshd_config.$(date +%Y%m%d_%H%M%S).bak"
        
        if ! cp "${SSHD_CONFIG}" "${backup_file}"; then
            log "error" "Falha ao criar backup do arquivo de configuração SSH"
            return 1
        fi
        
        log "info" "Backup do arquivo de configuração SSH criado em: ${backup_file}"
        echo "${backup_file}"
        return 0
    else
        log "error" "Arquivo de configuração SSH não encontrado: ${SSHD_CONFIG}"
        return 1
    fi
}

#
# update_ssh_setting
#
# Descrição:
#   Atualiza uma configuração específica no arquivo de configuração do SSH.
#   Se a configuração já existir, ela será atualizada. Caso contrário, será adicionada ao final do arquivo.
#
# Parâmetros:
#   $1 - Nome da configuração (ex: Port, PermitRootLogin)
#   $2 - Valor da configuração
#   $3 - Arquivo de configuração (opcional, padrão: /etc/ssh/sshd_config)
#
# Retorno:
#   0 - Configuração atualizada com sucesso
#   1 - Falha ao atualizar a configuração
#
update_ssh_setting() {
    local setting="$1"
    local value="$2"
    local config_file="${3:-${SSHD_CONFIG}}"
    local temp_file
    
    # Verificar se o arquivo de configuração existe
    if [ ! -f "${config_file}" ]; then
        log "error" "Arquivo de configuração não encontrado: ${config_file}"
        return 1
    fi
    
    # Criar arquivo temporário
    temp_file=$(mktemp)
    
    # Atualizar configuração
    if grep -qE "^[[:space:]]*#?[[:space:]]*${setting}[[:space:]]" "${config_file}"; then
        # Configuração existe, atualizar
        sed -E "s/^[[:space:]]*#?[[:space:]]*${setting}[[:space:]]+.*/${setting} ${value}/" "${config_file}" > "${temp_file}"
    else
        # Configuração não existe, adicionar
        cp "${config_file}" "${temp_file}"
        echo "${setting} ${value}" >> "${temp_file}"
    fi
    
    # O sed não retorna um código de erro útil aqui, então a verificação é movida para depois da substituição do arquivo
    
    # Verificar se o arquivo temporário está vazio
    if [ ! -s "${temp_file}" ]; then
        log "error" "O arquivo temporário está vazio após a atualização"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Fazer backup do arquivo original
    if ! cp "${config_file}" "${config_file}.bak.$(date +%s)"; then
        log "error" "Falha ao criar backup do arquivo de configuração"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Substituir o arquivo original
    if ! mv "${temp_file}" "${config_file}"; then
        log "error" "Falha ao atualizar o arquivo de configuração"
        rm -f "${temp_file}"
        return 1
    fi
    
    log "info" "Configuração atualizada: ${setting} ${value}"
    return 0
}

#
# generate_ssh_key
#
# Descrição:
#   Gera um novo par de chaves SSH para um usuário específico.
#
# Parâmetros:
#   $1 - Nome do usuário
#   $2 - Tipo de chave (padrão: ed25519)
#   $3 - Comentário para a chave (opcional)
#
# Retorno:
#   0 - Chave gerada com sucesso
#   1 - Falha ao gerar a chave
#
generate_ssh_key() {
    local username="$1"
    local key_type="${2:-ed25519}"
    local comment="${3:-${username}@$(hostname)}"
    local ssh_dir="/home/${username}/.ssh"
    local key_file="${ssh_dir}/id_${key_type}"
    
    # Verificar se o usuário existe
    if ! id -u "${username}" &> /dev/null; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Criar diretório .ssh se não existir
    if [ ! -d "${ssh_dir}" ]; then
        if ! mkdir -p "${ssh_dir}"; then
            log "error" "Falha ao criar diretório .ssh para o usuário ${username}"
            return 1
        fi
        chmod 700 "${ssh_dir}"
        chown "${username}:${username}" "${ssh_dir}"
    fi
    
    # Gerar chave SSH
    if ! ssh-keygen -t "${key_type}" -f "${key_file}" -N "" -C "${comment}"; then
        log "error" "Falha ao gerar chave SSH para o usuário ${username}"
        return 1
    fi
    
    # Ajustar permissões
    chmod 600 "${key_file}" "${key_file}.pub"
    chown -R "${username}:${username}" "${ssh_dir}"
    
    log "info" "Chave SSH gerada com sucesso para o usuário ${username}"
    echo "${key_file}.pub"
    return 0
}

#
# configure_ssh_port
#
# Descrição:
#   Configura a porta do servidor SSH.
#
# Parâmetros:
#   $1 - Número da porta (opcional, se não informado, será solicitado)
#
# Retorno:
#   0 - Porta configurada com sucesso
#   1 - Falha ao configurar a porta
#
configure_ssh_port() {
    local port="$1"
    
    # Se a porta não foi fornecida, solicitar ao usuário
    if [ -z "${port}" ]; then
        while true; do
            read -rp "Informe a porta SSH desejada (padrão: 22): " port
            port=${port:-22}
            
            # Validar número da porta
            if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
                log "error" "Por favor, informe um número de porta válido."
                continue
            fi
            
            if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
                log "error" "A porta deve estar entre 1 e 65535."
                continue
            fi
            
            # Verificar se a porta já está em uso
            if is_port_in_use "${port}"; then
                log "warn" "A porta ${port} já está em uso por outro serviço."
                if ! confirm_action "Deseja continuar mesmo assim?"; then
                    continue
                fi
            fi
            
            break
        done
    fi
    
    # Atualizar configuração da porta
    if ! update_ssh_setting "Port" "${port}"; then
        log "error" "Falha ao configurar a porta SSH"
        return 1
    fi
    
    log "info" "Porta SSH configurada para: ${port}"
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f backup_ssh_config update_ssh_setting generate_ssh_key configure_ssh_port
