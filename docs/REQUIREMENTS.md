# Requisitos do Sistema

Este documento descreve as dependências necessárias para executar os scripts de segurança e automação deste repositório.

## Dependências Principais

### Para todos os scripts
- **Bash 4.0+** - Shell padrão para execução dos scripts
- **GNU Core Utilities** - Utilitários básicos do sistema (grep, sed, awk, etc.)
- **sudo** - Para execução de comandos com privilégios elevados
- **curl** - Para download de arquivos e verificação de conectividade
- **jq** - Para processamento de JSON

### Para módulos específicos

#### Módulo UFW (Uncomplicated Firewall)
- **ufw** - Ferramenta de firewall simplificada
  - Ubuntu/Debian: `sudo apt install ufw`
  - CentOS/RHEL: `sudo yum install ufw`

#### Módulo Fail2Ban
- **fail2ban** - Prevenção contra força bruta
  - Ubuntu/Debian: `sudo apt install fail2ban`
  - CentOS/RHEL: `sudo yum install fail2ban`

#### Módulo Docker
- **Docker** - Para execução de contêineres
  - Instruções de instalação: https://docs.docker.com/engine/install/

#### Módulo SSH
- **OpenSSH Server** - Para gerenciamento remoto seguro
  - Ubuntu/Debian: `sudo apt install openssh-server`
  - CentOS/RHEL: `sudo yum install openssh-server`

## Verificação de Dependências

O script `check-dependencies.sh` pode ser usado para verificar se todas as dependências necessárias estão instaladas:

```bash
./check-dependencies.sh
```

## Instalação Automática (Ubuntu/Debian)

Para instalar automaticamente todas as dependências em sistemas baseados em Debian/Ubuntu, execute:

```bash
sudo apt update && \
sudo apt install -y bash coreutils sudo curl jq ufw fail2ban docker.io openssh-server
```

## Notas de Compatibilidade

- Os scripts foram testados principalmente em **Debian 12+** e **Ubuntu 22.04+**
- Para outras distribuições Linux, alguns ajustes podem ser necessários
- Recomenda-se sempre executar os scripts em um ambiente de teste antes de usar em produção

## Solução de Problemas

### Erro: Comando não encontrado
Se encontrar erros como "comando não encontrado", verifique se o pacote correspondente está instalado e no PATH do sistema.

### Erro: Permissão negada
Certifique-se de que o usuário tem permissões de superusuário (sudo) para executar os comandos necessários.

### Erro: Versão incompatível
Alguns scripts podem exigir versões específicas das dependências. Consulte a documentação de cada módulo para requisitos detalhados.
