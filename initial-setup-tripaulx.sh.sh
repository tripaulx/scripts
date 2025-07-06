#!/bin/bash
########################################################################
# Script Name: initial-setup-tripaulx.sh.sh
# Version:    1.0.0
# Date:       2025-07-06
# Author:     Flavius
#
# Description:
#   Prepara servidores Debian 12+ para produção: atualiza sistema,
#   configura timezone, locale, swap, segurança básica, utilitários,
#   instala Docker, Node.js, npm e CapRover CLI.
#
# Usage:
#   sudo ./initial-setup-tripaulx.sh.sh
#
# Exit codes:
#   0 - Sucesso completo
#   1 - Falha crítica (permissão, erro de rede, dependência, etc)
#
# Prerequisites:
#   - Debian 12+ (bookworm) ou compatível
#   - Permissão root
#   - Acesso à internet
#
# Steps performed by this script:
#   1. Atualização completa do sistema
#   2. Configuração de timezone e locale
#   3. Instalação de pacotes essenciais e utilitários
#   4. Ativação de UFW e Fail2Ban
#   5. Criação de swap (opcional)
#   6. Instalação do Docker Engine
#   7. Instalação do Node.js, npm e CapRover CLI
#   8. Exibição de informações rápidas do sistema
#
# See Also:
#   - https://caprover.com/docs/
#   - AGENTS.md (padrão de scripts)
########################################################################

set -e  # Encerra ao primeiro erro

echo "⏳ Atualizando sistema..."
apt update && apt upgrade -y && apt autoremove -y && apt clean

echo "🌐 Definindo fuso horário..."
timedatectl set-timezone America/Sao_Paulo

echo "🗣️ Corrigindo e padronizando locale (en_US.UTF-8)..."
apt install --reinstall locales -y

# Gera apenas o locale necessário
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

# Define como padrão no sistema (sem LC_ALL!)
echo 'LANG="en_US.UTF-8"
LANGUAGE="en_US"' > /etc/default/locale

# Checa e ajusta o locale do ambiente atual apenas se necessário
CURRENT_LANG=$(locale | grep '^LANG=' | cut -d= -f2)
if [[ "$CURRENT_LANG" != "en_US.UTF-8" ]]; then
  echo "🌎 Locale atual: $CURRENT_LANG. Ajustando para en_US.UTF-8..."
  unset LANG LC_ALL LC_CTYPE LANGUAGE
  export LANG="en_US.UTF-8"
  export LANGUAGE="en_US"
  echo "✅ Ambiente exportado com LANG=en_US.UTF-8 e LANGUAGE=en_US."
else
  echo "🌎 Locale do ambiente já está correto: $CURRENT_LANG"
fi

echo "🧱 Instalando pacotes essenciais..."
apt install -y curl ca-certificates gnupg lsb-release \
    software-properties-common apt-transport-https

echo "🔒 Ativando segurança básica com UFW e Fail2Ban..."
apt install -y ufw fail2ban
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80,443/tcp
ufw --force enable
systemctl enable fail2ban
systemctl start fail2ban

echo ""
# Bloco opcional: Criação de swap (recomendado para servidores cloud pequenos)
if ! swapon --show | grep -q "/swapfile"; then
  echo "💾 Criando swapfile de 2GB..."
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "✅ Swap ativada."
else
  echo "ℹ️ Swap já está ativa."
fi

echo "🛠️ Instalando utilitários extras (htop, vim, wget, git, unzip)..."
apt install -y htop vim wget git unzip

echo "💡 Informações rápidas do sistema:"
df -hT | grep -v tmpfs
ip -o -4 addr show | awk '{print $2, $4}'

# Hardening SSH (opcional):
# echo "🔒 Realizando hardening básico do SSH..."
# sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
# sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
# systemctl reload sshd
# echo "⚠️ Lembre-se de ajustar o acesso SSH antes de desconectar!"

echo "✅ Configuração inicial concluída com sucesso!"
# Instalação do Docker Engine
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Instalando Docker Engine..."
  apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "✅ Docker Engine instalado."
else
  echo "🐳 Docker Engine já está instalado."
fi

# Instalação do Node.js e npm (necessários para CapRover CLI)
if ! command -v node >/dev/null 2>&1; then
  echo "⬢ Instalando Node.js (v20.x)..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "⬢ Instalando npm..."
  apt-get install -y npm
fi

# Instalação do CapRover CLI
echo "🚢 Instalando CapRover CLI (npm install -g caprover)..."
npm install -g caprover

echo "📌 Recomendo reiniciar agora com: reboot"