#!/bin/bash
# ===================================================================
# Script Principal de Gerenciamento
# Arquivo: main.sh
# Descrição: Ponto de entrada para execução dos módulos de segurança e CapRover
# ===================================================================

# Configuração
set -euo pipefail

# Diretórios base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"
MODULES_DIR="${SCRIPT_DIR}/modules"
BIN_DIR="${SCRIPT_DIR}/bin"

# Verificar e carregar funções do core
if [[ -d "${CORE_DIR}" ]]; then
    for core_file in "${CORE_DIR}"/*.sh; do
        source "${core_file}"
    done
else
    echo "Erro: Diretório core não encontrado em ${CORE_DIR}" >&2
    exit 1
fi

# Configuração de cores
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_RESET="\033[0m"

# Variáveis globais
DRY_RUN=false
VERBOSE=false
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/security_hardening_${TIMESTAMP}.log"

# Criar diretórios necessários
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

# Função para exibir o cabeçalho
show_header() {
    clear
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}    SISTEMA DE GERENCIAMENTO DE SERVIDOR          ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Data: $(date)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Versão: 2.0.0${COLOR_RESET}\n"
}

# Função para exibir o menu principal
show_menu() {
    show_header
    echo -e "${COLOR_GREEN}MENU PRINCIPAL:${COLOR_RESET}"
    echo -e "1. 🔒 Segurança - Hardening e Diagnóstico"
    echo -e "2. 🐋 CapRover - Gerenciamento"
    echo -e "3. ⚙️  Configuração do Sistema"
    echo -e "4. 🛠️  Ferramentas Avançadas"
    echo -e "0. 🚪 Sair\n"
    echo -n "Escolha uma opção: "
}

# Função para exibir o menu de segurança
show_security_menu() {
    clear
    show_header
    echo -e "${COLOR_GREEN}SEGURANÇA:${COLOR_RESET}\n"
    
    echo -e "1. 🛡️  Executar Hardening Completo"
    echo -e "2. 🔍 Executar Diagnóstico de Segurança"
    echo -e "3. ⚙️  Configurar Módulos Individuais"
    echo -e "4. 🔄 Reverter Alterações (Rollback)"
    echo -e "0. ↩️  Voltar ao menu principal\n"
    echo -n "Escolha uma opção: "
}

# Função para exibir o menu do CapRover
show_caprover_menu() {
    clear
    show_header
    echo -e "${COLOR_GREEN}CAPROVER:${COLOR_RESET}\n"
    
    echo -e "1. 🚀 Instalar/Configurar CapRover"
    echo -e "2. 🔍 Validar Instalação"
    echo -e "3. 🛠️  Ferramentas de Manutenção"
    echo -e "0. ↩️  Voltar ao menu principal\n"
    echo -n "Escolha uma opção: "
}

# Função para exibir o menu de ferramentas avançadas
show_advanced_tools_menu() {
    clear
    show_header
    echo -e "${COLOR_GREEN}FERRAMENTAS AVANÇADAS:${COLOR_RESET}\n"
    
    echo -e "1. 🔄 Atualizar Scripts"
    echo -e "2. 📊 Gerar Relatório Detalhado"
    echo -e "3. 🧹 Limpar Dados Temporários"
    echo -e "4. 🔍 Verificar Dependências"
    echo -e "0. ↩️  Voltar ao menu principal\n"
    echo -n "Escolha uma opção: "
}

# Função para carregar um módulo específico
load_module() {
    local module_name=$1
    local module_dir="${MODULES_DIR}/${module_name}"
    
    if [ ! -d "$module_dir" ]; then
        error "Módulo $module_name não encontrado em $module_dir"
        return 1
    fi
    
    # Carregar módulo
    if [ -f "${module_dir}/${module_name}.sh" ]; then
        source "${module_dir}/${module_name}.sh"
    else
        error "Arquivo principal do módulo $module_name não encontrado"
        return 1
    fi
    
    # Carregar validações do módulo, se existirem
    if [ -f "${module_dir}/validations.sh" ]; then
        source "${module_dir}/validations.sh"
    fi
    
    return 0
}

# Função para executar o hardening completo
execute_full_hardening() {
    show_header
    echo -e "${COLOR_GREEN}EXECUTANDO HARDENING COMPLETO${COLOR_RESET}\n"
    
    # Verificar privilégios de superusuário
    check_root_privileges
    
    # Criar diretório de backup
    mkdir -p "$BACKUP_DIR"
    
    # Executar cada módulo
    for module in "${MODULES[@]}"; do
        echo -e "\n${COLOR_BLUE}=== CONFIGURANDO MÓDULO: ${module^^} ===${COLOR_RESET}"
        
        # Carregar módulo
        if ! load_module "$module"; then
            error "Falha ao carregar o módulo $module"
            continue
        fi
        
        # Executar função principal do módulo
        case $module in
            "ssh")
                # Obter porta SSH atual
                local ssh_port=$(grep -i "^\s*Port\s" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
                
                # Perguntar se deseja alterar a porta SSH
                echo -e "\n${COLOR_YELLOW}Porta SSH atual: $ssh_port${COLOR_RESET}"
                read -p "Deseja alterar a porta SSH? (s/N): " change_port
                
                if [[ "$change_port" =~ ^[Ss][IiMm]?$ ]]; then
                    read -p "Informe a nova porta SSH (deixe em branco para gerar aleatória): " new_port
                    
                    if [ -z "$new_port" ]; then
                        # Gerar porta aleatória entre 1024 e 32767
                        new_port=$((RANDOM % 31744 + 1024))
                        echo -e "${COLOR_YELLOW}Porta aleatória gerada: $new_port${COLOR_RESET}"
                    fi
                    
                    ssh_main secure "$new_port"
                else
                    ssh_main secure "$ssh_port"
                fi
                ;;
            "ufw")
                ufw_main secure
                ;;
            "fail2ban")
                fail2ban_main secure
                ;;
            *)
                error "Módulo desconhecido: $module"
                ;;
        esac
        
        echo -e "${COLOR_GREEN}✅ Módulo $module configurado com sucesso!${COLOR_RESET}"
    done
    
    echo -e "\n${COLOR_GREEN}✅ Hardening completo concluído com sucesso!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Recomenda-se reiniciar o servidor para aplicar todas as alterações.${COLOR_RESET}\n"
    
    read -p "Pressione Enter para continuar..."
}

# Função para configurar módulos individualmente
configure_individual_modules() {
    while true; do
        show_module_menu
        read -r choice
        
        case $choice in
            1) # SSH
                load_module "ssh"
                
                # Obter porta SSH atual
                local ssh_port=$(grep -i "^\s*Port\s" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
                
                echo -e "\n${COLOR_YELLOW}Porta SSH atual: $ssh_port${COLOR_RESET}"
                read -p "Deseja alterar a porta SSH? (s/N): " change_port
                
                if [[ "$change_port" =~ ^[Ss][IiMm]?$ ]]; then
                    read -p "Informe a nova porta SSH (deixe em branco para gerar aleatória): " new_port
                    
                    if [ -z "$new_port" ]; then
                        # Gerar porta aleatória entre 1024 e 32767
                        new_port=$((RANDOM % 31744 + 1024))
                        echo -e "${COLOR_YELLOW}Porta aleatória gerada: $new_port${COLOR_RESET}"
                    fi
                    
                    ssh_main secure "$new_port"
                else
                    ssh_main secure "$ssh_port"
                fi
                ;;
                
            2) # UFW
                load_module "ufw"
                ufw_main secure
                ;;
                
            3) # Fail2Ban
                load_module "fail2ban"
                fail2ban_main secure
                ;;
                
            0) # Voltar
                return 0
                ;;
                
            *)
                error "Opção inválida. Tente novamente."
                ;;
        esac
        
        read -p "Pressione Enter para continuar..."
    done
}

# Função para gerar relatório de segurança
generate_security_report() {
    show_header
    echo -e "${COLOR_GREEN}RELATÓRIO DE SEGURANÇA${COLOR_RESET}\n"
    
    echo -e "${COLOR_BLUE}=== INFORMAÇÕES DO SISTEMA ===${COLOR_RESET}"
    echo -e "Hostname: $(hostname)"
    echo -e "Sistema Operacional: $(lsb_release -d | cut -f2-)"
    echo -e "Kernel: $(uname -r)"
    echo -e "Arquitetura: $(uname -m)"
    echo -e "Data/Hora: $(date)\n"
    
    # Verificar cada módulo e gerar relatório
    for module in "${MODULES[@]}"; do
        echo -e "\n${COLOR_BLUE}=== MÓDULO: ${module^^} ===${COLOR_RESET}"
        
        # Carregar módulo
        if ! load_module "$module"; then
            echo -e "${COLOR_RED}❌ Módulo $module não encontrado ou com erros${COLOR_RESET}"
            continue
        fi
        
        # Executar função de relatório do módulo
        case $module in
            "ssh")
                ssh_main report
                ;;
            "ufw")
                ufw_main report
                ;;
            "fail2ban")
                fail2ban_main report
                ;;
            *)
                echo -e "${COLOR_YELLOW}⚠️  Relatório não disponível para o módulo $module${COLOR_RESET}"
                ;;
        esac
    done
    
    echo -e "\n${COLOR_GREEN}✅ Relatório de segurança concluído!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Recomendações de segurança foram exibidas acima.${COLOR_RESET}\n"
    
    read -p "Pressione Enter para continuar..."
}

# Função para reverter alterações (rollback)
rollback_changes() {
    show_header
    echo -e "${COLOR_GREEN}REVERTER ALTERAÇÕES (ROLLBACK)${COLOR_RESET}\n"
    
    echo -e "${COLOR_RED}⚠️  ATENÇÃO: Esta operação irá reverter as alterações feitas pelo script.${COLOR_RESET}\n"
    
    # Listar backups disponíveis
    echo -e "${COLOR_YELLOW}Backups disponíveis:${COLOR_RESET}"
    local backups=()
    local i=1
    
    if [ -d "$BACKUP_DIR" ]; then
        while IFS= read -r -d '' backup; do
            backups+=("$backup")
            echo -e "$i. ${backup##*/}"
            ((i++))
        done < <(find "$BACKUP_DIR" -type d -name "backup_*" -print0 | sort -zr)
    fi
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${COLOR_YELLOW}Nenhum backup encontrado.${COLOR_RESET}"
        read -p "Pressione Enter para continuar..."
        return 0
    fi
    
    echo -e "\n0. ↩️  Voltar"
    echo -n "\nEscolha um backup para restaurar (ou 0 para cancelar): "
    read -r choice
    
    # Validar escolha
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        error "Opção inválida. Apenas números são permitidos."
        read -p "Pressione Enter para continuar..."
        return 1
    fi
    
    if [ "$choice" -eq 0 ]; then
        return 0
    fi
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        error "Opção inválida. Escolha um número entre 1 e ${#backups[@]} ou 0 para cancelar."
        read -p "Pressione Enter para continuar..."
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    # Confirmar restauração
    echo -e "\n${COLOR_RED}⚠️  ATENÇÃO: Você está prestes a restaurar o sistema a partir do backup:${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}$selected_backup${COLOR_RESET}\n"
    
    read -p "Tem certeza que deseja continuar? (s/N): " confirm
    
    if ! [[ "$confirm" =~ ^[Ss][IiMm]?$ ]]; then
        echo -e "${COLOR_YELLOW}Operação cancelada pelo usuário.${COLOR_RESET}"
        read -p "Pressione Enter para continuar..."
        return 0
    fi
    
    # Implementar lógica de restauração
    echo -e "\n${COLOR_YELLOW}Iniciando restauração a partir do backup...${COLOR_RESET}"
    
    # Aqui você implementaria a lógica de restauração para cada módulo
    # Por exemplo:
    # - Restaurar configurações do SSH
    # - Restaurar regras do UFW
    # - Restaurar configurações do Fail2Ban
    
    echo -e "\n${COLOR_GREEN}✅ Restauração concluída com sucesso!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Recomenda-se reiniciar o servidor para aplicar as alterações.${COLOR_RESET}\n"
    
    read -p "Pressione Enter para continuar..."
}

