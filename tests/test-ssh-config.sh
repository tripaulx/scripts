#!/bin/bash
# ===================================================================
# Testes para configurações de SSH
# ===================================================================

# Carregar funções de teste
source "$(dirname "$0")/test-common.sh"

# Testar configurações recomendadas de segurança SSH
test_ssh_security_settings() {
    echo "Testando configurações de segurança do SSH..."
    
    local sshd_config="/etc/ssh/sshd_config"
    local settings=(
        "^[[:space:]]*PermitRootLogin[[:space:]]+no"
        "^[[:space:]]*PasswordAuthentication[[:space:]]+no"
        "^[[:space:]]*PermitEmptyPasswords[[:space:]]+no"
        "^[[:space:]]*X11Forwarding[[:space:]]+no"
        "^[[:space:]]*AllowTcpForwarding[[:space:]]+no"
        "^[[:space:]]*ChallengeResponseAuthentication[[:space:]]+no"
        "^[[:space:]]*PubkeyAuthentication[[:space:]]+yes"
        "^[[:space:]]*UsePAM[[:space:]]+yes"
    )
    
    if [ ! -f "$sshd_config" ]; then
        echo "Arquivo de configuração do SSH não encontrado: $sshd_config"
        return 1
    fi
    
    local all_ok=true
    
    for setting in "${settings[@]}"; do
        if ! file_contains "$sshd_config" "$setting"; then
            echo "Configuração não encontrada: $setting"
            all_ok=false
        fi
    done
    
    if $all_ok; then
        echo "Todas as configurações de segurança do SSH estão corretas"
        return 0
    else
        echo "Algumas configurações de segurança do SSH não estão corretas"
        return 1
    fi
}

# Testar se a porta SSH não é a padrão (22)
test_ssh_non_default_port() {
    echo "Verificando se a porta SSH não é a padrão (22)..."
    
    local sshd_config="/etc/ssh/sshd_config"
    local default_port_line
    
    default_port_line=$(grep -E '^[[:space:]]*Port[[:space:]]+22[[:space:]]*$' "$sshd_config" 2>/dev/null)
    
    if [ -z "$default_port_line" ]; then
        echo "A porta SSH não é a padrão (22)"
        return 0
    else
        echo "AVISO: A porta SSH está configurada como a porta padrão (22)"
        return 1
    fi
}

# Testar se o serviço SSH está em execução
test_ssh_service_running() {
    echo "Verificando se o serviço SSH está em execução..."
    
    if service_running "ssh" || service_running "sshd"; then
        echo "Serviço SSH está em execução"
        return 0
    else
        echo "AVISO: Serviço SSH não está em execução"
        return 1
    fi
}

# Executar todos os testes
run_tests "Testes de Configuração SSH" \
    test_ssh_security_settings \
    test_ssh_non_default_port \
    test_ssh_service_running
