#!/bin/bash
# check-shell-scripts.sh
# Executa ShellCheck e shfmt em todos os scripts do projeto
# Uso: ./bin/check-shell-scripts.sh

set -e

# Rodar ShellCheck
if ! command -v shellcheck &>/dev/null; then
  echo "[ERRO] ShellCheck não está instalado. Instale com: brew install shellcheck ou sudo apt install shellcheck" >&2
  exit 1
fi

find . -type f -name '*.sh' -exec shellcheck --severity=style --color=always {} +

# Rodar shfmt (opcional, para padronizar formatação)
if command -v shfmt &>/dev/null; then
  find . -type f -name '*.sh' -exec shfmt -w -i 4 -ci {} +
else
  echo "[INFO] shfmt não encontrado. Instale com: brew install shfmt ou sudo apt install shfmt"
fi

echo "[OK] Todos os scripts verificados. Corrija qualquer erro apontado acima."