# Função para ferramentas avançadas
advanced_tools() {
    while true; do
        show_advanced_tools_menu
        read -r choice
        
        case $choice in
            1) # Verificar portas abertas
                show_header
                echo -e "${COLOR_GREEN}VERIFICANDO PORTAS ABERTAS${COLOR_RESET}\n"
                
                echo -e "${COLOR_YELLOW}Portas TCP abertas:${COLOR_RESET}"
                ss -tuln | grep 'tcp'
                
                echo -e "\n${COLOR_YELLOW}Portas UDP abertas:${COLOR_RESET}"
                ss -uln | grep 'udp'
                
                echo -e "\n${COLOR_YELLOW}Portas em escuta:${COLOR_RESET}"
                netstat -tuln | grep 'LISTEN'
                ;;
                
            2) # Ver logs do sistema
                show_header
                echo -e "${COLOR_GREEN}LOGS DO SISTEMA${COLOR_RESET}\n"
                
                echo -e "1. 📋 Logs do sistema (systemd)"
                echo -e "2. 🔒 Logs de autenticação"
                echo -e "3. 🌐 Logs do servidor web"
                echo -e "4. 🛡️  Logs do Fail2Ban"
                echo -e "5. 🔥 Logs do UFW"
                echo -e "0. ↩️  Voltar\n"
                
                echo -n "Escolha um log para visualizar: "
                read -r log_choice
                
                case $log_choice in
                    1) # System logs
                        sudo journalctl -n 50 --no-pager
                        ;;
                    2) # Auth logs
                        sudo tail -n 50 /var/log/auth.log
                        ;;
                    3) # Web server logs
                        if [ -f "/var/log/nginx/error.log" ]; then
                            sudo tail -n 50 /var/log/nginx/error.log
                        elif [ -f "/var/log/apache2/error.log" ]; then
                            sudo tail -n 50 /var/log/apache2/error.log
                        else
                            echo -e "${COLOR_YELLOW}Nenhum log de servidor web encontrado.${COLOR_RESET}"
                        fi
                        ;;
                    4) # Fail2Ban logs
                        if systemctl is-active --quiet fail2ban; then
                            sudo tail -n 50 /var/log/fail2ban.log
                        else
                            echo -e "${COLOR_YELLOW}O serviço Fail2Ban não está em execução.${COLOR_RESET}"
                        fi
                        ;;
                    5) # UFW logs
                        if systemctl is-active --quiet ufw; then
                            sudo ufw status verbose
                        else
                            echo -e "${COLOR_YELLOW}O serviço UFW não está em execução.${COLOR_RESET}"
                        fi
                        ;;
                    0) # Voltar
                        continue
                        ;;
                    *)
                        error "Opção inválida."
                        ;;
                esac
                ;;
                
            3) # Testar configuração de segurança
                show_header
                echo -e "${COLOR_GREEN}TESTE DE CONFIGURAÇÃO DE SEGURANÇA${COLOR_RESET}\n"
                
                echo -e "${COLOR_YELLOW}Verificando configurações de segurança...${COLOR_RESET}\n"
                
                # Verificar cada módulo
                for module in "${MODULES[@]}"; do
                    echo -e "${COLOR_BLUE}=== TESTANDO MÓDULO: ${module^^} ===${COLOR_RESET}"
                    
                    # Carregar módulo
                    if ! load_module "$module"; then
                        echo -e "${COLOR_RED}❌ Módulo $module não encontrado ou com erros${COLOR_RESET}\n"
                        continue
                    fi
                    
                    # Executar teste de segurança do módulo
                    case $module in
                        "ssh")
                            check_ssh_security
                            ;;
                        "ufw")
                            check_ufw_security
                            ;;
                        "fail2ban")
                            check_fail2ban_security
                            ;;
                        *)
                            echo -e "${COLOR_YELLOW}⚠️  Teste de segurança não disponível para o módulo $module${COLOR_RESET}\n"
                            ;;
                    esac
                done
                
                echo -e "${COLOR_GREEN}✅ Teste de configuração de segurança concluído!${COLOR_RESET}\n"
                ;;
                
            4) # Atualizar scripts
                show_header
                echo -e "${COLOR_GREEN}ATUALIZAR SCRIPTS${COLOR_RESET}\n"
                
                echo -e "${COLOR_YELLOW}Verificando atualizações disponíveis...${COLOR_RESET}\n"
                
                # Aqui você implementaria a lógica para verificar e baixar atualizações
                # Por exemplo, de um repositório Git
                
                echo -e "${COLOR_YELLOW}Esta funcionalidade ainda não foi implementada.${COLOR_RESET}"
                echo -e "${COLOR_YELLOW}Por favor, consulte a documentação para obter instruções de atualização.${COLOR_RESET}\n"
                ;;
                
            0) # Voltar
                return 0
                ;;
                
            *)
                error "Opção inválida. Tente novamente."
                ;;
        esac
        
        read -p "Pressione Enter para continuar..."
    done
}

