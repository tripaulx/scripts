#!/bin/bash
# ===================================================================
# Script de Teste de Integração
# Arquivo: run-tests.sh
# Descrição: Testa a integração entre os módulos e o script principal
# ===================================================================

# Configuração
set -euo pipefail

# Cores
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_RESET="\033[0m"

# Diretórios
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${BASE_DIR}/test-results-$(date +%Y%m%d_%H%M%S).log"

# Funções auxiliares
log() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO") echo -e "${COLOR_BLUE}[${timestamp}] [INFO] ${message}${COLOR_RESET}" ;;
        "SUCCESS") echo -e "${COLOR_GREEN}[${timestamp}] [SUCCESS] ${message}${COLOR_RESET}" ;;
        "WARNING") echo -e "${COLOR_YELLOW}[${timestamp}] [WARNING] ${message}${COLOR_RESET}" ;;
        "ERROR") echo -e "${COLOR_RED}[${timestamp}] [ERROR] ${message}${COLOR_RESET}" ;;
        *) echo -e "[${timestamp}] [${level}] ${message}" ;;
    esac
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

run_test() {
    local test_name=$1
    local test_cmd=$2
    
    log "INFO" "Executando teste: ${test_name}"
    log "DEBUG" "Comando: ${test_cmd}"
    
    if eval "${test_cmd}"; then
        log "SUCCESS" "Teste '${test_name}' passou com sucesso"
        return 0
    else
        log "ERROR" "Teste '${test_name}' falhou"
        return 1
    fi
}

