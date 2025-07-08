#!/bin/bash
########################################################################
# Script Name: zero-initial.sh
# Version:    1.1.0
# Date:       2025-07-06
# Author:     Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Diagnóstico e hardening inicial: verifica vulnerabilidades comuns,
#   portas abertas, SSH, UFW, updates e recomendações de segurança.
#   Exibe um relatório formatado com emojis para melhor legibilidade.
#
# Usage:
#   sudo ./zero-initial.sh
#
# Exit codes:
#   0 - Tudo ok
#   1 - Vulnerabilidades críticas detectadas
#
# Prerequisites:
#   - Debian 12 (Bookworm) ou superior
#   - Permissão root
########################################################################

set -e

# Verifica versão do Bash
if [ "$(bash --version | head -n1 | grep -oE '[0-9]+')" -lt 4 ]; then
  echo -e "\033[0;31m[ERRO] Bash 4.0+ é obrigatório. Instale com 'brew install bash' (macOS) ou 'sudo apt install bash' (Linux).\033[0m"
  exit 1
fi

# Cores e estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

LOGFILE="zero-initial-$(date +%Y%m%d-%H%M%S).log"
VULNERABILIDADE_CRITICA=0

# Função para exibir cabeçalhos formatados
header() {
  echo -e "\n${BLUE}${BOLD}🔍 $1${NC}"
  echo "$1" >> "$LOGFILE"
  echo "$(printf '%*s' ${#1} | tr ' ' '=')" >> "$LOGFILE"
}

# Função para exibir status com emoji
status_ok() {
  echo -e "${GREEN}✅ $1${NC}"
  echo "[OK] $1" >> "$LOGFILE"
}

status_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
  echo "[WARN] $1" >> "$LOGFILE"
  VULNERABILIDADE_CRITICA=1
}

status_error() {
  echo -e "${RED}❌ $1${NC}"
  echo "[ERROR] $1" >> "$LOGFILE"
  VULNERABILIDADE_CRITICA=1
}

# Função para verificar porta
check_port() {
  if ss -tuln | grep -q ":$1 "; then
    echo -e "${YELLOW}🚨 Porta $1 aberta: $2${NC}"
    echo "[WARN] Porta $1 aberta: $2" >> "$LOGFILE"
    return 1
  else
    status_ok "Porta $1 fechada: $2"
    return 0
  fi
}

# Início do script
echo -e "\n${BLUE}${BOLD}🔒 ${UNDERLINE}ANÁLISE DE SEGURANÇA DO SISTEMA${NC}${NC}"
echo "Análise iniciada em: $(date)" | tee "$LOGFILE"

# Verificar se é root
if [ "$(id -u)" -ne 0 ]; then
  status_error "Este script deve ser executado como root"
  exit 1
fi

# 1. Verificar portas abertas
header "🔍 PORTAS ABERTAS"
PORTA_22=$(ss -tuln | grep ':22 ' || true)
PORTA_80=$(ss -tuln | grep ':80 ' || true)
PORTA_443=$(ss -tuln | grep ':443 ' || true)

ss -tuln | tee -a "$LOGFILE"

# 2. Verificar configuração SSH
header "🔐 CONFIGURAÇÃO SSH"
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_PORT=$(grep -E '^Port' "$SSH_CONFIG" | awk '{print $2}' || echo "22")
PERMIT_ROOT_LOGIN=$(grep -E '^PermitRootLogin' "$SSH_CONFIG" | awk '{print $2}' || echo "yes")
PASSWORD_AUTH=$(grep -E '^PasswordAuthentication' "$SSH_CONFIG" | awk '{print $2}' | tail -n 1 || echo "yes")

echo -e "Porta SSH: ${YELLOW}$SSH_PORT${NC}" | tee -a "$LOGFILE"
echo -e "PermitRootLogin: ${YELLOW}$PERMIT_ROOT_LOGIN${NC}" | tee -a "$LOGFILE"
echo -e "PasswordAuthentication: ${YELLOW}$PASSWORD_AUTH${NC}" | tee -a "$LOGFILE"

# 3. Verificar UFW
header "🛡️  CONFIGURAÇÃO DO FIREWALL (UFW)"
if command -v ufw >/dev/null 2>&1; then
  UFW_STATUS=$(ufw status | grep "Status" || echo "Status: inactive")
  if echo "$UFW_STATUS" | grep -q "active"; then
    status_ok "UFW está ativo"
    ufw status verbose | tee -a "$LOGFILE"
  else
    status_warn "UFW está inativo"
  fi
else
  status_error "UFW não está instalado"
fi

# 4. Verificar atualizações de segurança
header "🔄 ATUALIZAÇÕES DE SEGURANÇA"
if command -v apt >/dev/null 2>&1; then
  UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security || echo "Nenhuma atualização de segurança pendente")
  if [ "$UPDATES" != "Nenhuma atualização de segurança pendente" ]; then
    status_warn "Atualizações de segurança disponíveis:"
    echo "$UPDATES" | tee -a "$LOGFILE"
  else
    status_ok "Nenhuma atualização de segurança pendente"
  fi
