#!/bin/bash
#
# Nome do Arquivo: update_utils.sh
#
# Descrição:
#   Módulo principal para gerenciar atualizações do sistema.
#   Este arquivo serve como ponto de entrada para o módulo de atualizações,
#   carregando todas as funções necessárias dos submódulos.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - Submódulos em package_managers/, kernel/ e automatic/
#
# Uso:
#   source "$(dirname "$0")/update_utils.sh"
#
# Autor: Equipe de Segurança
# Versão: 2.0.0
# Data: 2025-07-07

# Caminho base para os submódulos
readonly UPDATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar funções utilitárias de segurança
if [ -f "${UPDATES_DIR}/../../core/security_utils.sh" ]; then
    source "${UPDATES_DIR}/../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

# Função para carregar um submódulo
load_submodule() {
    local submodule="$1"
    local submodule_path="${UPDATES_DIR}/${submodule}"
    
    if [ -f "${submodule_path}" ]; then
        # shellcheck source=/dev/null
        source "${submodule_path}" || {
            log "error" "Falha ao carregar submódulo: ${submodule}"
            return 1
        }
        log "debug" "Submódulo carregado: ${submodule}"
        return 0
    else
        log "error" "Submódulo não encontrado: ${submodule}"
        return 1
    fi
}

# Carregar todos os submódulos
log "debug" "Carregando submódulos de atualizações..."

# Carregar funções comuns de gerenciamento de pacotes
load_submodule "package_managers/common.sh" || exit 1

# Carregar funções específicas para APT
if [ -f "${UPDATES_DIR}/package_managers/apt_utils.sh" ]; then
    load_submodule "package_managers/apt_utils.sh"
fi

# Carregar funções relacionadas ao kernel
if [ -f "${UPDATES_DIR}/kernel/kernel_updates.sh" ]; then
    load_submodule "kernel/kernel_updates.sh"
fi

if [ -f "${UPDATES_DIR}/kernel/reboot_utils.sh" ]; then
    load_submodule "kernel/reboot_utils.sh"
fi

# Carregar funções de atualizações automáticas
if [ -f "${UPDATES_DIR}/automatic/unattended_upgrades.sh" ]; then
    load_submodule "automatic/unattended_upgrades.sh"
fi

log "debug" "Módulo de atualizações carregado com sucesso"

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
    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Atualizando lista de pacotes (${package_manager})"
    
    case "${package_manager}" in
        apt)
            apt-get update
            ;;
        yum)
            yum check-update -y
            ;;
        dnf)
            dnf check-update -y
            ;;
        zypper)
            zypper refresh
            ;;
        pacman)
            pacman -Syy
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao atualizar a lista de pacotes"
        return 1
    fi
    
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
    local package_manager
    package_manager=$(detect_package_manager)
    
    log "info" "Verificando atualizações de segurança (${package_manager})"
    
    case "${package_manager}" in
        apt)
            apt list --upgradable 2>/dev/null | grep -i security | cut -d'/' -f1
            ;;
        yum)
            yum updateinfo list security -y 2>/dev/null | grep '^FIXED'
            ;;
        dnf)
            dnf updateinfo list security -y 2>/dev/null | grep '^FIXED'
            ;;
        zypper)
            zypper list-patches --category security 2>/dev/null
            ;;
        pacman)
            pacman -Qu 2>/dev/null | grep -i security
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao verificar atualizações de segurança"
        return 1
    fi
    
    return 0
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
            apt-get install --only-upgrade $(echo "${security_updates}" | tr '\n' ' ')
            ;;
        yum)
            yum update --security -y
            ;;
        dnf)
            dnf upgrade --security -y
            ;;
        zypper)
            zypper patch --category security -y
            ;;
        pacman)
            pacman -Syu --noconfirm
            ;;
        *)
            log "error" "Gerenciador de pacotes não suportado: ${package_manager}"
            return 1
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao instalar as atualizações de segurança"
        return 1
    fi
    
    log "info" "Atualizações de segurança instaladas com sucesso"
    return 0
}