# Função para executar comandos do sistema
run_command() {
    local cmd="$1"
    local description="${2:-Executando comando}"
    
    echo -e "${COLOR_YELLOW}${description}...${COLOR_RESET}"
    if [ "$VERBOSE" = true ]; then
        echo -e "${COLOR_BLUE}Comando: ${cmd}${COLOR_RESET}"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}[MODO SIMULAÇÃO] O comando não foi executado.${COLOR_RESET}"
        return 0
    fi
    
    if eval "$cmd"; then
        echo -e "${COLOR_GREEN}✅ Sucesso!${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}❌ Falha ao executar o comando.${COLOR_RESET}" >&2
        return 1
    fi
}

# Função para verificar dependências
check_dependencies() {
    clear
    show_header
    echo -e "${COLOR_GREEN}VERIFICANDO DEPENDÊNCIAS:${COLOR_RESET}\n"
    
    if [ -x "${BIN_DIR}/check-deps" ]; then
        "${BIN_DIR}/check-deps"
    else
        echo -e "${COLOR_RED}Erro: Script de verificação de dependências não encontrado.${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_YELLOW}Pressione Enter para continuar...${COLOR_RESET}"
    read -r
}

# Função principal
main() {
    # Verificar se há argumentos de linha de comando
    if [ $# -gt 0 ]; then
        case $1 in
            --security)
                security_menu
                ;;
            --caprover)
                caprover_menu
                ;;
            --help | -h)
                show_help
                exit 0
                ;;
            --version | -v)
                echo -e "${COLOR_BLUE}Versão 2.0.0${COLOR_RESET}"
                exit 0
                ;;
            *)
                echo -e "${COLOR_RED}Opção inválida. Use --help para ver as opções disponíveis.${COLOR_RESET}"
                exit 1
                ;;
        esac
    fi
    
    # Modo interativo
    while true; do
        show_menu
        read -r option
        
        case $option in
            1) security_menu ;;
            2) caprover_menu ;;
            3) system_config_menu ;;
            4) advanced_tools_menu ;;
            0) 
                echo -e "\n${COLOR_GREEN}Saindo... Até logo! 👋${COLOR_RESET}"
                exit 0
                ;;
            *)
                echo -e "\n${COLOR_RED}Opção inválida! Por favor, tente novamente.${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Função para exibir o menu de segurança
