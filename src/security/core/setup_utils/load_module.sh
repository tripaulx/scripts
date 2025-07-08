#!/bin/bash
#
# Nome do Arquivo: load_module.sh
#
# Descrição:
#   Funções para carregar e gerenciar módulos de segurança.
#   Este arquivo contém funções utilitárias usadas pelo security_setup.sh
#   para carregar e executar módulos de segurança.
#
# Dependências:
#   - security_utils.sh
#
# Variáveis Globais Necessárias:
#   - MODULES_DIR: Diretório base dos módulos
#   - CORE_DIR: Diretório dos scripts core
#   - DRY_RUN: Se true, executa em modo de simulação
#   - LOG_FILE: Arquivo de log principal
#
# Uso:
#   source "${CORE_DIR}/setup_utils/load_module.sh"
#   load_module "ssh"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

#
# load_module
#
# Descrição:
#   Carrega e executa um módulo específico.
#
# Parâmetros:
#   $1 - Nome do módulo a ser carregado
#   $@ - Argumentos adicionais para o módulo
#
# Retorno:
#   0 - Sucesso
#   >0 - Código de erro do módulo
#
load_module() {
    local module="$1"
    shift
    local module_script="${MODULES_DIR}/${module}/configure_${module}.sh"
    local module_log="/var/log/security_${module}_$(date +%Y%m%d_%H%M%S).log"
    local start_time end_time duration
    
    start_time=$(date +%s)
    
    # Verificar se o módulo existe
    if [ ! -f "${module_script}" ]; then
        log "error" "Módulo '${module}' não encontrado: ${module_script}"
        return 3
    fi
    
    log "info" "Iniciando módulo: ${module}"
    
    # Executar o módulo
    if [ "${DRY_RUN}" = true ]; then
        log "warning" "[MODO DE SIMULAÇÃO] Nenhuma alteração será feita"
        log "info" "Simulando execução do módulo: ${module}"
        log "info" "Arquivo do módulo: ${module_script}"
        log "info" "Argumentos: $*"
        return 0
    fi
    
    # Criar diretório de logs se não existir
    mkdir -p "$(dirname "${module_log}")"
    
    # Registrar início da execução
    log "info" "Log detalhado em: ${module_log}"
    
    # Carregar o módulo em um subshell para isolar variáveis
    (
        # Configurar redirecionamento de saída
        exec > >(tee -a "${module_log}") 2>&1
        
        # Carregar funções utilitárias de segurança
        if [ -f "${CORE_DIR}/security_utils.sh" ]; then
            source "${CORE_DIR}/security_utils.sh"
        else
            log "error" "Não foi possível carregar security_utils.sh"
            return 1
        fi
        
        # Executar o módulo
        set -o pipefail
        
        log "info" "Carregando módulo: ${module_script}"
        source "${module_script}" || {
            log "error" "Falha ao carregar o módulo: ${module_script}"
            return 1
        }
        
        # Verificar se a função principal do módulo existe
        if ! declare -f "configure_${module}" > /dev/null; then
            log "error" "Função 'configure_${module}' não encontrada no módulo"
            return 1
        }
        
        # Executar a função principal do módulo
        log "info" "Executando função: configure_${module} $*"
        "configure_${module}" "$@"
        local result=$?
        
        # Verificar código de retorno
        if [ ${result} -eq 0 ]; then
            log "success" "Módulo '${module}' concluído com sucesso"
        else
            log "error" "Módulo '${module}' falhou com código de erro: ${result}"
        }
        
        return ${result}
    )
    
    local result=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Resumo da execução
    if [ ${result} -eq 0 ]; then
        log "success" "Módulo '${module}' concluído em ${duration}s"
    else
        log "error" "Falha no módulo '${module}' após ${duration}s (código: ${result})"
        log "info" "Consulte o log para detalhes: ${module_log}"
    fi
    
    return ${result}
}

#
# get_module_dependencies
#
# Descrição:
#   Obtém as dependências de um módulo específico.
#
# Parâmetros:
#   $1 - Nome do módulo
#
# Retorno:
#   Lista de dependências do módulo
#
get_module_dependencies() {
    local module="$1"
    local deps_file="${MODULES_DIR}/${module}/dependencies.txt"
    
    if [ -f "${deps_file}" ]; then
        cat "${deps_file}" | grep -v '^#' | tr '\n' ' '
    else
        echo ""
    fi
}

#
# validate_module
#
# Descrição:
#   Valida se um módulo está corretamente configurado.
#
# Parâmetros:
#   $1 - Nome do módulo
#
# Retorno:
#   0 - Módulo válido
#   >0 - Erro de validação
#
validate_module() {
    local module="$1"
    local module_script="${MODULES_DIR}/${module}/configure_${module}.sh"
    
    # Verificar se o script do módulo existe
    if [ ! -f "${module_script}" ]; then
        log "error" "Arquivo do módulo não encontrado: ${module_script}"
        return 1
    }
    
    # Verificar se a função principal existe
    if ! grep -q "^configure_${module}()" "${module_script}"; then
        log "error" "Função 'configure_${module}' não encontrada no módulo"
        return 1
    }
    
    return 0
}
