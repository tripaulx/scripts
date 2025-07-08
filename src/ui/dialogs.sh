#!/bin/bash
#
# Nome do Arquivo: dialogs.sh
#
# Descrição:
#   Funções auxiliares para exibição de diálogos e mensagens na interface do usuário.
#   Inclui funções para exibir cabeçalhos, mensagens de status e caixas de diálogo.
#
# Dependências:
#   - core/utils.sh (para constantes de cores e funções auxiliares)
#
# Uso:
#   source "$(dirname "$0")/dialogs.sh"
#   show_header "Título da Seção"
#
# Autor: Equipe de Infraestrutura
# Versão: 1.0.0
# Data: 2025-07-06

# Cores para formatação (caso não estejam definidas)
: "${COLOR_RESET:=\e[0m}"
: "${COLOR_RED:=\e[31m}"
: "${COLOR_GREEN:=\e[32m}"
: "${COLOR_YELLOW:=\e[33m}"
: "${COLOR_BLUE:=\e[34m}"
: "${COLOR_MAGENTA:=\e[35m}"
: "${COLOR_CYAN:=\e[36m}"

#
# Função: show_header
#
# Descrição:
#   Exibe um cabeçalho formatado com o título fornecido.
#
# Parâmetros:
#   $1 - Título a ser exibido
#   $2 - (Opcional) Subtítulo
#
# Retorno:
#   Nenhum
#
show_header() {
    clear
    local title="$1"
    local subtitle="${2:-}"
    
    echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║${COLOR_RESET}${COLOR_BLUE}                GERENCIADOR DE SERVIDOR - v1.0.0${COLOR_RESET}${COLOR_CYAN}            ║"
    echo -e "╠════════════════════════════════════════════════════════════╣"
    
    # Centraliza o título
    local title_length=${#title}
    local padding=$(( (60 - title_length) / 2 ))
    printf "║%${padding}s${COLOR_YELLOW}%s${COLOR_RESET}%${padding}s║\n" "" "$title" ""
    
    if [ -n "$subtitle" ]; then
        echo -e "${COLOR_CYAN}╟────────────────────────────────────────────────────────────╢"
        echo -e "║ ${COLOR_RESET}${subtitle}${COLOR_CYAN}"
    fi
    
    echo -e "╚════════════════════════════════════════════════════════════╝${COLOR_RESET}\n"
}

#
# Função: show_message
#
# Descrição:
#   Exibe uma mensagem formatada com o tipo especificado.
#
# Parâmetros:
#   $1 - Tipo de mensagem (info, success, warning, error)
#   $2 - Mensagem a ser exibida
#
# Retorno:
#   Nenhum
#
show_message() {
    local type="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$type" in
        info)
            echo -e "[${COLOR_BLUE}INFO${COLOR_RESET}][$timestamp] $message"
            ;;
        success)
            echo -e "[${COLOR_GREEN}SUCESSO${COLOR_RESET}][$timestamp] $message"
            ;;
        warning)
            echo -e "[${COLOR_YELLOW}AVISO${COLOR_RESET}][$timestamp] $message" >&2
            ;;
        error)
            echo -e "[${COLOR_RED}ERRO${COLOR_RESET}][$timestamp] $message" >&2
            ;;
        *)
            echo -e "[$timestamp] $message"
            ;;
    esac
}

#
# Função: confirm_action
#
# Descrição:
#   Solicita confirmação do usuário antes de executar uma ação.
#
# Parâmetros:
#   $1 - Mensagem de confirmação
#   $2 - (Opcional) Valor padrão (Y/n)
#
# Retorno:
#   0 se confirmado, 1 se negado
#
confirm_action() {
    local message="${1:-Tem certeza que deseja continuar?}"
    local default="${2:-y}"
    local prompt="[s/N]"
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="[S/n]"
    fi
    
    read -rp "${message} ${prompt} " response
    response="${response:-$default}"
    
    if [[ "$response" =~ ^[Ss]$ ]]; then
        return 0
    else
        return 1
    fi
}

#
# Função: show_progress
#
# Descrição:
#   Exibe uma barra de progresso animada durante a execução de um comando.
#
# Uso:
#   (comando_demorado) & show_progress $! "Mensagem de progresso..."
#
# Parâmetros:
#   $1 - PID do processo a ser monitorado
#   $2 - Mensagem a ser exibida
#
show_progress() {
    local pid=$1
    local message="${2:-Processando...}"
    local delay=0.25
    local spinstr='|/\-'
    
    echo -n "${message} "
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    
    printf "    \b\b\b\b"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET}"
}
