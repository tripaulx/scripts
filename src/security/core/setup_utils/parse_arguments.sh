#!/bin/bash
#
# Nome do Arquivo: parse_arguments.sh
#
# Descrição:
#   Funções para processar argumentos da linha de comando.
#   Este arquivo contém funções para análise e validação
#   dos argumentos fornecidos ao script principal.
#
# Dependências:
#   - security_utils.sh
#
# Variáveis Globais Necessárias:
#   - SELECTED_MODULES: Array para armazenar módulos selecionados
#   - CHECK_DEPS: Flag para verificação de dependências
#   - SKIP_DEPS: Flag para pular verificação de dependências
#   - DRY_RUN: Flag para modo de simulação
#
# Uso:
#   source "${CORE_DIR}/setup_utils/parse_arguments.sh"
#   parse_arguments "$@"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    echo "Uso: $0 [OPÇÕES] [MÓDULOS...]"
    echo
    echo "Opções:"
    echo "  --all               Executa todos os módulos de segurança"
    echo "  --ssh               Executa apenas o módulo SSH"
    echo "  --firewall          Executa apenas o módulo de firewall (UFW)"
    echo "  --fail2ban          Executa apenas o módulo Fail2Ban"
    echo "  --users             Executa apenas o módulo de gerenciamento de usuários"
    echo "  --updates           Executa apenas o módulo de atualizações"
    echo "  --check-deps        Verifica e instala dependências automaticamente"
    echo "  --skip-deps         Pula a verificação de dependências (não recomendado)"
    echo "  --dry-run           Simula as operações sem fazer alterações reais"
    echo "  --help              Exibe esta ajuda"
    echo
    echo "Exemplos:"
    echo "  # Executar todos os módulos com verificação de dependências"
    echo "  sudo $0 --all --check-deps"
    echo
    echo "  # Executar apenas SSH e Firewall sem verificar dependências"
    echo "  sudo $0 --ssh --firewall --skip-deps"
    echo
    echo "  # Verificar dependências sem executar módulos"
    echo "  sudo $0 --check-deps"
}

#
# parse_arguments
#
# Descrição:
#   Processa os argumentos da linha de comando.
#
# Parâmetros:
#   $@ - Argumentos da linha de comando
#
parse_arguments() {
    # Inicializar variáveis
    local all_modules=false
    
    # Processar cada argumento
    while [ $# -gt 0 ]; do
        case "$1" in
            --all)
                all_modules=true
                shift
                ;;
            --ssh)
                SELECTED_MODULES+=("ssh")
                shift
                ;;
            --firewall)
                SELECTED_MODULES+=("firewall")
                shift
                ;;
            --fail2ban)
                SELECTED_MODULES+=("fail2ban")
                shift
                ;;
            --users)
                SELECTED_MODULES+=("users")
                shift
                ;;
            --updates)
                SELECTED_MODULES+=("updates")
                shift
                ;;
            --check-deps)
                CHECK_DEPS=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                log "error" "Opção inválida: $1"
                show_help
                exit 1
                ;;
            *)
                # Tratar como nome de módulo
                if [ -d "${MODULES_DIR}/$1" ]; then
                    SELECTED_MODULES+=("$1")
                else
                    log "warning" "Módulo desconhecido: $1 (será ignorado)"
                fi
                shift
                ;;
        esac
    done
    
    # Se --all foi especificado, adicionar todos os módulos disponíveis
    if [ "${all_modules}" = true ]; then
        # Limpar módulos previamente selecionados
        SELECTED_MODULES=()
        
        # Adicionar todos os módulos encontrados no diretório de módulos
        if [ -d "${MODULES_DIR}" ]; then
            for module in "${MODULES_DIR}"/*/; do
                if [ -d "${module}" ]; then
                    module_name=$(basename "${module}")
                    SELECTED_MODULES+=("${module_name}")
                fi
            done
        fi
        
        if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
            log "error" "Nenhum módulo encontrado em ${MODULES_DIR}"
            exit 1
        fi
    fi
    
    # Remover duplicatas mantendo a ordem
    if [ ${#SELECTED_MODULES[@]} -gt 0 ]; then
        local -a unique_modules=()
        local -A seen
        
        for module in "${SELECTED_MODULES[@]}"; do
            if [ -z "${seen[$module]}" ]; then
                unique_modules+=("$module")
                seen["$module"]=1
            fi
        done
        
        SELECTED_MODULES=("${unique_modules[@]}")
    fi
    
    # Se nenhum módulo foi selecionado e não foi solicitada verificação de dependências
    if [ ${#SELECTED_MODULES[@]} -eq 0 ] && [ "${CHECK_DEPS}" = false ]; then
        log "info" "Nenhum módulo selecionado. Use --help para ver as opções disponíveis."
        show_help
        exit 0
    fi
    
    # Log das opções selecionadas
    log "debug" "Opções processadas:"
    log "debug" "  Módulos: ${SELECTED_MODULES[*]}"
    log "debug" "  Verificar dependências: ${CHECK_DEPS}"
    log "debug" "  Pular verificação de dependências: ${SKIP_DEPS}"
    log "debug" "  Modo de simulação: ${DRY_RUN}"
}

#
# validate_arguments
#
# Descrição:
#   Valida os argumentos fornecidos.
#
# Retorno:
#   0 - Argumentos válidos
#   >0 - Erro de validação
#
validate_arguments() {
    # Verificar se --check-deps e --skip-deps foram usados juntos
    if [ "${CHECK_DEPS}" = true ] && [ "${SKIP_DEPS}" = true ]; then
        log "error" "As opções --check-deps e --skip-deps são mutuamente exclusivas"
        return 1
    fi
    
    # Verificar se os módulos selecionados existem
    for module in "${SELECTED_MODULES[@]}"; do
        if [ ! -d "${MODULES_DIR}/${module}" ]; then
            log "error" "Módulo não encontrado: ${module}"
            return 1
        fi
    done
    
    return 0
}
