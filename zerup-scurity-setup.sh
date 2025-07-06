#!/bin/bash
# ===================================================================
# Script: zerup-scurity-setup.sh
# Version: 1.0.0
# Date: 2025-07-06
# Author: Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Script de hardening automatizado para servidores Linux que implementa as melhores
#   práticas de segurança para ambientes de produção. O script realiza:
#   - Configuração segura do SSH (troca de porta, desativação de root, autenticação por chave)
#   - Configuração do UFW (firewall) com regras restritivas
#   - Instalação e configuração do Fail2Ban para proteção contra força bruta
#   - Atualizações automáticas de segurança
#   - Validação de usuários não-root para acesso remoto
#   - Backup automático de arquivos de configuração originais
#   - Geração de relatório pós-instalação
#   - Validações de segurança para evitar bloqueio de acesso
#
# Usage:
#   sudo ./zerup-scurity-setup.sh [options]
#
# Options:
#   --port=PORTA    Especifica a porta SSH personalizada (padrão: aleatória)
#   --user=USUARIO  Define o usuário para acesso SSH (opcional, será perguntado se não informado)
#
# Exemplos:
#   sudo ./zerup-scurity-setup.sh
#   sudo ./zerup-scurity-setup.sh --port=2222 --user=admin
#
# Dependencies: sudo, ufw, fail2ban, sshd, systemd
# ===================================================================

set -e

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
CURRENT_SSH_PORT=22
BACKUP_DIR="/etc/ssh/backup_$(date +%Y%m%d_%H%M%S)"
SSH_USER=""

# Gerar porta SSH aleatória entre 1024 e 65535
RANDOM_PORT=$((RANDOM % 64512 + 1024))

# Variáveis para relatório
REPORT_FILE="/var/log/zerup-security-$(date +%Y%m%d_%H%M%S).log"
REPORT=()

# Funções
confirm_action() {
    local message="$1"
    local default_opt="${2:-y}"  # Padrão para sim (y/n)
    local options="[S/n]"
    
    if [[ "$default_opt" == "n" ]]; then
        options="[s/N]"
    fi
    
    while true; do
        read -p "${YELLOW}$message $options${NC} " -n 1 -r
        echo  # Mover para uma nova linha
        
        # Se vazio, usa o padrão
        if [[ -z "$REPLY" ]]; then
            REPLY="$default_opt"
        fi
        
        case "$REPLY" in
            [Ss]* ) return 0;;  # Sim
            [Nn]* ) return 1;;  # Não
            * ) echo "${RED}Opção inválida. Responda com s ou n.${NC}";;
        esac
    done
}

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "[${GREEN}INFO${NC}] $1"
    echo "$message" >> "$REPORT_FILE"
    REPORT+=("✅ $1")
}

error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [ERRO] $1"
    echo -e "[${RED}ERRO${NC}] $1" >&2
    echo "$message" >> "$REPORT_FILE"
    REPORT+=("❌ $1")
    exit 1
}

warn() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [AVISO] $1"
    echo -e "[${YELLOW}AVISO${NC}] $1" >&2
    echo "$message" >> "$REPORT_FILE"
    REPORT+=("⚠️ $1")
}

success() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCESSO] $1"
    echo -e "[${GREEN}SUCESSO${NC}] $1"
    echo "$message" >> "$REPORT_FILE"
    REPORT+=("✅ $1")
}

show_report() {
    echo -e "\n${YELLOW}=== RELATÓRIO DETALHADO ===${NC}"
    for item in "${REPORT[@]}"; do
        echo "- $item"
    done
    echo -e "${YELLOW}==========================${NC}"
    
    # Mostrar arquivo de log
    echo -e "\n${YELLOW}Log completo salvo em:${NC} $REPORT_FILE"
    echo -e "Visualize com: ${YELLOW}tail -f $REPORT_FILE${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Este script precisa ser executado como root (use sudo)."
    fi
}

backup_file() {
    if [ ! -f "$1" ]; then
        error "Arquivo $1 não encontrado para backup."
    fi
    
    mkdir -p "$BACKUP_DIR"
    cp "$1" "${BACKUP_DIR}/$(basename "$1").bak"
    log "Backup de $1 salvo em ${BACKUP_DIR}/"
}

