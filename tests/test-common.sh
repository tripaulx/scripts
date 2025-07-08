#!/bin/bash
# ===================================================================
# Funções comuns para testes
# ===================================================================

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores de testes
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0


# Inicializar testes
init_tests() {
    echo -e "${YELLOW}Iniciando testes: $1${NC}"
    echo "=================================================="
    shift
    TEST_FUNCTIONS=("$@")
    TOTAL_TESTS=${#TEST_FUNCTIONS[@]}
    PASSED_TESTS=0
    FAILED_TESTS=0
    SKIPPED_TESTS=0
}

# Executar testes
run_tests() {
    local suite_name=$1
    shift
    
    init_tests "$suite_name" "$@"
    
    for test_func in "${TEST_FUNCTIONS[@]}"; do
        echo -e "\n${YELLOW}Executando: ${test_func}${NC}"
        
        if ! command -v "$test_func" >/dev/null 2>&1; then
            echo -e "${YELLOW}❌ Função de teste '${test_func}' não encontrada${NC}"
            ((SKIPPED_TESTS++))
            continue
        fi
        
        # Executar o teste
        if "$test_func"; then
            echo -e "${GREEN}✅ ${test_func} PASSOU${NC}"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}❌ ${test_func} FALHOU${NC}"
            ((FAILED_TESTS++))
        fi
    done
    
    # Mostrar resumo
    echo -e "\n${YELLOW}=== Resumo dos Testes ===${NC}"
    echo -e "Total:    ${TOTAL_TESTS}"
    echo -e "${GREEN}Aprovados: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Falhas:    ${FAILED_TESTS}${NC}"
    echo -e "${YELLOW}Pulados:   ${SKIPPED_TESTS}${NC}"
    
    # Retornar código de saída baseado no resultado dos testes
    if [ $FAILED_TESTS -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Funções de validação
validate_ip() {
    local ip=$1
    
    # Verificar formato IPv4
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
                return 1
            fi
        done
        return 0
    # Verificar formato IPv6
    elif [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0
    fi
    
    return 1
}

validate_port() {
    local port=$1
    
    # Verificar se é um número
    if ! [[ $port =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Verificar intervalo válido
    if [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    
    return 1
}

# Função para validar nomes de usuário
validate_username() {
    local username=$1
    
    # Verificar se o nome de usuário não está vazio
    if [ -z "$username" ]; then
        return 1
    fi
    
    # Verificar comprimento mínimo e máximo
    if [ ${#username} -lt 3 ] || [ ${#username} -gt 32 ]; then
        return 1
    fi
    
    # Verificar caracteres permitidos: letras, números, hífen, ponto e sublinhado
    if ! [[ "$username" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        return 1
    fi
    
    # Verificar se não começa com hífen ou ponto
    if [[ "$username" =~ ^[.-] ]]; then
        return 1
    fi
    
    # Verificar se não termina com hífen ou ponto
    if [[ "$username" =~ [.-]$ ]]; then
        return 1
    fi
    
    return 0
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para verificar se um arquivo contém um padrão
file_contains() {
    local file=$1
    local pattern=$2
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    grep -q "$pattern" "$file"
    return $?
}

# Função para verificar se um serviço está em execução
service_running() {
    local service=$1
    
    if ! command_exists systemctl; then
        echo "Sistema sem systemd, não é possível verificar o serviço"
        return 1
    fi
    
    systemctl is-active --quiet "$service"
    return $?
}

# Função para verificar se um pacote está instalado
package_installed() {
    local pkg=$1
    
    if command_exists dpkg; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
        return $?
    elif command_exists rpm; then
        rpm -q "$pkg" >/dev/null 2>&1
        return $?
    else
        echo "Gerenciador de pacotes não suportado"
        return 1
    fi
}
