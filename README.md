# Gerenciamento de Servidor Debian 12

> **ATENÇÃO:**
> Este arquivo excede o limite de 600 linhas definido no STYLE_GUIDE.md.
> Modularize e divida em múltiplos arquivos menores o quanto antes.

---

## 📚 Documentação Principal

- [Onboarding](docs/ONBOARDING.md): Instalação e configuração inicial
- [Uso Avançado](docs/USAGE.md): Comandos, automação e exemplos
- [Troubleshooting & FAQ](docs/TROUBLESHOOTING.md): Problemas comuns e soluções
- [Arquitetura](docs/ARCHITECTURE.md): Estrutura do projeto e decisões de design
- [Práticas de Segurança](docs/SECURITY.md): Hardening, auditoria e recomendações
- [Requisitos](docs/REQUIREMENTS.md): Dependências e compatibilidade
- [Contribuição](docs/CONTRIBUTING.md): Guia para contribuidores
- [Changelog](docs/CHANGELOG.md): Histórico de alterações
- [Roadmap](docs/ROADMAP.md): Planejamento futuro

---

> **Compatibilidade Exclusiva:**
> Scripts projetados e testados especificamente para **Debian 12 (Bookworm)**. 
> ⚠️ Não há suporte para outras versões ou distribuições.

Este repositório contém um conjunto de scripts modulares para gerenciamento de servidores Debian 12, com foco em:
- 🔒 **Segurança**: Hardening, auditoria e monitoramento
- 🐋 **CapRover**: Instalação e gerenciamento
- ⚙️ **Configuração**: Automação de tarefas comuns
- 🛡️ **Proteção**: Firewall, Fail2Ban e mais

## 🏗️ Estrutura do Projeto

```
.
├── bin/                    # Scripts executáveis
│   ├── caprover/          # Comandos do CapRover
│   │   ├── setup          # Instalação do CapRover
│   │   └── validate       # Validação da instalação
│   └── security/          # Comandos de segurança
│       ├── setup          # Configuração inicial
│       ├── harden         # Hardening do sistema
│       └── diagnose       # Diagnóstico de segurança
├── core/                  # Bibliotecas principais
├── docs/                  # Documentação detalhada
├── modules/               # Módulos de funcionalidades
├── tests/                 # Testes automatizados
├── main.sh                # Interface principal
├── setup -> bin/setup     # Configuração inicial
├── harden -> bin/security/harden  # Hardening de segurança
├── diagnose -> bin/security/diagnose  # Diagnóstico
├── caprover-setup -> bin/caprover/setup  # Instalação do CapRover
└── caprover-validate -> bin/caprover/validate  # Validação
```

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

## 🛠️ Recursos Principais

### 🔒 Segurança
- Hardening de sistema
- Configuração segura de SSH
- Firewall UFW
- Proteção Fail2Ban
- Auditoria de segurança

### 🐋 CapRover
- Instalação automatizada
- Validação de ambiente
- Gerenciamento de apps
- Backup e restauração

### ⚙️ Sistema
- Atualizações automáticas
- Monitoramento
- Logs centralizados
- Backup de configurações

## 🔄 Atualizações

Para atualizar para a versão mais recente:
```bash
git pull origin main
```

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor, leia nosso [Guia de Contribuição](docs/CONTRIBUTING.md) para começar.

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

### Verificação de Dependências

Para verificar automaticamente se todas as dependências necessárias estão instaladas, execute:

```bash
chmod +x check-dependencies.sh
./check-dependencies.sh
```

Consulte o arquivo [REQUIREMENTS.md](docs/REQUIREMENTS.md) para informações detalhadas sobre cada dependência e instruções de instalação específicas para diferentes distribuições.


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