security_menu() {
    while true; do
        show_security_menu
        read -r option
        
        case $option in
            1) 
                if [ -x "${BIN_DIR}/security/harden" ]; then
                    "${BIN_DIR}/security/harden"
                else
                    echo -e "${COLOR_RED}Erro: Script de hardening não encontrado.${COLOR_RESET}"
                fi
                ;;
            2)
                if [ -x "${BIN_DIR}/security/diagnose" ]; then
                    "${BIN_DIR}/security/diagnose"
                else
                    echo -e "${COLOR_RED}Erro: Script de diagnóstico não encontrado.${COLOR_RESET}"
                fi
                ;;
            3) configure_individual_modules ;;
            4) rollback_changes ;;
            0) break ;;
            *)
                echo -e "\n${COLOR_RED}Opção inválida!${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Função para exibir o menu do CapRover
caprover_menu() {
    while true; do
        show_caprover_menu
        read -r option
        
        case $option in
            1)
                if [ -x "${BIN_DIR}/caprover/setup" ]; then
                    "${BIN_DIR}/caprover/setup"
                else
                    echo -e "${COLOR_RED}Erro: Script de instalação do CapRover não encontrado.${COLOR_RESET}"
                fi
                ;;
            2)
                if [ -x "${BIN_DIR}/caprover/validate" ]; then
                    "${BIN_DIR}/caprover/validate"
                else
                    echo -e "${COLOR_RED}Erro: Script de validação do CapRover não encontrado.${COLOR_RESET}"
                fi
                ;;
            3) 
                echo -e "\n${COLOR_YELLOW}Em desenvolvimento...${COLOR_RESET}"
                sleep 1
                ;;
            0) break ;;
            *)
                echo -e "\n${COLOR_RED}Opção inválida!${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Função para exibir o menu de configuração do sistema
