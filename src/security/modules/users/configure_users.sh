#!/bin/bash
#
# Nome do Arquivo: configure_users.sh
#
# Descrição:
#   Script para gerenciamento de usuários e grupos no sistema.
#   Permite criar, modificar e remover usuários e grupos, além de configurar
#   permissões e acessos.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - user_utils.sh (funções auxiliares de usuários)
#
# Uso:
#   source "$(dirname "$0")/configure_users.sh"
#   configure_users [opções] [argumentos]
#
# Opções:
#   --create-user USERNAME [--fullname "NOME COMPLETO"] [--shell SHELL] [--home DIR]
#                         Cria um novo usuário
#   --set-password USERNAME [PASSWORD]
#                         Define uma senha para o usuário (gera aleatória se não fornecida)
#   --add-to-group USERNAME GROUP1,GROUP2,... [--create-groups]
#                         Adiciona o usuário a um ou mais grupos
#   --setup-sudo TARGET [--rule "REGRA_SUDO"] [--file ARQUIVO]
#                         Configura acesso sudo para um usuário ou grupo
#   --lock-account USERNAME
#                         Bloqueia uma conta de usuário
#   --unlock-account USERNAME
#                         Desbloqueia uma conta de usuário
#   --list-users [all|system|human]
#                         Lista usuários do sistema
#   --user-info USERNAME  Exibe informações detalhadas sobre um usuário
#   --dry-run             Simula as operações sem fazer alterações reais
#   --help                Exibe esta ajuda
#
# Exemplos:
#   # Criar um novo usuário
#   configure_users.sh --create-user johndoe --fullname "John Doe" --shell /bin/bash
#
#   # Adicionar usuário a grupos (criando os grupos se não existirem)
#   configure_users.sh --add-to-group johndoe sudo,adm,www-data --create-groups
#
#   # Configurar acesso sudo para um usuário
#   configure_users.sh --setup-sudo johndoe --rule "ALL=(ALL:ALL) ALL"
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-06

# Carregar funções utilitárias de segurança
if [ -f "$(dirname "$0")/../../core/security_utils.sh" ]; then
    source "$(dirname "$0")/../../core/security_utils.sh"
else
    echo "Erro: Não foi possível carregar security_utils.sh" >&2
    exit 1
fi

# Carregar funções utilitárias de usuários
UTILS_PATH="$(dirname "$0")/user_utils.sh"
echo "[DEBUG] Sourcing $UTILS_PATH" >&2
if [ -f "$UTILS_PATH" ]; then
    # shellcheck source=/dev/null
    source "$UTILS_PATH"
else
    echo "Erro: Não foi possível carregar user_utils.sh em $UTILS_PATH" >&2
    exit 1
fi

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    grep '^#/' "$0" | cut -c4-
    exit 0
}

