#!/bin/bash
#
# Nome do Arquivo: configure_ufw.sh
#
# Descrição:
#   Script para configuração segura do UFW (Uncomplicated Firewall).
#   Implementa as melhores práticas de segurança para firewalls em servidores Linux.
#
# Dependências:
#   - security_utils.sh (funções de log e validação)
#   - ufw_utils.sh (funções auxiliares de UFW)
#
# Uso:
#   source "$(dirname "$0")/configure_ufw.sh"
#   configure_ufw [opções]
#
# Opções:
#   --install         Instala o UFW se não estiver instalado
#   --enable          Habilita o UFW com configurações padrão
#   --ssh-port=PORTA  Configura a porta SSH (padrão: 22)
#   --allow-ips=IPS   Lista de IPs permitidos (separados por vírgula)
#   --enable-logging  Habilita o registro de logs (nível médio)
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

# Carregar funções utilitárias do UFW
if [ -f "$(dirname "$0")/ufw_utils.sh" ]; then
    source "$(dirname "$0")/ufw_utils.sh"
else
    log "error" "Não foi possível carregar ufw_utils.sh"
    exit 1
fi

#
# configure_ufw
#
# Descrição:
#   Função principal para configurar o UFW com as melhores práticas de segurança.
#
# Parâmetros:
#   $@ - Argumentos de linha de comando
#
# Retorno:
#   0 - Configuração concluída com sucesso
#   1 - Falha na configuração
#
configure_ufw() {
    local install_ufw=false
    local enable_ufw=false
    local ssh_port=""
    local allowed_ips=()
    local enable_logging=false
    local dry_run=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)
                install_ufw=true
                shift
                ;;
            --enable)
                enable_ufw=true
                shift
                ;;
            --ssh-port=*)
                ssh_port="${1#*=}"
                shift
                ;;
            --allow-ips=*)
                IFS=',' read -r -a allowed_ips <<< "${1#*=}"
                shift
                ;;
            --enable-logging)
                enable_logging=true
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
    
    log "info" "Iniciando configuração do UFW..."
    
    # Instalar UFW se solicitado
    if ${install_ufw} && ! is_ufw_installed; then
        log "info" "Instalando UFW..."
        if ! install_ufw; then
            log "error" "Falha ao instalar o UFW"
            return 1
        fi
    elif ${install_ufw}; then
        log "info" "UFW já está instalado."
    fi
    
    # Verificar se o UFW está instalado
    if ! is_ufw_installed; then
        log "error" "UFW não está instalado. Use a opção --install para instalar."
        return 1
    fi
    
    # Fazer backup da configuração atual
    log "info" "Criando backup da configuração atual..."
    local backup_dir
    backup_dir=$(backup_ufw_config)
    
    if [ $? -ne 0 ]; then
        log "error" "Falha ao criar backup da configuração do UFW"
        return 1
    fi
    
    log "info" "Backup criado em: ${backup_dir}"
    
    # Habilitar UFW se solicitado
    if ${enable_ufw}; then
        log "info" "Habilitando UFW..."
        
        # Verificar se estamos em modo de simulação
        if ${dry_run}; then
            log "info" "[DRY RUN] UFW seria habilitado com configurações padrão"
        else
            if ! enable_ufw "noninteractive"; then
                log "error" "Falha ao habilitar o UFW"
                return 1
            fi
        fi
    fi
    
    # Configurar porta SSH
    if [ -n "${ssh_port}" ]; then
        log "info" "Configurando porta SSH: ${ssh_port}"
        
        if ${dry_run}; then
            log "info" "[DRY RUN] Porta SSH seria configurada para: ${ssh_port}"
        else
            if ! allow_port "${ssh_port}" "tcp" "SSH"; then
                log "error" "Falha ao configurar a porta SSH"
                return 1
            fi
        fi
    fi
    
    # Configurar IPs permitidos
    if [ ${#allowed_ips[@]} -gt 0 ]; then
        log "info" "Configurando IPs permitidos..."
        
        for ip in "${allowed_ips[@]}"; do
            # Remover espaços em branco
            ip=$(echo "${ip}" | tr -d '[:space:]')
            
            # Validar endereço IP
            if ! validate_ip "${ip}"; then
                log "warn" "Endereço IP inválido: ${ip}"
                continue
            fi
            
            if ${dry_run}; then
                log "info" "[DRY RUN] IP seria permitido: ${ip}"
            else
                if ! allow_ip "${ip}"; then
                    log "warn" "Falha ao permitir o IP: ${ip}"
                else
                    log "info" "IP permitido com sucesso: ${ip}"
                fi
            fi
        done
    fi
    
    # Habilitar logging se solicitado
    if ${enable_logging}; then
        log "info" "Habilitando logs do UFW..."
        
        if ${dry_run}; then
            log "info" "[DRY RUN] Logs do UFW seriam habilitados com nível médio"
        else
            if ! enable_logging "medium"; then
                log "warn" "Falha ao habilitar os logs do UFW"
            fi
        fi
    fi
    
    # Adicionar regras de segurança adicionais
    log "info" "Adicionando regras de segurança adicionais..."
    
    # Permitir localhost
    if ! ${dry_run}; then
        allow_ip "127.0.0.1"
        allow_ip "::1"
    fi
    
    # Negar tráfego suspeito
    local suspicious_ports=(
        "135:139"  # NetBIOS
        "445"      # SMB
        "1433:1434" # MS SQL
        "3306"     # MySQL
        "5432"     # PostgreSQL
        "3389"     # RDP
        "5900"     # VNC
        "8080"     # Proxy HTTP alternativo
    )
    
    for port in "${suspicious_ports[@]}"; do
        if ${dry_run}; then
            log "info" "[DRY RUN] Tráfego seria negado na porta: ${port}"
        else
            if ! deny_port "${port}" "tcp" "Porta suspeita"; then
                log "warn" "Falha ao negar tráfego na porta: ${port}"
            fi
        fi
    done
    
    # Permitir ICMP (ping)
    if ! ${dry_run}; then
        ufw allow in icmp --icmp-type echo-request
    fi
    
    # Mostrar status final
    if ! ${dry_run}; then
        show_status
    else
        log "info" "[DRY RUN] Modo de simulação ativado. Nenhuma alteração foi feita."
    fi
    
    log "info" "Configuração do UFW concluída com sucesso."
    return 0
}

#
# configure_default_ufw_rules
#
# Descrição:
#   Configura regras padrão recomendadas para o UFW.
#   Esta função é chamada internamente por configure_ufw.
#
# Retorno:
#   0 - Sucesso
#   1 - Falha
#
configure_default_ufw_rules() {
    log "info" "Configurando regras padrão do UFW..."
    
    # Definir políticas padrão
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir conexões SSH (se a porta não foi especificada)
    if [ -z "${ssh_port}" ]; then
        ufw allow 22/tcp comment 'SSH'
    fi
    
    # Permitir tráfego HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Permitir DNS
    ufw allow 53/udp comment 'DNS'
    
    # Permitir NTP
    ufw allow 123/udp comment 'NTP'
    
    return 0
}

# Se o script for executado diretamente, não apenas incluído
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ufw "$@"
fi

# Exportar funções que serão usadas em outros módulos
export -f configure_ufw configure_default_ufw_rules
