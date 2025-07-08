#!/bin/bash
#
# Nome do Arquivo: main_functions.sh
#
# Descrição:
#   Funções principais do script security_setup.sh.
#   Este arquivo contém a lógica principal de execução.
#
# Dependências:
#   - security_utils.sh
#   - setup_utils/load_module.sh
#   - setup_utils/parse_arguments.sh
#
# Variáveis Globais Necessárias:
#   - LOG_FILE: Caminho para o arquivo de log
#   - MODULES_DIR: Diretório base dos módulos
#   - CORE_DIR: Diretório dos scripts core
#   - SELECTED_MODULES: Array com os módulos selecionados
#   - CHECK_DEPS: Flag para verificação de dependências
#   - SKIP_DEPS: Flag para pular verificação de dependências
#   - DRY_RUN: Flag para modo de simulação
#   - ERRORS: Array para armazenar mensagens de erro
#
# Uso:
#   source "${CORE_DIR}/setup_utils/main_functions.sh"
#   main "$@"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

#
# check_os
#
# Descrição:
#   Verifica se o sistema operacional é suportado.
#
# Retorno:
#   0 - Sistema operacional suportado
#   >0 - Sistema operacional não suportado
#
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID}" in
            debian|ubuntu)
                return 0
                ;;
            *)
                log "error" "Sistema operacional não suportado: ${PRETTY_NAME}"
                return 1
                ;;
        esac
    else
        log "error" "Não foi possível determinar o sistema operacional"
        return 1
    fi
}

#
# check_root
#
# Descrição:
#   Verifica se o script está sendo executado como root.
#
# Retorno:
#   0 - Executando como root
#   >0 - Não está executando como root
#
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "error" "Este script deve ser executado como root"
        log "info"  "Use: sudo $0 [opções]"
        return 1
    fi
    return 0
}

#
# check_dependencies
#
# Descrição:
#   Verifica e instala as dependências do sistema.
#
# Retorno:
#   0 - Dependências instaladas com sucesso
#   >0 - Falha ao instalar dependências
#
check_dependencies() {
    log "info" "Verificando dependências do sistema..."
    
    if [ ! -f "${CORE_DIR}/check_dependencies.sh" ]; then
        log "error" "Arquivo de dependências não encontrado: ${CORE_DIR}/check_dependencies.sh"
        return 1
    fi
    
    if ! "${CORE_DIR}/check_dependencies.sh" --install; then
        log "error" "Falha ao instalar dependências"
        return 1
    fi
    
    log "success" "Todas as dependências estão instaladas"
    return 0
}

#
# show_summary
#
# Descrição:
#   Exibe um resumo da execução.
#
# Parâmetros:
#   $1 - Tempo total de execução em segundos
#   $2 - Código de saída
#   ${failed_modules[@]} - Array com os módulos que falharam
#
show_summary() {
    local total_time="$1"
    local exit_code="$2"
    shift 2
    local failed_modules=("$@")
    
    log "info" "\n=== Resumo da Execução ==="
    log "info" "Tempo total: ${total_time} segundos"
    log "info" "Módulos executados: ${#SELECTED_MODULES[@]}"
    
    if [ ${#failed_modules[@]} -gt 0 ]; then
        log "error" "Módulos com falha (${#failed_modules[@]}): ${failed_modules[*]}"
    fi
    
    if [ ${#ERRORS[@]} -gt 0 ]; then
        log "error" "Foram encontrados ${#ERRORS[@]} erros durante a execução:"
        for error in "${ERRORS[@]}"; do
            echo "  - ${error}" >&2
        done
    fi
    
        if [ "${exit_code}" -eq 0 ]; then
        log "success" "Todos os módulos foram executados com sucesso"
    else
        log "error" "Alguns módulos falharam durante a execução"
    fi
    
    log "info" "Log completo disponível em: ${LOG_FILE}"
}

#
# main
#
# Descrição:
#   Função principal do script.
#
# Parâmetros:
#   $@ - Argumentos da linha de comando
#
# Retorno:
#   0 - Execução bem-sucedida
#   >0 - Código de erro
#
main() {
    local start_time end_time duration
    local -a failed_modules=()
    local exit_code=0
    
    start_time=$(date +%s)
    
    # Inicializar arquivo de log
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "=== Início do log: $(date) ===" > "${LOG_FILE}"
    
    # Processar argumentos da linha de comando
    parse_arguments "$@"
    
    # Validar argumentos
    if ! validate_arguments; then
        exit_code=1
        show_summary 0 ${exit_code} "${failed_modules[@]}"
        return ${exit_code}
    fi
    
    # Verificar sistema operacional
    if ! check_os; then
        exit_code=5
        show_summary 0 ${exit_code} "${failed_modules[@]}"
        return ${exit_code}
    fi
    
    # Verificar privilégios de root
    if ! check_root; then
        exit_code=4
        show_summary 0 ${exit_code} "${failed_modules[@]}"
        return ${exit_code}
    fi
    
    log "info" "Iniciando configuração de segurança"
    log "info" "Log principal: ${LOG_FILE}"
    
    # Verificar dependências se necessário
    if [ "${SKIP_DEPS}" = false ]; then
        if [ "${CHECK_DEPS}" = true ] || [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
            if ! check_dependencies; then
                exit_code=2
                show_summary 0 ${exit_code} "${failed_modules[@]}"
                return ${exit_code}
            fi
        fi
    else
        log "warning" "Verificação de dependências desativada (não recomendado)"
    fi
    
    # Se apenas verificação de dependências foi solicitada, sair
    if [ "${CHECK_DEPS}" = true ] && [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        log "success" "Verificação de dependências concluída com sucesso"
        return 0
    fi
    
    if [ "${DRY_RUN}" = true ]; then
        log "warning" "MODO DE SIMULAÇÃO ATIVADO - Nenhuma alteração será feita"
    fi
    
    # Executar cada módulo selecionado
    for module in "${SELECTED_MODULES[@]}"; do
        log "info" "\n=== Iniciando módulo: ${module} ==="
        if ! load_module "${module}"; then
            exit_code=3
            failed_modules+=("${module}")
            
            # Continuar para o próximo módulo mesmo em caso de falha
            log "warning" "Continuando para o próximo módulo..."
        fi
    done
    
    # Calcular tempo total de execução
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Mostrar resumo
    show_summary ${duration} ${exit_code} "${failed_modules[@]}"
    
    return ${exit_code}
}
