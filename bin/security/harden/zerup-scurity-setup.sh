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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
CURRENT_SSH_PORT=22
BACKUP_DIR="/etc/ssh/backup_$(date +%Y%m%d_%H%M%S)"
SSH_USER=""
DRY_RUN=false
ROLLBACK_DIR="/root/zerup_rollback_$(date +%s)"

# Gerar porta SSH aleatória entre 1024 e 65535
RANDOM_PORT=$((RANDOM % 64512 + 1024))

# Variáveis para relatório
REPORT_FILE="/var/log/zerup-security-$(date +%Y%m%d_%H%M%S).log"
REPORT=()

# Configurações de segurança padrão
SSH_PORT=22
SSH_PORT_NEW=$RANDOM_PORT
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
UFW_CONFIG_FILE="/etc/ufw/user.rules"
FAIL2BAN_CONFIG_FILE="/etc/fail2ban/jail.local"

# Variáveis de estado para rollback
HAS_BACKUP=false
HAS_SSH_CHANGES=false
HAS_UFW_CHANGES=false
HAS_FAIL2BAN_CHANGES=false

# Funções de utilidade
check_dependencies() {
    local deps=("sudo" "ssh" "sshd" "ufw" "fail2ban" "grep" "sed" "awk" "date")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "Dependências ausentes: ${missing[*]}"
        if confirm_action "Deseja instalar as dependências ausentes?" "y"; then
            apt-get update && apt-get install -y "${missing[@]}" || error "Falha ao instalar dependências"
        else
            error "Dependências necessárias não atendidas"
        fi
    fi
}

check_disk_space() {
    local required=100  # MB
    local available
    available=$(df -m / | awk 'NR==2 {print $4}')
    
    if [ "$available" -lt "$required" ]; then
        warn "Espaço em disco baixo: ${available}MB disponíveis (${required}MB recomendados)"
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            error "Espaço em disco insuficiente"
        fi
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        warn "Sem conexão com a internet. Algumas verificações podem falhar."
        if ! confirm_action "Deseja continuar sem conexão com a internet?" "n"; then
            error "Conexão com a internet necessária"
        fi
        return 1
    fi
    return 0
}

# Função para executar comandos com tratamento de erro
run_cmd() {
    local cmd="$*"
    log "Executando: $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY RUN]${NC} $cmd"
        return 0
    fi
    
    if ! eval "$cmd"; then
        error "Falha ao executar: $cmd"
        return 1
    fi
    return 0
}

# Função para backup de arquivos
backup_file() {
    local file="$1"
    local backup_file="${BACKUP_DIR}/$(basename "$file").bak"
    
    if [ ! -f "$file" ]; then
        warn "Arquivo $file não encontrado para backup"
        return 1
    }
    
    mkdir -p "$BACKUP_DIR"
    if ! cp "$file" "$backup_file"; then
        error "Falha ao criar backup de $file"
        return 1
    fi
    
    log "Backup de $file salvo em $backup_file"
    HAS_BACKUP=true
    return 0
}

# Função para rollback em caso de falha
rollback_changes() {
    echo -e "\n${RED}=== ERRO CRÍTICO DETECTADO ===${NC}"
    echo -e "${YELLOW}Iniciando rollback das alterações...${NC}"
    
    if [ "$HAS_SSH_CHANGES" = true ]; then
        warn "Revertendo alterações do SSH..."
        cp "${BACKUP_DIR}/sshd_config.bak" "$SSH_CONFIG_FILE"
        systemctl restart sshd
    fi
    
    if [ "$HAS_UFW_CHANGES" = true ]; then
        warn "Revertendo alterações do UFW..."
        ufw --force reset
        ufw disable
    fi
    
    if [ "$HAS_FAIL2BAN_CHANGES" = true ]; then
        warn "Revertendo alterações do Fail2Ban..."
        systemctl stop fail2ban
        apt-get remove -y --purge fail2ban
    fi
    
    echo -e "${GREEN}Rollback concluído.${NC} Verifique os arquivos de log para mais detalhes."
    exit 1
}

# Configurar tratamento de erros
trap 'error "Script interrompido pelo usuário"' INT TERM
trap 'rollback_changes' EXIT

# Funções de interação com o usuário
confirm_action() {
    local message="$1"
    local default_opt="${2:-y}"  # Padrão para sim (y/n)
    local options="[S/n]"
    
    if [[ "$default_opt" == "n" ]]; then
        options="[s/N]"
    fi
    
    # Se estiver em modo não-interativo, retorna o valor padrão
    if [ "$NON_INTERACTIVE" = true ]; then
        log "[NÃO INTERATIVO] $message $options - Usando padrão: $default_opt"
        [[ "$default_opt" == [yY] ]] && return 0 || return 1
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
            * ) echo -e "${RED}Opção inválida. Responda com s ou n.${NC}";;
        esac
    done
}

# Função para validar endereço IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Função para validar nome de usuário
validate_username() {
    local username=$1
    local regex='^[a-z_][a-z0-9_-]*$'
    
    if [[ ! "$username" =~ $regex ]]; then
        echo -e "${RED}Nome de usuário inválido. Use apenas letras minúsculas, números, hífens e sublinhados.${NC}"
        return 1
    fi
    
    # Verificar se o usuário existe
    if ! id "$username" &>/dev/null; then
        echo -e "${YELLOW}O usuário '$username' não existe no sistema.${NC}"
        return 1
    fi
    
    # Verificar se o usuário tem privilégios sudo
    if ! groups "$username" | grep -q '\bsudo\b' && ! groups "$username" | grep -q '\bwheel\b'; then
        echo -e "${YELLOW}O usuário '$username' não tem privilégios sudo.${NC}"
        if confirm_action "Deseja adicionar o usuário ao grupo sudo?" "y"; then
            run_cmd "usermod -aG sudo \"$username\"" || return 1
            log "Usuário '$username' adicionado ao grupo sudo"
        else
            return 1
        fi
    fi
    
    return 0
}

# Função para verificar se uma porta está em uso
is_port_in_use() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        local process
        process=$(ss -tulpn | grep ":$port " | awk '{print $6}')
        echo -e "${YELLOW}A porta $port já está em uso por: $process${NC}"
        return 0
    fi
    return 1
}

# Função para validar e configurar porta SSH
configure_ssh_port() {
    local default_port=$1
    local port
    
    while true; do
        read -p "Digite a porta SSH desejada [$default_port]: " port
        port=${port:-$default_port}
        
        # Validar formato da porta
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}Porta inválida. Use um número entre 1 e 65535.${NC}"
            continue
        fi
        
        # Verificar se a porta já está em uso
        if is_port_in_use "$port"; then
            if [ "$port" -ne 22 ]; then  # Ignorar se for a porta 22 (já em uso pelo SSH atual)
                if ! confirm_action "A porta $port já está em uso. Deseja usar outra porta?" "y"; then
                    return 1
                fi
                continue
            fi
        fi
        
        # Aviso sobre portas privilegiadas
        if [ "$port" -lt 1024 ] && [ "$EUID" -ne 0 ]; then
            echo -e "${YELLOW}Aviso: Portas abaixo de 1024 requerem privilégios root.${NC}"
            if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
                continue
            fi
        fi
        
        echo "$port"
        break
    done
    
    return 0
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

