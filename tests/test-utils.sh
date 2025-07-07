#!/bin/bash
# ===================================================================
# Testes para funções utilitárias
# ===================================================================

# Carregar funções de teste
source "$(dirname "$0")/test-common.sh"

# Testar a função de verificação de comando
test_command_exists() {
    echo "Testando command_exists..."
    
    # Testar comando existente
    if command_exists "ls"; then
        echo "PASS: command_exists encontrou o comando 'ls'"
    else
        echo "FAIL: command_exists não encontrou o comando 'ls'"
        return 1
    fi
    
    # Testar comando inexistente
    if ! command_exists "comando_inexistente_123"; then
        echo "PASS: command_exists identificou corretamente comando inexistente"
    else
        echo "FAIL: command_exists falhou ao identificar comando inexistente"
        return 1
    fi
}

# Testar a função de validação de endereço IP
test_validate_ip() {
    echo "Testando validate_ip..."
    
    # IPs válidos
    local valid_ips=(
        "192.168.1.1"
        "10.0.0.1"
        "172.16.0.1"
        "8.8.8.8"
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        "::1"
    )
    
    # IPs inválidos
    local invalid_ips=(
        "256.256.256.256"
        "192.168.1.256"
        "not.an.ip"
        "192.168.1"
        "192.168.1.1.1"
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334:1234"
    )
    
    # Testar IPs válidos
    for ip in "${valid_ips[@]}"; do
        if validate_ip "$ip"; then
            echo "PASS: IP válido detectado corretamente: $ip"
        else
            echo "FAIL: IP válido não detectado: $ip"
            return 1
        fi
    done
    
    # Testar IPs inválidos
    for ip in "${invalid_ips[@]}"; do
        if ! validate_ip "$ip"; then
            echo "PASS: IP inválido detectado corretamente: $ip"
        else
            echo "FAIL: IP inválido não detectado: $ip"
            return 1
        fi
    done
}

# Testar a função de validação de porta
test_validate_port() {
    echo "Testando validate_port..."
    
    # Portas válidas
    local valid_ports=(
        "1"
        "22"
        "80"
        "443"
        "1024"
        "65535"
    )
    
    # Portas inválidas
    local invalid_ports=(
        "0"
        "65536"
        "-1"
        "abc"
        "12345abc"
        ""
    )
    
    # Testar portas válidas
    for port in "${valid_ports[@]}"; do
        if validate_port "$port"; then
            echo "PASS: Porta válida detectada corretamente: $port"
        else
            echo "FAIL: Porta válida não detectada: $port"
            return 1
        fi
    done
    
    # Testar portas inválidas
    for port in "${invalid_ports[@]}"; do
        if ! validate_port "$port"; then
            echo "PASS: Porta inválida detectada corretamente: $port"
        else
            echo "FAIL: Porta inválida não detectada: $port"
            return 1
        fi
    done
}

# Executar todos os testes
run_tests "Testes de Utilidades" \
    test_command_exists \
    test_validate_ip \
    test_validate_port
