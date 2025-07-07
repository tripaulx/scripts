#!/bin/bash
#
# Nome do Arquivo: user_utils.sh
#
# Descrição:
#   Módulo de funções utilitárias para gerenciamento de usuários e grupos no sistema.
#   Contém funções para criar, modificar e remover usuários e grupos.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/user_utils.sh"
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

#
# user_exists
#
# Descrição:
#   Verifica se um usuário existe no sistema.
#
# Parâmetros:
#   $1 - Nome do usuário
#
# Retorno:
#   0 - Usuário existe
#   1 - Usuário não existe
#
user_exists() {
    local username="$1"
    
    if id -u "${username}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

#
# create_user
#
# Descrição:
#   Cria um novo usuário no sistema com configurações seguras.
#
# Parâmetros:
#   $1 - Nome do usuário
#   $2 - Nome completo do usuário (opcional)
#   $3 - Shell padrão (opcional, padrão: /bin/bash)
#   $4 - Diretório home (opcional, padrão: /home/username)
#
# Retorno:
#   0 - Usuário criado com sucesso
#   1 - Falha ao criar o usuário
#
create_user() {
    local username="$1"
    local fullname="${2:-}"
    local shell="${3:-/bin/bash}"
    local home_dir="${4:-/home/${username}}"
    local comment=""
    
    # Validar nome de usuário
    if ! validate_username "${username}"; then
        log "error" "Nome de usuário inválido: ${username}"
        return 1
    fi
    
    # Verificar se o usuário já existe
    if user_exists "${username}"; then
        log "warn" "O usuário '${username}' já existe"
        return 0
    fi
    
    # Configurar comentário (GECOS)
    if [ -n "${fullname}" ]; then
        comment="-c \"${fullname}\""
    fi
    
    # Comando para criar o usuário
    local useradd_cmd="useradd -m -d ${home_dir} -s ${shell} ${comment} ${username}"
    
    # Executar o comando
    log "info" "Criando usuário: ${username}"
    
    if ! eval "${useradd_cmd}"; then
        log "error" "Falha ao criar o usuário '${username}'"
        return 1
    fi
    
    log "info" "Usuário '${username}' criado com sucesso"
    return 0
}

#
# set_user_password
#
# Descrição:
#   Define ou altera a senha de um usuário.
#   Se nenhuma senha for fornecida, será gerada uma senha aleatória.
#
# Parâmetros:
#   $1 - Nome do usuário
#   $2 - Senha (opcional, se não fornecida, será gerada uma senha aleatória)
#
# Retorno:
#   A senha definida (útil quando uma senha aleatória é gerada)
#   1 - Falha ao definir a senha
#
set_user_password() {
    local username="$1"
    local password="$2"
    
    # Verificar se o usuário existe
    if ! user_exists "${username}"; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Gerar senha aleatória se não for fornecida
    if [ -z "${password}" ]; then
        password=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' | head -c 16)
        log "info" "Senha gerada para o usuário '${username}'"
    fi
    
    # Definir a senha
    if command -v chpasswd &> /dev/null; then
        echo "${username}:${password}" | chpasswd
    else
        # Alternativa para sistemas sem chpasswd
        echo "${password}" | passwd --stdin "${username}" > /dev/null 2>&1
    fi
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao definir a senha para o usuário '${username}'"
        return 1
    fi
    
    log "info" "Senha definida para o usuário '${username}'"
    echo "${password}"
    return 0
}

#
# add_user_to_group
#
# Descrição:
#   Adiciona um usuário a um ou mais grupos.
#
# Parâmetros:
#   $1 - Nome do usuário
#   $2 - Lista de grupos separados por vírgula
#   $3 - Se definido como "create", cria os grupos que não existirem
#
# Retorno:
#   0 - Usuário adicionado aos grupos com sucesso
#   1 - Falha ao adicionar o usuário a um ou mais grupos
#
add_user_to_group() {
    local username="$1"
    local groups_input="$2"
    local create_groups="$3"
    local result=0
    
    # Verificar se o usuário existe
    if ! user_exists "${username}"; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Dividir a lista de grupos por vírgula
    IFS=',' read -r -a groups <<< "${groups_input}"
    
    # Processar cada grupo
    for group in "${groups[@]}"; do
        # Remover espaços em branco
        group=$(echo "${group}" | tr -d '[:space:]')
        
        # Verificar se o grupo existe
        if ! getent group "${group}" &> /dev/null; then
            if [ "${create_groups}" = "create" ]; then
                # Criar o grupo se não existir
                if ! groupadd "${group}"; then
                    log "warn" "Falha ao criar o grupo '${group}'"
                    result=1
                    continue
                fi
                log "info" "Grupo '${group}' criado"
            else
                log "warn" "O grupo '${group}' não existe. Use --create-groups para criar automaticamente."
                result=1
                continue
            fi
        fi
        
        # Adicionar o usuário ao grupo
        if ! usermod -a -G "${group}" "${username}"; then
            log "warn" "Falha ao adicionar o usuário '${username}' ao grupo '${group}'"
            result=1
            continue
        fi
        
        log "info" "Usuário '${username}' adicionado ao grupo '${group}'"
    done
    
    return ${result}
}

#
# setup_sudo_access
#
# Descrição:
#   Configura o acesso sudo para um usuário ou grupo.
#
# Parâmetros:
#   $1 - Nome do usuário ou grupo (com prefixo % para grupos)
#   $2 - Nível de acesso (padrão: ALL=(ALL:ALL) ALL)
#   $3 - Arquivo de configuração (opcional, padrão: /etc/sudoers.d/90-custom-users)
#
# Retorno:
#   0 - Acesso sudo configurado com sucesso
#   1 - Falha ao configurar o acesso sudo
#
setup_sudo_access() {
    local target="$1"
    local sudo_rule="${2:-ALL=(ALL:ALL) ALL}"
    local sudo_file="${3:-/etc/sudoers.d/90-custom-users}"
    local temp_file
    
    # Verificar se o alvo existe
    if [[ "${target}" == %* ]]; then
        # É um grupo
        local group_name="${target#%}"
        if ! getent group "${group_name}" &> /dev/null; then
            log "error" "O grupo '${group_name}' não existe"
            return 1
        fi
    else
        # É um usuário
        if ! user_exists "${target}"; then
            log "error" "O usuário '${target}' não existe"
            return 1
        fi
    fi
    
    # Criar arquivo temporário
    temp_file=$(mktemp)
    
    # Se o arquivo de destino já existir, copiar o conteúdo
    if [ -f "${sudo_file}" ]; then
        cp "${sudo_file}" "${temp_file}"
    else
        # Cabeçalho do arquivo
        echo "# Arquivo de configuração sudo gerado automaticamente" > "${temp_file}"
        echo "# Gerado em: $(date)" >> "${temp_file}"
        echo "" >> "${temp_file}"
    fi
    
    # Verificar se a regra já existe
    if grep -q "^${target}[[:space:]]" "${temp_file}"; then
        log "warn" "Já existe uma regra para '${target}' no arquivo ${sudo_file}"
        return 0
    fi
    
    # Adicionar a nova regra
    echo "${target} ${sudo_rule}" >> "${temp_file}"
    
    # Validar a sintaxe do arquivo
    if ! visudo -cf "${temp_file}" &> /dev/null; then
        log "error" "Erro de sintaxe no arquivo sudoers. A alteração não foi aplicada."
        rm -f "${temp_file}"
        return 1
    fi
    
    # Instalar o arquivo com as permissões corretas
    install -m 0440 "${temp_file}" "${sudo_file}"
    
    # Verificar se a instalação foi bem-sucedida
    if [ $? -ne 0 ]; then
        log "error" "Falha ao instalar o arquivo de configuração sudo"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Limpar arquivo temporário
    rm -f "${temp_file}"
    
    log "info" "Acesso sudo configurado para '${target}' em ${sudo_file}"
    return 0
}

#
# lock_user_account
#
# Descrição:
#   Bloqueia uma conta de usuário para evitar login.
#
# Parâmetros:
#   $1 - Nome do usuário
#
# Retorno:
#   0 - Conta bloqueada com sucesso
#   1 - Falha ao bloquear a conta
#
lock_user_account() {
    local username="$1"
    
    # Verificar se o usuário existe
    if ! user_exists "${username}"; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Bloquear a conta
    if ! usermod -L "${username}"; then
        log "error" "Falha ao bloquear a conta do usuário '${username}'"
        return 1
    fi
    
    # Expirar a senha para forçar a alteração no próximo login
    chage -E0 "${username}"
    
    log "info" "Conta do usuário '${username}' foi bloqueada"
    return 0
}

#
# unlock_user_account
#
# Descrição:
#   Desbloqueia uma conta de usuário.
#
# Parâmetros:
#   $1 - Nome do usuário
#
# Retorno:
#   0 - Conta desbloqueada com sucesso
#   1 - Falha ao desbloquear a conta
#
unlock_user_account() {
    local username="$1"
    
    # Verificar se o usuário existe
    if ! user_exists "${username}"; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Desbloquear a conta
    if ! usermod -U "${username}"; then
        log "error" "Falha ao desbloquear a conta do usuário '${username}'"
        return 1
    fi
    
    # Remover a expiração da senha
    chage -E -1 "${username}"
    
    log "info" "Conta do usuário '${username}' foi desbloqueada"
    return 0
}

#
# list_users
#
# Descrição:
#   Lista todos os usuários do sistema.
#
# Parâmetros:
#   $1 - Filtro (opcional, padrão: todos os usuários)
#        Pode ser "system" para listar apenas usuários do sistema
#        ou "human" para listar apenas usuários humanos
#
# Retorno:
#   Lista de usuários, um por linha
#
list_users() {
    local filter="${1:-all}"
    local min_uid=1000
    local max_uid=60000
    
    case "${filter}" in
        system)
            # Listar apenas usuários do sistema
            getent passwd | \
                awk -F: -v min=0 -v max=999 '$3 >= min && $3 <= max && $1 != "nobody" {print $1}'
            ;;
        human)
            # Listar apenas usuários humanos (não do sistema)
            getent passwd | \
                awk -F: -v min=${min_uid} -v max=${max_uid} '$3 >= min && $3 <= max {print $1}'
            ;;
        *)
            # Listar todos os usuários
            getent passwd | cut -d: -f1
            ;;
    esac
    
    return 0
}

