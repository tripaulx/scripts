# Script de Configuração de Segurança

Este é um conjunto de scripts para configuração e endurecimento de segurança em servidores Debian/Ubuntu. O projeto foi projetado para ser modular, permitindo a execução de componentes individuais ou o sistema completo de forma integrada.

## 📋 Visão Geral

Este projeto oferece uma solução completa para endurecimento de segurança em servidores Linux, com foco em ambientes Debian/Ubuntu. Os recursos incluem:

- 🔒 Configuração segura de serviços essenciais (SSH, Firewall, etc.)
- 🔍 Verificação e instalação automática de dependências
- 🧪 Testes automatizados em containers isolados
- 📊 Logs detalhados e relatórios de execução
- 🔄 Suporte a modo de simulação (dry-run)

## 🚀 Novas Funcionalidades

- **Verificação de Dependências Automática** - Verifica e instala automaticamente todas as dependências necessárias
- **Ambiente de Teste Isolado** - Execute testes em containers Docker limpos
- **Logs Aprimorados** - Registro detalhado de todas as operações
- **Validação de Ambiente** - Verifica pré-requisitos antes da execução

## 🗂️ Estrutura do Projeto

```
src/security/
├── core/
│   ├── security_utils.sh      # Funções utilitárias compartilhadas
│   └── check_dependencies.sh  # Verificação de dependências do sistema
├── modules/
│   ├── ssh/                   # Módulo SSH
│   │   ├── configure_ssh.sh   # Script principal de configuração
│   │   └── ssh_utils.sh       # Funções auxiliares do SSH
│   │
│   ├── firewall/              # Módulo de Firewall (UFW)
│   │   ├── configure_ufw.sh   # Script principal de configuração
│   │   └── ufw_utils.sh       # Funções auxiliares do UFW
│   │
│   ├── fail2ban/              # Módulo Fail2Ban
│   │   ├── configure_fail2ban.sh  # Script principal de configuração
│   │   └── fail2ban_utils.sh      # Funções auxiliares do Fail2Ban
│   │
│   ├── users/                 # Módulo de Gerenciamento de Usuários
│   │   ├── configure_users.sh # Script principal de configuração
│   │   └── user_utils.sh      # Funções auxiliares de usuários
│   │
│   └── updates/               # Módulo de Atualizações
│       ├── configure_updates.sh  # Script principal de configuração
│       └── update_utils.sh    # Funções auxiliares de atualizações
│
├── security_setup.sh          # Script principal de orquestração
├── init_environment.sh        # Inicialização do ambiente
├── run_tests.sh               # Script de testes automatizados
└── README.md                  # Este arquivo
```

## Requisitos

- Sistema operacional: Debian 11/12, Ubuntu 20.04/22.04
- Acesso root ou permissões de superusuário (sudo)
- Bash 4.0 ou superior

## 🛠️ Instalação

1. **Pré-requisitos**:
   - Docker (para testes automatizados)
   - Git
   - Acesso root ou sudo

2. Clone o repositório:
   ```bash
   git clone <repositório>
   cd scripts/src/security
   ```

3. Torne os scripts executáveis:
   ```bash
   chmod +x security_setup.sh
   chmod +x modules/*/configure_*.sh
   ```

## Uso

### Script Principal (security_setup.sh)

O script principal `security_setup.sh` permite executar todos os módulos ou módulos específicos:

```bash
# Executar todos os módulos
./security_setup.sh --all

# Executar módulos específicos
./security_setup.sh --ssh --firewall --fail2ban

# Modo de simulação (não faz alterações reais)
./security_setup.sh --all --dry-run

# Ajuda
./security_setup.sh --help
```

### Módulos Individuais

Cada módulo pode ser executado individualmente:

#### SSH
```bash
./modules/ssh/configure_ssh.sh [opções]
```

#### Firewall (UFW)
```bash
./modules/firewall/configure_ufw.sh [opções]
```

#### Fail2Ban
```bash
./modules/fail2ban/configure_fail2ban.sh [opções]
```

#### Gerenciamento de Usuários
```bash
./modules/users/configure_users.sh [opções]
```

#### Atualizações do Sistema
```bash
./modules/updates/configure_updates.sh [opções]
```

## Opções Comuns

A maioria dos módulos suporta as seguintes opções:

- `--dry-run`: Simula as operações sem fazer alterações reais
- `--help`: Exibe a ajuda do módulo

## Logs

Os logs são exibidos no console com diferentes níveis de severidade:
- `[INFO]`: Mensagens informativas
- `[SUCCESS]`: Operações concluídas com sucesso
- `[WARNING]`: Avisos que não impedem a execução
- `[ERROR]`: Erros que podem impedir a conclusão da operação

## Melhores Práticas

1. **Faça backup** do sistema antes de executar os scripts
2. Teste em um ambiente de desenvolvimento antes de usar em produção
3. Use `--dry-run` para ver o que será feito antes de fazer alterações reais
4. Revise as configurações geradas após a execução

## Contribuição

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/meu-recurso`)
3. Commit suas alterações (`git commit -am 'Adiciona novo recurso'`)
4. Push para a branch (`git push origin feature/meu-recurso`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Contato

Equipe de Segurança - [email@exemplo.com](mailto:email@exemplo.com)

### 🚦 Uso Básico

### Execução Padrão

Para executar todos os módulos de segurança com verificação de dependências:

```bash
# Inicializar ambiente (opcional, mas recomendado)
source init_environment.sh --verbose

# Executar todos os módulos
sudo ./security_setup.sh --all --check-deps
```

### Execução de Módulos Específicos

```bash
# Apenas SSH e Firewall com verificação de dependências
sudo ./security_setup.sh --ssh --firewall --check-deps

# Modo de simulação (não faz alterações reais)
sudo ./security_setup.sh --all --dry-run
```

### Testes Automatizados

Para executar os testes em um container Docker limpo:

```bash
# Executar testes básicos
./run_tests.sh

# Executar testes e limpar recursos após a conclusão
./run_tests.sh --clean

# Modo verboso para depuração
./run_tests.sh --verbose
```

## 🔍 Verificação de Dependências

O script `check_dependencies.sh` verifica e instala automaticamente as dependências necessárias:

```bash
# Verificar dependências sem instalar
./core/check_dependencies.sh --list

# Verificar e instalar dependências
sudo ./core/check_dependencies.sh --install
```

## 📊 Logs e Depuração

- **Logs principais**: `/var/log/security_setup_*.log`
- **Logs de módulos individuais**: `/var/log/security_<módulo>_*.log`
- **Modo verboso**: Adicione `--verbose` aos scripts
- **Modo dry-run**: Adicione `--dry-run` para simular sem fazer alterações reais

## 🐛 Solução de Problemas

### Problemas Comuns

1. **Falha de permissão**:
   ```bash
   sudo chmod +x *.sh
   sudo chmod +x core/*.sh
   ```

2. **Dependências ausentes**:
   ```bash
   sudo apt-get update
   sudo ./core/check_dependencies.sh --install
   ```

3. **Erros no Docker**:
   - Verifique se o Docker está em execução: `sudo systemctl status docker`
   - Se necessário, inicie o Docker: `sudo systemctl start docker`

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor, siga estes passos:

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Faça commit das suas alterações (`git commit -am 'Adiciona nova feature'`)
4. Faça push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 📞 Suporte

Para suporte, por favor abra uma issue no repositório ou entre em contato com a equipe de segurança.

---

<div align="center">
  <p>Feito com ❤️ pela Equipe de Segurança</p>
  <p>Última atualização: Julho de 2025</p>
</div>