# Verificar dependências
check_dependencies() {
    local deps=("bash" "grep" "awk" "sed" "docker" "jq" "ufw" "fail2ban-client")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing_deps+=("${dep}")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "WARNING" "Dependências ausentes: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Teste 1: Verificar estrutura de diretórios
test_directory_structure() {
    local dirs=(
        "${BASE_DIR}/core"
        "${BASE_DIR}/modules/ssh"
        "${BASE_DIR}/modules/ufw"
        "${BASE_DIR}/modules/fail2ban"
        "${BASE_DIR}/scripts"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "${dir}" ]; then
            log "ERROR" "Diretório não encontrado: ${dir}"
            return 1
        fi
    done
    
    return 0
}

# Teste 2: Verificar arquivos principais
test_main_files() {
    local files=(
        "${BASE_DIR}/main.sh"
        "${BASE_DIR}/core/utils.sh"
        "${BASE_DIR}/core/validations.sh"
        "${BASE_DIR}/core/backup.sh"
        "${BASE_DIR}/core/security.sh"
        "${BASE_DIR}/modules/ssh/ssh.sh"
        "${BASE_DIR}/modules/ufw/ufw.sh"
        "${BASE_DIR}/modules/fail2ban/fail2ban.sh"
    )
    
    for file in "${files[@]}"; do
        if [ ! -f "${file}" ]; then
            log "ERROR" "Arquivo não encontrado: ${file}"
            return 1
        fi
    done
    
    return 0
}

# Teste 3: Verificar permissões de execução
test_execution_permissions() {
    local files=(
        "${BASE_DIR}/main.sh"
        "${BASE_DIR}/initial-setup.sh"
        "${BASE_DIR}/setup-caprover.sh"
        "${BASE_DIR}/validate-postreboot.sh"
        "${BASE_DIR}/zero-initial.sh"
        "${BASE_DIR}/bin/security/harden/zerup-scurity-setup.sh"
    )
    
    for file in "${files[@]}"; do
        if [ ! -x "${file}" ]; then
            log "WARNING" "Arquivo não executável: ${file}"
            log "INFO" "Tentando corrigir permissões..."
            if ! chmod +x "${file}"; then
                log "ERROR" "Falha ao tornar o arquivo executável: ${file}"
                return 1
            fi
        fi
    done
    
    return 0
}

# Teste 4: Verificar sintaxe dos scripts
test_script_syntax() {
    local scripts=(
        "${BASE_DIR}/main.sh"
        "${BASE_DIR}/core/utils.sh"
        "${BASE_DIR}/core/validations.sh"
        "${BASE_DIR}/core/backup.sh"
        "${BASE_DIR}/core/security.sh"
        "${BASE_DIR}/modules/ssh/ssh.sh"
        "${BASE_DIR}/modules/ufw/ufw.sh"
        "${BASE_DIR}/modules/fail2ban/fail2ban.sh"
        "${BASE_DIR}/initial-setup.sh"
        "${BASE_DIR}/setup-caprover.sh"
        "${BASE_DIR}/validate-postreboot.sh"
        "${BASE_DIR}/zero-initial.sh"
        "${BASE_DIR}/bin/security/harden/zerup-scurity-setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        log "INFO" "Verificando sintaxe de: ${script}"
        if ! bash -n "${script}"; then
            log "ERROR" "Erro de sintaxe em: ${script}"
            return 1
        fi
    done
    
    return 0
}

# Teste 5: Testar funções principais (modo dry-run)
test_main_functions() {
    local functions=(
        "show_header"
        "load_module"
        "check_root_privileges"
        "generate_security_report"
    )
    
    # Carregar funções do core
    source "${BASE_DIR}/core/utils.sh"
    source "${BASE_DIR}/core/validations.sh"
    
    for func in "${functions[@]}"; do
        log "INFO" "Testando função: ${func}"
        if ! type -t "${func}" &> /dev/null; then
            log "ERROR" "Função não encontrada: ${func}"
            return 1
        fi
    done
    
    # Testar funções específicas
    if ! check_root_privileges; then
        log "ERROR" "Falha na verificação de privilégios de root"
        return 1
    fi
    
    return 0
}

# Teste 6: Testar carregamento de módulos
test_module_loading() {
    local modules=("ssh" "ufw" "fail2ban")
    
    for module in "${modules[@]}"; do
        log "INFO" "Testando carregamento do módulo: ${module}"
        
        # Carregar o módulo
        if ! source "${BASE_DIR}/main.sh"; then
            log "ERROR" "Falha ao carregar o script principal"
            return 1
        fi
        
        # Verificar se a função principal do módulo existe
        if ! type -t "${module}_main" &> /dev/null; then
            log "ERROR" "Função principal do módulo ${module} não encontrada"
            return 1
        fi
        
        # Testar função de relatório (deve funcionar sem alterações no sistema)
        if ! ${module}_main report; then
            log "WARNING" "Falha ao gerar relatório do módulo ${module}"
            # Não falha o teste, apenas registra um aviso
        fi
    done
    
    return 0
}

# Teste 7: Testar modo de ajuda
test_help_mode() {
    log "INFO" "Testando modo de ajuda"
    
    if ! "${BASE_DIR}/main.sh" --help | grep -q "Uso:"; then
        log "ERROR" "Falha ao exibir ajuda"
        return 1
    fi
    
    return 0
}

# Teste 8: Testar modo de relatório
test_report_mode() {
    log "INFO" "Testando modo de relatório"
    
    local temp_file
    temp_file=$(mktemp)
    
    if ! "${BASE_DIR}/main.sh" --report > "${temp_file}"; then
        log "ERROR" "Falha ao gerar relatório"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Verificar se o relatório contém informações relevantes
    if ! grep -q "RELATÓRIO DE SEGURANÇA" "${temp_file}"; then
        log "ERROR" "Relatório não contém seção de segurança"
        rm -f "${temp_file}"
        return 1
    fi
    
    rm -f "${temp_file}"
    return 0
}

# Função principal
main() {
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # Cabeçalho
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}     TESTE DE INTEGRAÇÃO - SISTEMA DE SEGURANÇA    ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "Data: $(date)"
    echo -e "Log: ${LOG_FILE}\n"
    
    # Verificar dependências
    log "INFO" "Verificando dependências..."
    if ! check_dependencies; then
        log "WARNING" "Algumas dependências estão ausentes, alguns testes podem falhar"
    fi
    
    # Lista de testes
    local tests=(
        "test_directory_structure"
        "test_main_files"
        "test_execution_permissions"
        "test_script_syntax"
        "test_main_functions"
        "test_module_loading"
        "test_help_mode"
        "test_report_mode"
    )
    
    # Executar testes
    for test_func in "${tests[@]}"; do
        log "INFO" "Iniciando teste: ${test_func}"
        
        if ${test_func}; then
            log "SUCCESS" "Teste ${test_func} passou com sucesso"
            ((tests_passed++))
        else
            log "ERROR" "Teste ${test_func} falhou"
            ((tests_failed++))
        fi
    done
    
    # Resumo
    echo -e "\n${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}                RESUMO DOS TESTES                ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "Total de testes: ${#tests[@]}"
    echo -e "${COLOR_GREEN}Testes aprovados: ${tests_passed}${COLOR_RESET}"
    
    if [ ${tests_failed} -gt 0 ]; then
        echo -e "${COLOR_RED}Testes reprovados: ${tests_failed}${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}Todos os testes foram aprovados!${COLOR_RESET}"
    fi
    
    if [ ${tests_skipped} -gt 0 ]; then
        echo -e "${COLOR_YELLOW}Testes pulados: ${tests_skipped}${COLOR_RESET}"
    fi
    
    echo -e "\nLog completo: ${LOG_FILE}"
    
    # Retornar código de saída apropriado
    if [ ${tests_failed} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Executar função principal
if ! main; then
    exit 1
fi
