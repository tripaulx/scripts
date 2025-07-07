#!/bin/bash
########################################################################
# Script Name: zerup-scurity-setup.sh
# Version:    2.0.0
# Date:       2025-07-07
# Author:     Equipe de Seguranca
#
# Description:
#   Entrada principal para hardening. Carrega modulos em src/security
#   (ssh, firewall, fail2ban, etc.) e executa a logica definida.
#
# Usage:
#   sudo ./harden/zerup-scurity-setup.sh --all
########################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=../../../../src/security/security_setup.sh
source "${REPO_ROOT}/src/security/security_setup.sh" || {
    echo "Nao foi possivel carregar security_setup.sh" >&2
    exit 1
}

main "$@"
exit $?
