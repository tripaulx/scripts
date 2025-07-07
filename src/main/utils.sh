#!/bin/bash
########################################################################
# Nome do Arquivo: utils.sh
# Version:    1.0.0
# Date:       2025-07-07
# Author:     Equipe de Infraestrutura
#
# Descricao:
#   Funcoes utilitarias usadas pelo script principal.
########################################################################

error_handler() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "${COLOR_RED}Erro na linha ${line_no}. Codigo: ${exit_code}${COLOR_RESET}" >&2
    exit "${exit_code}"
}
