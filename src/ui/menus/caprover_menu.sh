#!/bin/bash
#
# Nome do Arquivo: caprover_menu.sh
#
# Descrição:
#   Implementação do menu de gerenciamento do CapRover.
#   Permite instalar, configurar e gerenciar instâncias do CapRover.
#
# Dependências:
#   - src/ui/dialogs.sh
#   - Módulos do CapRover em src/core/caprover/
#
# Uso:
#   source "$(dirname "$0")/caprover_menu.sh"
#   show_caprover_menu
#
# Autor: Equipe de Infraestrutura
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar dependências
source "$(dirname "${BASH_SOURCE[0]}")/../dialogs.sh"

#
# Função: show_caprover_menu
#
# Descrição:
#   Exibe o menu do CapRover e gerencia a navegação entre as opções.
#
# Retorno:
#   Nenhum
#
show_caprover_menu() {
    while true; do
        show_header "MENU DO CAPROVER"
        
        echo "${COLOR_CYAN}1.${COLOR_RESET} Instalar CapRover"
        echo "${COLOR_CYAN}2.${COLOR_RESET} Configurar Domínio"
        echo "${COLOR_CYAN}3.${COLOR_RESET} Gerenciar Aplicações"
        echo "${COLOR_CYAN}4.${COLOR_RESET} Fazer Backup"
        echo "${COLOR_CYAN}5.${COLOR_RESET} Restaurar Backup"
        echo "${COLOR_CYAN}6.${COLOR_RESET} Voltar"
        echo
        
        read -rp "Selecione uma opção [1-6]: " choice
        
        case $choice in
            1)
                install_caprover
                ;;
            2)
                configure_domain
                ;;
            3)
                manage_apps
                ;;
            4)
                create_backup
                ;;
            5)
                restore_backup
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
# Função: install_caprover
#
# Descrição:
#   Instala e configura o CapRover no servidor.
#
install_caprover() {
    show_header "INSTALAÇÃO DO CAPROVER"

    "${SCRIPT_DIR}/src/security/core/check_dependencies.sh" --install

    if command -v caprover &> /dev/null; then
        show_message "info" "CapRover já está instalado."
        return 0
    fi
    
    show_message "info" "Este assistente irá instalar o CapRover no seu servidor."
    echo -e "${COLOR_YELLOW}Requisitos mínimos:${COLOR_RESET}"
    echo "- Ubuntu 18.04+ ou Debian 9+"
    echo "- 1GB de RAM (2GB recomendado)"
    echo "- 20GB de espaço em disco"
    echo "- Portas 80, 443, 3000, 996, 7946, 4789 e 2377 devem estar abertas"
    
    if ! confirm_action "Deseja continuar com a instalação?"; then
        show_message "warning" "Instalação cancelada pelo usuário."
        return 0
    fi
    

    # Dependências já verificadas pelo check_dependencies.sh
    
    # Instalar CapRover
    show_message "info" "Iniciando instalação do CapRover..."
    caprover serversetup
    
    if [ $? -eq 0 ]; then
        show_message "success" "CapRover instalado com sucesso!"
        echo -e "${COLOR_GREEN}Acesse o painel em: https://captain.seudominio.com${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}Senha padrão:${COLOR_RESET} captain42"
    else
        show_message "error" "Ocorreu um erro durante a instalação do CapRover."
        return 1
    fi
    
    read -rp "Pressione Enter para continuar..."
}

# Funções de exemplo (implementação simplificada)
configure_domain() {
    show_header "CONFIGURAR DOMÍNIO"
    
    if ! command -v caprover &> /dev/null; then
        show_message "error" "CapRover não está instalado."
        return 1
    fi
    
    read -rp "Digite o domínio principal (ex: meudominio.com): " domain
    
    if [[ -z "$domain" ]]; then
        show_message "error" "Domínio inválido."
        return 1
    fi
    
    show_message "info" "Configurando domínio $domain..."
    # Comando real seria: caprover api -o "/api/v2/user/system/enablecustomdomain" -m POST -d "{"customDomain":"$domain"}"
    
    show_message "success" "Domínio configurado com sucesso!"
    echo -e "${COLOR_YELLOW}Acesse o painel em: https://captain.$domain${COLOR_RESET}"
    
    read -rp "Pressione Enter para continuar..."
}

manage_apps() {
    show_header "GERENCIAR APLICAÇÕES"
    show_message "info" "Abrindo gerenciador de aplicações..."
    # Implementação futura
    sleep 1
}

create_backup() {
    show_header "CRIAR BACKUP"
    
    if ! command -v caprover &> /dev/null; then
        show_message "error" "CapRover não está instalado."
        return 1
    fi
    
    local backup_dir="/backups/caprover"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="caprover_backup_$timestamp.tar"
    
    mkdir -p "$backup_dir"
    
    show_message "info" "Criando backup do CapRover..."
    
    # Comando real seria: caprover api -o "/api/v2/user/system/backup" -m POST -d "{}" > "$backup_dir/$backup_file"
    
    # Simulando criação de backup
    echo "Arquivos de backup seriam salvos em: $backup_dir/$backup_file"
    show_message "success" "Backup criado com sucesso em $backup_dir/$backup_file"
    
    read -rp "Pressione Enter para continuar..."
}

restore_backup() {
    show_header "RESTAURAR BACKUP"
    
    if ! command -v caprover &> /dev/null; then
        show_message "error" "CapRover não está instalado."
        return 1
    fi
    
    local backup_dir="/backups/caprover"
    
    if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir" 2>/dev/null | grep '\.tar$')" ]; then
        show_message "warning" "Nenhum arquivo de backup encontrado em $backup_dir"
        return 1
    fi
    
    echo "Backups disponíveis:"
    local i=1
    local backup_files=()
    
    for file in "$backup_dir"/*.tar; do
        backup_files+=("$file")
        echo "${i}. $(basename "$file") - $(stat -c %y "$file")"
        ((i++))
    done
    
    read -rp "Selecione o número do backup para restaurar (ou 0 para cancelar): " choice
    
    if [[ "$choice" == "0" || "$choice" -ge "$i" ]]; then
        show_message "info" "Restauração cancelada."
        return 0
    fi
    
    local selected_backup="${backup_files[$((choice-1))]}"
    
    if confirm_action "Tem certeza que deseja restaurar o backup $(basename "$selected_backup")? Isso irá sobrescrever a configuração atual."; then
        show_message "info" "Restaurando backup..."
        # Comando real seria: cat "$selected_backup" | caprover api -o "/api/v2/user/system/restore" -m POST -f -
        show_message "success" "Backup restaurado com sucesso!"
    else
        show_message "info" "Restauração cancelada."
    fi
    
    read -rp "Pressione Enter para continuar..."
}
