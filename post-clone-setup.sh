#!/bin/bash
# post-clone-setup.sh
# Torna todos os scripts .sh executáveis após o clone do repositório
# Uso: bash post-clone-setup.sh

find . -type f -name '*.sh' -exec chmod +x {} +
echo "Permissões de execução aplicadas a todos os scripts .sh."
