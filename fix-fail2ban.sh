#!/bin/bash
# Script para corrigir problemas comuns do Fail2Ban
# Uso: sudo ./fix-fail2ban.sh

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Iniciando correção do Fail2Ban ===${NC}"

# 1. Parar o serviço Fail2Ban
echo -e "\n${YELLOW}[1/6] Parando o serviço Fail2Ban...${NC}"
sudo systemctl stop fail2ban

# 2. Configurar o SSH para log apropriado
echo -e "\n${YELLOW}[2/6] Configurando logs do SSH...${NC}"
if ! grep -q "^SyslogFacility AUTH" /etc/ssh/sshd_config; then
    echo "SyslogFacility AUTH" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "LogLevel INFO" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo -e "${GREEN}✓ Configuração do SSH atualizada${NC}"
    sudo systemctl restart sshd
else
    echo -e "${GREEN}✓ Configuração do SSH já está correta${NC}"
fi

# 3. Criar configuração personalizada para o Fail2Ban
echo -e "\n${YELLOW}[3/6] Configurando o Fail2Ban...${NC}"
sudo bash -c 'cat > /etc/fail2ban/jail.d/sshd.conf' << 'EOL'
[sshd]
enabled = true
port = ssh
backend = auto
maxretry = 3
bantime = 1h
findtime = 600
ignoreip = 127.0.0.1/8 ::1
EOL

echo -e "${GREEN}✓ Configuração do Fail2Ban atualizada${NC}"

# 4. Verificar e corrigir permissões
echo -e "\n${YELLOW}[4/6] Verificando permissões...${NC}"
sudo chown -R root:root /etc/fail2ban
sudo chmod -R 755 /etc/fail2ban

# 5. Testar configuração
echo -e "\n${YELLOW}[5/6] Testando configuração do Fail2Ban...${NC}" 
if sudo fail2ban-client -t; then
    echo -e "${GREEN}✓ Configuração do Fail2Ban testada com sucesso${NC}"
else
    echo -e "${RED}✗ Erro na configuração do Fail2Ban${NC}"
    echo -e "${YELLOW}Verifique os logs com: sudo journalctl -u fail2ban${NC}"
    exit 1
fi

# 6. Iniciar o serviço
echo -e "\n${YELLOW}[6/6] Iniciando o serviço Fail2Ban...${NC}"
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Verificar status
if systemctl is-active --quiet fail2ban; then
    echo -e "\n${GREEN}✓ Fail2Ban está rodando com sucesso!${NC}"
    echo -e "\n${YELLOW}=== Status do Fail2Ban ===${NC}"
    sudo fail2ban-client status
    
    echo -e "\n${YELLOW}=== Status da prisão do SSH ===${NC}"
    if sudo fail2ban-client status sshd &>/dev/null; then
        sudo fail2ban-client status sshd
    else
        echo -e "${YELLOW}Aviso: A prisão do SSH não está ativa. Verifique os logs.${NC}"
    fi
else
    echo -e "\n${RED}✗ Falha ao iniciar o Fail2Ban${NC}"
    echo -e "\n${YELLOW}=== Últimas linhas do log do Fail2Ban ===${NC}"
    sudo journalctl -u fail2ban --no-pager -n 20
    exit 1
fi

echo -e "\n${GREEN}=== Correção concluída! ===${NC}"
echo "Para monitorar tentativas de acesso, use: sudo fail2ban-client status sshd"
echo "Para ver os IPs banidos, use: sudo fail2ban-client get sshd banned"
