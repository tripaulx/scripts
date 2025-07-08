#!/bin/bash
#
# Nome do Arquivo: initialization.sh
#
# Descrição:
#   Script de inicialização do sistema de gerenciamento.
#   Configura o ambiente, carrega dependências e inicia a aplicação.
#
# Dependências:
#   - src/ui/dialogs.sh
#   - src/ui/menus/main_menu.sh
#
# Uso:
#   source "$(dirname "$0")/initialization.sh"
#   initialize
#
# Autor: Equipe de Infraestrutura
# Versão: 1.0.0
# Data: 2025-07-06

# Cores para formatação
export COLOR_RESET="\e[0m"
export COLOR_RED="\e[31m"
export COLOR_GREEN="\e[32m"
export COLOR_YELLOW="\e[33m"
export COLOR_BLUE="\e[34m"
export COLOR_MAGENTA="\e[35m"
export COLOR_CYAN="\e[36m"

# Variáveis globais


echo "Verificando e criando diretórios necessários..."
mkdir -p "$(dirname "$0")/../../logs"

#
# Função: check_root
#
# Descrição:
#   Verifica se o script está sendo executado como root.
#   Encerra a execução se não for root.
#
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${COLOR_RED}Erro: Este script deve ser executado como root.${COLOR_RESET}" >&2
        exit 1
    fi
}

#
# Função: load_config
#
# Descrição:
#   Carrega as configurações do sistema a partir de arquivos de configuração.
#
load_config() {
    local config_file
    config_file="$(dirname "$0")/../../config/settings.conf"
    
    if [ -f "$config_file" ]; then
        # shellcheck source=/dev/null
        source "$config_file"
    else
        # Valores padrão
        export LOG_LEVEL="INFO"
        export BACKUP_DIR="/var/backups"
    fi
}

#
# Função: setup_environment
#
# Descrição:
#   Configura o ambiente para execução do script.
#   Define variáveis de ambiente, cria diretórios necessários, etc.
#
setup_environment() {
    # Verificar se é root
    check_root
    
    # Carregar configurações
    load_config
    
    # Configurar tratamento de erros
    set -o errexit
    set -o nounset
    set -o pipefail
    
    # Configurar locale
    export LANG=pt_BR.UTF-8
    export LC_ALL=pt_BR.UTF-8
    
    # Configurar timezone
    export TZ=America/Sao_Paulo
    
    # Configurar PATH
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    
    # Criar diretórios necessários
    mkdir -p "$BACKUP_DIR"
    
    # Configurar permissões
    umask 0027
}

#
# Função: check_dependencies
#
# Descrição:
#   Verifica se todas as dependências necessárias estão instaladas.
#
check_dependencies() {
    local dependencies=("bash" "grep" "sed" "awk" "curl" "wget" "tar" "gzip")
    local missing=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${COLOR_RED}Erro: As seguintes dependências não foram encontradas:${COLOR_RESET}"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo -e "\nPor favor, instale as dependências faltantes e tente novamente."
        exit 1
    fi
}

#
# Função: initialize
#
# Descrição:
#   Função principal de inicialização do sistema.
#   Deve ser chamada para iniciar a aplicação.
#
initialize() {
    # Configurar tratamento de sinais
    trap 'cleanup' EXIT INT TERM
    
    # Configurar ambiente
    setup_environment
    
    # Verificar dependências
    check_dependencies
    
    # Carregar módulos de UI
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Carregar funções de diálogo
    if [ -f "${script_dir}/../ui/dialogs.sh" ]; then
        # shellcheck source=/dev/null
        source "${script_dir}/../ui/dialogs.sh"
    else
        echo -e "${COLOR_RED}Erro: Não foi possível carregar as funções de diálogo.${COLOR_RESET}" >&2
        exit 1
    fi
    
    # Carregar menu principal
    if [ -f "${script_dir}/../ui/menus/main_menu.sh" ]; then
        # shellcheck source=/dev/null
        source "${script_dir}/../ui/menus/main_menu.sh"
    else
        show_message "error" "Não foi possível carregar o menu principal."
        exit 1
    fi
    
    # Iniciar aplicação
    show_main_menu
}

#
# Função: cleanup
#
# Descrição:
#   Função de limpeza executada ao encerrar o script.
#   Remove arquivos temporários, finaliza processos, etc.
#
cleanup() {
    local exit_code=$?
    
    # Restaurar configurações do terminal
    stty sane
    tput cnorm
    
    # Exibir mensagem de encerramento
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${COLOR_GREEN}Script finalizado com sucesso.${COLOR_RESET}"
    else
        echo -e "\n${COLOR_RED}Script encerrado com erro (código: $exit_code).${COLOR_RESET}" >&2
    fi
    
    exit $exit_code
}
