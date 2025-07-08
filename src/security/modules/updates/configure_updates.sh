#!/bin/bash
#
# Nome do Arquivo: configure_updates.sh
#
# Descrição:
#   Script para gerenciar atualizações do sistema operacional e pacotes.
#   Permite verificar, instalar e configurar atualizações automáticas de segurança.
#   Utiliza o módulo de atualizações modularizado.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - update_utils.sh (módulo principal de atualizações)
#   - Módulos em package_managers/, kernel/ e automatic/
#
# Uso:
#   source "$(dirname "$0")/configure_updates.sh"
#   configure_updates [opções] [argumentos]
#
# Opções:
#   --check-updates         Verifica atualizações disponíveis
#   --security-updates      Lista apenas atualizações de segurança
#   --install-updates       Instala todas as atualizações disponíveis
#   --install-security      Instala apenas atualizações de segurança
#   --setup-auto-updates    Configura atualizações automáticas
#   --check-reboot          Verifica se é necessário reiniciar o sistema
#   --schedule-reboot [MIN] Agenda uma reinicialização (padrão: 10 minutos)
#   --dry-run               Simula as operações sem fazer alterações reais
#   --help                  Exibe esta ajuda
#
# Exemplos:
#   # Verificar atualizações disponíveis
#   configure_updates.sh --check-updates
#
#   # Instalar apenas atualizações de segurança
#   configure_updates.sh --install-security
#
#   # Configurar atualizações automáticas
#   configure_updates.sh --setup-auto-updates
#
#   # Verificar se é necessário reiniciar
#   configure_updates.sh --check-reboot
#
# Autor: Equipe de Segurança
# Versão: 2.0.0
# Data: 2025-07-07

# Caminho base para os submódulos
UPDATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar funções utilitárias de segurança
if [ -f "${UPDATES_DIR}/../../core/security_utils.sh" ]; then
    source "${UPDATES_DIR}/../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

# Carregar o módulo de atualizações
if [ -f "${UPDATES_DIR}/update_utils.sh" ]; then
    source "${UPDATES_DIR}/update_utils.sh"
    log "debug" "Módulo de atualizações carregado com sucesso"
else
    log "error" "Não foi possível carregar o módulo de atualizações"
    exit 1
fi

# Variáveis globais
DRY_RUN=0

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    grep '^#/' "$0" | cut -c4-
    exit 0
}

#
# check_system_updates
#
# Descrição:
#   Verifica atualizações disponíveis no sistema.
#
check_system_updates() {
    local package_manager
    package_manager=$(detect_package_manager)
    
    if [ -z "${package_manager}" ]; then
        log "error" "Não foi possível detectar o gerenciador de pacotes"
        return 1
    fi
    
    log "info" "Verificando atualizações disponíveis (${package_manager})"
    
    case "${package_manager}" in
        apt)
            apt update > /dev/null 2>&1
            apt list --upgradable 2>/dev/null
            ;;
        yum)
            yum check-update 2>/dev/null
            ;;
        dnf)
            dnf check-update 2>/dev/null
            ;;
        zypper)
            zypper list-updates 2>/dev/null
            ;;
        pacman)
            pacman -Qu 2>/dev/null
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    local result=$?
    
    if [ ${result} -eq 0 ]; then
        log "info" "Verificação de atualizações concluída com sucesso"
        return 0
    elif [ ${result} -eq 1 ]; then
        log "info" "Nenhuma atualização disponível"
        return 0
    else
        log "info" "Verificando todas as atualizações disponíveis..."
        
        # Atualizar a lista de pacotes primeiro
        if ! update_package_list; then
            log "error" "Falha ao atualizar a lista de pacotes"
            return 1
        fi
        
        # Verificar atualizações disponíveis
        case $(detect_package_manager) in
            apt)
                apt list --upgradable 2>/dev/null | grep -v "^Listing..."
                ;;
            yum|dnf)
                ${package_manager} check-update 2>/dev/null | grep -v "^$" | grep -v "^Last"
                ;;
            zypper)
                zypper list-updates 2>/dev/null
                ;;
            pacman)
                pacman -Qu 2>/dev/null
                ;;
            *)
                log "error" "Gerenciador de pacotes não suportado"
                return 1
                ;;
        esac
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log "info" "Nenhuma atualização disponível"
            return 1
        fi
        
        return 0
    fi
}

#
# install_updates
#
# Descrição:
#   Instala todas as atualizações disponíveis.
#
# Parâmetros:
#   $1 - Se definido como "security", instala apenas atualizações de segurança
#
install_updates() {
    local security_only="${1:-no}"
    local package_manager
    package_manager=$(detect_package_manager)
    
    if [ -z "${package_manager}" ]; then
        log "error" "Não foi possível detectar o gerenciador de pacotes"
        return 1
    fi
    
    # Verificar se estamos em modo de simulação
    if [ ${DRY_RUN} -eq 1 ]; then
        log "info" "[DRY RUN] Simulando instalação de atualizações"
        if [ "${security_only}" = "security" ]; then
            log "info" "  Apenas atualizações de segurança seriam instaladas"
        else
            log "info" "  Todas as atualizações disponíveis seriam instaladas"
        fi
        return 0
    fi
    
    # Atualizar a lista de pacotes primeiro
    if ! update_package_list; then
        log "error" "Falha ao atualizar a lista de pacotes"
        return 1
    fi
    
    # Instalar as atualizações
    if [ "${security_only}" = "security" ]; then
        log "info" "Instalando apenas atualizações de segurança"
        install_security_updates "yes"
    else
        log "info" "Instalando todas as atualizações disponíveis"
        
        case "${package_manager}" in
            apt)
                DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
                ;;
            yum)
                yum update -y
                ;;
            dnf)
                dnf upgrade -y
                ;;
            zypper)
                zypper update -y
                ;;
            pacman)
                pacman -Syu --noconfirm
                ;;
            *)
                log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
                return 1
                ;;
        esac
    fi
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao instalar as atualizações"
        return 1
    fi
    
    log "info" "Atualizações instaladas com sucesso"
    return 0
}

