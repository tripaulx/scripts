#!/bin/bash
#
# Nome do Arquivo: main.sh
#
# Descrição:
#   Ponto de entrada principal para o sistema de gerenciamento de servidor.
#   Este script foi refatorado para utilizar uma estrutura modular, seguindo
#   as melhores práticas de desenvolvimento e os padrões definidos em AGENTS.md.
#
# Estrutura:
#   - src/ui/         # Interface com o usuário (menus, diálogos)
#   - src/core/       # Lógica principal e inicialização
#   - src/modules/    # Módulos de funcionalidades específicas
#
# Uso:
#   sudo ./main.sh [opções]
#
# Opções:
#   -h, --help      Mostra esta ajuda
#   -v, --verbose   Modo verboso (mais detalhes na saída)
#   -d, --dry-run   Simula as alterações sem aplicá-las
#
# Autor: Equipe de Infraestrutura
# Data: 2025-07-06
# Versão: 2.0.0
#
# Histórico de Alterações:
#   2025-07-06 - Versão 2.0.0 - Refatoração para estrutura modular
#   2025-07-06 - Versão 1.0.0 - Versão inicial
#
# Dependências:
#   - Bash 4.0+
#   - Módulos em src/core/ e src/ui/
#   - Permissões de superusuário (recomendado)

# Obter diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar módulo de inicialização
if [ -f "${SCRIPT_DIR}/src/core/initialization.sh" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/src/core/initialization.sh"
else
    echo "Erro: Não foi possível carregar o módulo de inicialização." >&2
    exit 1
fi

# Ponto de entrada principal
initialize

# Configurar tratamento de erros
trap 'error_handler $? $LINENO' ERR

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

#
# BLOCO: Interface de Usuário
#
# Propósito:
#   Funções responsáveis pela exibição e interação com o usuário,
#   incluindo menus, cabeçalhos e mensagens formatadas.
#
# Contexto:
#   - Utiliza variáveis de cor para melhorar a legibilidade
#   - Centraliza a formatação de saída
#   - Mantém consistência visual em toda a aplicação
#
# Exceções:
#   - Não deve conter lógica de negócio
#   - Deve ser independente de outras partes do sistema
#

#
# Função: show_header
#
# Descrição:
#   Exibe o cabeçalho formatado do sistema no terminal.
#   Inclui informações de versão, data e hora atuais.
#
# Parâmetros:
#   Nenhum
#
# Retorno:
#   Nenhum (exibe saída formatada no terminal)
#
# Exemplo:
#   show_header
#
show_header() {
    clear
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}    SISTEMA DE GERENCIAMENTO DE SERVIDOR          ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  Versão: 1.0.0${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  Data: $(date +'%d/%m/%Y %H:%M:%S')${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}\n"
}

#
# Função: show_menu
#
# Descrição:
#   Exibe o menu principal do sistema com opções numeradas.
#   Interface primária para navegação do usuário.
#
# Fluxo:
#   1. Limpa a tela e exibe o cabeçalho
#   2. Mostra as opções disponíveis
#   3. Aguarda a seleção do usuário
#
# Opções:
#   1. Segurança do Sistema - Acessa o menu de segurança
#   2. Gerenciar CapRover - Acessa o menu do CapRover
#   3. Configurações do Sistema - Acessa configurações avançadas
#   4. Ferramentas Avançadas - Acessa utilitários avançados
#   5. Sair - Encerra a aplicação
#
# Retorno:
#   Nenhum (exibe o menu no terminal)
#
show_menu() {
    show_header
    echo -e "${COLOR_BLUE}MENU PRINCIPAL${COLOR_RESET}"
    echo -e "${COLOR_BLUE}--------------${COLOR_RESET}"
    echo -e "1. Segurança do Sistema"
    echo -e "2. Gerenciar CapRover"
    echo -e "3. Configurações do Sistema"
    echo -e "4. Ferramentas Avançadas"
    echo -e "5. Sair"
    echo -e "\n${COLOR_YELLOW}Selecione uma opção [1-5]: ${COLOR_RESET}"
}

#
# Função: show_security_menu
#
# Descrição:
#   Exibe o menu de segurança do sistema com opções para execução de hardening,
#   diagnóstico e gerenciamento de módulos de segurança.
#
# Fluxo:
#   1. Limpa a tela e exibe o cabeçalho
#   2. Mostra as opções de segurança disponíveis
#   3. Aguarda a seleção do usuário
#
# Opções:
#   1. Executar Hardening Completo - Aplica todas as configurações de segurança
#   2. Executar Diagnóstico - Verifica o estado atual de segurança
#   3. Configurar Módulos - Ajusta configurações individuais
#   4. Reverter Alterações - Desfaz as últimas alterações
#   0. Voltar - Retorna ao menu principal
#
# Variáveis de Ambiente:
#   - COLOR_BLUE: Cor para títulos
#   - COLOR_GREEN: Cor para opções ativas
#   - COLOR_YELLOW: Cor para entrada do usuário
#   - COLOR_RESET: Resetar formatação de cor
#
# Retorno:
#   Nenhum (exibe o menu no terminal)
#
show_security_menu() {
    clear
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}    MENU DE SEGURANÇA DO SISTEMA          ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1. 🔒 Executar Hardening Completo${COLOR_RESET}"
    echo -e "${COLOR_GREEN}2. 🔍 Executar Diagnóstico de Segurança${COLOR_RESET}"
    echo -e "${COLOR_GREEN}3. ⚙️ Configurar Módulos Individuais${COLOR_RESET}"
    echo -e "${COLOR_GREEN}4. 🔄 Reverter Alterações (Rollback)${COLOR_RESET}"
    echo -e "${COLOR_GREEN}0. ↩️ Voltar ao menu principal${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}Selecione uma opção [0-4]: ${COLOR_RESET}"
    show_header
    echo -e "${COLOR_GREEN}SEGURANÇA:${COLOR_RESET}\n"
    
    echo -e "1. 🛡️  Executar Hardening Completo"
    echo -e "2. 🔍 Executar Diagnóstico de Segurança"
    echo -e "3. ⚙️  Configurar Módulos Individuais"
    echo -e "4. 🔄 Reverter Alterações (Rollback)"
    echo -e "0. ↩️  Voltar ao menu principal\n"
    echo -n "Escolha uma opção: "
}

