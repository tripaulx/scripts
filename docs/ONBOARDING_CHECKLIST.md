# 📋 Checklist de Onboarding

Este guia fornece um fluxo de trabalho passo a passo para configurar um novo servidor com segurança usando os scripts deste repositório.

## 🔄 Fluxo de Trabalho Recomendado

### 1. Pré-requisitos Iniciais
- [ ] Acessar o servidor como usuário com privilégios de superusuário (root ou com sudo)
- [ ] Atualizar o sistema operacional: `apt update && apt upgrade -y`
- [ ] Instalar o Git: `apt install -y git`

### 2. Clonar o Repositório
```bash
git clone https://github.com/seu-usuario/scripts.git /opt/security-scripts
cd /opt/security-scripts
```

### 3. Verificar Dependências
```bash
chmod +x check-dependencies.sh
./check-dependencies.sh
```

### 4. Configuração Inicial
- [ ] Revisar e configurar as variáveis de ambiente em `.env` (se necessário)
- [ ] Tornar os scripts executáveis: `chmod +x *.sh`

### 5. Executar o Script Principal
```bash
./main.sh
```

## 🚀 Fluxo de Trabalho Detalhado

### 1. Primeiro Acesso ao Servidor
1. Faça login como root ou um usuário com privilégios sudo
2. Atualize os pacotes do sistema:
   ```bash
   apt update && apt upgrade -y
   ```
3. Instale o Git (se ainda não estiver instalado):
   ```bash
   apt install -y git
   ```

### 2. Obtenção dos Scripts
1. Clone o repositório para um local apropriado:
   ```bash
   git clone https://github.com/seu-usuario/scripts.git /opt/security-scripts
   cd /opt/security-scripts
   ```

### 3. Verificação do Ambiente
1. Execute o script de verificação de dependências:
   ```bash
   chmod +x check-dependencies.sh
   ./check-dependencies.sh
   ```
2. Instale quaisquer dependências ausentes conforme indicado pelo script

### 4. Configuração
1. Revise e edite o arquivo `.env` se necessário:
   ```bash
   cp .env.example .env
   nano .env  # ou seu editor preferido
   ```
2. Torne os scripts executáveis:
   ```bash
   chmod +x *.sh
   chmod +x core/*.sh
   chmod +x modules/*/*.sh
   ```

### 5. Execução
1. Inicie o script principal:
   ```bash
   ./main.sh
   ```
2. Siga o menu interativo para executar as operações desejadas
3. Para automação, consulte a seção de [Uso Avançado](#-uso-avançado) no README

## 🔄 Uso Avançado

### Execução Não-Interativa
Para automação, você pode passar argumentos diretamente para o script principal:

```bash
# Executar hardening completo de forma não-interativa
./main.sh --full-harden --non-interactive

# Apenas configurar o firewall
./main.sh --module ufw --action configure
```

### Variáveis de Ambiente
Você pode configurar o comportamento dos scripts usando variáveis de ambiente. Consulte o arquivo `.env.example` para opções disponíveis.

## 🔍 Solução de Problemas

### Erros Comuns
1. **Permissão negada**: Certifique-se de que os scripts têm permissão de execução (`chmod +x`)
2. **Comando não encontrado**: Verifique se todas as dependências estão instaladas
3. **Erros de sintaxe**: Verifique se você está usando Bash 4.0 ou superior

### Obtendo Ajuda
- Consulte o arquivo [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para soluções de problemas comuns
- Verifique os logs em `/var/log/security-scripts/` para mensagens de erro detalhadas

## 🔒 Próximos Passos

Após a configuração inicial, considere:
1. Configurar backup automático
2. Implementar monitoramento
3. Agendar verificações de segurança regulares
4. Revisar logs periodicamente

---

📌 **Nota**: Sempre teste as configurações em um ambiente de teste antes de aplicar em produção.
