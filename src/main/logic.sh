#!/bin/bash
########################################################################
# Nome do Arquivo: logic.sh
# Version:    1.0.0
# Date:       2025-07-07
# Author:     Equipe de Infraestrutura
#
# Descricao:
#   Funcao principal que inicializa o sistema e exibe o menu.
########################################################################

main() {
    initialize
    while true; do
        show_menu
    done
}