# Função para validar porta
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}Porta inválida: $port. Use uma porta entre 1 e 65535.${NC}"
        return 1
    elif [ "$port" -le 1024 ]; then
        echo -e "${YELLOW}Aviso: Portas abaixo de 1024 requerem privilégios root.${NC}"
    fi
    return 0
}

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --port=*)
            if ! validate_port "${1#*=}"; then
                error "Porta inválida fornecida via argumento."
            fi
            SSH_PORT="${1#*=}"
            shift
            ;;
        --user=*)
            SSH_USER="${1#*=}"
            shift
            ;;
        *)
            error "Argumento inválido: $1"
            ;;
    esac
done

# Início do script
clear
echo -e "${YELLOW}=== ZERUP SECURITY SETUP ===${NC}"

# Verificar se há usuários não-root
if [ -z "$SSH_USER" ]; then
    echo -e "${YELLOW}Verificando usuários não-root...${NC}"
    NON_ROOT_USERS=$(getent passwd | grep -v '^root:' | grep -v '/usr/sbin/nologin' | grep -v '/bin/false' | cut -d: -f1 | tr '\n' ' ')
    
    if [ -z "$NON_ROOT_USERS" ]; then
        error "Nenhum usuário não-root encontrado. Crie um usuário com permissões sudo antes de continuar.\nComando sugerido: adduser novousuario && usermod -aG sudo novousuario"
    else
        echo -e "${GREEN}Usuários não-root encontrados:${NC} $NON_ROOT_USERS"
        read -p "Digite o nome do usuário que usará para acesso SSH: " SSH_USER
        
        # Verificar se o usuário existe
        if ! id "$SSH_USER" &>/dev/null; then
            error "O usuário '$SSH_USER' não existe. Por favor, verifique o nome e tente novamente."
        fi
    fi
fi

# Configurar porta SSH
if [ -z "$SSH_PORT" ]; then
    echo -e "\n${YELLOW}Configuração da Porta SSH${NC}"
    echo "A porta SSH padrão (22) é alvo comum de ataques."
    echo -e "Porta sugerida: ${GREEN}$RANDOM_PORT${NC} (gerada aleatoriamente)"
    
    while true; do
        read -p "Digite o número da porta SSH desejada [$RANDOM_PORT]: " input_port
        input_port=${input_port:-$RANDOM_PORT}
        
        if validate_port "$input_port"; then
            SSH_PORT="$input_port"
            break
        fi
    done
fi

echo -e "\n${YELLOW}=== RESUMO DAS ALTERAÇÕES ===${NC}"
echo "- Nova porta SSH: $SSH_PORT"
echo "- Login root via SSH será desativado"
echo "- Apenas o usuário '$SSH_USER' terá acesso SSH"
echo "- Firewall (UFW) será configurado"
echo "- Fail2Ban será ativado para proteção contra força bruta"
echo -e "${YELLOW}==============================${NC}"

read -p "Deseja continuar? (s/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Operação cancelada pelo usuário."
    exit 0
fi

# 1. Iniciar relatório
log "Iniciando relatório de segurança em $(date)"
log "Usuário: $(whoami)"
log "Hostname: $(hostname)"
log "Endereço IP: $(hostname -I | awk '{print $1}')"

# 1. Atualizar sistema
if confirm_action "Deseja atualizar o sistema operacional?" "y"; then
    log "Atualizando o sistema..."
    if apt update && apt upgrade -y; then
        success "Sistema atualizado com sucesso"
    else
        warn "Falha ao atualizar o sistema."
    fi
else
    log "Atualização do sistema pulada pelo usuário"
fi

# 2. Configurar SSH
if confirm_action "Deseja configurar o SSH com as opções de segurança?" "y"; then
    log "Iniciando configuração do SSH..."
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Verificar se o arquivo de configuração existe
    if [ ! -f "$SSHD_CONFIG" ]; then
        error "Arquivo de configuração do SSH não encontrado: $SSHD_CONFIG"
    fi

    log "Criando backup do arquivo de configuração do SSH"
    if backup_file "$SSHD_CONFIG"; then
        success "Backup do SSH criado com sucesso"
    else
        warn "Falha ao criar backup do SSH. Continuando..."
    fi
else
    log "Configuração do SSH pulada pelo usuário"
    SSHD_CONFIG=""  # Impede execução das próximas etapas do SSH
fi

# Garantir que o usuário tenha acesso
if ! grep -q "^AllowUsers" "$SSHD_CONFIG"; then
    echo "AllowUsers $SSH_USER" >> "$SSHD_CONFIG"
