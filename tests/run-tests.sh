#!/bin/bash
# ===================================================================
# Testes Automatizados para Scripts de Segurança
# ===================================================================

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$BASE_DIR/tests"
LOG_FILE="$TEST_DIR/test-results-$(date +%Y%m%d_%H%M%S).log"
PASSED=0
FAILED=0
SKIPPED=0

# Funções auxiliares
log() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO") echo -e "${YELLOW}[${timestamp}] [INFO] ${message}${NC}" ;;
        "PASS") echo -e "${GREEN}[${timestamp}] [PASS] ${message}${NC}" ;;
        "FAIL") echo -e "${RED}[${timestamp}] [FAIL] ${message}${NC}" ;;
        "SKIP") echo -e "${YELLOW}[${timestamp}] [SKIP] ${message}${NC}" ;;
        *) echo -e "[${timestamp}] [${level}] ${message}" ;;
    esac
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

run_test() {
    local test_name=$1
    local test_script=$2
    
    log "INFO" "Executando teste: ${test_name}"
    
    if [ ! -f "$test_script" ]; then
        log "SKIP" "Arquivo de teste não encontrado: ${test_script}"
        ((SKIPPED++))
        return 1
    fi
    
    # Executar o teste em um subshell para capturar saída e erros
    (
        cd "$(dirname "$test_script")" || exit 1
        bash "$(basename "$test_script")" 2>&1
    ) >> "$LOG_FILE" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log "PASS" "Teste '${test_name}' passou com sucesso"
        ((PASSED++))
        return 0
    else
        log "FAIL" "Teste '${test_name}' falhou com código ${exit_code}"
        ((FAILED++))
        return 1
    fi
}

# Iniciar testes
echo -e "\n${YELLOW}=== Iniciando Testes Automatizados ===${NC}\n"

# Criar diretório de logs
mkdir -p "$TEST_DIR/logs"

# Lista de testes a serem executados
declare -a TESTS=(
    "test-utils.sh"
    "test-validations.sh"
    "test-ssh-config.sh"
    "test-fail2ban-config.sh"
)

# Executar cada teste
for test_script in "${TESTS[@]}"; do
    run_test "${test_script%.*}" "$TEST_DIR/$test_script"
done

# Resumo dos testes
echo -e "\n${YELLOW}=== Resumo dos Testes ===${NC}"
echo -e "${GREEN}✓ Aprovados: ${PASSED}${NC}"
echo -e "${RED}✗ Falhas: ${FAILED}${NC}"
echo -e "${YELLOW}⚠  Pulados: ${SKIPPED}${NC}"
echo -e "\nLog completo: ${LOG_FILE}"

# Retornar código de saída apropriado
if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
