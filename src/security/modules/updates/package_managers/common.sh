#!/bin/bash
#
# Nome do Arquivo: common.sh
#
# Descrição:
#   Funções comuns para gerenciamento de pacotes em diferentes sistemas.
#   Contém funções básicas para detecção e operações com gerenciadores de pacotes.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/common.sh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

# Carregar funções utilitárias de segurança
if [ -f "$(dirname "$0")/../../../core/security_utils.sh" ]; then
    source "$(dirname "$0")/../../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

#
# is_update_manager_available
#
# Descrição:
#   Verifica se um gerenciador de pacotes está disponível no sistema.
#
# Parâmetros:
#   $1 - Nome do gerenciador de pacotes (apt, yum, dnf, etc.)
#
# Retorno:
#   0 - Gerenciador de pacotes disponível
#   1 - Gerenciador de pacotes não disponível
#
is_update_manager_available() {
    local manager="$1"
    
    if command -v "${manager}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

#
# detect_package_manager
#
# Descrição:
#   Detecta o gerenciador de pacotes disponível no sistema.
#
# Retorno:
#   Nome do gerenciador de pacotes (apt, yum, dnf, etc.)
#   Retorna uma string vazia se nenhum for detectado
#
detect_package_manager() {
    if is_update_manager_available "apt-get"; then
        echo "apt"
    elif is_update_manager_available "yum"; then
        echo "yum"
    elif is_update_manager_available "dnf"; then
        echo "dnf"
    elif is_update_manager_available "zypper"; then
        echo "zypper"
    elif is_update_manager_available "pacman"; then
        echo "pacman"
    else
        echo ""
        return 1
    fi
    
    return 0
}

#
# update_package_list
#
# Descrição:
#   Atualiza a lista de pacotes disponíveis nos repositórios.
#
# Retorno:
#   0 - Atualização bem-sucedida
#   1 - Falha ao atualizar a lista de pacotes
#
update_package_list() {
    # Atualiza lista de pacotes eliminando uso indireto de $? (SC2181)

    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Atualizando lista de pacotes (${package_manager})"
    
    case "${package_manager}" in
        apt)
            if ! apt-get update; then
                log "error" "Falha ao atualizar a lista de pacotes (apt)"
                return 1
            fi
            ;;
        yum)
            if ! yum check-update -y; then
                log "error" "Falha ao atualizar a lista de pacotes (yum)"
                return 1
            fi
            ;;
        dnf)
            if ! dnf check-update -y; then
                log "error" "Falha ao atualizar a lista de pacotes (dnf)"
                return 1
            fi
            ;;
        zypper)
            if ! zypper refresh; then
                log "error" "Falha ao atualizar a lista de pacotes (zypper)"
                return 1
            fi
            ;;
        pacman)
            if ! pacman -Syy; then
                log "error" "Falha ao atualizar a lista de pacotes (pacman)"
                return 1
            fi
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    log "info" "Lista de pacotes atualizada com sucesso"
    return 0
}

#
# get_security_updates
#
# Descrição:
#   Obtém uma lista de atualizações de segurança disponíveis.
#
# Retorno:
#   Lista de pacotes com atualizações de segurança
#
get_security_updates() {
    # Elimina SC2181 usando captura direta de saída

    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Verificando atualizações de segurança (${package_manager})"
    
    case "${package_manager}" in
        apt)
            updates=$(apt list --upgradable 2>/dev/null | grep -i security | cut -d'/' -f1) || true
            ;;
        yum)
            updates=$(yum updateinfo list security -y 2>/dev/null | grep '^FIXED') || true
            ;;
        dnf)
            updates=$(dnf updateinfo list security -y 2>/dev/null | grep '^FIXED') || true
            ;;
        zypper)
            updates=$(zypper list-patches --category security 2>/dev/null) || true
            ;;
        pacman)
            updates=$(pacman -Qu 2>/dev/null | grep -i security) || true
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac

    printf '%s
' "${updates}"
}

#
# install_security_updates
#
# Descrição:
#   Instala todas as atualizações de segurança disponíveis.
#
# Parâmetros:
#   $1 - Se definido como "yes", instala as atualizações sem confirmação
#
# Retorno:
#   0 - Atualizações instaladas com sucesso
#   1 - Falha ao instalar as atualizações
#
install_security_updates() {
    # Remove SC2181 e corrige quoting SC2046/2086

    local auto_confirm="${1:-no}"
    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Instalando atualizações de segurança (${package_manager})"
    
    # Verificar se há atualizações de segurança disponíveis
    local security_updates
    security_updates=$(get_security_updates)
    if [ -z "${security_updates}" ]; then
        log "info" "Nenhuma atualização de segurança disponível"
        return 0
    fi
    
    log "info" "Atualizações de segurança disponíveis:"
    echo "${security_updates}"
    
    # Confirmar instalação se não estiver no modo automático
    if [ "${auto_confirm}" != "yes" ]; then
        read -p "Deseja instalar as atualizações de segurança? [s/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            log "info" "Instalação das atualizações cancelada pelo usuário"
            return 0
        fi
    fi
    
    # Instalar as atualizações de segurança
    case "${package_manager}" in
        apt)
            if ! apt-get install --only-upgrade "$(echo "${security_updates}" | tr '\n' ' ')"; then
                log "error" "Falha ao instalar atualizações (apt)"
                return 1
            fi
            ;;
        yum)
            if ! yum update --security -y; then
                log "error" "Falha ao instalar atualizações (yum)"
                return 1
            fi
            ;;
        dnf)
            if ! dnf upgrade --security -y; then
                log "error" "Falha ao instalar atualizações (dnf)"
                return 1
            fi
            ;;
        zypper)
            if ! zypper patch --category security -y; then
                log "error" "Falha ao instalar atualizações (zypper)"
                return 1
            fi
            ;;
        pacman)
            if ! pacman -Syu --noconfirm; then
                log "error" "Falha ao instalar atualizações (pacman)"
                return 1
            fi
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    log "info" "Atualizações de segurança instaladas com sucesso"
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f is_update_manager_available detect_package_manager update_package_list \
         get_security_updates install_security_updates