#
# get_user_info
#
# Descrição:
#   Obtém informações detalhadas sobre um usuário.
#
# Parâmetros:
#   $1 - Nome do usuário
#
# Retorno:
#   Informações detalhadas sobre o usuário
#
get_user_info() {
    local username="$1"
    
    # Verificar se o usuário existe
    if ! user_exists "${username}"; then
        log "error" "O usuário '${username}' não existe"
        return 1
    fi
    
    # Obter informações do usuário
    local user_info
    user_info=$(getent passwd "${username}")
    
    if [ -z "${user_info}" ]; then
        log "error" "Falha ao obter informações do usuário '${username}'"
        return 1
    fi
    
    # Extrair campos relevantes
    local uid
    local gid
    local gecos
    local home
    local shell
    
    IFS=':' read -r _ _ uid gid gecos home shell _ <<< "${user_info}"
    
    # Obter grupos do usuário
    local groups
    groups=$(groups "${username}" | cut -d: -f2 | sed 's/^[ \t]*//')
    
    # Obter informações de expiração da senha
    local password_expires
    password_expires=$(chage -l "${username}" | grep "Password expires" | cut -d: -f2 | sed 's/^[ \t]*//')
    
    # Obter informações de bloqueio da conta
    local account_status
    if passwd -S "${username}" | grep -q "locked"; then
        account_status="Bloqueada"
    else
        account_status="Ativa"
    fi
    
    # Exibir informações formatadas
    echo "=== Informações do Usuário ==="
    echo "Usuário: ${username}"
    echo "UID: ${uid}"
    echo "GID: ${gid}"
    echo "Nome completo: ${gecos}"
    echo "Diretório home: ${home}"
    echo "Shell padrão: ${shell}"
    echo "Grupos: ${groups}"
    echo "Status da conta: ${account_status}"
    echo "Senha expira em: ${password_expires}"
    
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f user_exists create_user set_user_password add_user_to_group \
         setup_sudo_access lock_user_account unlock_user_account \
         list_users get_user_info