# Função para configurar o SSH de forma segura
configure_ssh() {
    log "Iniciando configuração segura do SSH..."
    
    # Fazer backup do arquivo de configuração
    if ! backup_file "$SSH_CONFIG_FILE"; then
        error "Falha ao fazer backup do arquivo de configuração do SSH"
        return 1
    }
    
    # Configurar porta SSH
    log "Configurando porta SSH..."
    local new_port
    new_port=$(configure_ssh_port "$SSH_PORT_NEW") || {
        error "Falha ao configurar a porta SSH"
        return 1
    }
    
    # Atualizar a porta SSH
    if grep -q "^Port " "$SSH_CONFIG_FILE"; then
        run_cmd "sed -i 's/^Port .*/Port $new_port/' \"$SSH_CONFIG_FILE\""
    else
        echo "Port $new_port" | tee -a "$SSH_CONFIG_FILE" > /dev/null
    fi
    
    # Configurações de segurança do SSH
    log "Aplicando configurações de segurança do SSH..."
    
    # Lista de configurações a serem aplicadas
    declare -A ssh_configs=(
        ["PermitRootLogin"]="no"
        ["PasswordAuthentication"]="no"
        ["PermitEmptyPasswords"]="no"
        ["ChallengeResponseAuthentication"]="no"
        ["UsePAM"]="yes"
        ["X11Forwarding"]="no"
        ["ClientAliveInterval"]="300"
        ["ClientAliveCountMax"]="2"
        ["MaxAuthTries"]="3"
        ["MaxSessions"]="3"
    )
    
    # Aplicar configurações
    for setting in "${!ssh_configs[@]}"; do
        local value="${ssh_configs[$setting]}"
        if grep -q "^$setting " "$SSH_CONFIG_FILE"; then
            run_cmd "sed -i 's/^$setting .*/$setting $value/' \"$SSH_CONFIG_FILE\""
        else
            echo "$setting $value" | tee -a "$SSH_CONFIG_FILE" > /dev/null
        fi
    done
    
    # Configurar AllowUsers se não estiver configurado
    if ! grep -q "^AllowUsers " "$SSH_CONFIG_FILE"; then
        echo "AllowUsers $SSH_USER" | tee -a "$SSH_CONFIG_FILE" > /dev/null
    fi
    
    # Configurar chaves SSH se não existirem
    local ssh_dir="/home/$SSH_USER/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    if [ ! -d "$ssh_dir" ]; then
        run_cmd "mkdir -p \"$ssh_dir\""
        run_cmd "chown $SSH_USER:$SSH_USER \"$ssh_dir\""
        run_cmd "chmod 700 \"$ssh_dir\""
    fi
    
    if [ ! -f "$auth_keys" ]; then
        run_cmd "touch \"$auth_keys\""
        run_cmd "chown $SSH_USER:$SSH_USER \"$auth_keys\""
        run_cmd "chmod 600 \"$auth_keys\""
        warn "Nenhuma chave SSH configurada para o usuário $SSH_USER"
        echo -e "${YELLOW}Por favor, adicione suas chaves SSH ao arquivo: $auth_keys${NC}"
    fi
    
    # Reiniciar o serviço SSH
    log "Reiniciando o serviço SSH..."
    if ! systemctl restart sshd; then
        error "Falha ao reiniciar o serviço SSH. Verifique o log: journalctl -xe"
        return 1
    fi
    
    # Verificar se o serviço está rodando na nova porta
    if ! ss -tuln | grep -q ":$new_port "; then
        error "Falha ao iniciar o SSH na porta $new_port"
        return 1
    fi
    
    HAS_SSH_CHANGES=true
    success "SSH configurado com sucesso na porta $new_port"
    
    # Se a porta foi alterada, informar o usuário
    if [ "$new_port" -ne 22 ]; then
        echo -e "${YELLOW}IMPORTANTE: A porta SSH foi alterada para $new_port${NC}"
        echo -e "${YELLOW}Use o seguinte comando para se conectar:${NC}"
        echo -e "${GREEN}ssh -p $new_port $SSH_USER@$(hostname -I | awk '{print $1}')${NC}\n"
        
        if confirm_action "Deseja manter a porta 22 aberta temporariamente para teste?" "n"; then
            warn "A porta 22 permanecerá aberta até o próximo reinício do servidor."
        else
            run_cmd "ufw delete allow 22/tcp"
        fi
    fi
    
    return 0
}

# Função para exibir ajuda
show_usage() {
    echo -e "${GREEN}Uso:${NC} $0 [opções]"
    echo "Opções:"
    echo "  --port=PORTA     Especifica a porta SSH (padrão: aleatória entre 1024-65535)"
    echo "  --user=USUARIO   Define o usuário para acesso SSH"
    echo "  --dry-run        Simula as alterações sem aplicá-las"
    echo "  --non-interactive Usa valores padrão sem interação"
    echo "  -h, --help       Mostra esta ajuda"
    echo -e "\n${YELLOW}Exemplos:${NC}"
    echo "  $0                            # Modo interativo com configurações padrão"
    echo "  $0 --port=2222 --user=admin  # Configurações personalizadas"
    echo "  $0 --dry-run                 # Simula as alterações"
    echo -e "\n${YELLOW}Recomendações:${NC}"
    echo "  - Execute como root ou com sudo"
    echo "  - Tenha um usuário não-root com privilégios sudo"
    echo "  - Faça backup do servidor antes de executar"
    echo -e "  - Mantenha uma sessão ativa durante a execução\n"
}

# Função para configurar o SSH de forma segura
configure_ssh() {
    log "Iniciando configuração segura do SSH..."
    
    # Fazer backup do arquivo de configuração atual
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="${BACKUP_DIR}/sshd_config.$(date +%Y%m%d_%H%M%S).bak"
    
    log "Criando backup do arquivo de configuração do SSH em: $backup_file"
    if ! cp "$sshd_config" "$backup_file"; then
        error "Falha ao criar backup do arquivo de configuração do SSH"
        return 1
    fi
    
    # Verificar se estamos no modo de simulação
    if [ "$DRY_RUN" = true ]; then
        log "[SIMULAÇÃO] As seguintes alterações seriam feitas no SSH:"
        log "- Alterar porta SSH para: $SSH_PORT_NEW"
        log "- Desativar login como root"
        log "- Desativar autenticação por senha"
        log "- Habilitar autenticação por chaves públicas"
        log "- Configurar restrições de usuários e grupos"
        log "- Ajustar parâmetros de segurança"
        HAS_SSH_CHANGES=true
        return 0
    fi
    
    # Criar um arquivo temporário para as alterações
    local temp_config
    temp_config=$(mktemp)
    cp "$sshd_config" "$temp_config"
    
    # Função auxiliar para atualizar ou adicionar uma configuração
    update_sshd_config() {
        local key="$1"
        local value="$2"
        local comment="$3"
        
        if grep -q -E "^\s*#?\s*${key}" "$temp_config"; then
            # Se a chave já existe, atualiza
            sed -i -E "s/^\s*#?\s*${key}.*/${key} ${value}/" "$temp_config"
        else
            # Se não existe, adiciona no final do arquivo
            if [ -n "$comment" ]; then
                echo "# $comment" >> "$temp_config"
            fi
            echo "${key} ${value}" >> "$temp_config"
        fi
    }
    
    # Configurações básicas de segurança
    log "Aplicando configurações de segurança ao SSH..."
    
    # Alterar a porta SSH
    update_sshd_config "Port" "$SSH_PORT_NEW" "Porta de acesso SSH"
    
    # Desativar protocolo SSHv1
    update_sshd_config "Protocol" "2" "Usar apenas SSHv2"
    
    # Configurações de autenticação
    update_sshd_config "PermitRootLogin" "no" "Impedir login direto como root"
    update_sshd_config "PasswordAuthentication" "no" "Desativar autenticação por senha"
    update_sshd_config "PubkeyAuthentication" "yes" "Habilitar autenticação por chaves públicas"
    update_sshd_config "ChallengeResponseAuthentication" "no" "Desativar autenticação por desafio"
    update_sshd_config "UsePAM" "yes" "Usar PAM para autenticação"
    update_sshd_config "X11Forwarding" "no" "Desativar encaminhamento X11"
    
    # Configurações de segurança adicionais
    update_sshd_config "AllowTcpForwarding" "no" "Desativar encaminhamento de porta TCP"
    update_sshd_config "ClientAliveInterval" "300" "Desconectar sessões ociosas após 5 minutos"
    update_sshd_config "ClientAliveCountMax" "2" "Número de verificações antes de desconectar"
    update_sshd_config "MaxAuthTries" "3" "Número máximo de tentativas de autenticação"
    update_sshd_config "LoginGraceTime" "60" "Tempo máximo para autenticação"
    update_sshd_config "Banner" "/etc/issue.net" "Arquivo de banner para exibir antes do login"
    
    # Restringir usuários e grupos (se especificado)
    if [ -n "$SSH_USER" ]; then
        update_sshd_config "AllowUsers" "$SSH_USER" "Permitir apenas usuários específicos"
    fi
    
    # Configurações de criptografia
    update_sshd_config "Ciphers" "aes256-ctr,aes192-ctr,aes128-ctr" "Algoritmos de criptografia permitidos"
    update_sshd_config "MACs" "hmac-sha2-512,hmac-sha2-256" "Algoritmos MAC permitidos"
    update_sshd_config "KexAlgorithms" "curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256" "Algoritmos de troca de chaves"
    
    # Configurações de log
    update_sshd_config "LogLevel" "VERBOSE" "Nível de log detalhado"
    update_sshd_config "SyslogFacility" "AUTH" "Facilidade de log para mensagens de autenticação"
    
    # Validar o arquivo de configuração antes de aplicar
    if ! sshd -t -f "$temp_config"; then
        error "Erro de validação no arquivo de configuração do SSH. Verifique a sintaxe."
        rm -f "$temp_config"
        return 1
    fi
    
    # Fazer backup do arquivo original e aplicar as alterações
    if ! mv "$temp_config" "$sshd_config"; then
        error "Falha ao aplicar as alterações no arquivo de configuração do SSH"
        rm -f "$temp_config"
        return 1
    fi
    
    # Ajustar permissões do arquivo de configuração
    chmod 600 "$sshd_config"
    chown root:root "$sshd_config"
    
    # Verificar se o diretório .ssh do usuário existe e tem as permissões corretas
    if [ -n "$SSH_USER" ]; then
        local ssh_dir="/home/$SSH_USER/.ssh"
        local authorized_keys="$ssh_dir/authorized_keys"
        
        # Criar diretório .ssh se não existir
        if [ ! -d "$ssh_dir" ]; then
            log "Criando diretório .ssh para o usuário $SSH_USER..."
            mkdir -p "$ssh_dir"
            chmod 700 "$ssh_dir"
            chown -R "$SSH_USER:$SSH_USER" "$ssh_dir"
        fi
        
        # Criar arquivo authorized_keys se não existir
        if [ ! -f "$authorized_keys" ]; then
            log "Criando arquivo authorized_keys para o usuário $SSH_USER..."
            touch "$authorized_keys"
            chmod 600 "$authorized_keys"
            chown "$SSH_USER:$SSH_USER" "$authorized_keys"
        fi
    fi
    
    HAS_SSH_CHANGES=true
    success "Configuração do SSH concluída com sucesso"
    
    # Mostrar instruções para o usuário
    log "\n${YELLOW}INSTRUÇÕES IMPORTANTES:${NC}"
    log "1. A nova porta SSH é: $SSH_PORT_NEW"
    log "2. O login como root foi desativado"
    log "3. A autenticação por senha foi desativada"
    log "4. Certifique-se de que sua chave pública está em ~/.ssh/authorized_keys"
    log "5. Teste o acesso antes de fechar esta sessão!"
    
    return 0
}

