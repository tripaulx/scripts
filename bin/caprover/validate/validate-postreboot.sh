#!/bin/bash
########################################################################
# Script Name: validate-postreboot.sh
# Version:    1.0.0
# Date:       2025-07-06
# Author:     Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Diagnóstico pós-reboot: checa serviços essenciais, espaço, swap,
#   conectividade, logs e recomenda snapshot/backup antes de scripts destrutivos.
#
# Usage:
#   sudo ./validate-postreboot.sh
#
# Exit codes:
#   0 - Tudo ok
#   1 - Algum serviço crítico não está ativo
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

LOGFILE="validate-postreboot-$(date +%Y%m%d-%H%M%S).log"

banner() {
  printf "\n==================== %s ====================\n" "$1"
}

banner "Diagnóstico Pós-Reboot"

# Função para configurar o SSH para log apropriado
configure_ssh_logging() {
  echo -e "\n[INFO] Configurando logs do SSH..."
  if ! grep -q "^SyslogFacility AUTH" /etc/ssh/sshd_config; then
    echo "SyslogFacility AUTH" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "LogLevel INFO" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "[SUCESSO] Configuração do SSH atualizada"
    sudo systemctl restart sshd
    return 0
  else
    echo "[INFO] Configuração do SSH já está correta"
    return 1
  fi
}

# Função para configurar o Fail2Ban
configure_fail2ban() {
  echo -e "\n[INFO] Configurando o Fail2Ban..."
  
  # Criar diretório de filtros personalizados se não existir
  sudo mkdir -p /etc/fail2ban/filter.d

  # Criar filtro personalizado para systemd
  echo -e "[INFO] Configurando filtro personalizado para systemd..."
  sudo bash -c 'cat > /etc/fail2ban/filter.d/sshd-systemd.conf' << 'EOL'
[INCLUDES]
before = common.conf

[Definition]
_daemon = sshd
failregex = ^%(__prefix_line)s(?:error: PAM: )?[aA]uthentication (?:failure|error|failed).* for (?:illegal user )?(?:user )?.*(?: from <HOST>(?: port \d+)?(?: ssh\d*)?(?: on \S+)?(?: port \d+)?(?: \S+)?)?\s*$
            ^%(__prefix_line)s(?:error: PAM: )?User not known to the underlying authentication module for .* from <HOST>\s*$
            ^%(__prefix_line)sFailed (?:password|publickey) for (?:invalid user |illegal user )?.* from <HOST>(?: port \d+)?(?: ssh\d*)?\s*$
            ^%(__prefix_line)sReceived disconnect from <HOST>: 3: \\S+: (?:authentication|user) failed\s*$

ignoreregex =
EOL

  # Configuração do jail para usar systemd
  echo -e "[INFO] Configurando jail para usar systemd..."
  sudo bash -c 'cat > /etc/fail2ban/jail.d/sshd.conf' << 'EOL'
[sshd]
enabled = true
port = ssh
filter = sshd-systemd
backend = systemd
maxretry = 3
bantime = 1h
findtime = 600
ignoreip = 127.0.0.1/8 ::1
EOL

  # Ajustar permissões
  sudo chown -R root:root /etc/fail2ban
  sudo chmod -R 755 /etc/fail2ban
  
  echo -e "[SUCESSO] Configuração do Fail2Ban atualizada"
  return 0
}

# Função para corrigir o Fail2Ban
fix_fail2ban() {
  echo -e "\n[INFO] Tentando corrigir o Fail2Ban automaticamente..."
  
  # 1. Parar o serviço
  sudo systemctl stop fail2ban 2>/dev/null
  
  # 2. Configurar SSH
  configure_ssh_logging
  
  # 3. Configurar Fail2Ban
  configure_fail2ban
  
  # 4. Testar configuração
  echo -e "\n[INFO] Testando configuração do Fail2Ban..."
  if ! sudo fail2ban-client -t; then
    echo "[ERRO] Falha na configuração do Fail2Ban" | tee -a "$LOGFILE"
    return 1
  fi
  
  # 5. Iniciar o serviço
  echo -e "\n[INFO] Iniciando o serviço Fail2Ban..."
  sudo systemctl start fail2ban
  sudo systemctl enable fail2ban
  
  # Verificar status
  if systemctl is-active --quiet fail2ban; then
    echo -e "\n[SUCESSO] Fail2Ban está rodando com sucesso!"
    echo -e "\n=== Status do Fail2Ban ==="
    sudo fail2ban-client status
    
    echo -e "\n=== Status da prisão do SSH ==="
    if sudo fail2ban-client status sshd &>/dev/null; then
      sudo fail2ban-client status sshd
    else
      echo "[AVISO] A prisão do SSH não está ativa. Verifique os logs."
    fi
    return 0
  else
    echo "[ERRO] Falha ao iniciar o Fail2Ban" | tee -a "$LOGFILE"
    echo -e "\n=== Últimas linhas do log do Fail2Ban ==="
    sudo journalctl -u fail2ban --no-pager -n 20 | tee -a "$LOGFILE"
    return 1
  fi
}

# Checagem dos principais serviços
for svc in docker ufw; do
  echo -n "[INFO] Checando serviço $svc... "
  if systemctl is-active --quiet $svc; then
    echo "OK"
  else
    echo "FALHOU"
    echo "[ERRO] Serviço $svc não está ativo!" | tee -a "$LOGFILE"
  fi
done

# Verificação especial para o Fail2Ban com opção de correção
echo -n "[INFO] Checando serviço fail2ban... "
if systemctl is-active --quiet fail2ban; then
  echo "OK"
else
  echo "FALHOU"
  echo "[ERRO] Serviço fail2ban não está ativo!" | tee -a "$LOGFILE"
  
  # Pergunta se deseja corrigir automaticamente
  if [ -t 0 ]; then  # Se estiver em um terminal interativo
    read -p "Deseja tentar corrigir o Fail2Ban automaticamente? [s/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
      fix_fail2ban
    fi
  else
    # Em modo não interativo, tenta corrigir automaticamente
    fix_fail2ban
  fi
fi

# Checa binários essenciais
for bin in node npm caprover; do
  echo -n "[INFO] Checando $bin... "
  if command -v $bin >/dev/null 2>&1; then
    echo "OK ($( $bin --version 2>/dev/null | head -n1 ))"
  else
    echo "FALHOU"
    echo "[ERRO] $bin não encontrado!" | tee -a "$LOGFILE"
  fi
done

# Espaço em disco
banner "Espaço em disco"
df -hT | tee -a "$LOGFILE"

# Swap
banner "Swap ativa"
swapon --show | tee -a "$LOGFILE"

# Conectividade
banner "Conectividade"
if ping -c 2 8.8.8.8; then
    echo "[OK] Internet funcionando"
  else
    echo "[ERRO] Sem conectividade externa!" | tee -a "$LOGFILE"
  fi

# Logs recentes de erro
banner "Logs recentes do sistema"
journalctl -p 3 -n 10 --no-pager | tee -a "$LOGFILE"

banner "Recomendações"
echo "Faça snapshot/backup do servidor ANTES de rodar scripts destrutivos!" | tee -a "$LOGFILE"
echo "Próximo passo: sudo ./zero-initial.sh para hardening e validação de segurança."

exit 0