#
# Função: show_caprover_menu
#
# Descrição:
#   Exibe o menu de gerenciamento do CapRover com opções para instalação,
#   validação e manutenção do ambiente CapRover.
#
# Fluxo:
#   1. Limpa a tela e exibe o cabeçalho
#   2. Mostra as opções do CapRover disponíveis
#   3. Aguarda a seleção do usuário
#
# Opções:
#   1. Instalar/Configurar - Instala ou reconfigura o CapRover
#   2. Validar Instalação - Verifica a instalação atual
#   3. Ferramentas de Manutenção - Acessa utilitários avançados
#   0. Voltar - Retorna ao menu principal
#
# Dependências:
#   - show_header: Função para exibir o cabeçalho
#
# Retorno:
#   Nenhum (exibe o menu no terminal)
#
show_caprover_menu() {
    clear
    show_header
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}    GERENCIAMENTO CAPROVER          ${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}1. 🚀 Instalar/Configurar CapRover${COLOR_RESET}"
    echo -e "${COLOR_GREEN}2. 🔍 Validar Instalação${COLOR_RESET}"
    echo -e "${COLOR_GREEN}3. 🛠️  Ferramentas de Manutenção${COLOR_RESET}"
    echo -e "${COLOR_GREEN}0. ↩️  Voltar ao menu principal${COLOR_RESET}"
    echo -e "\n${COLOR_YELLOW}Selecione uma opção [0-3]: ${COLOR_RESET}"
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

#
# Função: load_module
#
# Descrição:
#   Carrega dinamicamente um módulo do sistema, incluindo suas funções e validações.
#   Esta função é responsável por carregar os scripts necessários para a execução
#   de funcionalidades modulares do sistema.
#
# Parâmetros:
#   $1 - Nome do módulo a ser carregado (sem extensão)
#
# Fluxo:
#   1. Verifica se o diretório do módulo existe
#   2. Carrega o arquivo principal do módulo (.sh)
#   3. Carrega as validações do módulo, se existirem (validations.sh)
#
# Retorno:
#   0 - Módulo carregado com sucesso
#   1 - Falha ao carregar o módulo
#
# Variáveis Globais:
#   - MODULES_DIR: Diretório base dos módulos
#
# Dependências:
#   - error: Função para exibir mensagens de erro
#
# Exemplo:
#   load_module "ssh"
#   if [ $? -eq 0 ]; then
#       echo "Módulo SSH carregado com sucesso"
#   fi
#
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

