#!/bin/bash
#
# Nome do Arquivo: unattended_upgrades.sh
#
# Descrição:
#   Configura e gerencia atualizações automáticas não supervisionadas.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/unattended_upgrades.sh"
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
    if ! command -v apt-get &> /dev/null; then
        log "error" "Atualizações automáticas só são suportadas em sistemas baseados em Debian/Ubuntu"
        return 1
    fi
    
    # Instalar dependências se necessário
    if [ "${install_deps}" = "yes" ] || ! dpkg -l | grep -q 'unattended-upgrades\|apt-listchanges'; then
        log "info" "Instalando dependências necessárias"
        
        if ! apt-get update; then
            log "error" "Falha ao atualizar a lista de pacotes"
            return 1
        fi
        
        if ! apt-get install -y unattended-upgrades apt-listchanges; then
            log "error" "Falha ao instalar as dependências necessárias"
            return 1
        fi
    fi
    
    # Configurar atualizações automáticas
    local config_file="/etc/apt/apt.conf.d/20auto-upgrades"
    
    log "info" "Configurando arquivo ${config_file}"
    
    # Criar ou atualizar o arquivo de configuração
    cat > "${config_file}" << EOF
// Atualizar a lista de pacotes a cada dia
APT::Periodic::Update-Package-Lists "1";
// Instalar atualizações automaticamente
APT::Periodic::Unattended-Upgrade "1";
// Baixar pacotes atualizáveis
APT::Periodic::Download-Upgradeable-Packages "1";
// Limpar o cache a cada 7 dias
APT::Periodic::AutocleanInterval "7";
// Exibir informações detalhadas
APT::Periodic::Verbose "1";
EOF
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao configurar o arquivo ${config_file}"
        return 1
    fi
    
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
// Configurações para atualizações automáticas não supervisionadas
Unattended-Upgrade::Allowed-Origins {
    // Atualizações de segurança
    "${distro_id}:${distro_codename}-security";
    // Atualizações recomendadas
    "${distro_id}:${distro_codename}-updates";
    // Atualizações de segurança estendidas (Ubuntu)
    "${distro_id}ESM:${distro_codename}";
};

// Lista negra de pacotes que não devem ser atualizados automaticamente
Unattended-Upgrade::Package-Blacklist {
    // Descomente as linhas abaixo para evitar atualizações automáticas de pacotes específicos
    // "linux-image-*";
    // "linux-headers-*
};

// Atualizar automaticamente pacotes com dependências quebradas
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Remover automaticamente pacotes obsoletos
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reiniciar automaticamente quando necessário (após atualizações de kernel)
// ATENÇÃO: Habilite apenas se o servidor puder ser reiniciado automaticamente
Unattended-Upgrade::Automatic-Reboot "false";

// Horário para reinicialização automática (se habilitada)
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Enviar e-mail com relatório de atualizações
// Descomente e configure as linhas abaixo para receber notificações por e-mail
// Unattended-Upgrade::Mail "admin@example.com";
// Unattended-Upgrade::MailReport "on-change";

// Remover pacotes desnecessários após a instalação
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Atualizar o arquivo de pacotes automaticamente
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Opções adicionais
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao configurar o arquivo ${unattended_file}"
        return 1
    fi
    
    # Habilitar e iniciar o serviço de atualizações automáticas
    if ! systemctl is-enabled unattended-upgrades &> /dev/null; then
        log "info" "Habilitando o serviço de atualizações automáticas"
        if ! systemctl enable unattended-upgrades; then
            log "error" "Falha ao habilitar o serviço de atualizações automáticas"
            return 1
        fi
    fi
    
    log "info" "Reiniciando o serviço de atualizações automáticas"
    if ! systemctl restart unattended-upgrades; then
        log "error" "Falha ao reiniciar o serviço de atualizações automáticas"
        return 1
    fi
    
    log "success" "Atualizações automáticas configuradas com sucesso"
    return 0
}

#
# disable_unattended_upgrades
#
# Descrição:
#   Desativa as atualizações automáticas não supervisionadas.
#
# Retorno:
#   0 - Desativação bem-sucedida
#   1 - Falha ao desativar
#
disable_unattended_upgrades() {
    log "info" "Desativando atualizações automáticas"
    
    # Parar e desabilitar o serviço
    if systemctl is-active unattended-upgrades &> /dev/null; then
        log "info" "Parando o serviço de atualizações automáticas"
        if ! systemctl stop unattended-upgrades; then
            log "error" "Falha ao parar o serviço de atualizações automáticas"
            return 1
        fi
    fi
    
    if systemctl is-enabled unattended-upgrades &> /dev/null; then
        log "info" "Desabilitando o serviço de atualizações automáticas"
        if ! systemctl disable unattended-upgrades; then
            log "error" "Falha ao desabilitar o serviço de atualizações automáticas"
            return 1
        fi
    fi
    
    log "success" "Atualizações automáticas desativadas com sucesso"
    return 0
}

#
# get_unattended_upgrades_status
#
# Descrição:
#   Verifica o status das atualizações automáticas.
#
# Retorno:
#   0 - Atualizações automáticas estão ativadas
#   1 - Atualizações automáticas estão desativadas
#   2 - Erro ao verificar o status
#
get_unattended_upgrades_status() {
    if ! command -v apt-get &> /dev/null; then
        log "error" "Esta função só está disponível em sistemas baseados em Debian/Ubuntu"
        return 2
    fi
    
    # Verificar se o pacote está instalado
    if ! dpkg -l | grep -q 'unattended-upgrades'; then
        log "info" "O pacote unattended-upgrades não está instalado"
        return 1
    fi
    
    # Verificar se o serviço está ativo
    if systemctl is-active unattended-upgrades &> /dev/null; then
        log "info" "Atualizações automáticas estão ativadas e em execução"
        return 0
    else
        log "info" "Atualizações automáticas estão instaladas mas não em execução"
        return 1
    fi
}

# Exportar funções que serão usadas em outros módulos
export -f install_unattended_upgrades disable_unattended_upgrades get_unattended_upgrades_status
