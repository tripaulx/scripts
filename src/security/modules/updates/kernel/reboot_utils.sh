#!/bin/bash
#
# Nome do Arquivo: reboot_utils.sh
#
# Descrição:
#   Funções para gerenciar reinicializações após atualizações do sistema.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#
# Uso:
#   source "$(dirname "$0")/reboot_utils.sh"
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
        
        # Mostrar pacotes que requerem reinicialização, se disponível
        if [ -f "/var/run/reboot-required.pkgs" ]; then
            log "info" "Pacotes que requerem reinicialização:"
            sed 's/^/  /' "/var/run/reboot-required.pkgs"
        fi
        
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
    if [ -f "$(dirname "$0")/kernel_updates.sh" ]; then
        source "$(dirname "$0")/kernel_updates.sh"
        if check_kernel_updates; then
            log "warning" "Atualizações do kernel instaladas, mas o sistema não foi reiniciado"
            return 0
        fi
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

#
# cancel_scheduled_reboot
#
# Descrição:
#   Cancela uma reinicialização agendada.
#
# Retorno:
#   0 - Reinicialização cancelada com sucesso
#   1 - Falha ao cancelar a reinicialização ou nenhuma reinicialização agendada
#
cancel_scheduled_reboot() {
    # Verificar se há uma reinicialização agendada
    if [ -f "/run/systemd/shutdown/scheduled" ]; then
        log "info" "Encontrada reinicialização agendada. Cancelando..."
        
        if shutdown -c; then
            log "info" "Reinicialização cancelada com sucesso"
            
            # Notificar os usuários conectados
            if command -v wall &> /dev/null; then
                echo "A reinicialização agendada foi cancelada." | wall
            fi
            
            return 0
        else
            log "error" "Falha ao cancelar a reinicialização agendada"
            return 1
        fi
    else
        log "info" "Nenhuma reinicialização agendada encontrada"
        return 0
    fi
}

#
# is_reboot_required
#
# Descrição:
#   Verifica se uma reinicialização é necessária sem exibir mensagens detalhadas.
#   Útil para scripts que precisam verificar o status de forma silenciosa.
#
# Retorno:
#   0 - Reinicialização necessária
#   1 - Nenhuma reinicialização necessária
#
is_reboot_required() {
    # Verificar se o arquivo /var/run/reboot-required existe
    [ -f "/var/run/reboot-required" ] && return 0
    
    # Verificar serviços que precisam ser reiniciados
    if command -v needrestart &> /dev/null; then
        needrestart -b -r l 2>/dev/null | grep -q 'NEEDRESTART-KILL' && return 0
    fi
    
    # Verificar atualizações do kernel
    if [ -f "$(dirname "$0")/kernel_updates.sh" ]; then
        source "$(dirname "$0")/kernel_updates.sh"
        if check_kernel_updates &> /dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Exportar funções que serão usadas em outros módulos
export -f reboot_if_required schedule_reboot cancel_scheduled_reboot is_reboot_required