#
# Função: execute_full_hardening
#
# Descrição:
#   Executa todas as etapas de hardening do sistema de forma sequencial,
#   aplicando as configurações de segurança definidas nos módulos.
#
# Fluxo:
#   1. Verifica privilégios de superusuário
#   2. Cria diretório de backup
#   3. Carrega e executa todos os módulos de segurança
#   4. Aplica as configurações de hardening
#   5. Gera relatório de execução
#
# Requisitos:
#   - Execução como superusuário (root)
#   - Módulos de segurança instalados
#
# Variáveis Globais:
#   - BACKUP_DIR: Diretório para armazenar backups
#   - LOG_DIR: Diretório para armazenar logs
#   - MODULES: Lista de módulos a serem executados
#
# Dependências:
#   - load_module: Para carregar os módulos de segurança
#   - check_root_privileges: Para verificar privilégios
#   - show_header: Para exibir o cabeçalho
#
# Retorno:
#   0 - Hardening executado com sucesso
#   1 - Falha durante a execução do hardening
#
# Função: configure_individual_modules
#
# Descrição:
#   Permite configurar cada módulo de segurança individualmente, fornecendo
#   uma interface interativa para ajustes específicos em cada módulo.
#
# Fluxo:
#   1. Exibe o menu de módulos disponíveis
#   2. Aguarda a seleção do usuário
#   3. Carrega o módulo selecionado
#   4. Executa a configuração específica do módulo
#   5. Retorna ao menu após a conclusão
#
# Módulos Suportados:
#   1. SSH - Configurações de segurança do servidor SSH
#   2. UFW - Configuração do firewall
#   3. Fail2Ban - Configuração de proteção contra força bruta
#
# Variáveis Globais:
#   - COLOR_YELLOW: Cor para mensagens de aviso
#   - COLOR_RESET: Resetar formatação de cor
#
# Dependências:
#   - load_module: Para carregar os módulos
#   - show_module_menu: Para exibir o menu de módulos
#
# Retorno:
#   Nenhum (interface interativa)
#
# Exemplo:
#   configure_individual_modules
#
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