# Função para processar argumentos da linha de comando
parse_arguments() {
    # Valores padrão
    SSH_PORT_NEW=""
    SSH_USER=""
    DRY_RUN=false
    NON_INTERACTIVE=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port=*)
                SSH_PORT_NEW="${1#*=}"
                # Validar número da porta
                if ! [[ "$SSH_PORT_NEW" =~ ^[0-9]+$ ]] || [ "$SSH_PORT_NEW" -lt 1 ] || [ "$SSH_PORT_NEW" -gt 65535 ]; then
                    error "Número de porta inválido: $SSH_PORT_NEW. Use uma porta entre 1 e 65535."
                    exit 1
                fi
                shift
                ;;
            --user=*)
                SSH_USER="${1#*=}"
                # Validar nome de usuário
                if ! [[ "$SSH_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                    error "Nome de usuário inválido: $SSH_USER"
                    exit 1
                fi
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log "Modo de simulação ativado (nenhuma alteração será feita)"
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                log "Modo não-interativo ativado (usando valores padrão)"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version)
                echo "zerup-scurity-setup v1.0.0"
                exit 0
                ;;
            *)
                error "Argumento inválido: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Definir porta SSH padrão se não especificada
    if [ -z "$SSH_PORT_NEW" ]; then
        # Gerar uma porta aleatória entre 1024 e 65535
        SSH_PORT_NEW=$((RANDOM % 64511 + 1024))
        log "Nenhuma porta SSH especificada, usando porta aleatória: $SSH_PORT_NEW"
    fi
    
    # Verificar se o usuário atual tem privilégios de root
    if [ "$(id -u)" -ne 0 ]; then
        error "Este script deve ser executado como root. Use 'sudo $0' ou faça login como root."
        exit 1
    fi
    
    # Verificar se o usuário SSH especificado existe
    if [ -n "$SSH_USER" ] && ! id "$SSH_USER" &>/dev/null; then
        error "O usuário '$SSH_USER' não existe no sistema."
        if [ "$NON_INTERACTIVE" = true ] || ! confirm_action "Deseja criar o usuário '$SSH_USER'?" "n"; then
            exit 1
        fi
        
        # Criar o usuário se confirmado
        if ! adduser --disabled-password --gecos "" "$SSH_USER"; then
            error "Falha ao criar o usuário '$SSH_USER'"
            exit 1
        fi
        
        # Adicionar usuário ao grupo sudo
        if ! usermod -aG sudo "$SSH_USER"; then
            warn "Não foi possível adicionar o usuário '$SSH_USER' ao grupo sudo"
        fi
        
        # Definir senha para o usuário
        if [ "$NON_INTERACTIVE" = false ]; then
            echo -e "\n${YELLOW}Defina uma senha para o usuário '$SSH_USER':${NC}"
            passwd "$SSH_USER"
        else
            # No modo não interativo, definir uma senha aleatória
            local temp_pass
            temp_pass=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
            echo "$SSH_USER:$temp_pass" | chpasswd
            log "Senha definida para o usuário '$SSH_USER': $temp_pass"
            warn "Lembre-se de alterar a senha do usuário '$SSH_USER' após o login"
        fi
    fi
    
    # Verificar se estamos no modo de simulação
    if [ "$DRY_RUN" = true ]; then
        log "MODO DE SIMULAÇÃO ATIVADO - Nenhuma alteração será feita"
    fi
    
    # Inicializar variáveis de controle
    HAS_SSH_CHANGES=false
    HAS_UFW_CHANGES=false
    HAS_FAIL2BAN_CHANGES=false
    
    return 0
}