3. **Executando o Script Principal**
   
   O script principal oferece uma interface interativa para gerenciar todas as funcionalidades:
   
   ```bash
   # Executar o script principal
   sudo ./main.sh
   ```
   
   O menu principal oferece as seguintes opções:
   - 🔒 Executar Hardening Completo
   - ⚙️  Configurar Módulos Individuais
   - 📊 Gerar Relatório de Segurança
   - 🔄 Reverter Alterações (Rollback)
   - 🛠️  Ferramentas Avançadas
   - 🚪 Sair

4. **Preparação Inicial do Servidor**  
   Execute o script de preparação para garantir um sistema atualizado e pronto:
   ```bash
   sudo ./setup
   ```
   > Dica: Este script pode incluir atualizações, timezone, swap, SSH seguro, etc.

5. **Validação pós-reboot**  
   Após reiniciar o servidor, valide se o ambiente está saudável:
   ```bash
   sudo ./caprover-validate/validate-postreboot.sh
   ```
   > Esse script checa serviços essenciais, swap, espaço em disco, conectividade e recomenda snapshot/backup antes de rodar scripts destrutivos.

6. **Hardening de Segurança**  
   Execute o assistente interativo de hardening:
   ```bash
   sudo ./harden/zerup-scurity-setup.sh
   ```
   > Configurações de segurança interativas, incluindo SSH, UFW, Fail2Ban e mais.

7. **Diagnóstico de Segurança (Opcional)**  
   Para verificar o estado de segurança sem fazer alterações:
   ```bash
   sudo ./diagnose/zero-initial.sh
   ```
   > Apenas diagnóstico (não faz alterações) de portas abertas, configurações do SSH, UFW, etc.

8. **Setup Automatizado do CapRover**  
   Use o script principal para instalar, limpar ambiente Docker e configurar CapRover totalmente automatizado:
   ```bash
   export CAPROVER_ADMIN_PASS=suasenha
   export CAPROVER_ROOT_DOMAIN=seudominio.com
   export CAPROVER_ADMIN_EMAIL=seu@email.com
   sudo ./caprover-setup/setup-caprover.sh --force
   ```
   - **--force**: Executa sem confirmações interativas (ideal para automação/CI).
   - As variáveis de ambiente permitem configurar domínio, senha e e-mail do admin automaticamente no wizard inicial via CLI.

## 🚀 Quick Start (Após Clonar)

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

## Módulos Principais

### main.sh

O script principal que oferece uma interface interativa para gerenciar todas as funcionalidades de segurança e configuração do servidor.

**Funcionalidades principais:**
- Interface de menu interativa
- Execução de hardening completo ou por módulos individuais
- Geração de relatórios de segurança
- Ferramentas avançadas para diagnóstico e solução de problemas
- Sistema de rollback para reverter alterações

**Uso básico:**
```bash
# Modo interativo
sudo ./main.sh

# Ajuda
sudo ./main.sh --help
```

### Scripts de Uso Específico

#### zerup-scurity-setup.sh
Script interativo de hardening de segurança completo que implementa as melhores práticas para servidores Linux em produção, com confirmação em cada etapa.

**Funcionalidades principais:**
- 🔒 **SSH Seguro**
  - Troca interativa da porta SSH (sugere porta aleatória)
  - Desativação segura do login root (verifica usuário alternativo)
  - Configuração de autenticação por chave
  - Timeouts e limitações de tentativas de login

- 🛡️ **Firewall (UFW)**
  - Configuração interativa de regras restritivas
  - Abertura apenas das portas necessárias (SSH, HTTP, HTTPS)
  - Ativação de logging
  - Instalação opcional do UFW se não estiver presente

- 🛑 **Proteção contra Ataques**
  - Instalação e configuração interativa do Fail2Ban
  - Proteção contra força bruta
  - Configurações personalizadas de banimento
  - Instalação opcional se não estiver presente

- 🔍 **Validações de Segurança**
  - Verificação de usuários não-root antes de desabilitar root
  - Backup automático de arquivos de configuração
  - Prevenção contra bloqueio acidental
  - Validação de dependências