else
  status_warn "Gerenciador de pacotes apt não encontrado"
fi

# 5. Verificar pacotes vulneráveis
header "⚠️  PACOTES ATUALIZÁVEIS"
if command -v apt >/dev/null 2>&1; then
  UPDATABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." || echo "Nenhum pacote para atualizar")
  if [ "$UPDATABLE" != "Nenhum pacote para atualizar" ]; then
    status_warn "Pacotes desatualizados encontrados:"
    echo "$UPDATABLE" | tee -a "$LOGFILE"
  else
    status_ok "Todos os pacotes estão atualizados"
  fi
fi

# 6. Verificar Fail2Ban
header "🛡️  STATUS DO FAIL2BAN"
if systemctl is-active --quiet fail2ban; then
  status_ok "Fail2Ban está em execução"
  echo -e "\n${BLUE}📊 Status das prisões:${NC}"
  if sudo fail2ban-client status | grep -q "Status\|Jail list"; then
    sudo fail2ban-client status | tee -a "$LOGFILE"
    if sudo fail2ban-client status | grep -q "sshd"; then
      echo -e "\n${BLUE}📊 Status da prisão do SSH:${NC}"
      sudo fail2ban-client status sshd | tee -a "$LOGFILE"
    fi
  else
    status_warn "Nenhuma prisão ativa no Fail2Ban"
  fi
else
  status_warn "Fail2Ban não está em execução"
fi

# 7. Relatório de segurança
header "📊 RESUMO DA ANÁLISE DE SEGURANÇA"

# Verificação de portas críticas
check_port 22 "SSH (padrão)"
check_port 3306 "MySQL"
check_port 5432 "PostgreSQL"
check_port 27017 "MongoDB"
check_port 6379 "Redis"

# Verificação de configurações críticas
echo -e "\n${BLUE}🔐 CONFIGURAÇÕES CRÍTICAS:${NC}"

# Verificar porta SSH padrão
if [ "$SSH_PORT" = "22" ]; then
  status_warn "Porta SSH padrão (22) em uso"
else
  status_ok "Porta SSH personalizada em uso: $SSH_PORT"
fi

# Verificar login root
if [ "$PERMIT_ROOT_LOGIN" = "yes" ] || [ "$PERMIT_ROOT_LOGIN" = "prohibit-password" ] || [ "$PERMIT_ROOT_LOGIN" = "without-password" ]; then
  status_warn "Login root via SSH está habilitado"
else
  status_ok "Login root via SSH está desabilitado"
fi

# Verificar autenticação por senha
if [ "$PASSWORD_AUTH" = "yes" ]; then
  status_warn "Autenticação por senha está habilitada"
else
  status_ok "Autenticação por senha está desabilitada"
fi

# 8. Recomendações
header "🚀 RECOMENDAÇÕES DE SEGURANÇA"

echo -e "${BOLD}🔧 Recomendações de Hardening:${NC}"
echo -e "${YELLOW}1.${NC} ${BOLD}SSH:${NC}"
echo "   - Altere a porta SSH padrão (22) para uma porta alta (ex: 2222, 39999)"
echo "   - Desative o login root via SSH (defina PermitRootLogin no)"
echo "   - Desative a autenticação por senha (defina PasswordAuthentication no)"
echo -e "\n${YELLOW}2.${NC} ${BOLD}Firewall (UFW):${NC}"
echo "   - Mantenha apenas as portas estritamente necessárias abertas"
echo "   - Considere limitar o acesso SSH por IP de origem"
echo -e "\n${YELLOW}3.${NC} ${BOLD}Atualizações:${NC}"
echo "   - Execute 'apt update && apt upgrade -y' regularmente"
echo "   - Configure atualizações automáticas de segurança"
echo -e "\n${YELLOW}4.${NC} ${BOLD}Monitoramento:${NC}"
echo "   - Revise os logs regularmente: /var/log/auth.log, /var/log/fail2ban.log"
echo "   - Considere configurar alertas para tentativas de acesso suspeitas"

# 9. Conclusão
echo -e "\n${BLUE}${BOLD}📋 RESUMO FINAL:${NC}${NC}"
if [ $VULNERABILIDADE_CRITICA -eq 0 ]; then
  echo -e "${GREEN}✅ Nenhuma vulnerabilidade crítica encontrada!${NC}"
  echo "Nenhuma vulnerabilidade crítica encontrada em $(date)" >> "$LOGFILE"
else
  echo -e "${YELLOW}⚠️  Foram encontradas $VULNERABILIDADE_CRITICA configurações que precisam de atenção!${NC}"
  echo "$VULNERABILIDADE_CRITICA vulnerabilidades encontradas em $(date)" >> "$LOGFILE"
fi

echo -e "\n${BLUE}📝 Log completo salvo em: $PWD/$LOGFILE${NC}"

exit $VULNERABILIDADE_CRITICA