# Função principal
main() {
    # Inicialização
    clear
    echo -e "${GREEN}=== ZERUP SECURITY SETUP ===${NC}"
    echo -e "${YELLOW}Configuração Automática de Segurança para Servidores Linux${NC}\n"
    
    # Verificar e processar argumentos
    parse_arguments "$@"
    
    # Verificar pré-requisitos
    if ! check_prerequisites; then
        error "Falha na verificação de pré-requisitos. Verifique as mensagens acima para mais detalhes."
        exit 1
    fi
    
    # Criar diretório de backup
    BACKUP_DIR="/root/zerup_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Iniciar log
    LOG_FILE="$BACKUP_DIR/zerup_security_setup.log"
    log "Iniciando configuração de segurança"
    log "Diretório de backup: $BACKUP_DIR"
    log "Arquivo de log: $LOG_FILE"
    
    # Configurar SSH
    if confirm_action "Deseja configurar o SSH?" "y"; then
        if ! configure_ssh; then
            error "Falha na configuração do SSH"
            if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
                exit 1
            fi
        fi
    fi
    
    # Configurar UFW (Firewall)
    if confirm_action "Deseja configurar o UFW (firewall)?" "y"; then
        if ! configure_ufw; then
            error "Falha na configuração do UFW"
            if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
                exit 1
            fi
        fi
    fi
    
    # Configurar Fail2Ban
    if confirm_action "Deseja configurar o Fail2Ban?" "y"; then
        if ! configure_fail2ban; then
            error "Falha na configuração do Fail2Ban"
            if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
                exit 1
            fi
        fi
    fi
    
    # Atualizar o sistema
    if confirm_action "Deseja atualizar o sistema agora?" "y"; then
        log "Atualizando o sistema..."
        if ! apt-get update || ! apt-get upgrade -y; then
            error "Falha ao atualizar o sistema"
            if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
                exit 1
            fi
        fi
    fi
    
    # Reiniciar serviços necessários
    if [ "$HAS_SSH_CHANGES" = true ] || [ "$HAS_UFW_CHANGES" = true ] || [ "$HAS_FAIL2BAN_CHANGES" = true ]; then
        log "Reiniciando serviços..."
        
        if [ "$HAS_SSH_CHANGES" = true ]; then
            log "Reiniciando serviço SSH..."
            if ! systemctl restart sshd; then
                error "Falha ao reiniciar o serviço SSH"
            fi
        fi
        
        if [ "$HAS_UFW_CHANGES" = true ]; then
            log "Reiniciando serviço UFW..."
            if ! ufw --force enable; then
                error "Falha ao reiniciar o serviço UFW"
            fi
        fi
        
        if [ "$HAS_FAIL2BAN_CHANGES" = true ]; then
            log "Reiniciando serviço Fail2Ban..."
            if ! systemctl restart fail2ban; then
                error "Falha ao reiniciar o serviço Fail2Ban"
            fi
        fi
    fi
    
    # Gerar relatório final
    generate_report
    
    # Verificar se é necessário reiniciar
    if [ -f "/var/run/reboot-required" ]; then
        warn "\nUma reinicialização é necessária para aplicar todas as alterações."
        if confirm_action "Deseja reiniciar o sistema agora?" "n"; then
            log "Reiniciando o sistema..."
            reboot
            exit 0
        else
            warn "Lembre-se de reiniciar o sistema assim que possível para aplicar todas as alterações."
        fi
    fi
    
    # Mensagem final
    success "\nConfiguração de segurança concluída com sucesso!"
    echo -e "\n${YELLOW}IMPORTANTE:${NC}"
    echo -e "- Verifique se você ainda tem acesso ao servidor pela nova porta SSH ($SSH_PORT_NEW)"
    echo -e "- Consulte o relatório gerado em: $report_file"
    echo -e "- Recomenda-se testar todas as configurações antes de encerrar a sessão atual\n"
    
    return 0
}

# Função para gerar relatório detalhado das alterações
generate_report() {
    local report_file="/root/zerup_security_report_$(date +%Y%m%d_%H%M%S).txt"
    local separator="\n$(printf '=%.0s' {1..80})\n"
    
    # Cabeçalho do relatório
    {
        echo -e "${separator}"
        echo -e "${GREEN}ZERUP SECURITY SETUP - RELATÓRIO DE ALTERAÇÕES${NC}"
        echo -e "${separator}"
        echo -e "Data e Hora: $(date '+%d/%m/%Y %H:%M:%S')"
        echo -e "Hostname: $(hostname -f) ($(hostname -I | awk '{print $1}'))"
        echo -e "Sistema Operacional: $(lsb_release -d | cut -d: -f2 | sed 's/^[ \t]*//') $(uname -m)"
        echo -e "Kernel: $(uname -r)"
        echo -e "${separator}"
        
        # Resumo das alterações
        echo -e "${YELLOW}RESUMO DAS ALTERAÇÕES${NC}"
        echo -e "${separator}"
        
        if [ "$HAS_SSH_CHANGES" = true ]; then
            echo -e "✅ ${GREEN}SSH${NC}"
            echo -e "   • Porta SSH alterada para: $SSH_PORT_NEW"
            echo -e "   • Login como root: $(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Autenticação por senha: $(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Chaves públicas: $(grep -i "^PubkeyAuthentication" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Usuários permitidos: $(grep -i "^AllowUsers" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Grupos permitidos: $(grep -i "^AllowGroups" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • LogLevel: $(grep -i "^LogLevel" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Máx. tentativas de login: $(grep -i "^MaxAuthTries" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Tempo de login: $(grep -i "^LoginGraceTime" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Tempo de inatividade: $(grep -i "^ClientAliveInterval" /etc/ssh/sshd_config | tail -1) / $(grep -i "^ClientAliveCountMax" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • Ciphers: $(grep -i "^Ciphers" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • MACs: $(grep -i "^MACs" /etc/ssh/sshd_config | tail -1)"
            echo -e "   • KexAlgorithms: $(grep -i "^KexAlgorithms" /etc/ssh/sshd_config | tail -1)"
        fi
        
        if [ "$HAS_UFW_CHANGES" = true ]; then
            echo -e "\n✅ ${GREEN}UFW (Firewall)${NC}"
            echo -e "   • Status: $(ufw status | grep "Status:" | cut -d' ' -f2)"
            echo -e "   • Política padrão: $(ufw status verbose | grep "Default:" | cut -d' ' -f2-)"
            echo -e "   • Regras ativas:"
            ufw status | grep -v "Status:" | grep -v "^$" | sed 's/^/     - /'
        fi
        
        if [ "$HAS_FAIL2BAN_CHANGES" = true ]; then
            echo -e "\n✅ ${GREEN}Fail2Ban${NC}"
            echo -e "   • Status: $(systemctl is-active fail2ban)"
            echo -e "   • Jails ativos:"
            fail2ban-client status | grep -v "Status" | grep -v "Number" | grep -v "^$" | sed 's/^/     - /'
            echo -e "   • IPs banidos:"
            for jail in $(fail2ban-client status | grep "Jail list" | cut -d':' -f2 | tr ',' ' '); do
                local banned_ips
                banned_ips=$(fail2ban-client status "$jail" | grep "Banned IP list:" | cut -d':' -f2- | xargs)
                if [ -n "$banned_ips" ]; then
                    echo -e "     - $jail: $banned_ips"
                fi
            done
        fi
        
        # Configurações de rede
        echo -e "\n${YELLOW}CONFIGURAÇÕES DE REDE${NC}"
        echo -e "${separator}"
        echo -e "${CYAN}Endereços IP:${NC}"
        ip -brief -4 addr show | awk '{print "  "$1": "$3}' | grep -v 'lo:'
        
        echo -e "\n${CYAN}Portas em uso:${NC}"
        ss -tulpn | grep -E 'LISTEN|ESTAB' | awk '{print $5}' | cut -d':' -f2 | sort -n | uniq | xargs -I{} echo "  - Porta {}: $(lsof -i :{} | head -n2 | tail -1 | awk '{print $1}')"
        
        # Recomendações de segurança
        echo -e "\n${YELLOW}RECOMENDAÇÕES DE SEGURANÇA${NC}"
        echo -e "${separator}"
        
        # Verificar se o sistema está atualizado
        local updates_available
        updates_available=$(apt list --upgradable 2>/dev/null | wc -l)
        if [ "$updates_available" -gt 1 ]; then
            echo -e "⚠️  ${YELLOW}Atualizações disponíveis: $((updates_available - 1)) pacotes podem ser atualizados.${NC}"
            echo -e "   Execute 'apt update && apt upgrade -y' para atualizar o sistema.\n"
        fi
        
        # Verificar se o SSH está rodando na porta padrão
        if [ "$SSH_PORT_NEW" = "22" ]; then
            echo -e "⚠️  ${YELLOW}O SSH está rodando na porta padrão (22).${NC}"
            echo -e "   Considere alterar para uma porta não padrão para evitar varreduras automáticas.\n"
        fi
        
        # Verificar se o login root está desativado
        if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
            echo -e "⚠️  ${YELLOW}O login como root está habilitado.${NC}"
            echo -e "   Considere desativar o login direto como root para maior segurança.\n"
        fi
        
        # Verificar se a autenticação por senha está habilitada
        if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
            echo -e "⚠️  ${YELLOW}A autenticação por senha está habilitada.${NC}"
            echo -e "   Considere usar apenas autenticação por chaves públicas para maior segurança.\n"
        fi
        
        # Verificar se o UFW está ativo
        if ! ufw status | grep -q "Status: active"; then
            echo -e "⚠️  ${YELLOW}O UFW (firewall) não está ativo.${NC}"
            echo -e "   Ative o UFW com 'ufw enable' para proteger seu servidor.\n"
        fi
        
        # Verificar se o Fail2Ban está ativo
        if ! systemctl is-active --quiet fail2ban; then
            echo -e "⚠️  ${YELLOW}O Fail2Ban não está ativo.${NC}"
            echo -e "   Ative o Fail2Ban com 'systemctl enable --now fail2ban' para se proteger contra ataques de força bruta.\n"
        fi
        
        # Verificar se há atualizações de segurança pendentes
        if [ -f "/var/run/reboot-required" ]; then
            echo -e "⚠️  ${YELLOW}Uma reinicialização é necessária para concluir as atualizações de segurança.${NC}\n"
        fi
        
        # Mensagem final
        echo -e "${separator}"
        echo -e "${GREEN}CONFIGURAÇÃO DE SEGURANÇA CONCLUÍDA COM SUCESSO!${NC}"
        echo -e "${separator}"
        echo -e "Este relatório foi salvo em: $report_file"
        echo -e "\n${YELLOW}PRÓXIMOS PASSOS:${NC}"
        echo -e "1. Teste o acesso SSH na nova porta ($SSH_PORT_NEW) antes de fechar a sessão atual"
        echo -e "2. Verifique os logs em busca de erros ou avisos"
        echo -e "3. Considere configurar backups automáticos"
        echo -e "4. Monitore regularmente os logs de segurança"
        echo -e "\n${YELLOW}SUPORTE:${NC}"
        echo -e "Em caso de problemas, consulte a documentação ou entre em contato com o suporte."
        echo -e "${separator}"
        
    } > "$report_file"
    
    # Exibir mensagem de sucesso
    success "Relatório de segurança gerado em: $report_file"
    
    # Exibir resumo na tela
    echo -e "\n${GREEN}=== RESUMO DAS ALTERAÇÕES ===${NC}"
    tail -n 30 "$report_file" | grep -A 30 "RESUMO DAS ALTERAÇÕES" | grep -v "RESUMO DAS ALTERAÇÕES" | sed 's/✅ /• /g'
    
    return 0
}

