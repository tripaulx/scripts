#!/bin/bash
########################################################################
# Script Name: main.sh
# Version:    2.1.0
# Date:       2025-07-07
# Author:     Equipe de Infraestrutura
#
# Description:
#   Entrada principal que carrega modulos em src/ e executa o menu.
#
# Usage:
#   sudo ./main.sh
########################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar modulos
source "${SCRIPT_DIR}/src/main/utils.sh"
source "${SCRIPT_DIR}/src/core/initialization.sh"
source "${SCRIPT_DIR}/src/main/menu.sh"
source "${SCRIPT_DIR}/src/main/logic.sh"

trap 'error_handler $? $LINENO' ERR

main "$@"
