#!/bin/bash
#
# Nome do Arquivo: apt_utils.sh
#
# Descrição:
#   Funções específicas para gerenciamento de pacotes em sistemas baseados em Debian/Ubuntu (APT).
#
# Dependências:
#   - common.sh (funções básicas de gerenciamento de pacotes)
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/apt_utils.sh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

# Carregar funções comuns
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Erro: Não foi possível carregar common.sh" >&2
    exit 1
fi

#
# apt_update_package_list
#
# Descrição:
#   Atualiza a lista de pacotes disponíveis usando APT.
#
# Retorno:
#   0 - Atualização bem-sucedida
#   1 - Falha ao atualizar a lista de pacotes
#
apt_update_package_list() {
    log "info" "Atualizando lista de pacotes (APT)"
    
    if ! command -v apt-get &> /dev/null; then
        log "error" "APT não está disponível neste sistema"
        return 1
    fi
    
    apt-get update
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao atualizar a lista de pacotes (APT)"
        return 1
    fi
    
    log "info" "Lista de pacotes atualizada com sucesso (APT)"
    return 0
}

#
# apt_get_security_updates
#
# Descrição:
#   Obtém uma lista de atualizações de segurança disponíveis usando APT.
#
# Retorno:
#   Lista de pacotes com atualizações de segurança
#
apt_get_security_updates() {
    log "info" "Verificando atualizações de segurança (APT)"
    
    if ! command -v apt-get &> /dev/null; then
        log "error" "APT não está disponível neste sistema"
        return 1
    fi
    
    apt list --upgradable 2>/dev/null | grep -i security | cut -d'/' -f1
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao verificar atualizações de segurança (APT)"
        return 1
    fi
    
    return 0
}

#
# apt_install_security_updates
#
# Descrição:
#   Instala todas as atualizações de segurança disponíveis usando APT.
#
# Parâmetros:
#   $1 - Se definido como "yes", instala as atualizações sem confirmação
#
# Retorno:
#   0 - Atualizações instaladas com sucesso
#   1 - Falha ao instalar as atualizações
#
apt_install_security_updates() {
    local auto_confirm="${1:-no}"
    
    log "info" "Instalando atualizações de segurança (APT)"
    
    if ! command -v apt-get &> /dev/null; then
        log "error" "APT não está disponível neste sistema"
        return 1
    fi
    
    # Verificar se há atualizações de segurança disponíveis
    local security_updates
    security_updates=$(apt_get_security_updates)
    
    if [ -z "${security_updates}" ]; then
        log "info" "Nenhuma atualização de segurança disponível (APT)"
        return 0
    fi
    
    log "info" "Atualizações de segurança disponíveis (APT):"
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
    apt-get install --only-upgrade $(echo "${security_updates}" | tr '\n' ' ')
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao instalar as atualizações de segurança (APT)"
        return 1
    fi
    
    log "info" "Atualizações de segurança instaladas com sucesso (APT)"
    return 0
}

# Exportar funções que serão usadas em outros módulos
export -f apt_update_package_list apt_get_security_updates apt_install_security_updates