- 🔄 **Manutenção**
  - Atualizações automáticas de segurança (opcional)
  - Limpeza de pacotes desnecessários (opcional)
  - Relatório detalhado pós-instalação

**Uso Interativo (Recomendado):**
```bash
# Modo interativo (perguntará confirmação para cada etapa)
sudo ./harden/zerup-scurity-setup.sh
```

**Modo Não-Interativo (Avançado):**
```bash
# Modo não-interativo com parâmetros
sudo ./harden/zerup-scurity-setup.sh --port=2222 --user=admin --non-interactive
```

**Opções:**
- `--port=PORTA`: Especifica a porta SSH personalizada (padrão: aleatória)
- `--user=USUARIO`: Define o usuário para acesso SSH (opcional, será perguntado se não informado)
- `--non-interactive`: Executa sem confirmações (use com cautela)

**Fluxo Típico:**
1. Pergunta sobre atualização do sistema
2. Configuração do SSH com confirmação de porta e usuário
3. Configuração do UFW com opção de instalação
4. Configuração do Fail2Ban com opção de instalação
5. Atualizações automáticas (opcional)
6. Limpeza de sistema (opcional)
7. Relatório final detalhado

**Segurança:**
- Todas as alterações são confirmadas antes da execução
- Backups automáticos dos arquivos modificados
- Verificação de usuário alternativo antes de desabilitar root
- Log detalhado em `/var/log/zerup-security-*.log`

---

#### setup-caprover.sh
- Diagnóstico do sistema e Docker
- Backup e validação do volume `/captain`
- Limpeza agressiva de containers, volumes, redes e serviços Docker antigos
- Liberação e validação das portas críticas (80, 443, 3000, 996, 7946, 4789, 2377)
- Instala todas as dependências necessárias (Docker, Node.js, CLI CapRover, utilitários)
- Executa o container CapRover com as melhores práticas
- Automatiza o wizard inicial do CapRover via CLI (`caprover serversetup`)
- Diagnóstico pós-instalação, logs e troubleshooting automático

## Módulos de Segurança

### Módulo SSH
Configuração segura do servidor SSH, incluindo:
- Troca da porta padrão
- Desativação do login root
- Limitação de tentativas de login
- Autenticação por chaves

### Módulo UFW (Firewall)
Configuração do firewall não-complicado:
- Regras restritivas padrão
- Abertura apenas de portas necessárias
- Proteção contra varredura de portas
- Logging de tentativas de acesso

### Módulo Fail2Ban
Proteção contra força bruta:
- Detecção de tentativas de login
- Banimento automático de IPs maliciosos
- Proteção para serviços como SSH, Nginx, Apache
- Notificações por e-mail (opcional)

## Pré-requisitos
- Debian 12+ (bookworm) ou compatível
- Permissão root (sudo)
- Acesso à internet

## Variáveis de Ambiente Importantes

### Configuração do CapRover
| Variável                 | Descrição                                    |
|-------------------------|-----------------------------------------------|
| CAPROVER_ADMIN_PASS     | Senha do admin CapRover (obrigatório)         |
| CAPROVER_ROOT_DOMAIN    | Domínio root do painel CapRover               |
| CAPROVER_ADMIN_EMAIL    | E-mail do admin CapRover                      |

### Configurações de Segurança
| Variável                 | Descrição                                    |
|-------------------------|-----------------------------------------------|
| SSH_PORT               | Porta SSH personalizada (padrão: 22)          |
| UFW_ENABLE_LOGGING     | Habilitar logging do UFW (padrão: yes)        |
| FAIL2BAN_EMAIL        | E-mail para notificações do Fail2Ban          |

> Se não definir, valores padrão seguros serão usados, mas recomenda-se sempre definir as suas variáveis.

## Troubleshooting

### Problemas Comuns

#### Falha na Inicialização do CapRover
- Verifique os logs em tempo real: `docker service logs captain-captain --tail 100 --follow`
- Verifique se todas as portas necessárias estão abertas: `sudo netstat -tuln`
- Confirme se o domínio está apontando para o IP correto