#
# setup_auto_updates
#
# Descrição:
#   Configura atualizações automáticas no sistema.
#
setup_auto_updates() {
    # Verificar se estamos em modo de simulação
    if [ ${DRY_RUN} -eq 1 ]; then
        log "info" "[DRY RUN] Simulando configuração de atualizações automáticas"
        return 0
    fi
    
    log "info" "Configurando atualizações automáticas"
    
    # Instalar e configurar atualizações automáticas
    if ! install_unattended_upgrades "yes"; then
        log "error" "Falha ao configurar atualizações automáticas"
        return 1
    fi
    
    log "info" "Atualizações automáticas configuradas com sucesso"
    return 0
}

#
# check_reboot_required
#
# Descrição:
#   Verifica se é necessário reiniciar o sistema após atualizações.
#   Utiliza as funções do módulo de atualizações.
#
# Retorno:
#   0 - Reinicialização necessária
#   1 - Nenhuma reinicialização necessária
#
check_reboot_required() {
    if reboot_if_required; then
        log "warning" "Reinicialização necessária para concluir as atualizações"
        
        # Mostrar pacotes que requerem reinicialização, se disponível
        if [ -f "/var/run/reboot-required.pkgs" ]; then
            log "info" "Pacotes que requerem reinicialização:"
            cat "/var/run/reboot-required.pkgs" | sed 's/^/  /'
        fi
        
        return 0
    else
        log "info" "Nenhuma reinicialização necessária no momento"
        return 1
    fi
}

#
# main
#
# Descrição:
#   Função principal do script.
#
main() {
    local check_updates=0
    local security_updates=0
    local install_updates_flag=0
    local install_security=0
    local setup_auto=0
    local check_reboot=0
    local schedule_reboot_flag=0
    local reboot_minutes=10
    
    # Verificar se não há argumentos
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    # Processar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --check-updates)
                check_updates=1
                shift
                ;;
            --security-updates)
                security_updates=1
                shift
                ;;
            --install-updates)
                install_updates_flag=1
                shift
                ;;
            --install-security)
                install_security=1
                shift
                ;;
            --setup-auto-updates)
                setup_auto=1
                shift
                ;;
            --check-reboot)
                check_reboot=1
                shift
                ;;
            --schedule-reboot)
                schedule_reboot_flag=1
                # Verificar se o próximo argumento é um número
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    reboot_minutes="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --dry-run)
                DRY_RUN=1
                log "info" "Modo de simulação ativado (nenhuma alteração será feita)"
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log "error" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar se o script está sendo executado como root
    if [ "$(id -u)" -ne 0 ] && [ ${DRY_RUN} -eq 0 ]; then
        log "error" "Este script deve ser executado como root"
        exit 1
    fi
    
    # Executar ações com base nos argumentos
    local success=0
    
    if [ ${check_updates} -eq 1 ]; then
        log "info" "Verificando atualizações disponíveis..."
        if ! check_system_updates; then
            success=1
        fi
    fi
    
    if [ ${security_updates} -eq 1 ]; then
        log "info" "Verificando atualizações de segurança..."
        if ! get_security_updates; then
            success=1
        fi
    fi
    
    if [ ${install_updates_flag} -eq 1 ]; then
        log "info" "Instalando todas as atualizações disponíveis..."
        if ! install_updates; then
            success=1
        fi
    fi
    
    if [ ${install_security} -eq 1 ]; then
        log "info" "Instalando apenas atualizações de segurança..."
        if ! install_updates "security"; then
            success=1
        fi
    fi
    
    if [ ${setup_auto} -eq 1 ]; then
        log "info" "Configurando atualizações automáticas..."
        if ! setup_auto_updates; then
            success=1
        fi
    fi
    
    if [ ${check_reboot} -eq 1 ]; then
        if ! check_reboot_required; then
            success=1
        fi
    fi
    
    if [ ${schedule_reboot_flag} -eq 1 ]; then
        log "info" "Agendando reinicialização em ${reboot_minutes} minutos..."
        if ! schedule_reboot "+${reboot_minutes}"; then
            success=1
        fi
    fi
    
    # Retornar status de saída apropriado
    if [ ${success} -eq 0 ]; then
        log "info" "Operação concluída com sucesso"
        return 0
    else
        log "error" "Algumas operações falharam"
        return 1
    fi
}

#
# configure_updates
#
# Descrição:
#   Função principal para configuração de atualizações do sistema.
#   Esta função é chamada pelo script principal security_setup.sh
#   quando o módulo de atualizações é selecionado.
#
# Parâmetros:
#   $@ - Argumentos adicionais (opcionais)
#
# Retorno:
#   0 - Sucesso
#   >0 - Código de erro
#
configure_updates() {
    log "info" "Iniciando configuração de atualizações do sistema"
    
    # Executar a função main para processar os argumentos
    main "$@"
    
    return $?
}

# Se o script for executado diretamente, não apenas incluído
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# Exportar funções que serão usadas em outros módulos
export -f main