else
    if ! grep -q "AllowUsers.*$SSH_USER" "$SSHD_CONFIG"; then
        sed -i -E "/^AllowUsers/ s/$/ $SSH_USER/" "$SSHD_CONFIG"
    fi
fi

# Fazer backup da chave SSH atual
if [ -f "/etc/ssh/ssh_host_rsa_key" ]; then
    backup_file "/etc/ssh/ssh_host_rsa_key"
    backup_file "/etc/ssh/ssh_host_rsa_key.pub"
fi

# Gerar nova chave SSH se não existir
if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
    log "Gerando novas chaves SSH..."
    ssh-keygen -A
fi

# Configurar SSHD
log "Aplicando configurações de segurança no SSH..."
sed -i -E "s/^#?Port .*/Port $SSH_PORT/" "$SSHD_CONFIG"
sed -i -E 's/^#?PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i -E 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' "$SSLD_CONFIG"
sed -i -E 's/^#?PermitEmptyPasswords .*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
sed -i -E 's/^#?X11Forwarding .*/X11Forwarding no/' "$SSHD_CONFIG"
sed -i -E 's/^#?ClientAliveInterval .*/ClientAliveInterval 300/' "$SSHD_CONFIG"
sed -i -E 's/^#?ClientAliveCountMax .*/ClientAliveCountMax 2/' "$SSLD_CONFIG"
sed -i -E 's/^#?MaxAuthTries .*/MaxAuthTries 3/' "$SSHD_CONFIG"

# 3. Configurar UFW
if confirm_action "Deseja configurar o firewall UFW?" "y"; then
    log "Iniciando configuração do UFW..."
    
    if ! command -v ufw &> /dev/null; then
        if confirm_action "UFW não está instalado. Deseja instalar?" "y"; then
            if apt install -y ufw; then
                success "UFW instalado com sucesso"
            else
                error "Falha ao instalar o UFW"
            fi
        else
            log "Instalação do UFW cancelada pelo usuário"
        fi
    fi

    if command -v ufw &> /dev/null; then
        log "Configurando regras do UFW..."
        {
            ufw --force reset &&
            ufw default deny incoming &&
            ufw default allow outgoing &&
            ufw allow "$SSH_PORT/tcp" &&
            ufw allow 80/tcp &&
            ufw allow 443/tcp &&
            ufw --force enable
        } && {
            systemctl enable --now ufw
            success "UFW configurado com sucesso na porta $SSH_PORT"
            log "Regras ativas do UFW:"
            ufw status numbered | tee -a "$REPORT_FILE"
        } || {
            warn "Falha ao configurar o UFW. Verifique as permissões."
        }
    else
        warn "UFW não disponível. Pulando configuração do firewall."
    fi
else
    log "Configuração do UFW pulada pelo usuário"
fi

# 4. Configurar Fail2Ban
if confirm_action "Deseja instalar e configurar o Fail2Ban?" "y"; then
    log "Configurando Fail2Ban..."
    
    if ! command -v fail2ban-client &> /dev/null; then
        if confirm_action "Fail2Ban não está instalado. Deseja instalar?" "y"; then
            if apt install -y fail2ban; then
                success "Fail2Ban instalado com sucesso"
            else
                error "Falha ao instalar o Fail2Ban"
            fi
        else
            log "Instalação do Fail2Ban cancelada pelo usuário"
        fi
    fi

    if command -v fail2ban-client &> /dev/null; then
        log "Criando configuração personalizada do Fail2Ban..."
        
        # Criar diretório se não existir
        mkdir -p /etc/fail2ban/jail.d/
        
        cat > /etc/fail2ban/jail.d/zerup.conf << EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 1h
findtime = 600
ignoreip = 127.0.0.1/8 ::1
EOF

        if systemctl restart fail2ban && systemctl enable fail2ban; then
            success "Fail2Ban configurado com sucesso"
            log "Status do Fail2Ban:"
            fail2ban-client status | tee -a "$REPORT_FILE"
        else
            warn "Falha ao configurar o Fail2Ban"
        fi
    else
        warn "Fail2Ban não disponível. Pulando configuração."
    fi
else
    log "Configuração do Fail2Ban pulada pelo usuário"
fi