#
# install_unattended_upgrades
#
# Descrição:
#   Configura atualizações automáticas não supervisionadas.
#
# Parâmetros:
#   $1 - Se definido como "yes", instala as dependências necessárias
#
# Retorno:
#   0 - Configuração concluída com sucesso
#   1 - Falha na configuração
#
install_unattended_upgrades() {
    local install_deps="${1:-no}"
    
    log "info" "Configurando atualizações automáticas"
    
    # Verificar se o sistema é baseado em Debian/Ubuntu
    if ! is_update_manager_available "apt-get"; then
        log "error" "Atualizações automáticas só são suportadas em sistemas baseados em Debian/Ubuntu"
        return 1
    fi
    
    # Instalar dependências se necessário
    if [ "${install_deps}" = "yes" ] || ! dpkg -l | grep -q 'unattended-upgrades\|apt-listchanges'; then
        log "info" "Instalando dependências necessárias"
        apt-get update && apt-get install -y unattended-upgrades apt-listchanges
        
        if [ $? -ne 0 ]; then
            log "error" "Falha ao instalar as dependências necessárias"
            return 1
        fi
    fi
    
    # Configurar atualizações automáticas
    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    
    log "info" "Configurando arquivo ${config_file}"
    
    cat > "${config_file}" << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Verbose "1";
EOF
    
    # Configurar quais atualizações instalar automaticamente
    local unattended_file="/etc/apt/apt.conf.d/50unattended-upgrades"
    
    log "info" "Configurando arquivo ${unattended_file}"
    
    # Fazer backup do arquivo original se existir
    if [ -f "${unattended_file}" ]; then
        cp "${unattended_file}" "${unattended_file}.bak"
        log "info" "Backup do arquivo original salvo em ${unattended_file}.bak"
    fi
    
    # Configurar atualizações automáticas
    cat > "${unattended_file}" << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESM:${distro_codename}";
};

Unattended-Upgrade::Package-Blacklist {
    // Descomente as linhas abaixo para evitar atualizações automáticas de pacotes específicos
    // "linux-image-*";
    // "linux-headers-*";
};

// Atualizar automaticamente pacotes com dependências quebradas
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Remover automaticamente pacotes obsoletos
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reiniciar automaticamente quando necessário (após atualizações de kernel)
Unattended-Upgrade::Automatic-Reboot "false";

// Horário para reinicialização automática (se habilitada)
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Enviar e-mail com relatório de atualizações
// Unattended-Upgrade::Mail "admin@example.com";
// Unattended-Upgrade::MailReport "on-change";

// Remover pacotes desnecessários após a instalação
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Atualizar o arquivo de pacotes automaticamente
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Verificar atualizações a cada 1 dia
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    # Habilitar o serviço de atualizações automáticas
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao iniciar o serviço de atualizações automáticas"
        return 1
    fi
    
    log "info" "Atualizações automáticas configuradas com sucesso"
    return 0
}

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
# reboot_if_required
#
# Descrição:
#   Verifica se é necessário reiniciar o sistema após atualizações.
#
# Retorno:
#   0 - Reinicialização necessária
#   1 - Nenhuma reinicialização necessária
#
reboot_if_required() {
    # Verificar se o arquivo /var/run/reboot-required existe (sistemas baseados em Debian/Ubuntu)
    if [ -f "/var/run/reboot-required" ]; then
        log "warning" "Reinicialização necessária para concluir as atualizações"
        cat "/var/run/reboot-required.pkgs" 2>/dev/null || true
        return 0
    fi
    
    # Verificar se há serviços que precisam ser reiniciados
    if command -v needrestart &> /dev/null; then
        local services
        services=$(needrestart -b -r l 2>/dev/null | grep -c 'NEEDRESTART-KILL' || true)
        
        if [ "${services}" -gt 0 ]; then
            log "warning" "${services} serviço(s) precisam ser reiniciados para aplicar atualizações"
            return 0
        fi
    fi
    
    # Verificar se há atualizações do kernel pendentes
    if check_kernel_updates; then
        log "warning" "Atualizações do kernel instaladas, mas o sistema não foi reiniciado"
        return 0
    fi
    
    log "info" "Nenhuma reinicialização necessária no momento"
    return 1
}

#
# schedule_reboot
#
# Descrição:
#   Agenda uma reinicialização do sistema.
#
# Parâmetros:
#   $1 - Tempo até a reinicialização (padrão: +10 minutos)
#   $2 - Mensagem a ser exibida aos usuários (opcional)
#
# Retorno:
#   0 - Reinicialização agendada com sucesso
#   1 - Falha ao agendar a reinicialização
#
schedule_reboot() {
    local when="${1:-+10}"
    local message="${2:-'Reinicialização do sistema agendada para aplicar atualizações de segurança. Por favor, salve seu trabalho.'}"
    
    log "warning" "Agendando reinicialização do sistema em ${when}"
    
    # Verificar se o comando shutdown está disponível
    if ! command -v shutdown &> /dev/null; then
        log "error" "Comando 'shutdown' não encontrado"
        return 1
    fi
    
    # Agendar a reinicialização
    if shutdown -r ${when} "${message}"; then
        log "info" "Reinicialização agendada com sucesso para daqui a ${when}"
        
        # Notificar os usuários conectados
        if command -v wall &> /dev/null; then
            echo "${message}" | wall
        fi
        
        return 0
    else
        log "error" "Falha ao agendar a reinicialização"
        return 1
    fi
}

# Exportar funções que serão usadas em outros módulos
export -f is_update_manager_available detect_package_manager update_package_list \
         get_security_updates install_security_updates install_unattended_upgrades \
         check_kernel_updates reboot_if_required schedule_reboot