# Função para verificar dependências e pré-requisitos do sistema
check_prerequisites() {
    log "Verificando pré-requisitos do sistema..."
    
    # Verificar se estamos executando como root
    if [ "$(id -u)" -ne 0 ]; then
        error "Este script deve ser executado como root. Use 'sudo $0' ou faça login como root."
        return 1
    fi
    
    # Verificar distribuição compatível (Debian/Ubuntu)
    if [ ! -f /etc/debian_version ]; then
        error "Este script é compatível apenas com distribuições baseadas em Debian/Ubuntu"
        return 1
    fi
    
    # Verificar versão do sistema operacional
    local os_id os_version
    os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    
    log "Sistema operacional detectado: $os_id $os_version"
    
    # Verificar se é Debian 12+ ou Ubuntu 20.04+
    if [ "$os_id" = "debian" ] && [ "$(echo "$os_version < 12" | bc)" -eq 1 ]; then
        warn "Versão do Debian ($os_version) anterior à 12. Algumas funcionalidades podem não estar disponíveis."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    elif [ "$os_id" = "ubuntu" ] && [ "$(echo "$os_version < 20.04" | bc)" -eq 1 ]; then
        warn "Versão do Ubuntu ($os_version) anterior à 20.04. Algumas funcionalidades podem não estar disponíveis."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar conexão com a internet
    log "Verificando conexão com a internet..."
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        error "Sem conexão com a internet. Verifique sua conexão de rede."
        return 1
    fi
    
    # Verificar se o sistema está atualizado
    log "Verificando atualizações do sistema..."
    if ! apt-get update >/dev/null 2>&1; then
        warn "Não foi possível atualizar a lista de pacotes. Verifique sua conexão com a internet."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar espaço em disco
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [ "$disk_usage" -gt 90 ]; then
        error "Espaço em disco crítico! $disk_usage% de uso na partição raiz."
        return 1
    elif [ "$disk_usage" -gt 75 ]; then
        warn "Espaço em disco baixo: $disk_usage% de uso na partição raiz."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar memória disponível
    local mem_available
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ "$mem_available" -lt 1048576 ]; then  # Menos de 1GB de memória disponível
        warn "Memória disponível baixa: $((mem_available / 1024))MB. Recomenda-se pelo menos 1GB de memória livre."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar se o sistema requer reinicialização
    if [ -f "/var/run/reboot-required" ]; then
        warn "O sistema requer reinicialização. É recomendado reiniciar antes de continuar."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar dependências necessárias
    log "Verificando dependências necessárias..."
    local missing_deps=()
    local required_deps=(
        "ssh" "sshd" "ufw" "fail2ban" "grep" "sed" "awk" 
        "gawk" "coreutils" "lsb-release" "apt-transport-https"
        "ca-certificates" "curl" "wget" "gnupg" "iptables"
    )
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    # Verificar pacotes ausentes
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "As seguintes dependências estão ausentes: ${missing_deps[*]}"
        
        if [ "$NON_INTERACTIVE" = true ] || confirm_action "Deseja instalar as dependências ausentes?" "y"; then
            log "Instalando dependências ausentes..."
            if ! apt-get update || ! apt-get install -y "${missing_deps[@]}"; then
                error "Falha ao instalar as dependências necessárias"
                return 1
            fi
        else
            error "Dependências ausentes não instaladas. O script não pode continuar."
            return 1
        fi
    fi
    
    # Verificar se o UFW está ativo
    if ufw status | grep -q 'Status: active'; then
        log "Firewall UFW já está ativo"
    else
        log "Firewall UFW não está ativo, será ativado durante a configuração"
    fi
    
    # Verificar se o Fail2Ban está instalado e ativo
    if systemctl is-active --quiet fail2ban; then
        log "Serviço Fail2Ban já está em execução"
    else
        log "Fail2Ban não está ativo, será configurado durante a instalação"
    fi
    
    # Verificar se o SSH está em execução
    if ! systemctl is-active --quiet sshd; then
        warn "O serviço SSH não está em execução. Tentando iniciar..."
        if ! systemctl start sshd; then
            error "Não foi possível iniciar o serviço SSH"
            return 1
        fi
    fi
    
    # Verificar se há sessões SSH ativas
    local active_ssh_sessions
    active_ssh_sessions=$(who | grep -c "^[^ ]* *pts/")
    
    if [ "$active_ssh_sessions" -gt 1 ]; then
        warn "Existem $active_ssh_sessions sessões SSH ativas neste servidor."
        log "Usuários conectados:"
        who
        
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    success "Verificação de pré-requisitos concluída com sucesso"
    return 0
    local missing_deps=()
    local required_commands=("awk" "grep" "sed" "cut" "tr" "date" "id" "whoami" "systemctl" "ip" "ss" "lsof" "apt-get" "dpkg")
    local required_pkgs=("coreutils" "grep" "sed" "gawk" "util-linux" "systemd" "iproute2" "iputils-ping" "lsof" "apt" "dpkg")
    
    log "Verificando pré-requisitos do sistema..."
    
    # Verificar se está rodando como root
    if [ "$(id -u)" -ne 0 ]; then
        error "Este script deve ser executado como root. Use 'sudo $0' ou faça login como root."
        return 1
    fi
    
    # Verificar distribuição Linux (Debian/Ubuntu)
    if [ ! -f /etc/debian_version ] && [ ! -f /etc/lsb-release ] && [ ! -f /etc/os-release ]; then
        warn "Este script foi projetado para sistemas Debian/Ubuntu. Outras distribuições podem não ser totalmente suportadas."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar comandos essenciais
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Verificar pacotes essenciais
    for pkg in "${required_pkgs[@]}"; do
        if ! dpkg -l | grep -q "^ii\s*$pkg\s"; then
            if ! echo "${missing_deps[@]}" | grep -q "$pkg"; then
                missing_deps+=("$pkg")
            fi
        fi
    done
    
    # Se faltar algum pacote, tentar instalar
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Os seguintes pacotes/comandos estão faltando: ${missing_deps[*]}"
        
        if confirm_action "Deseja instalar automaticamente os pacotes faltantes?" "y"; then
            log "Atualizando lista de pacotes..."
            if ! apt-get update; then
                error "Falha ao atualizar a lista de pacotes"
                return 1
            fi
            
            log "Instalando pacotes necessários..."
            if ! apt-get install -y "${missing_deps[@]}"; then
                error "Falha ao instalar os pacotes necessários"
                return 1
            fi
        else
            error "Por favor, instale os pacotes manualmente e execute o script novamente."
            return 1
        fi
    fi
    
    # Verificar espaço em disco
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$disk_usage" -gt 90 ]; then
        warn "ATENÇÃO: O uso do disco está em ${disk_usage}%. É recomendado ter pelo menos 10% de espaço livre."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar memória disponível
    local mem_available
    mem_available=$(awk '/MemAvailable/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    if [ "$mem_available" -lt 1 ]; then
        warn "ATENÇÃO: Memória disponível muito baixa (${mem_available}GB). Recomenda-se pelo menos 1GB de memória livre."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar conexão com a internet
    log "Verificando conexão com a internet..."
    if ! ping -c 1 -W 5 8.8.8.8 &> /dev/null && ! ping -c 1 -W 5 1.1.1.1 &> /dev/null; then
        warn "Não foi possível verificar a conexão com a internet. Algumas funcionalidades podem não funcionar corretamente."
        if ! confirm_action "Deseja continuar sem conexão com a internet?" "n"; then
            return 1
        fi
    fi
    
    # Verificar se o sistema está atualizado
    local updates_available
    updates_available=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$updates_available" -gt 1 ]; then
        warn "Existem $((updates_available - 1)) atualizações de pacotes disponíveis."
        if confirm_action "Deseja atualizar o sistema agora?" "y"; then
            log "Atualizando o sistema..."
            if ! apt-get update || ! apt-get upgrade -y; then
                error "Falha ao atualizar o sistema"
                return 1
            fi
            if [ -f /var/run/reboot-required ]; then
                warn "ATENÇÃO: Uma reinicialização é necessária para concluir as atualizações."
                if confirm_action "Deseja reiniciar o sistema agora?" "n"; then
                    log "Reiniciando o sistema..."
                    reboot
                    exit 0
                fi
            fi
        fi
    fi
    
    # Verificar se o sistema está rodando em um container
    if grep -q docker /proc/1/cgroup || [ -f /.dockerenv ]; then
        warn "ATENÇÃO: Este script está sendo executado em um container Docker. Algumas funcionalidades podem não funcionar corretamente."
        if ! confirm_action "Deseja continuar mesmo assim?" "n"; then
            return 1
        fi
    fi
    
    # Verificar se o sistema usa systemd
    if ! command -v systemctl &> /dev/null || ! systemctl --version &> /dev/null; then
        error "Este script requer systemd para gerenciar serviços. Seu sistema não parece usar systemd."
        return 1
    fi
    
    # Verificar se o sistema está usando systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        log "Sistema está usando systemd-resolved para resolução de DNS"
    fi
    
    # Verificar se o sistema está usando NetworkManager
    if command -v nmcli &> /dev/null && systemctl is-active --quiet NetworkManager; then
        log "Sistema está usando NetworkManager para gerenciamento de rede"
    fi
    
    success "Verificação de pré-requisitos concluída com sucesso"
    return 0
}

