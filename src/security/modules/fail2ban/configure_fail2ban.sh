#!/bin/bash
#
# Nome do Arquivo: configure_fail2ban.sh
#
# Descrição:
#   Script para configuração segura do Fail2Ban.
#   Implementa as melhores práticas de segurança para proteção contra ataques de força bruta.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - fail2ban_utils.sh (funções auxiliares do Fail2Ban)
#
# Uso:
#   source "$(dirname "$0")/configure_fail2ban.sh"
#   configure_fail2ban [opções]
#
# Opções:
#   --install         Instala o Fail2Ban se não estiver instalado
#   --enable          Habilita e inicia o serviço Fail2Ban
#   --ssh-port=PORTA  Porta SSH para monitorar (padrão: 22)
#   --bantime=TEMPO   Tempo de banimento em segundos (padrão: 1h - 3600)
#   --findtime=TEMPO  Janela de tempo para contagem de falhas (padrão: 10m - 600)
#   --maxretry=NUM    Número máximo de tentativas antes do banimento (padrão: 5)
#   --dry-run         Simula as alterações sem aplicá-las
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

# Carregar funções utilitárias do Fail2Ban
if [ -f "$(dirname "$0")/fail2ban_utils.sh" ]; then
    source "$(dirname "$0")/fail2ban_utils.sh"
else
    log "error" "Não foi possível carregar fail2ban_utils.sh"
    exit 1
fi

#
# configure_fail2ban
#
# Descrição:
#   Função principal para configurar o Fail2Ban com as melhores práticas de segurança.
#
# Parâmetros:
#   $@ - Argumentos de linha de comando
#
# Retorno:
#   0 - Configuração concluída com sucesso
#   1 - Falha na configuração
#
configure_fail2ban() {
    local install_f2b=false
    local enable_f2b=false
    local ssh_port="22"
    local ban_time="3600"     # 1 hora
    local find_time="600"     # 10 minutos
    local max_retry="5"
    local dry_run=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                install_f2b=true
                shift
                ;;
            --enable)
                enable_f2b=true
                shift
                ;;
            --ssh-port=*)
                ssh_port="${1#*=}"
                shift
                ;;
            --bantime=*)
                ban_time="${1#*=}"
                shift
                ;;
            --findtime=*)
                find_time="${1#*=}"
                shift
                ;;
            --maxretry=*)
                max_retry="${1#*=}"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                log "warn" "Opção desconhecida: $1"
                shift
                ;;
        esac
    done
    
    log "info" "Iniciando configuração do Fail2Ban..."
    
    # Instalar Fail2Ban se solicitado
    if ${install_f2b} && ! is_fail2ban_installed; then
        log "info" "Instalando Fail2Ban..."
        if ${dry_run}; then
            log "info" "[DRY RUN] Fail2Ban seria instalado"
        else
            if ! install_fail2ban; then
                log "error" "Falha ao instalar o Fail2Ban"
                return 1
            fi
        fi
    elif ${install_f2b}; then
        log "info" "Fail2Ban já está instalado."
    fi
    
    # Verificar se o Fail2Ban está instalado
    if ! is_fail2ban_installed; then
        log "error" "Fail2Ban não está instalado. Use a opção --install para instalar."
        return 1
    fi
    
    # Fazer backup da configuração atual
    log "info" "Criando backup da configuração atual..."
    local backup_dir
    
    if ${dry_run}; then
        log "info" "[DRY RUN] Backup seria criado em /etc/fail2ban/backup_*"
    else
        if ! backup_dir=$(backup_fail2ban_config); then
            log "error" "Falha ao criar backup da configuração do Fail2Ban"
            return 1
        fi
        
        log "info" "Backup criado em: ${backup_dir}"
    fi
    
    # Configuração básica do Fail2Ban
    log "info" "Configurando parâmetros básicos do Fail2Ban..."
    
    # Configuração do jail SSH
    local ssh_jail_config="\
enabled = true\
port = ${ssh_port}\
filter = sshd\
logpath = /var/log/auth.log\
maxretry = ${max_retry}\
bantime = ${ban_time}\
findtime = ${find_time}\
ignoreip = 127.0.0.1/8 ::1"

    # Configuração do jail para ataques de força bruta SSH
    local ssh_brute_force_config="\
[sshd]\
enabled = true\
port = ${ssh_port}\
filter = sshd\
logpath = /var/log/auth.log\
maxretry = 3\
bantime = 86400\
findtime = 600\
ignoreip = 127.0.0.1/8 ::1"

    # Configuração do jail para ataques de força bruta ao WordPress
    local wordpress_config="\
[wordpress]\
enabled = true\
filter = wordpress\
logpath = /var/log/nginx/access.log\
port = http,https\
maxretry = 3\
bantime = 86400\
findtime = 600"

    # Configuração do jail para ataques de força bruta ao Nginx
    local nginx_http_auth_config="\
[nginx-http-auth]\
enabled = true\
filter = nginx-http-auth\
port = http,https\
logpath = /var/log/nginx/error.log\
maxretry = 3\
bantime = 86400\
findtime = 600"

    # Aplicar configurações se não for um dry run
    if ${dry_run}; then
        log "info" "[DRY RUN] As seguintes configurações seriam aplicadas:"
        log "info" "=== Jail SSH ===\n${ssh_jail_config}"
        log "info" "=== Jail SSH Brute Force ===\n${ssh_brute_force_config}"
        log "info" "=== Jail WordPress ===\n${wordpress_config}"
        log "info" "=== Jail Nginx HTTP Auth ===\n${nginx_http_auth_config}"
    else
        # Aplicar configurações
        log "info" "Aplicando configurações do Fail2Ban..."
        
        # Configurar jails
        configure_jail "sshd" "${ssh_jail_config}" || {
            log "error" "Falha ao configurar o jail SSH"
            return 1
        }
        
        configure_jail "ssh-brute-force" "${ssh_brute_force_config}" || {
            log "warn" "Falha ao configurar o jail para ataques de força bruta SSH"
        }
        
        # Verificar se o Nginx está instalado
        if command -v nginx &> /dev/null; then
            configure_jail "wordpress" "${wordpress_config}" || {
                log "warn" "Falha ao configurar o jail para WordPress"
            }
            
            configure_jail "nginx-http-auth" "${nginx_http_auth_config}" || {
                log "warn" "Falha ao configurar o jail para autenticação HTTP do Nginx"
            }
        fi
        
        # Configurações adicionais para o Fail2Ban
        local fail2ban_config="\
[Definition]\
# Nível de log\
loglevel = INFO\
logtarget = /var/log/fail2ban.log\
\n# Endereço IP para escutar (0.0.0.0 para todos os endereços)\
socket = /var/run/fail2ban/fail2ban.sock\
pidfile = /var/run/fail2ban/fail2ban.pid\
\n# Configurações avançadas\
dbfile = /var/lib/fail2ban/fail2ban.sqlite3\
dbmaxmatches = 10\
dbpurgeage = 1h"
        
        # Criar diretório de configuração se não existir
        mkdir -p "$(dirname "${FAIL2BAN_JAIL_LOCAL}")"
        
        # Escrever configuração básica
        echo -e "${fail2ban_config}" > "${FAIL2BAN_JAIL_LOCAL}.conf"
        
        # Configurar permissões
        chmod 640 "${FAIL2BAN_JAIL_LOCAL}"
        chown root:root "${FAIL2BAN_JAIL_LOCAL}"
    fi
    
    # Habilitar e iniciar o serviço se solicitado
    if ${enable_f2b}; then
        log "info" "Habilitando e iniciando o serviço Fail2Ban..."
        
        if ${dry_run}; then
            log "info" "[DRY RUN] O serviço Fail2Ban seria habilitado e iniciado"
        else
            # Habilitar inicialização automática
            if command -v systemctl &> /dev/null; then
                systemctl enable fail2ban
            elif command -v update-rc.d &> /dev/null; then
                update-rc.d fail2ban defaults
            fi
            
            # Reiniciar o serviço para aplicar as alterações
            if ! restart_fail2ban; then
                log "error" "Falha ao reiniciar o serviço Fail2Ban"
                return 1
            fi
            
            # Verificar status do serviço
            if ! is_fail2ban_running; then
                log "error" "O serviço Fail2Ban não está em execução após a reinicialização"
                return 1
            fi
            
            log "info" "Serviço Fail2Ban está em execução."
        fi
    fi
    
    # Mostrar resumo da configuração
    log "info" "Configuração do Fail2Ban concluída com sucesso."
    log "info" "Resumo da configuração:"
    log "info" "- Porta SSH: ${ssh_port}"
    log "info" "- Tentativas máximas: ${max_retry}"
    log "info" "- Tempo de banimento: ${ban_time} segundos"
    log "info" "- Janela de tempo: ${find_time} segundos"
    
    if ${dry_run}; then
        log "info" "[DRY RUN] Modo de simulação ativado. Nenhuma alteração foi feita."
    fi
    
    return 0
}

