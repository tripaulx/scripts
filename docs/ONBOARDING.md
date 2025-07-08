# Onboarding

> [Voltar para o README](../README.md)

## 🚀 Começando Rápido

### 1. Clone o repositório
```bash
git clone https://github.com/tripaulx/scripts.git
cd scripts
```

### 2. Dê permissão de execução
```bash
chmod +x main.sh setup harden diagnose caprover-*
```

### 3. Execute o menu principal
```bash
sudo ./main.sh
```

### 4. Ou use comandos diretos
- Configuração inicial: `sudo ./setup`
- Hardening de segurança: `sudo ./harden`
- Diagnóstico: `sudo ./diagnose`
- Instalar CapRover: `sudo ./caprover-setup`
- Validar instalação: `sudo ./caprover-validate`

## 📋 Requisitos do Sistema

- **Sistema Operacional**: Debian 12 (Bookworm)
- **Acesso**: root ou usuário com sudo
- **Conexão**: Internet estável
- **Mínimo**: 1GB RAM, 1 CPU, 10GB disco
- **Recomendado**: 4GB+ RAM, 2+ CPUs, 20GB+ disco

## 🛠 Instalação no Debian 12

1. **Atualize o sistema**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Clone o repositório**
   ```bash
   git clone https://github.com/tripaulx/scripts.git
   cd scripts
   ```

3. **Dê permissão de execução aos scripts**
   ```bash
   chmod +x *.sh
   ```

4. **Execute o script de verificação de dependências**
   ```bash
   sudo ./check-dependencies.sh
   ```
   > 💡 Este script irá instalar automaticamente todas as dependências necessárias no Debian 12.

5. **Executando o Script Principal**
   O script principal oferece uma interface interativa para gerenciar todas as funcionalidades:
   ```bash
   sudo ./main.sh
   ```

6. **Preparação Inicial do Servidor**
   Execute o script de preparação para garantir um sistema atualizado e pronto:
   ```bash
   sudo ./setup
   ```
   > Dica: Este script pode incluir atualizações, timezone, swap, SSH seguro, etc.

7. **Validação pós-reboot**
   Após reiniciar o servidor, valide se o ambiente está saudável:
   ```bash
   sudo ./caprover-validate/validate-postreboot.sh
   ```
   > Esse script checa serviços essenciais, swap, espaço em disco, conectividade e recomenda snapshot/backup antes de rodar scripts destrutivos.

8. **Hardening de Segurança**
   Execute o assistente interativo de hardening:
   ```bash
   sudo ./harden/zerup-scurity-setup.sh
   ```
   > Configurações de segurança interativas, incluindo SSH, UFW, Fail2Ban e mais.

9. **Diagnóstico de Segurança (Opcional)**
   Para verificar o estado de segurança sem fazer alterações:
   ```bash
   sudo ./diagnose/zero-initial.sh
   ```
   > Apenas diagnóstico (não faz alterações) de portas abertas, configurações do SSH, UFW, etc.

10. **Setup Automatizado do CapRover**
    Use o script principal para instalar, limpar ambiente Docker e configurar CapRover totalmente automatizado:
    ```bash
    export CAPROVER_ADMIN_PASS=suasenha
    export CAPROVER_ROOT_DOMAIN=seudominio.com
    export CAPROVER_ADMIN_EMAIL=seu@email.com
    sudo ./caprover-setup/setup-caprover.sh --force
    ```
    - **--force**: Executa sem confirmações interativas (ideal para automação/CI).
    - As variáveis de ambiente permitem configurar domínio, senha e e-mail do admin automaticamente no wizard inicial via CLI.

## Quick Start (Após Clonar)

1. **Torne todos os scripts executáveis:**
   ```bash
   bash post-clone-setup.sh
   ```
   > Isso garante que todos os scripts .sh tenham permissão de execução, mesmo em novos clones.

2. **Verifique dependências:**
   ```bash
   ./bin/check-deps
   ```

3. **Requisito de Bash:**
   > Todos os scripts requerem **Bash 4.0+**. No macOS, instale com `brew install bash` e execute scripts com `/usr/local/bin/bash script.sh`.
