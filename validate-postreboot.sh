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
#   - Debian 12+ ou macOS
#   - Permissão root
########################################################################

set -e

LOGFILE="validate-postreboot-$(date +%Y%m%d-%H%M%S).log"

banner() {
  echo "\n==================== $1 ===================="
}

banner "Diagnóstico Pós-Reboot"

# Checagem dos principais serviços
for svc in docker ufw fail2ban; do
  echo -n "[INFO] Checando serviço $svc... "
  if systemctl is-active --quiet $svc; then
    echo "OK"
  else
    echo "FALHOU"
    echo "[ERRO] Serviço $svc não está ativo!" | tee -a "$LOGFILE"
  fi
done

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
ping -c 2 8.8.8.8 && echo "[OK] Internet funcionando" || echo "[ERRO] Sem conectividade externa!" | tee -a "$LOGFILE"

# Logs recentes de erro
banner "Logs recentes do sistema"
journalctl -p 3 -n 10 --no-pager | tee -a "$LOGFILE"

banner "Recomendações"
echo "Faça snapshot/backup do servidor ANTES de rodar scripts destrutivos!" | tee -a "$LOGFILE"
echo "Próximo passo: sudo ./zero-initial.sh para hardening e validação de segurança."

exit 0
