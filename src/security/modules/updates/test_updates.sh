#!/bin/bash
#
# Nome do Arquivo: test_updates.sh
#
# Descrição:
#   Script de teste para o módulo de atualizações.
#   Verifica se todas as funções estão funcionando corretamente.
#
# Uso:
#   sudo ./test_updates.sh
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagem de sucesso
success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

# Função para exibir mensagem de aviso
warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Função para exibir mensagem de erro
error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Verificar se o script está sendo executado como root
if [ "$(id -u)" -ne 0 ]; then
    error "Este script deve ser executado como root"
    exit 1
fi

# Caminho para o diretório do módulo de atualizações
UPDATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar o módulo de atualizações
if [ -f "${UPDATES_DIR}/update_utils.sh" ]; then
    echo "Carregando módulo de atualizações..."
    # shellcheck source=/dev/null
    source "${UPDATES_DIR}/update_utils.sh"
else
    error "Não foi possível encontrar o módulo de atualizações"
    exit 1
fi

# Testar detecção do gerenciador de pacotes
echo -e "\n=== Testando detecção do gerenciador de pacotes ==="
package_manager=$(detect_package_manager)
if [ -n "${package_manager}" ]; then
    success "Gerenciador de pacotes detectado: ${package_manager}"
else
    error "Falha ao detectar o gerenciador de pacotes"
    exit 1
fi

# Testar atualização da lista de pacotes
echo -e "\n=== Testando atualização da lista de pacotes ==="
if update_package_list; then
    success "Lista de pacotes atualizada com sucesso"
else
    warning "Falha ao atualizar a lista de pacotes"
fi

# Testar verificação de atualizações de segurança
echo -e "\n=== Testando verificação de atualizações de segurança ==="
if security_updates=$(get_security_updates); then
    if [ -n "${security_updates}" ]; then
        success "Atualizações de segurança disponíveis:"
        echo "${security_updates}"
    else
        warning "Nenhuma atualização de segurança disponível"
    fi
else
    error "Falha ao verificar atualizações de segurança"
fi

# Testar verificação de atualizações do kernel
echo -e "\n=== Testando verificação de atualizações do kernel ==="
if check_kernel_updates; then
    current_kernel=$(get_current_kernel_version)
    success "Atualizações do kernel disponíveis"
    echo "Versão atual do kernel: ${current_kernel}"
    echo "Atualizações disponíveis:"
    get_available_kernel_updates
else
    warning "Nenhuma atualização do kernel disponível"
fi

# Testar verificação de reinicialização necessária
echo -e "\n=== Testando verificação de reinicialização necessária ==="
if is_reboot_required; then
    warning "Reinicialização necessária para aplicar atualizações"
    
    # Testar agendamento de reinicialização
    echo -e "\n=== Testando agendamento de reinicialização ==="
    if schedule_reboot "+15" "Reinicialização de teste agendada pelo script de teste"; then
        success "Reinicialização agendada com sucesso"
        
        # Testar cancelamento de reinicialização agendada
        echo -e "\n=== Testando cancelamento de reinicialização agendada ==="
        if cancel_scheduled_reboot; then
            success "Reinicialização agendada foi cancelada"
        else
            error "Falha ao cancelar a reinicialização agendada"
        fi
    else
        error "Falha ao agendar a reinicialização"
    fi
else
    success "Nenhuma reinicialização necessária no momento"
fi

# Testar gerenciamento de atualizações automáticas
echo -e "\n=== Testando gerenciamento de atualizações automáticas ==="
if get_unattended_upgrades_status; then
    warning "As atualizações automáticas já estão ativadas"
    
    # Testar desativação de atualizações automáticas
    echo -e "\n=== Testando desativação de atualizações automáticas ==="
    if disable_unattended_upgrades; then
        success "Atualizações automáticas desativadas com sucesso"
        
        # Testar reativação de atualizações automáticas
        echo -e "\n=== Testando ativação de atualizações automáticas ==="
        if install_unattended_upgrades "yes"; then
            success "Atualizações automáticas ativadas com sucesso"
        else
            error "Falha ao ativar as atualizações automáticas"
        fi
    else
        error "Falha ao desativar as atualizações automáticas"
    fi
else
    # Testar ativação de atualizações automáticas
    echo -e "\n=== Testando ativação de atualizações automáticas ==="
    if install_unattended_upgrades "yes"; then
        success "Atualizações automáticas ativadas com sucesso"
        
        # Testar desativação de atualizações automáticas
        echo -e "\n=== Testando desativação de atualizações automáticas ==="
        if disable_unattended_upgrades; then
            success "Atualizações automáticas desativadas com sucesso"
        else
            error "Falha ao desativar as atualizações automáticas"
        fi
    else
        error "Falha ao ativar as atualizações automáticas"
    fi
fi

echo -e "\n=== Teste concluído ==="

exit 0