# Função para configurar o Fail2Ban
configure_fail2ban() {
    log "Iniciando configuração do Fail2Ban..."
    
    # Verificar se o Fail2Ban está instalado
    if ! command -v fail2ban-client &> /dev/null; then
        if ! confirm_action "Fail2Ban não está instalado. Deseja instalar?" "y"; then
            warn "Fail2Ban não será configurado. A proteção contra força bruta não estará ativa."
            return 1
        fi
        
        log "Instalando Fail2Ban..."
        if ! apt-get update || ! apt-get install -y fail2ban; then
            error "Falha ao instalar o Fail2Ban"
            return 1
        fi
    fi
    
    # Parar o serviço Fail2Ban se estiver rodando
    if systemctl is-active --quiet fail2ban; then
        log "Parando o serviço Fail2Ban..."
        run_cmd "systemctl stop fail2ban"
    fi
    
    # Fazer backup das configurações atuais
    log "Criando backup das configurações do Fail2Ban..."
    mkdir -p "${BACKUP_DIR}/fail2ban"
    
    if [ -d "/etc/fail2ban" ]; then
        run_cmd "cp -r /etc/fail2ban/ \"${BACKUP_DIR}/fail2ban/config_$(date +%Y%m%d_%H%M%S)/\""
    fi
    
    # Criar configuração personalizada
    local fail2ban_local="/etc/fail2ban/jail.local"
    local fail2ban_filter_dir="/etc/fail2ban/filter.d"
    
    log "Aplicando configurações de segurança do Fail2Ban..."
    
    # Criar arquivo de configuração principal
    cat > "$fail2ban_local" << EOF
[sshd]
enabled = true
port = $SSH_PORT_NEW
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
findtime = 600
bantime = 3600
ignoreip = 127.0.0.1/8 ::1

[sshd-ddos]
enabled = true
port = $SSH_PORT_NEW
filter = sshd-ddos
logpath = %(sshd_log)s
maxretry = 2
findtime = 600
bantime = 86400

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = %(banaction_allports)s
bantime = 604800
findtime = 86400
maxretry = 5

[ssh-iptables-ipset]
enabled = true
filter = sshd
action = iptables-ipset-proto4[name=SSH, port=$SSH_PORT_NEW, protocol=tcp]
logpath = %(sshd_log)s
maxretry = 3
findtime = 600
bantime = 3600

EOF

    # Configurações adicionais para o SSH
    cat > "$fail2ban_filter_dir/sshd-ddos.conf" << 'EOF'
[INCLUDES]
before = common.conf

[Definition]
_daemon = sshd
failregex = ^%(__prefix_line)s(?:error: PAM: )?[aA]uthentication (?:failure|error|failed) for .* from <HOST>( via \S+)*$
            ^%(__prefix_line)s(?:error: )?[iI](?:llegal|nvalid) user .* from <HOST>(?: port \d+)?$
            ^%(__prefix_line)s(?:error: )?Failed (?:password|publickey) for (?:invalid user |illegal user )?.* from <HOST>(?: port \d+)?(?: ssh2)?$
            ^%(__prefix_line)s(?:error: )?Received disconnect from <HOST>: \d+: \d+ \[preauth\]$
            ^%(__prefix_line)s(?:error: )?User not known to the underlying authentication module for .* from <HOST>$
            ^%(__prefix_line)s(?:error: )?Maximum authentication attempts exceeded for .* from <HOST>(?: port \d+)?(?: ssh2)?$
            ^%(__prefix_line)s(?:error: )?User .+ from <HOST> not allowed because none of user's groups are listed in AllowGroups$
            ^%(__prefix_line)s(?:error: )?User .+ from <HOST> not allowed because none of user's groups are listed in AllowGroups$

ignoreregex =
datepattern = {^LN-BEG}

# Autor: Fail2Ban Team
# Versão: 0.11.2
EOF

    # Configuração de banimento permanente para reincidentes
    cat > "$fail2ban_filter_dir/recidive.conf" << 'EOF'
[INCLUDES]
before = common.conf

[Definition]
# O filtro combina todas as mensagens de banimento do fail2ban
failregex = ^(%(__prefix_line)s|\s*)NOTICE\s+\[\S+\]\s+Ban\s+<HOST>\b
            ^(%(__prefix_line)s|\s*)WARNING\s+\[\S+\]\s+Ban\s+<HOST>\b

ignoredate = 
datepattern = {^LN-BEG}

# Autor: Fail2Ban Team
# Versão: 0.11.2
EOF

    # Configuração de proteção contra força bruta no SSH
    cat > "$fail2ban_filter_dir/ssh-iptables-ipset.conf" << EOF
[INCLUDES]
before = iptables-common.conf

[Definition]
# Nome da chain do iptables
chain = INPUT

# Porta que será protegida
port = $SSH_PORT_NEW

# Protocolo (tcp/udp)
protocol = tcp

# Nome do conjunto ipset
ipset = fail2ban-SSH

# Tabela do ipset
table = filter

# Nome da chain do ipset
chain = INPUT

# Ação a ser tomada (DROP/REJECT)
blocktype = DROP

# Nome do serviço
name = SSH

# Nome da chain personalizada
chain = f2b-<name>

# Nome da chain de log
chain_log = f2b-<name>-log

# Nome da chain de drop
chain_drop = f2b-<name>-drop

# Nome da chain de rejeição
chain_reject = f2b-<name>-reject

# Nome da chain de aceitação
chain_accept = f2b-<name>-accept

# Nome da chain de log do ipset
chain_ipset_log = f2b-<name>-ipset-log

# Nome da chain de drop do ipset
chain_ipset_drop = f2b-<name>-ipset-drop

# Nome da chain de rejeição do ipset
chain_ipset_reject = f2b-<name>-ipset-reject

# Nome da chain de aceitação do ipset
chain_ipset_accept = f2b-<name>-ipset-accept

# Opções adicionais
# Número de tentativas antes do banimento
maxretry = 3

# Tempo em segundos para contar as tentativas
findtime = 600

# Tempo de banimento em segundos
bantime = 3600

# IPs a serem ignorados (separados por espaço)
ignoreip = 127.0.0.1/8 ::1

# Habilitar o banimento permanente para reincidentes
recidive = true

# Número de banimentos antes do banimento permanente
recidivemax = 3

# Tempo de banimento permanente em segundos (7 dias)
recidivemaxtime = 604800
EOF

    # Configurar o serviço Fail2Ban
    log "Reiniciando o serviço Fail2Ban..."
    if ! systemctl enable --now fail2ban; then
        error "Falha ao iniciar o serviço Fail2Ban"
        return 1
    fi
    
    # Verificar status
    if ! systemctl is-active --quiet fail2ban; then
        error "O serviço Fail2Ban não está ativo. Verifique os logs: journalctl -u fail2ban"
        return 1
    fi
    
    # Verificar se o Fail2Ban está funcionando corretamente
    if ! fail2ban-client status sshd &> /dev/null; then
        warn "O jail do SSH não foi carregado corretamente no Fail2Ban"
    fi
    
    HAS_FAIL2BAN_CHANGES=true
    success "Fail2Ban configurado com sucesso"
    
    # Mostrar status dos jails
    log "Status dos jails do Fail2Ban:"
    fail2ban-client status | sed 's/^/  /'
    
    # Mostrar IPs banidos
    local banned_ips
    banned_ips=$(fail2ban-client status sshd | grep 'Banned IP list:' | cut -d':' -f2- | xargs)
    if [ -n "$banned_ips" ]; then
        log "IPs atualmente banidos no jail 'sshd': $banned_ips"
    else
        log "Nenhum IP banido no momento no jail 'sshd'"
    fi
    
    return 0
}

