#!/bin/bash
# ===================================================================
# Testes para funções de validação
# ===================================================================

# Carregar funções de teste
source "$(dirname "$0")/test-common.sh"

# Testar validação de endereços IP
test_validate_ip() {
    echo "Testando validação de endereços IP..."
    
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
    
    echo "Todos os testes de validação de IP passaram"
    return 0
}

# Testar validação de portas
test_validate_port() {
    echo "Testando validação de portas..."
    
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
    
    echo "Todos os testes de validação de porta passaram"
    return 0
}

# Testar validação de nomes de usuário
test_validate_username() {
    echo "Testando validação de nomes de usuário..."
    
    # Nomes de usuário válidos
    local valid_usernames=(
        "usuario"
        "usuario123"
        "usuario-teste"
        "usuario.teste"
        "usuario_teste"
    )
    
    # Nomes de usuário inválidos
    local invalid_usernames=(
        ""
        "us"
        "usuario!"
        "usuario@dominio"
        "usuário"
        "usuario "
        " usuario"
    )
    
    # Testar nomes de usuário válidos
    for user in "${valid_usernames[@]}"; do
        if validate_username "$user"; then
            echo "PASS: Nome de usuário válido detectado corretamente: $user"
        else
            echo "FAIL: Nome de usuário válido não detectado: $user"
            return 1
        fi
    done
    
    # Testar nomes de usuário inválidos
    for user in "${invalid_usernames[@]}"; do
        if ! validate_username "$user"; then
            echo "PASS: Nome de usuário inválido detectado corretamente: $user"
        else
            echo "FAIL: Nome de usuário inválido não detectado: $user"
            return 1
        fi
    done
    
    echo "Todos os testes de validação de nome de usuário passaram"
    return 0
}

# Executar todos os testes
run_tests "Testes de Validação" \
    test_validate_ip \
    test_validate_port \
    test_validate_username