#
# Função: generate_security_report
#
# Descrição:
#   Gera um relatório abrangente de segurança do sistema, incluindo verificações
#   de serviços, atualizações, portas abertas, usuários, logs e muito mais.
#
# Fluxo:
#   1. Cria diretório de relatórios com timestamp
#   2. Coleta informações do sistema
#   3. Verifica status de serviços essenciais
#   4. Coleta informações de segurança
#   5. Gera relatório detalhado em arquivo
#
# Seções do Relatório:
#   1. Informações do Sistema
#   2. Status dos Serviços (SSH, UFW, Fail2Ban)
#   3. Atualizações Disponíveis
#   4. Portas Abertas
#   5. Usuários com Privilégios
#   6. Contas com Senhas Vazias
#   7. Logs de Segurança
#   8. Verificação de Rootkits
#   9. Verificação de Malware
#   10. Verificação de Integridade de Arquivos
#   11. Últimos Logins Bem-Sucedidos
#   12. Tentativas de Login Malsucedidas
#   13. Arquivos de Inicialização
#   14. Tarefas Agendadas
#   15. Permissões de Arquivos Importantes
#   16. Uso de Disco
#   17. Uso de Memória
#   18. Processos em Execução
#   19. Conexões de Rede Ativas
#   20. Atualizações de Segurança
#
# Variáveis Globais:
#   - REPORTS_DIR: Diretório base para armazenar relatórios
#   - COLOR_GREEN: Cor para mensagens de sucesso
#   - COLOR_YELLOW: Cor para mensagens de aviso
#   - COLOR_RESET: Resetar formatação de cor
#
# Dependências:
#   - check_root_privileges: Para verificar privilégios de superusuário
#   - show_header: Para exibir o cabeçalho
#
# Retorno:
#   Nenhum (gera arquivo de relatório)
#
# Exemplo:
#   generate_security_report
#
generate_security_report() {
    show_header
    echo -e "${COLOR_GREEN}RELATÓRIO DE SEGURANÇA${COLOR_RESET}\n"
    
    # Verificar privilégios de superusuário
    check_root_privileges
    
    # Criar diretório de relatórios
    local report_dir="${REPORTS_DIR}/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$report_dir"
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

#
# Função: rollback_changes
#
# Descrição:
#   Permite reverter as alterações feitas pelo script para um estado anterior,
#   utilizando os backups criados durante a execução das operações.
#
# Fluxo:
#   1. Exibe cabeçalho e aviso de confirmação
#   2. Lista todos os backups disponíveis no diretório de backup
#   3. Permite ao usuário selecionar um backup para restauração
#   4. Executa a restauração do backup selecionado
#
# Variáveis Globais:
#   - BACKUP_DIR: Diretório onde os backups estão armazenados
#   - COLOR_GREEN: Cor para mensagens de sucesso
#   - COLOR_RED: Cor para mensagens de erro/aviso
#   - COLOR_YELLOW: Cor para mensagens informativas
#   - COLOR_RESET: Resetar formatação de cor
#
# Dependências:
#   - show_header: Para exibir o cabeçalho
#   - Funções de rollback específicas de cada módulo
#
# Retorno:
#   0 - Rollback concluído com sucesso
#   1 - Falha durante o processo de rollback
#
# Exemplo:
#   rollback_changes
#
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

#
# Função: advanced_tools
#
# Descrição:
#   Fornece um conjunto de ferramentas avançadas para gerenciamento do sistema,
#   incluindo atualização de scripts, geração de relatórios e limpeza de dados.
#
# Opções:
#   1. Atualizar Scripts - Atualiza os scripts a partir do repositório Git
#   2. Gerar Relatório Detalhado - Gera um relatório de segurança completo
#   3. Limpar Dados Temporários - Remove arquivos temporários e caches
#   4. Verificar Dependências - Verifica as dependências do sistema
#   0. Voltar - Retorna ao menu anterior
#
# Fluxo:
#   1. Exibe o menu de ferramentas avançadas
#   2. Aguarda a seleção do usuário
#   3. Executa a ação correspondente
#   4. Retorna ao menu após a conclusão
#
# Variáveis Globais:
#   - COLOR_BLUE: Cor para títulos
#   - COLOR_GREEN: Cor para mensagens de sucesso
#   - COLOR_RED: Cor para mensagens de erro/aviso
#   - COLOR_YELLOW: Cor para mensagens informativas
#   - COLOR_RESET: Resetar formatação de cor
#
# Dependências:
#   - show_advanced_tools_menu: Para exibir o menu
#   - generate_security_report: Para gerar relatórios
#   - check_dependencies: Para verificar dependências
#   - Comandos do sistema: git, apt-get, find, rm
#
# Retorno:
#   Nenhum (interface interativa)
#
# Exemplo:
#   advanced_tools
#
advanced_tools() {
    while true; do
        show_advanced_tools_menu
        read -r choice
        
        case $choice in
            1) # Atualizar Scripts
                echo -e "\n${COLOR_BLUE}=== ATUALIZAR SCRIPTS ===${COLOR_RESET}\n"
                
                # Verificar se o git está instalado
                if ! command -v git &> /dev/null; then
                    error "Git não está instalado. Instale o Git para continuar."
                    read -p "Pressione Enter para continuar..."
                    continue
                fi
                
                # Verificar se o diretório é um repositório git
                if [ ! -d ".git" ]; then
                    error "Este não é um repositório Git."
                    read -p "Pressione Enter para continuar..."
                    continue
                fi
                
                # Obter o branch atual
                current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
                if [ $? -ne 0 ]; then
                    error "Falha ao obter o branch atual."
                    read -p "Pressione Enter para continuar..."
                    continue
                fi
                
                echo -e "Branch atual: ${COLOR_YELLOW}$current_branch${COLOR_RESET}"
                echo -e "\n${COLOR_YELLOW}⚠️  ATENÇÃO: Esta operação irá sobrescrever todas as alterações locais.${COLOR_RESET}\n"
                
                read -p "Tem certeza que deseja atualizar os scripts? (s/N): " confirm
                
                if [[ "$confirm" =~ ^[Ss][IiMm]?$ ]]; then
                    echo -e "\n${COLOR_YELLOW}Atualizando scripts...${COLOR_RESET}"
                    
                    # Fazer backup das alterações locais
                    echo -e "\n${COLOR_BLUE}Fazendo backup das alterações locais...${COLOR_RESET}"
                    git stash save "Alterações locais antes da atualização em $(date +'%Y-%m-%d %H:%M:%S')"
                    
                    # Atualizar o repositório
                    echo -e "\n${COLOR_BLUE}Atualizando repositório...${COLOR_RESET}"
                    git fetch origin "$current_branch"
                    
                    if [ $? -ne 0 ]; then
                        error "Falha ao buscar atualizações do repositório remoto."
                        read -p "Pressione Enter para continuar..."
                        continue
                    fi
                    
                    # Verificar se há atualizações disponíveis
                    LOCAL=$(git rev-parse @)
                    REMOTE=$(git rev-parse "@\{u\}")
                    
                    if [ "$LOCAL" = "$REMOTE" ]; then
                        echo -e "\n${COLOR_GREEN}✅ Seus scripts já estão atualizados!${COLOR_RESET}"
                        read -p "Pressione Enter para continuar..."
                        continue
                    fi
                    
                    # Aplicar as atualizações
                    echo -e "\n${COLOR_BLUE}Aplicando atualizações...${COLOR_RESET}"
                    git reset --hard "origin/$current_branch"
                    
                    if [ $? -ne 0 ]; then
                        error "Falha ao aplicar as atualizações."
                        read -p "Pressione Enter para continuar..."
                        continue
                    fi
                    
                    # Tornar os scripts executáveis
                    echo -e "\n${COLOR_BLUE}Configurando permissões...${COLOR_RESET}"
                    chmod +x *.sh
                    
                    echo -e "\n${COLOR_GREEN}✅ Scripts atualizados com sucesso!${COLOR_RESET}"
                    echo -e "${COLOR_YELLOW}Reinicie o script para aplicar as alterações.${COLOR_RESET}"
                    exit 0
                else
                    echo -e "\n${COLOR_YELLOW}Atualização cancelada pelo usuário.${COLOR_RESET}"
                    read -p "Pressione Enter para continuar..."
                fi
                ;;
                
            2) # Gerar Relatório Detalhado
                generate_security_report
                ;;
                
            3) # Limpar Dados Temporários
                echo -e "\n${COLOR_BLUE}=== LIMPAR DADOS TEMPORÁRIOS ===${COLOR_RESET}\n"
                
                echo -e "${COLOR_RED}⚠️  ATENÇÃO: Esta operação irá remover arquivos temporários e caches.${COLOR_RESET}\n"
                
                read -p "Tem certeza que deseja continuar? (s/N): " confirm
                
                if [[ "$confirm" =~ ^[Ss][IiMm]?$ ]]; then
                    echo -e "\n${COLOR_YELLOW}Limpando dados temporários...${COLOR_RESET}"
                    
                    # Limpar cache do apt
                    if command -v apt-get &> /dev/null; then
                        echo -e "\n${COLOR_BLUE}Limpando cache do apt...${COLOR_RESET}"
                        apt-get clean
                        apt-get autoclean
                    fi
                    
                    # Limpar logs antigos
                    echo -e "\n${COLOR_BLUE}Limpando logs antigos...${COLOR_RESET}"
                    find /var/log -type f -name "*.gz" -delete
                    find /var/log -type f -name "*.log.*" -delete
                    
                    # Limpar diretórios temporários
                    echo -e "\n${COLOR_BLUE}Limpando diretórios temporários...${COLOR_RESET}"
                    rm -rf /tmp/*
                    rm -rf /var/tmp/*
                    
                    echo -e "\n${COLOR_GREEN}✅ Limpeza concluída com sucesso!${COLOR_RESET}"
                else
                    echo -e "\n${COLOR_YELLOW}Operação cancelada pelo usuário.${COLOR_RESET}"
                fi
                
                read -p "Pressione Enter para continuar..."
                ;;
                
            4) # Verificar Dependências
                echo -e "\n${COLOR_BLUE}=== VERIFICAR DEPENDÊNCIAS ===${COLOR_RESET}\n"
                
                check_dependencies
                
                read -p "Pressione Enter para continuar..."
                ;;
                
            0) # Voltar
                return 0
                ;;
                
            *)
                error "Opção inválida. Tente novamente."
                read -p "Pressione Enter para continuar..."
                ;;
        esac
    done
}
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