#
# show_fail2ban_status
#
# Descrição:
#   Exibe o status atual do Fail2Ban, incluindo jails ativos e IPs banidos.
#
# Retorno:
#   0 - Sucesso
#   1 - Falha ao obter o status
#
show_fail2ban_status() {
    if ! is_fail2ban_installed; then
        log "error" "Fail2Ban não está instalado"
        return 1
    fi
    
    if ! is_fail2ban_running; then
        log "error" "O serviço Fail2Ban não está em execução"
        return 1
    fi
    
    log "info" "=== Status do Fail2Ban ==="
    
    # Mostrar versão
    echo -n "Versão: "
    fail2ban-client --version
    
    # Mostrar status geral
    echo -e "\n=== Status do Serviço ==="
    systemctl status fail2ban --no-pager
    
    # Mostrar jails ativos
    echo -e "\n=== Jails Ativos ==="
    fail2ban-client status | grep -A 100 'Jail list'
    
    # Mostrar IPs banidos
    echo -e "\n=== IPs Banidos ==="
    local banned_ips
    banned_ips=$(get_banned_ips)
    
    if [ -z "${banned_ips}" ]; then
        echo "Nenhum IP banido no momento."
    else
        echo "${banned_ips}" | sort | uniq -c | sort -nr
    fi
    
    return 0
}

# Se o script for executado diretamente, não apenas incluído
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_fail2ban "$@"
fi

# Exportar funções que serão usadas em outros módulos
export -f configure_fail2ban show_fail2ban_status
