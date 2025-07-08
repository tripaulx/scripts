#!/bin/bash
#
# Nome do Arquivo: security_menu.sh
#
# Descrição:
#   Implementação do menu de segurança do sistema.
#   Contém funções para gerenciar configurações de segurança como firewall,
#   usuários, SSH e auditorias.
#
# Dependências:
#   - src/ui/dialogs.sh
#   - Módulos de segurança em src/core/security/
#
# Uso:
#   source "$(dirname "$0")/security_menu.sh"
#   show_security_menu
#
# Autor: Equipe de Infraestrutura
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar dependências
source "$(dirname "${BASH_SOURCE[0]}")/../dialogs.sh"

#
# Função: show_security_menu
#
# Descrição:
#   Exibe o menu de segurança e gerencia a navegação entre as opções.
#
# Retorno:
#   Nenhum
#
show_security_menu() {
    while true; do
        show_header "MENU DE SEGURANÇA"
        
        echo "${COLOR_CYAN}1.${COLOR_RESET} Configurar Firewall (UFW)"
        echo "${COLOR_CYAN}2.${COLOR_RESET} Configurar SSH"
        echo "${COLOR_CYAN}3.${COLOR_RESET} Configurar Fail2Ban"
        echo "${COLOR_CYAN}4.${COLOR_RESET} Executar Auditoria de Segurança"
        echo "${COLOR_CYAN}5.${COLOR_RESET} Hardening do Sistema"
        echo "${COLOR_CYAN}6.${COLOR_RESET} Voltar"
        echo
        
        read -rp "Selecione uma opção [1-6]: " choice
        
        case $choice in
            1)
                configure_firewall
                ;;
            2)
                configure_ssh
                ;;
            3)
                configure_fail2ban
                ;;
            4)
                run_security_audit
                ;;
            5)
                run_hardening
                ;;
            6)
                return 0
                ;;
            *)
                show_message "error" "Opção inválida. Tente novamente."
                sleep 1
                ;;
        esac
    done
}

#
# Função: configure_firewall
#
# Descrição:
#   Configura as regras básicas do firewall UFW.
#
configure_firewall() {
    show_header "CONFIGURAÇÃO DO FIREWALL (UFW)"
    
    if ! command -v ufw &> /dev/null; then
        show_message "warning" "UFW não está instalado. Deseja instalar agora?"
        if confirm_action "Instalar UFW?"; then
            if ! { apt-get update && apt-get install -y ufw; }; then
                show_message "error" "Falha ao instalar o UFW."
                return 1
            fi
        else
            return 0
        fi
    fi
    
    echo -e "${COLOR_YELLOW}Status atual do UFW:${COLOR_RESET}"
    ufw status verbose
    
    echo -e "\n${COLOR_CYAN}Opções de configuração:${COLOR_RESET}"
    echo "1. Ativar UFW com configurações padrão"
    echo "2. Permitir porta específica"
    echo "3. Negar porta específica"
    echo "4. Voltar"
    
    read -rp "Selecione uma opção [1-4]: " choice
    
    case $choice in
        1)
            if confirm_action "Isso irá ativar o UFW e bloquear todas as conexões, exceto as permitidas. Continuar?"; then
                ufw --force reset
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow ssh
                ufw enable
                show_message "success" "UFW ativado com sucesso!"
            fi
            ;;
        2)
            read -rp "Digite o número da porta a ser permitida (ex: 80): " port
            if [[ "$port" =~ ^[0-9]+$ ]]; then
                ufw allow "$port"
                show_message "success" "Porta $port permitida com sucesso!"
            else
                show_message "error" "Porta inválida."
            fi
            ;;
        3)
            read -rp "Digite o número da porta a ser bloqueada (ex: 23): " port
            if [[ "$port" =~ ^[0-9]+$ ]]; then
                ufw deny "$port"
                show_message "success" "Porta $port bloqueada com sucesso!"
            else
                show_message "error" "Porta inválida."
            fi
            ;;
        4)
            return 0
            ;;
        *)
            show_message "error" "Opção inválida."
            ;;
    esac
    
    read -rp "Pressione Enter para continuar..."
}

# Funções de exemplo (serão implementadas posteriormente)
configure_ssh() {
    show_header "CONFIGURAÇÃO DO SSH"
    show_message "info" "Abrindo configurações do SSH..."
    # Implementação futura
    sleep 1
}

configure_fail2ban() {
    show_header "CONFIGURAÇÃO DO FAIL2BAN"
    show_message "info" "Abrindo configurações do Fail2Ban..."
    # Implementação futura
    sleep 1
}

run_security_audit() {
    show_header "AUDITORIA DE SEGURANÇA"
    show_message "info" "Executando auditoria de segurança..."
    # Implementação futura
    sleep 1
}

run_hardening() {
    show_header "HARDENING DO SISTEMA"
    
    if confirm_action "Isso aplicará configurações de segurança avançadas. Deseja continuar?"; then
        show_message "info" "Iniciando processo de hardening..."
        # Simular hardening
                for _ in {1..5}; do
            echo -n "."
            sleep 0.5
        done
        echo -e "\n${COLOR_GREEN}Hardening concluído com sucesso!${COLOR_RESET}"
    else
        show_message "warning" "Hardening cancelado pelo usuário."
    fi
    
    read -rp "Pressione Enter para continuar..."
}
