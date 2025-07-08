#!/bin/bash
#
# Nome do Arquivo: kernel_updates.sh
#
# Descrição:
#   Funções para verificar e gerenciar atualizações do kernel.
#
# Dependências:
#   - common.sh (funções básicas de gerenciamento de pacotes)
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/kernel_updates.sh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

# Carregar funções comuns
if [ -f "$(dirname "$0")/../package_managers/common.sh" ]; then
    source "$(dirname "$0")/../package_managers/common.sh"
else
    echo "Erro: Não foi possível carregar common.sh" >&2
    exit 1
fi

#
# check_kernel_updates
#
# Descrição:
#   Verifica se há atualizações do kernel disponíveis.
#
# Retorno:
#   0 - Atualizações disponíveis
#   1 - Nenhuma atualização disponível ou erro
#
check_kernel_updates() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Verificando atualizações do kernel (${package_manager})"
    
    case "${package_manager}" in
        apt)
            apt list --upgradable 2>/dev/null | grep -E '^linux-image-.*-generic/'
            ;;
        yum|dnf)
            ${package_manager} check-update kernel 2>/dev/null
            ;;
        zypper)
            zypper list-patches --category security | grep -i kernel
            ;;
        pacman)
            pacman -Qu | grep -i linux
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    local result=$?
    
    if [ ${result} -eq 0 ]; then
        log "info" "Atualizações do kernel disponíveis"
        return 0
    elif [ ${result} -eq 1 ]; then
        log "info" "Nenhuma atualização do kernel disponível"
        return 1
    else
        log "error" "Falha ao verificar atualizações do kernel"
        return 1
    fi
}

#
# get_current_kernel_version
#
# Descrição:
#   Obtém a versão atual do kernel em execução.
#
# Retorno:
#   Versão do kernel atual
#
get_current_kernel_version() {
    uname -r
}

#
# get_available_kernel_updates
#
# Descrição:
#   Obtém uma lista de atualizações de kernel disponíveis.
#
# Retorno:
#   Lista de pacotes de kernel com atualizações disponíveis
#
get_available_kernel_updates() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    case "${package_manager}" in
        apt)
            apt list --upgradable 2>/dev/null | grep -E '^linux-image-.*-generic/'
            ;;
        yum|dnf)
            ${package_manager} check-update kernel 2>/dev/null
            ;;
        zypper)
            zypper list-patches --category security | grep -i kernel
            ;;
        pacman)
            pacman -Qu | grep -i linux
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
}

# Exportar funções que serão usadas em outros módulos
export -f check_kernel_updates get_current_kernel_version get_available_kernel_updates