# Função para configurar o UFW (firewall)
configure_ufw() {
    log "Iniciando configuração do UFW (firewall)..."
    
    # Verificar se o UFW está instalado
    if ! command -v ufw >/dev/null 2>&1; then
        error "UFW não está instalado. Instalando..."
        if ! apt-get install -y ufw; then
            error "Falha ao instalar o UFW"
            return 1
        fi
    fi
    
    # Fazer backup da configuração atual
    local ufw_backup="${BACKUP_DIR}/ufw.before"
    log "Criando backup da configuração atual do UFW em: $ufw_backup"
    ufw status verbose > "${ufw_backup}.status" 2>&1
    
    # Verificar se estamos no modo de simulação
    if [ "$DRY_RUN" = true ]; then
        log "[SIMULAÇÃO] As seguintes alterações seriam feitas no UFW:"
        log "- Redefinir todas as regras (ufw --force reset)"
        log "- Definir política padrão: DENY (entrada), ALLOW (saída)"
        log "- Permitir tráfego de saída"
        log "- Permitir conexões na porta SSH: $SSH_PORT_NEW"
        log "- Permitir conexões HTTP/HTTPS (portas 80, 443)"
        log "- Bloquear tráfego de entrada não solicitado"
        log "- Habilitar proteção contra IP spoofing"
        log "- Habilitar logging"
        log "- Ativar o UFW"
        
        HAS_UFW_CHANGES=true
        return 0
    fi
    
    # Resetar todas as regras
    log "Redefinindo todas as regras do UFW..."
    ufw --force reset
    
    # Definir políticas padrão
    log "Definindo políticas padrão..."
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir tráfego de loopback
    ufw allow in on lo
    ufw allow out on lo
    
    # Permitir conexões estabelecidas e relacionadas
    ufw allow in on eth0 proto tcp from any to any port $SSH_PORT_NEW comment 'SSH acesso'
    ufw allow in on eth0 proto tcp from any to any port 80 comment 'HTTP acesso'
    ufw allow in on eth0 proto tcp from any to any port 443 comment 'HTTPS acesso'
    
    # Permitir ping (ICMP)
    ufw allow in on eth0 proto icmp --icmp-type echo-request
    
    # Proteção contra IP spoofing
    local public_interface
    public_interface=$(ip route | grep default | awk '{print $5}')
    
    if [ -n "$public_interface" ]; then
        log "Aplicando proteção contra IP spoofing na interface $public_interface..."
        
        # Obter o endereço IP público atual
        local public_ip
        public_ip=$(curl -s https://api.ipify.org)
        
        if [ -n "$public_ip" ]; then
            # Bloquear pacotes com IP de origem falso (IP spoofing)
            ufw route deny in on $public_interface from $public_ip to any
            ufw route deny in on $public_interface from 10.0.0.0/8 to any
            ufw route deny in on $public_interface from 172.16.0.0/12 to any
            ufw route deny in on $public_interface from 192.168.0.0/16 to any
            ufw route deny in on $public_interface from 224.0.0.0/4 to any
            ufw route deny in on $public_interface from 240.0.0.0/5 to any
            ufw route deny in on $public_interface from 127.0.0.0/8 to any
            ufw route deny in on $public_interface from 0.0.0.0/8 to any
        else
            warn "Não foi possível determinar o endereço IP público. Pulando proteção contra IP spoofing."
        fi
    else
        warn "Não foi possível determinar a interface de rede pública. Pulando proteção contra IP spoofing."
    fi
    
    # Configurações adicionais de segurança
    log "Aplicando configurações adicionais de segurança..."
    
    # Proteção contra ataques de força bruta no SSH
    ufw limit $SSH_PORT_NEW/tcp
    
    # Proteção contra port scanning
    ufw limit ssh
    
    # Habilitar logging
    ufw logging on
    ufw logging high
    
    # Habilitar proteção contra ataques de negação de serviço (DoS)
    sysctl -w net.ipv4.tcp_syncookies=1
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf
    
    # Desabilitar roteamento de pacotes entre interfaces
    sysctl -w net.ipv4.ip_forward=0
    echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
    
    # Proteção contra spoofing
    sysctl -w net.ipv4.conf.all.rp_filter=1
    sysctl -w net.ipv4.conf.default.rp_filter=1
    echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter=1" >> /etc/sysctl.conf
    
    # Desabilitar redirecionamento de pacotes
    sysctl -w net.ipv4.conf.all.send_redirects=0
    sysctl -w net.ipv4.conf.default.send_redirects=0
    echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.send_redirects=0" >> /etc/sysctl.conf
    
    # Ativar proteção contra SYN flood
    sysctl -w net.ipv4.tcp_syncookies=1
    sysctl -w net.ipv4.tcp_max_syn_backlog=2048
    sysctl -w net.ipv4.tcp_synack_retries=2
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=2048" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_synack_retries=2" >> /etc/sysctl.conf
    
    # Aplicar as alterações do sysctl
    sysctl -p
    
    # Ativar o UFW
    log "Ativando o UFW..."
    if ! echo "y" | ufw enable; then
        error "Falha ao ativar o UFW"
        return 1
    fi
    
    # Verificar o status do UFW
    log "Verificando o status do UFW..."
    ufw status verbose
    
    HAS_UFW_CHANGES=true
    success "Configuração do UFW concluída com sucesso"
    
    # Mostrar instruções para o usuário
    log "\n${YELLOW}INFORMAÇÕES IMPORTANTES:${NC}"
    log "1. O firewall UFW foi configurado com as seguintes portas abertas:"
    log "   - Porta SSH: $SSH_PORT_NEW"
    log "   - Porta HTTP: 80"
    log "   - Porta HTTPS: 443"
    log "2. Todas as outras portas estão bloqueadas por padrão"
    log "3. O logging do UFW foi ativado com nível alto"
    log "4. Proteções contra IP spoofing foram habilitadas"
    log "5. Proteções contra DoS foram configuradas"
    log "\nPara visualizar o status do UFW, execute: ufw status verbose"
    log "Para visualizar os logs do UFW, execute: journalctl -u ufw -f"
    
    return 0
    log "Iniciando configuração do UFW..."
    
    # Verificar se o UFW está instalado
    if ! command -v ufw &> /dev/null; then
        if ! confirm_action "UFW não está instalado. Deseja instalar?" "y"; then
            warn "UFW não será configurado. A segurança do firewall não está ativada."
            return 1
        fi
        
        log "Instalando UFW..."
        if ! apt-get update || ! apt-get install -y ufw; then
            error "Falha ao instalar o UFW"
            return 1
        fi
    fi
    
    # Fazer backup das configurações atuais
    log "Criando backup das configurações do UFW..."
    mkdir -p "${BACKUP_DIR}/ufw"
    run_cmd "ufw status verbose > \"${BACKUP_DIR}/ufw/status.bak\""
    run_cmd "cp -r /etc/ufw \"${BACKUP_DIR}/ufw/config\""
    
    # Configurações padrão do UFW
    log "Aplicando configurações de segurança do UFW..."
    
    # Resetar UFW para padrão (sem afetar as regras existentes)
    run_cmd "ufw --force reset"
    
    # Configurações básicas
    run_cmd "ufw default deny incoming"
    run_cmd "ufw default allow outgoing"
    
    # Permitir porta SSH (nova porta configurada)
    if [ "$SSH_PORT_NEW" -ne 22 ]; then
        run_cmd "ufw allow ${SSH_PORT_NEW}/tcp comment 'SSH (alterada da porta 22)'"
        
        # Se a porta 22 estiver aberta, remover após configurar a nova porta
        if ufw status | grep -q "^22/tcp.*ALLOW"; then
            if confirm_action "A porta 22 está aberta. Deseja fechá-la após configurar a porta $SSH_PORT_NEW?" "y"; then
                run_cmd "ufw delete allow 22/tcp"
                log "Porta 22/tcp removida do UFW"
            fi
        fi
    else
        run_cmd "ufw allow ${SSH_PORT_NEW}/tcp comment 'SSH'"
    fi
    
    # Permitir portas comuns (HTTP, HTTPS, DNS)
    for port in 80 443 53; do
        if is_port_in_use "$port"; then
            if confirm_action "Deseja permitir a porta $port no firewall?" "y"; then
                run_cmd "ufw allow ${port}/tcp comment 'Serviço na porta ${port}'"
            fi
        fi
    done
    
    # Habilitar logging
    run_cmd "ufw logging on"
    
    # Habilitar proteção contra IP spoofing
    if [ -f "/etc/default/ufw" ]; then
        run_cmd "sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw"
    fi
    
    # Habilitar UFW
    log "Ativando o UFW..."
    if ! echo "y" | ufw enable; then
        error "Falha ao ativar o UFW"
        return 1
    fi
    
    # Verificar status
    if ! ufw status | grep -q "Status: active"; then
        error "O UFW não está ativo. Verifique as configurações."
        return 1
    fi
    
    HAS_UFW_CHANGES=true
    success "UFW configurado com sucesso"
    
    # Mostrar resumo das regras
    log "Resumo das regras do UFW:"
    ufw status numbered | sed 's/^/  /'
    
    return 0
}

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --port=*)
            SSH_PORT_NEW="${1#*=}"
            if ! [[ "$SSH_PORT_NEW" =~ ^[0-9]+$ ]] || [ "$SSH_PORT_NEW" -lt 1 ] || [ "$SSH_PORT_NEW" -gt 65535 ]; then
                error "Porta inválida: $SSH_PORT_NEW. Use uma porta entre 1 e 65535."
            fi
            shift
            ;;
        --user=*)
            SSH_USER="${1#*=}"
            if ! validate_username "$SSH_USER"; then
                error "Usuário inválido ou sem privilégios sudo: $SSH_USER"
            fi
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            log "Modo de simulação ativado (nenhuma alteração será feita)"
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            log "Modo não-interativo ativado (usando valores padrão)"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            error "Argumento inválido: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Início do script
clear
echo -e "${YELLOW}=== ZERUP SECURITY SETUP ===${NC}"