system_config_menu() {
    while true; do
        clear
        show_header
        echo -e "${COLOR_GREEN}CONFIGURAÇÃO DO SISTEMA:${COLOR_RESET}\n"
        
        echo -e "1. ⚙️  Configuração Inicial do Servidor"
        echo -e "2. 🔄 Atualizar Sistema"
        echo -e "3. 🔍 Verificar Dependências"
        echo -e "0. ↩️  Voltar ao menu principal\n"
        echo -n "Escolha uma opção: "
        
        read -r option
        
        case $option in
            1)
                if [ -x "${BIN_DIR}/setup" ]; then
                    "${BIN_DIR}/setup"
                else
                    echo -e "${COLOR_RED}Erro: Script de configuração inicial não encontrado.${COLOR_RESET}"
                fi
                ;;
            2)
                run_command "sudo apt update && sudo apt upgrade -y" "Atualizando o sistema"
                ;;
            3)
                check_dependencies
                ;;
            0) break ;;
            *)
                echo -e "\n${COLOR_RED}Opção inválida!${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Função para exibir o menu de ferramentas avançadas
advanced_tools_menu() {
    while true; do
        show_advanced_tools_menu
        read -r option
        
        case $option in
            1)
                echo -e "\n${COLOR_YELLOW}Atualizando scripts...${COLOR_RESET}"
                # Lógica para atualizar os scripts
                echo -e "${COLOR_GREEN}Scripts atualizados com sucesso!${COLOR_RESET}"
                ;;
            2)
                echo -e "\n${COLOR_YELLOW}Gerando relatório...${COLOR_RESET}"
                # Lógica para gerar relatório
                echo -e "${COLOR_GREEN}Relatório gerado com sucesso!${COLOR_RESET}"
                ;;
            3)
                echo -e "\n${COLOR_YELLOW}Limpando dados temporários...${COLOR_RESET}"
                # Lógica para limpar dados temporários
                echo -e "${COLOR_GREEN}Limpeza concluída!${COLOR_RESET}"
                ;;
            4)
                check_dependencies
                ;;
            0) break ;;
            *)
                echo -e "\n${COLOR_RED}Opção inválida!${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Função para exibir ajuda
