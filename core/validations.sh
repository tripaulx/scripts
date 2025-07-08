#!/bin/bash
# ===================================================================
# Arquivo: core/validations.sh
# Descrição: Funções de validação para o sistema
# ===================================================================

# Carregar funções utilitárias
# shellcheck source=core/utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Função para verificar dependências do sistema
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Dependências ausentes: ${missing[*]}"
        if confirm_action "Deseja instalar as dependências ausentes?" "y"; then
            if apt-get update && apt-get install -y "${missing[@]}"; then
                :
            else
                error "Falha ao instalar dependências"
            fi
        else
            error "Dependências necessárias não atendidas"
        fi
    fi
}

# Função para verificar espaço em disco
check_disk_space() {
    local required=${1:-100}  # MB (valor padrão: 100MB)
    local available
    
    if ! available=$(df -m / | awk 'NR==2 {print $4}' 2>/dev/null); then
        warn "Não foi possível verificar o espaço em disco disponível"
        return 1
    fi
    
    if [ "$available" -lt "$required" ]; then
        warn "Espaço em disco baixo: ${available}MB disponíveis (${required}MB recomendados)"
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Espaço em disco insuficiente"
        fi
    fi
    
    return 0
}

# Função para verificar conexão com a internet
check_internet() {
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        warn "Sem conexão com a internet. Verifique sua conexão de rede."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Conexão com a internet necessária"
        fi
    fi
}

# Função para validar se o sistema operacional é suportado
check_os_compatibility() {
    local supported_distros=("debian" "ubuntu")
    local supported_versions=("10" "11" "12" "20.04" "22.04")
    
    # Verificar se o arquivo /etc/os-release existe
    if [ ! -f "/etc/os-release" ]; then
        warn "Não foi possível determinar a distribuição do sistema"
        return 1
    fi
    
    # Carregar informações do sistema operacional
    # shellcheck source=/dev/null
    source /etc/os-release
    
    local os_id="${ID:-unknown}"
    local os_version="${VERSION_ID:-unknown}"
    
    # Verificar se a distribuição é suportada
    local is_supported_distro=false
    for distro in "${supported_distros[@]}"; do
        if [[ "$os_id" == "$distro" ]]; then
            is_supported_distro=true
            break
        fi
    done
    
    if [ "$is_supported_distro" = false ]; then
        warn "Distribuição não suportada: $os_id ($os_version)"
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Distribuição não suportada"
        fi
        return 0
    fi
    
    # Verificar se a versão é suportada
    local is_supported_version=false
    for version in "${supported_versions[@]}"; do
        if [[ "$os_version" == "$version"* ]]; then
            is_supported_version=true
            break
        fi
    done
    
    if [ "$is_supported_version" = false ]; then
        warn "Versão não suportada: $os_id $os_version"
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Versão não suportada"
        fi
    fi
    
    return 0
}

# Função para validar se o sistema requer reinicialização
check_reboot_required() {
    if [ -f "/var/run/reboot-required" ]; then
        warn "O sistema requer reinicialização. É recomendado reiniciar antes de continuar."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Reinicialização do sistema necessária"
        fi
    fi
}

# Função para validar configuração de memória
check_memory() {
    local min_memory=${1:-512}  # MB (valor padrão: 512MB)
    local available_memory
    
    if ! available_memory=$(grep MemAvailable /proc/meminfo | awk '{print $2}'); then
        warn "Não foi possível verificar a memória disponível"
        return 1
    fi
    
    # Converter KB para MB
    available_memory=$((available_memory / 1024))
    
    if [ "$available_memory" -lt "$min_memory" ]; then
        warn "Memória disponível baixa: ${available_memory}MB (${min_memory}MB recomendados)"
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Memória insuficiente"
        fi
    fi
    
    return 0
}

# Função para validar se um serviço está em execução
check_service_running() {
    local service=$1
    
    if ! systemctl is-active --quiet "$service" 2>/dev/null; then
        warn "O serviço $service não está em execução"
        if confirm_action "Deseja iniciar o serviço $service?" "y"; then
            if ! systemctl start "$service"; then
                error "Falha ao iniciar o serviço $service"
            fi
        else
            warn "Algumas funcionalidades podem não estar disponíveis"
        fi
    fi
}

# Função para validar se um arquivo de configuração existe
check_config_file() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        warn "Arquivo de configuração não encontrado: $config_file"
        return 1
    fi
    
    return 0
}

# Função para validar permissões de arquivo
check_file_permissions() {
    local file=$1
    local expected_perm=$2
    local expected_owner=$3
    local expected_group=$4
    
    if [ ! -f "$file" ]; then
        warn "Arquivo não encontrado: $file"
        return 1
    fi
    
    # Verificar permissões
    local current_perm
    current_perm=$(stat -c "%a" "$file")
    
    if [ "$current_perm" != "$expected_perm" ]; then
        warn "Permissões incorretas para $file (atual: $current_perm, esperado: $expected_perm)"
        if confirm_action "Deseja corrigir as permissões para $expected_perm?" "y"; then
            if ! chmod "$expected_perm" "$file"; then
                error "Falha ao alterar as permissões de $file"
            fi
        fi
    fi
    
    # Verificar dono e grupo
    local current_owner
    local current_group
    current_owner=$(stat -c "%U" "$file")
    current_group=$(stat -c "%G" "$file")
    
    if [ "$current_owner" != "$expected_owner" ] || [ "$current_group" != "$expected_group" ]; then
        warn "Proprietário/grupo incorreto para $file (atual: $current_owner:$current_group, esperado: $expected_owner:$expected_group)"
        if confirm_action "Deseja alterar o proprietário/grupo?" "y"; then
            if ! chown "$expected_owner:$expected_group" "$file"; then
                error "Falha ao alterar o proprietário/grupo de $file"
            fi
        fi
    fi
    
    return 0
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f check_dependencies check_disk_space check_internet check_os_compatibility