#
# parse_arguments
#
# Descrição:
#   Processa os argumentos da linha de comando.
#
# Retorno:
#   Configura as variáveis globais com base nos argumentos fornecidos
#
parse_arguments() {
    local create_user=0
    local set_password=0
    local add_to_group=0
    local setup_sudo=0
    local lock_account=0
    local unlock_account=0
    local list_users=0
    local user_info=0
    local dry_run=0
    
    local username=""
    local fullname=""
    local shell="/bin/bash"
    local home_dir=""
    local password=""
    local groups=""
    local create_groups=0
    local sudo_target=""
    local sudo_rule="ALL=(ALL:ALL) ALL"
    local sudo_file="/etc/sudoers.d/90-custom-users"
    local list_filter="all"
    
    # Verificar se não há argumentos
    if [ $# -eq 0 ]; then
        show_help
    fi
    
    # Processar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --create-user)
                create_user=1
                username="$2"
                shift 2
                ;;
            --fullname)
                fullname="$2"
                shift 2
                ;;
            --shell)
                shell="$2"
                shift 2
                ;;
            --home)
                home_dir="$2"
                shift 2
                ;;
            --set-password)
                set_password=1
                username="$2"
                if [ -n "$3" ] && [[ ! "$3" == --* ]]; then
                    password="$3"
                    shift 3
                else
                    shift 2
                fi
                ;;
            --add-to-group)
                add_to_group=1
                username="$2"
                groups="$3"
                shift 3
                ;;
            --create-groups)
                create_groups=1
                shift
                ;;
            --setup-sudo)
                setup_sudo=1
                sudo_target="$2"
                shift 2
                ;;
            --rule)
                sudo_rule="$2"
                shift 2
                ;;
            --file)
                sudo_file="$2"
                shift 2
                ;;
            --lock-account)
                lock_account=1
                username="$2"
                shift 2
                ;;
            --unlock-account)
                unlock_account=1
                username="$2"
                shift 2
                ;;
            --list-users)
                list_users=1
                if [ -n "$2" ] && [[ ! "$2" == --* ]]; then
                    list_filter="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --user-info)
                user_info=1
                username="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log "error" "Opção inválida: $1"
                show_help
                exit 1
                ;;  # SC2317: nenhum código após exit
        esac
    done
    
    # Executar ações com base nos argumentos
    if [ ${create_user} -eq 1 ]; then
        if [ -z "${username}" ]; then
            log "error" "Nome de usuário não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Criando usuário: ${username}"
        if [ ${dry_run} -eq 0 ]; then
            create_user "${username}" "${fullname}" "${shell}" "${home_dir}" || exit 1  # SC2317: nenhum código após exit
            
            # Definir senha se fornecida
            if [ -n "${password}" ]; then
                set_user_password "${username}" "${password}" > /dev/null || exit 1
            fi
        else
            log "info" "[DRY RUN] Criar usuário: ${username}"
            log "info" "  Nome completo: ${fullname}"
            log "info" "  Shell: ${shell}"
            log "info" "  Diretório home: ${home_dir:-/home/${username}}"
        fi
    fi
    
    if [ ${set_password} -eq 1 ]; then
        if [ -z "${username}" ]; then
            log "error" "Nome de usuário não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Definindo senha para o usuário: ${username}"
        if [ ${dry_run} -eq 0 ]; then
            local new_password
            if new_password=$(set_user_password "${username}" "${password}"); then
                log "info" "Senha definida com sucesso para o usuário: ${username}"
                if [ -z "${password}" ]; then
                    log "info" "Senha gerada: ${new_password}"
                fi
            else
                log "error" "Falha ao definir a senha para o usuário: ${username}"
                exit 1
            fi
        else
            log "info" "[DRY RUN] Definir senha para o usuário: ${username}"
            if [ -n "${password}" ]; then
                log "info" "  Senha fornecida: [REDACTED]"
            else
                log "info" "  Será gerada uma senha aleatória"
            fi
        fi
    fi
    
    if [ ${add_to_group} -eq 1 ]; then
        if [ -z "${username}" ] || [ -z "${groups}" ]; then
            log "error" "Nome de usuário e/ou grupos não especificados"
            show_help
            exit 1
        fi
        
        log "info" "Adicionando usuário ${username} aos grupos: ${groups}"
        if [ ${dry_run} -eq 0 ]; then
            add_user_to_group "${username}" "${groups}" "$([ ${create_groups} -eq 1 ] && echo "create")" || exit 1
        else
            log "info" "[DRY RUN] Adicionar usuário ${username} aos grupos: ${groups}"
            if [ ${create_groups} -eq 1 ]; then
                log "info" "  Criar grupos que não existirem: Sim"
            fi
        fi
    fi
    
    if [ ${setup_sudo} -eq 1 ]; then
        if [ -z "${sudo_target}" ]; then
            log "error" "Alvo (usuário ou grupo) não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Configurando acesso sudo para: ${sudo_target}"
        log "debug" "Regra: ${sudo_target} ${sudo_rule}"
        
        if [ ${dry_run} -eq 0 ]; then
            setup_sudo_access "${sudo_target}" "${sudo_rule}" "${sudo_file}" || exit 1
        else
            log "info" "[DRY RUN] Configurar acesso sudo para: ${sudo_target}"
            log "info" "  Regra: ${sudo_target} ${sudo_rule}"
            log "info" "  Arquivo: ${sudo_file}"
        fi
    fi
    
    if [ ${lock_account} -eq 1 ]; then
        if [ -z "${username}" ]; then
            log "error" "Nome de usuário não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Bloqueando conta do usuário: ${username}"
        if [ ${dry_run} -eq 0 ]; then
            lock_user_account "${username}" || exit 1
        else
            log "info" "[DRY RUN] Bloquear conta do usuário: ${username}"
        fi
    fi
    
    if [ ${unlock_account} -eq 1 ]; then
        if [ -z "${username}" ]; then
            log "error" "Nome de usuário não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Desbloqueando conta do usuário: ${username}"
        if [ ${dry_run} -eq 0 ]; then
            unlock_user_account "${username}" || exit 1
        else
            log "info" "[DRY RUN] Desbloquear conta do usuário: ${username}"
        fi
    fi
    
    if [ ${list_users} -eq 1 ]; then
        log "info" "Listando usuários (${list_filter}):"
        if [ ${dry_run} -eq 0 ]; then
            list_users "${list_filter}" || exit 1
        else
            log "info" "[DRY RUN] Listar usuários (${list_filter})"
        fi
    fi
    
    if [ ${user_info} -eq 1 ]; then
        if [ -z "${username}" ]; then
            log "error" "Nome de usuário não especificado"
            show_help
            exit 1
        fi
        
        log "info" "Obtendo informações do usuário: ${username}"
        if [ ${dry_run} -eq 0 ]; then
            get_user_info "${username}" || exit 1
        else
            log "info" "[DRY RUN] Obter informações do usuário: ${username}"
        fi
    fi
}

#
# main
#
# Descrição:
#   Função principal do script.
#
main() {
    # Verificar se o script está sendo executado como root
    if [ "$(id -u)" -ne 0 ]; then
        log "error" "Este script deve ser executado como root"
        exit 1
    fi
    
    # Processar argumentos
    parse_arguments "$@"
    
    log "info" "Operação concluída com sucesso"
    return 0
}

# Se o script for executado diretamente, não apenas incluído
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# Exportar funções que serão usadas em outros módulos
export -f parse_arguments main