# 5. Aplicar configurações
if [ -n "$SSHD_CONFIG" ]; then
    if confirm_action "Deseja reiniciar o serviço SSH para aplicar as configurações?" "y"; then
        log "Reiniciando serviço SSH..."
        if systemctl restart sshd; then
            success "Serviço SSH reiniciado com sucesso"
        else
            error "Falha ao reiniciar o serviço SSH"
        fi
    else
        log "Reinicialização do SSH pulada pelo usuário"
        warn "As alterações no SSH só terão efeito após a reinicialização do serviço"
    fi
fi

# 6. Configurar atualizações automáticas
if confirm_action "Deseja configurar atualizações automáticas de segurança?" "y"; then
    log "Configurando atualizações automáticas..."
    
    if ! command -v unattended-upgrade &> /dev/null; then
        if confirm_action "Pacote 'unattended-upgrades' não encontrado. Instalar?" "y"; then
            if apt install -y unattended-upgrades; then
                success "Pacote unattended-upgrades instalado com sucesso"
            else
                warn "Falha ao instalar o pacote unattended-upgrades"
            fi
        else
            log "Instalação do unattended-upgrades cancelada pelo usuário"
        fi
    fi

    if command -v unattended-upgrade &> /dev/null; then
        log "Configurando atualizações automáticas..."
        if dpkg-reconfigure -plow unattended-upgrades; then
            success "Atualizações automáticas configuradas com sucesso"
            log "Configuração atual:"
            cat /etc/apt/apt.conf.d/20auto-upgrades | tee -a "$REPORT_FILE"
        else
            warn "Falha ao configurar atualizações automáticas"
        fi
    else
        warn "unattended-upgrades não disponível. Pulando configuração de atualizações automáticas."
    fi
else
    log "Configuração de atualizações automáticas pulada pelo usuário"
fi

# 7. Limpar cache
if confirm_action "Deseja limpar o cache de pacotes e remover pacotes não utilizados?" "y"; then
    log "Limpando cache de pacotes..."
    
    log "Removendo pacotes não utilizados..."
    if apt autoremove -y; then
        success "Pacotes não utilizados removidos com sucesso"
    else
        warn "Falha ao remover pacotes não utilizados"
    fi
    
    log "Limpando cache do apt..."
    if apt autoclean; then
        success "Cache do apt limpo com sucesso"
    else
        warn "Falha ao limpar o cache do apt"
    fi
else
    log "Limpeza de cache pulada pelo usuário"
fi

# 8. Mostrar resumo
success "Configuração de segurança concluída com sucesso!"

echo -e "\n${GREEN}=== CONFIGURAÇÃO CONCLUÍDA ===${NC}"

# Mostrar relatório detalhado
show_report

echo -e "\n${YELLOW}=== PRÓXIMOS PASSOS ===${NC}"
echo "1. Abra uma NOVA janela de terminal e teste o acesso SSH:"
echo -e "   ${GREEN}ssh -p $SSH_PORT $SSH_USER@$(hostname -I | awk '{print $1}')${NC}"
echo "2. Verifique se consegue acessar com o usuário '$SSH_USER'"
echo "3. Só então feche esta sessão"

echo -e "\n${YELLOW}=== RESUMO DAS ALTERAÇÕES ===${NC}"
echo "- 🔒 Porta SSH alterada para: $SSH_PORT"
echo "- 🚫 Login root via SSH desativado"
echo "- 🔥 UFW configurado (portas $SSH_PORT, 80, 443 abertas)"
echo "- 🛡️  Fail2Ban ativo e monitorando a porta $SSH_PORT"
echo -e "\n${YELLOW}=== BACKUPS E LOGS ===${NC}"
echo "- 📂 Arquivos de backup salvos em: $BACKUP_DIR"
echo "- 📋 Log completo em: $REPORT_FILE"

echo -e "\n${GREEN}=== SEGURANÇA CONCLUÍDA COM SUCESSO! ===${NC}\n"

# 9. Mostrar status final
echo -e "\n${YELLOW}=== STATUS ATUAL ===${NC}"
echo -n "UFW: " && ufw status | grep -q "Status: active" && echo -e "${GREEN}Ativo${NC}" || echo -e "${RED}Inativo${NC}"
echo -n "Fail2Ban: " && systemctl is-active --quiet fail2ban && echo -e "${GREEN}Ativo${NC}" || echo -e "${RED}Inativo${NC}"
echo -n "SSH na porta $SSH_PORT: " && (nc -z localhost "$SSH_PORT" 2>/dev/null && echo -e "${GREEN}Aberto${NC}" || echo -e "${RED}Fechado${NC}")

exit 0
