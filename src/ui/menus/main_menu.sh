#!/bin/bash
#
# Nome do Arquivo: main_menu.sh
#
# Descrição:
#   Implementação do menu principal do sistema de gerenciamento de servidor.
#   Este arquivo contém as funções para exibição e manipulação do menu principal.
#
# Dependências:
#   - src/ui/dialogs.sh
#   - src/ui/menus/security_menu.sh
#   - src/ui/menus/caprover_menu.sh
#   - src/ui/menus/advanced_menu.sh
#
# Uso:
#   source "$(dirname "$0")/main_menu.sh"
#   show_main_menu
#
# Autor: Equipe de Infraestrutura
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar dependências
source "$(dirname "${BASH_SOURCE[0]}")/../dialogs.sh"
source "$(dirname "${BASH_SOURCE[0]}")/security_menu.sh"
source "$(dirname "${BASH_SOURCE[0]}")/caprover_menu.sh"
source "$(dirname "${BASH_SOURCE[0]}")/advanced_menu.sh"

#
# Função: show_main_menu
#
# Descrição:
#   Exibe o menu principal e gerencia a navegação entre as opções.
#
# Retorno:
#   Nenhum
#
show_main_menu() {
    while true; do
        show_header "MENU PRINCIPAL"
        
        echo "${COLOR_CYAN}1.${COLOR_RESET} Menu de Segurança"
        echo "${COLOR_CYAN}2.${COLOR_RESET} Menu do CapRover"
        echo "${COLOR_CYAN}3.${COLOR_RESET} Configurações do Sistema"
        echo "${COLOR_CYAN}4.${COLOR_RESET} Ferramentas Avançadas"
        echo "${COLOR_CYAN}5.${COLOR_RESET} Sair"
        echo
        
        read -rp "Selecione uma opção [1-5]: " choice
        
        case $choice in
            1)
                show_security_menu
                ;;
            2)
                show_caprover_menu
                ;;
            3)
                show_system_menu
                ;;
            4)
                show_advanced_tools_menu
                ;;
            5)
                echo -e "\n${COLOR_GREEN}Saindo...${COLOR_RESET}"
                exit 0
                ;;
            *)
                show_message "error" "Opção inválida. Tente novamente."
                sleep 1
                ;;
        esac
    done
}

#
# Função: show_system_menu
#
# Descrição:
#   Exibe o menu de configurações do sistema.
#
# Retorno:
#   Nenhum
#
show_system_menu() {
    while true; do
        show_header "CONFIGURAÇÕES DO SISTEMA"
        
        echo "${COLOR_CYAN}1.${COLOR_RESET} Atualizar Sistema"
        echo "${COLOR_CYAN}2.${COLOR_RESET} Configurar Rede"
        echo "${COLOR_CYAN}3.${COLOR_RESET} Gerenciar Usuários"
        echo "${COLOR_CYAN}4.${COLOR_RESET} Voltar"
        echo
        
        read -rp "Selecione uma opção [1-4]: " choice
        
        case $choice in
            1)
                update_system
                ;;
            2)
                configure_network
                ;;
            3)
                manage_users
                ;;
            4)
                return 0
                ;;
            *)
                show_message "error" "Opção inválida. Tente novamente."
                sleep 1
                ;;
        esac
    done
}

# Funções de exemplo (serão movidas para seus respectivos módulos)
update_system() {
    show_header "ATUALIZAÇÃO DO SISTEMA"
    show_message "info" "Iniciando atualização do sistema..."
    
    if confirm_action "Deseja realmente atualizar o sistema?"; then
        # Simular atualização
        sleep 2
        show_message "success" "Sistema atualizado com sucesso!"
    else
        show_message "warning" "Atualização cancelada pelo usuário."
    fi
    
    read -rp "Pressione Enter para continuar..."
}

configure_network() {
    show_header "CONFIGURAÇÃO DE REDE"
    show_message "info" "Abrindo configurações de rede..."
    # Implementação futura
    sleep 1
}

manage_users() {
    show_header "GERENCIAMENTO DE USUÁRIOS"
    show_message "info" "Abrindo gerenciador de usuários..."
    # Implementação futura
    sleep 1
}