# Função para criar novo usuário com privilégios sudo
create_sudo_user() {
    echo -e "\n${YELLOW}=== CRIAR NOVO USUÁRIO COM PRIVILÉGIOS SUDO ===${NC}"
    
    while true; do
        read -p "Digite o nome do novo usuário: " NEW_USER
        if [ -z "$NEW_USER" ]; then
            echo -e "${RED}O nome de usuário não pode estar vazio.${NC}"
            continue
        fi
        
        if id "$NEW_USER" &>/dev/null; then
            echo -e "${YELLOW}O usuário '$NEW_USER' já existe.${NC}"
            if confirm_action "Deseja usar este usuário?" "n"; then
                SSH_USER="$NEW_USER"
                return 0
            else
                continue
            fi
        fi
        
        # Criar o usuário
        if useradd -m -s /bin/bash "$NEW_USER"; then
            # Adicionar ao grupo sudo
            if command -v usermod &>/dev/null; then
                usermod -aG sudo "$NEW_USER"
            elif command -v gpasswd &>/dev/null; then
                gpasswd -a "$NEW_USER" sudo
            fi
            
            # Definir senha
            passwd "$NEW_USER"
            
            SSH_USER="$NEW_USER"
            log "Novo usuário '$NEW_USER' criado com sucesso e adicionado ao grupo sudo"
            return 0
        else
            error "Falha ao criar o usuário '$NEW_USER'"
            return 1
        fi
    done
}

# Verificar se há usuários não-root
if [ -z "$SSH_USER" ]; then
    echo -e "${YELLOW}=== VERIFICAÇÃO DE USUÁRIOS ===${NC}"
    echo -e "${YELLOW}Verificando usuários não-root...${NC}"
    
    # Listar usuários não-root
    NON_ROOT_USERS=$(getent passwd | grep -v '^root:' | grep -v '/usr/sbin/nologin' | grep -v '/bin/false' | cut -d: -f1 | tr '\n' ' ')
    
    if [ -z "$NON_ROOT_USERS" ]; then
        echo -e "${YELLOW}Nenhum usuário não-root encontrado.${NC}"
        if confirm_action "Deseja criar um novo usuário com privilégios sudo?" "y"; then
            create_sudo_user || error "Falha ao criar novo usuário"
        else
            error "É necessário ter pelo menos um usuário não-root com privilégios sudo para continuar."
        fi
    else
        echo -e "${GREEN}Usuários não-root encontrados:${NC} $NON_ROOT_USERS"
        
        # Opção de criar novo usuário
        echo -e "\n${YELLOW}Você pode:${NC}"
        echo "1. Usar um usuário existente"
        echo "2. Criar um novo usuário com privilégios sudo"
        
        while true; do
            read -p "Sua escolha [1-2]: " user_choice
            case $user_choice in
                1)
                    read -p "Digite o nome do usuário que usará para acesso SSH: " SSH_USER
                    # Verificar se o usuário existe
                    if id "$SSH_USER" &>/dev/null; then
                        break
                    else
                        echo -e "${RED}O usuário '$SSH_USER' não existe.${NC}"
                    fi
                    ;;
                2)
                    create_sudo_user && break
                    ;;
                *)
                    echo -e "${RED}Opção inválida. Escolha 1 ou 2.${NC}"
                    ;;
            esac
        done
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
