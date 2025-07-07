#!/bin/bash
# ===================================================================
# Testes para configurações do Fail2Ban
# ===================================================================

# Carregar funções de teste
source "$(dirname "$0")/test-common.sh"

# Testar se o Fail2Ban está instalado
test_fail2ban_installed() {
    echo "Verificando se o Fail2Ban está instalado..."
    
    if package_installed "fail2ban"; then
        echo "Fail2Ban está instalado"
        return 0
    else
        echo "AVISO: Fail2Ban não está instalado"
        return 1
    fi
}

# Testar se o serviço Fail2Ban está em execução
test_fail2ban_service_running() {
    echo "Verificando se o serviço Fail2Ban está em execução..."
    
    if service_running "fail2ban"; then
        echo "Serviço Fail2Ban está em execução"
        return 0
    else
        echo "AVISO: Serviço Fail2Ban não está em execução"
        return 1
    fi
}

# Testar configurações recomendadas de segurança do Fail2Ban
test_fail2ban_security_settings() {
    echo "Testando configurações de segurança do Fail2Ban..."
    
    local fail2ban_jail="/etc/fail2ban/jail.local"
    local fail2ban_default="/etc/fail2ban/jail.d/defaults-debian.conf"
    
    # Verificar se pelo menos um dos arquivos de configuração existe
    if [ ! -f "$fail2ban_jail" ] && [ ! -f "$fail2ban_default" ]; then
        echo "AVISO: Nenhum arquivo de configuração do Fail2Ban encontrado"
        return 1
    fi
    
    # Verificar configurações recomendadas
    local settings=(
        "^[[:space:]]*bantime[[:space:]]*=[[:space:]]*[1-9][0-9]*"
        "^[[:space:]]*findtime[[:space:]]*=[[:space:]]*[1-9][0-9]*"
        "^[[:space:]]*maxretry[[:space:]]*=[[:space:]]*[1-9][0-9]*"
        "^[[:space:]]*ignoreip[[:space:]]*=[[:space:]]*127\.0\.0\.1/8"
    )
    
    local config_file
    if [ -f "$fail2ban_jail" ]; then
        config_file="$fail2ban_jail"
    else
        config_file="$fail2ban_default"
    fi
    
    local all_ok=true
    
    for setting in "${settings[@]}"; do
        if ! file_contains "$config_file" "$setting"; then
            echo "Configuração não encontrada: $setting"
            all_ok=false
        fi
    done
    
    # Verificar se o jail do SSH está habilitado
    if ! file_contains "$config_file" "^[[:space:]]*\[sshd\][[:space:]]*$"; then
        echo "AVISO: Jail do SSH não está configurado"
        all_ok=false
    fi
    
    if $all_ok; then
        echo "Todas as configurações de segurança do Fail2Ban estão corretas"
        return 0
    else
        echo "Algumas configurações de segurança do Fail2Ban não estão corretas"
        return 1
    fi
}

# Testar se o Fail2Ban está bloqueando corretamente
test_fail2ban_blocking() {
    echo "Testando se o Fail2Ban está bloqueando corretamente..."
    
    if ! command_exists fail2ban-client; then
        echo "AVISO: Comando fail2ban-client não encontrado"
        return 1
    fi
    
    # Verificar status do Fail2Ban
    if ! fail2ban-client status >/dev/null 2>&1; then
        echo "AVISO: Falha ao verificar o status do Fail2Ban"
        return 1
    fi
    
    # Verificar se o jail do SSH está ativo
    if ! fail2ban-client status | grep -q "sshd"; then
        echo "AVISO: Jail do SSH não está ativo no Fail2Ban"
        return 1
    fi
    
    echo "Fail2Ban parece estar configurado e ativo"
    return 0
}

# Executar todos os testes
run_tests "Testes de Configuração Fail2Ban" \
    test_fail2ban_installed \
    test_fail2ban_service_running \
    test_fail2ban_security_settings \
    test_fail2ban_blocking
