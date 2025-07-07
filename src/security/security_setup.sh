#!/bin/bash
#
# Nome do Arquivo: security_setup.sh
#
# Descrição:
#   Script principal para configuração de segurança do sistema.
#   Orquestra a execução de todos os módulos de segurança.
#
# Dependências:
#   - Módulos de segurança em src/security/modules/
#   - Funções utilitárias em src/security/core/setup_utils/
#   - Dependências do sistema listadas em check_dependencies.sh
#
# Uso:
#   ./security_setup.sh [opções] [módulos...]
#
# Opções:
#   --all               Executa todos os módulos de segurança
#   --ssh               Executa apenas o módulo SSH
#   --firewall          Executa apenas o módulo de firewall (UFW)
#   --fail2ban          Executa apenas o módulo Fail2Ban
#   --users             Executa apenas o módulo de gerenciamento de usuários
#   --updates           Executa apenas o módulo de atualizações
#   --check-deps        Verifica e instala dependências automaticamente
#   --skip-deps         Pula a verificação de dependências (não recomendado)
#   --dry-run           Simula as operações sem fazer alterações reais
#   --help              Exibe esta ajuda
#
# Exit codes:
#   0 - Execução bem-sucedida
#   1 - Erro de parâmetro inválido
#   2 - Falha na verificação de dependências
#   3 - Falha na execução de um módulo
#   4 - Erro de permissão
#   5 - Sistema operacional não suportado
#
# Exemplos:
#   # Executar todos os módulos com verificação de dependências
#   sudo ./security_setup.sh --all --check-deps
#
#   # Executar apenas SSH e Firewall sem verificar dependências
#   sudo ./security_setup.sh --ssh --firewall --skip-deps
#
#   # Verificar dependências sem executar módulos
#   sudo ./security_setup.sh --check-deps
#
# Autor: Equipe de Segurança
# Versão: 2.0.0
# Data: 2025-07-07

# Encerrar em caso de erro
set -euo pipefail

# Cores para saída
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Caminhos importantes
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CORE_DIR="${SCRIPT_DIR}/core"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"
readonly SETUP_UTILS_DIR="${CORE_DIR}/setup_utils"
readonly LOG_FILE="/var/log/security_setup_$(date +%Y%m%d_%H%M%S).log"

# Configurações
declare -a ERRORS=()

# Carregar funções utilitárias
if [ ! -d "${SETUP_UTILS_DIR}" ]; then
    echo "Erro: Diretório de utilitários não encontrado: ${SETUP_UTILS_DIR}" >&2
    exit 1
fi

# Carregar módulos necessários
for module in "load_module.sh" "parse_arguments.sh" "main_functions.sh"; do
    if [ -f "${SETUP_UTILS_DIR}/${module}" ]; then
        source "${SETUP_UTILS_DIR}/${module}" || {
            echo "Erro ao carregar módulo: ${module}" >&2
            exit 1
        }
    else
        echo "Erro: Módulo não encontrado: ${module}" >&2
        exit 1
    fi
done
        log "error" "Foram encontrados ${#ERRORS[@]} erros durante a execução:"
        for error in "${ERRORS[@]}"; do
            echo "  - ${error}" >&2
        done
    fi
    
    if [ ${success} -eq 0 ]; then
        log "success" "Todos os módulos foram executados com sucesso"
    else
        log "error" "Alguns módulos falharam durante a execução"
    fi
    
    log "info" "Log completo disponível em: ${LOG_FILE}"
    
    return ${success}
}

# Executar a função principal
main "$@"
exit $?
