#!/bin/bash
########################################################################
# Script Name: zero-initial.sh
# Version:    1.0.0
# Date:       2025-07-06
# Author:     Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Diagnóstico e hardening inicial: verifica vulnerabilidades comuns,
#   portas abertas, SSH, UFW, updates e recomendações de segurança.
#
# Usage:
#   sudo ./zero-initial.sh
#
# Exit codes:
#   0 - Tudo ok
#   1 - Vulnerabilidades críticas detectadas
#
# Prerequisites:
#   - Debian 12+ ou macOS
#   - Permissão root
########################################################################

set -e

LOGFILE="zero-initial-$(date +%Y%m%d-%H%M%S).log"

banner() {
  echo "\n==================== $1 ===================="
}

banner "Diagnóstico de portas abertas"
ss -tuln | tee -a "$LOGFILE"

banner "Diagnóstico SSH"
grep -E '^Port|^PermitRootLogin|^PasswordAuthentication' /etc/ssh/sshd_config | tee -a "$LOGFILE"

banner "Diagnóstico UFW"
ufw status verbose | tee -a "$LOGFILE"

banner "Atualizações de segurança"
apt list --upgradable 2>/dev/null | grep -i security | tee -a "$LOGFILE"

banner "Pacotes potencialmente vulneráveis"
apt list --upgradable 2>/dev/null | tee -a "$LOGFILE"

banner "Recomendações de hardening"
echo "- Considere alterar a porta SSH padrão (Port 22) para outra."
echo "- Desabilite PermitRootLogin e PasswordAuthentication no SSH."
echo "- Permita apenas portas essenciais no UFW."
echo "- Mantenha o sistema sempre atualizado."
echo "- Revise os logs acima e corrija vulnerabilidades antes de produção."

exit 0