#### Problemas de Conexão SSH
- Verifique se o serviço SSH está rodando: `sudo systemctl status ssh`
- Confirme se a porta SSH está aberta no firewall: `sudo ufw status`
- Verifique se o IP não está bloqueado pelo Fail2Ban: `sudo fail2ban-client status`

#### Logs Importantes
- Logs do sistema: `/var/log/syslog`
- Logs de autenticação: `/var/log/auth.log`
- Logs do Docker: `journalctl -u docker.service`
- Logs do CapRover: `docker service logs captain-captain`
- Logs do UFW: `journalctl -u ufw`
- Logs do Fail2Ban: `journalctl -u fail2ban`

### Ferramentas de Diagnóstico

O script principal inclui ferramentas avançadas para diagnóstico:

1. **Verificar Portas Abertas**
   - Lista todas as portas em uso e por quais processos

2. **Verificar Logs do Sistema**
   - Acesso rápido aos logs de sistema, autenticação e serviços

3. **Testar Configuração de Segurança**
   - Verifica a configuração de todos os módulos de segurança
   - Gera relatório detalhado de possíveis problemas

4. **Atualizar Scripts**
   - Verifica e aplica atualizações dos scripts

### Mensagens de Erro Comuns

1. **"Porta já em uso"**
   - Solução: Use `lsof -i :PORTA` para identificar o processo e encerrá-lo ou escolha outra porta.

2. **"Permissão negada"**
   - Solução: Execute o script com `sudo` ou como usuário root.

3. **Falha no Fail2Ban**
   - Verifique se há erros de configuração: `sudo fail2ban-client -x -f start`
   - Confirme se os arquivos de log estão acessíveis

4. **Problemas com UFW**
   - Verifique se o UFW está ativo: `sudo ufw status`
   - Se necessário, desative e reative: `sudo ufw disable && sudo ufw enable`

### Logs Detalhados
- Logs do script principal: `/var/log/security_hardening_*.log`
- Logs de instalação do CapRover: `install.log`
- Backups de configurações: `/var/backups/security/`

### Recuperação de Desastres

#### Rollback de Configurações
O sistema mantém backups automáticos das configurações alteradas. Para reverter:

1. Acesse o menu principal: `sudo ./main.sh`
2. Selecione a opção "Reverter Alterações (Rollback)"
3. Escolha o backup desejado

#### Recuperação de Acesso SSH
Se você perdeu o acesso SSH:

1. Acesse o servidor via console (KVM, VNC, IPMI, etc.)
2. Faça login como root
3. Verifique o status do serviço SSH: `systemctl status ssh`
4. Verifique as regras de firewall: `ufw status`
5. Verifique se o Fail2Ban não está bloqueando seu IP: `fail2ban-client status`
6. Se necessário, restaure o acesso temporariamente:
   ```bash
   ufw allow 22/tcp
   fail2ban-client set sshd unbanip SEU_IP
   systemctl restart ssh
   ```

#### Restauração do CapRover
Se o painel do CapRover não estiver acessível:

1. Verifique os logs do serviço: `docker service logs captain-captain`
2. Verifique se os containers estão rodando: `docker ps -a`
3. Se necessário, reinicie o serviço:
   ```bash
   docker service scale captain-captain=0
   docker service scale captain-captain=1
   ```
4. Verifique o status do cluster Docker: `docker node ls`

### Suporte Adicional

