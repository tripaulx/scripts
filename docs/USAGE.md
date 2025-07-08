# Uso Avançado e Exemplos

> [Voltar para o README](../README.md)

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
sudo ./harden/zerup-scurity-setup.sh
```

**Modo Não-Interativo (Avançado):**
```bash
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