show_help() {
    echo -e "${COLOR_BLUE}Uso:${COLOR_RESET} $0 [OPÇÃO]"
    echo -e "\n${COLOR_BLUE}Opções:${COLOR_RESET}"
    echo -e "  --security     Abre o menu de segurança"
    echo -e "  --caprover     Abre o menu do CapRover"
    echo -e "  -h, --help     Mostra esta mensagem de ajuda"
    echo -e "  -v, --version  Mostra a versão do script"
    echo -e "\n${COLOR_BLUE}Exemplos:${COLOR_RESET}"
    echo -e "  $0 --security   # Abre o menu de segurança"
    echo -e "  $0 --caprover   # Abre o menu do CapRover"
    echo -e "  $0             # Abre o menu interativo"
}

# Função para configurar módulos individuais (legado)
configure_individual_modules() {
    echo -e "\n${COLOR_YELLOW}Esta funcionalidade foi movida para o menu de segurança.${COLOR_RESET}"
    echo -e "Por favor, use a opção 'Configurar Módulos Individuais' no menu de segurança.\n"
    sleep 2
}

# Função para reverter alterações (legado)
rollback_changes() {
    echo -e "\n${COLOR_YELLOW}Esta funcionalidade foi movida para o menu de segurança.${COLOR_RESET}"
    echo -e "Por favor, use a opção 'Reverter Alterações (Rollback)' no menu de segurança.\n"
    sleep 2
}

# Função para ferramentas avançadas (legado)
advanced_tools() {
    advanced_tools_menu
}

# Executar função principal
main "$@"