Para suporte adicional, consulte:
- [Documentação do CapRover](https://caprover.com/docs/)
- [Documentação do UFW](https://help.ubuntu.com/community/UFW)
- [Documentação do Fail2Ban](https://www.fail2ban.org/wiki/index.php/Main_Page)

Se o problema persistir, colete as seguintes informações antes de entrar em contato com o suporte:
1. Saída de `uname -a`
2. Versão do Docker: `docker --version`
3. Logs relevantes (conforme listado acima)
4. Comportamento esperado vs. comportamento observado

## Automação e Infraestrutura como Código

### Integração com Ferramentas de Automação

#### Ansible
```yaml
- name: Executar hardening de segurança
  hosts: all
  become: yes
  tasks:
    - name: Copiar scripts para o servidor
      copy:
        src: ./
        dest: /opt/security-scripts
        mode: '0755'
    
    - name: Executar hardening
      command: /opt/security-scripts/main.sh --non-interactive
      environment:
        SSH_PORT: "{{ ssh_port }}"
        UFW_ENABLE_LOGGING: "yes"
```

#### Terraform
```hcl
resource "null_resource" "server_hardening" {
  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/tripaulx/scripts.git /tmp/security-scripts",
      "chmod +x /tmp/security-scripts/*.sh",
      "sudo /tmp/security-scripts/main.sh --non-interactive"
    ]
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.server.public_ip
    }
  }
}
```

### Variáveis de Ambiente para Automação

Para execução não-interativa, você pode definir as seguintes variáveis de ambiente:

```bash
# Configurações básicas
SSH_PORT=2222
UFW_ENABLE_LOGGING=yes
FAIL2BAN_EMAIL=admin@example.com

# Configurações do CapRover
export CAPROVER_ADMIN_PASS=seupassword
export CAPROVER_ROOT_DOMAIN=meudominio.com
export CAPROVER_ADMIN_EMAIL=admin@meudominio.com

# Executar em modo não-interativo
./main.sh --non-interactive
```

### Boas Práticas para Automação

1. **Idempotência**: Todos os scripts podem ser executados múltiplas vezes sem efeitos colaterais indesejados.

2. **Logs Detalhados**: Logs são salvos em `/var/log/security_hardening_*.log` para auditoria.

3. **Backup Automático**: Configurações originais são salvas em `/var/backups/security/`.

4. **Saídas de Status**: Os scripts retornam códigos de saída apropriados para integração com ferramentas de CI/CD.

## Referências

### Documentação Oficial
- [CapRover Documentation](https://caprover.com/docs/)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Fail2Ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [OpenSSH Documentation](https://www.openssh.com/manual.html)

### Troubleshooting
- [CapRover Troubleshooting](https://caprover.com/docs/troubleshooting.html)
- [UFW Common Issues](https://help.ubuntu.com/community/UFW#Common_Issues)
- [Fail2Ban Troubleshooting](https://www.fail2ban.org/wiki/index.php/FAQ)

### Scripts Auxiliares
- `validate-postreboot.sh`: Diagnóstico pós-reinicialização
- `zero-initial.sh`: Diagnóstico de segurança
- `zerup-scurity-setup.sh`: Assistente de hardening
- `setup-caprover.sh`: Instalação automatizada do CapRover

## 📜 Histórico de Alterações

Para um registro detalhado de todas as alterações significativas feitas no projeto, consulte o [CHANGELOG.md](docs/CHANGELOG.md).

## Contribuição

### Padrões de Código
- Siga o [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` para verificar erros comuns
- Documente todas as funções com comentários claros

### Processo de Contribuição
1. Crie um fork do repositório
2. Crie uma branch para sua feature: `git checkout -b feature/nova-funcionalidade`
3. Faça commit das suas alterações: `git commit -m 'Adiciona nova funcionalidade'`
4. Push para a branch: `git push origin feature/nova-funcionalidade`
5. Abra um Pull Request

### Testes
Antes de enviar um PR, certifique-se de:
1. Executar todos os testes: `./run-tests.sh`
2. Verificar se o shellcheck não encontra erros: `shellcheck **/*.sh`
3. Atualizar a documentação conforme necessário

## Licença
Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## Agradecimentos
- Equipe do CapRover por uma ferramenta incrível
- Comunidade de código aberto por contribuições valiosas
- Todos os mantenedores e contribuidores ativos

---

Para suporte adicional, integração personalizada ou consultoria em segurança, entre em contato com nossa equipe.
