# Automação CapRover & Setup 

> **Compatibilidade:**
> Scripts projetados e testados para **Debian 12+** e **macOS** apenas. Não há garantia de funcionamento em outras distribuições ou sistemas.

Este repositório contém scripts para provisionamento, diagnóstico, limpeza e automação total da instalação do CapRover em servidores Debian 12+ (ou compatíveis).

## Fluxo Recomendado

### Como usar

1. Clone este repositório:

```sh
git clone https://github.com/tripaulx/scripts.git
cd scripts
```

2. Permissão de execução (importante!)

Se ao rodar um script aparecer `Permission denied`, torne-o executável:

```sh
chmod +x *.sh
```

3. **Preparação Inicial do Servidor**  
   Execute o script de preparação para garantir um sistema atualizado e pronto:
   ```bash
   sudo ./initial-setup.sh
   ```
   > Dica: Este script pode incluir atualizações, timezone, swap, SSH seguro, etc.

4. **Validação pós-reboot**  
   Após reiniciar o servidor, valide se o ambiente está saudável:
   ```bash
   sudo ./validate-postreboot.sh
   ```
   > Esse script checa serviços essenciais, swap, espaço em disco, conectividade e recomenda snapshot/backup antes de rodar scripts destrutivos.

5. **Hardening de Segurança**  
   Execute o assistente interativo de hardening:
   ```bash
   sudo ./zerup-scurity-setup.sh
   ```
   > Configurações de segurança interativas, incluindo SSH, UFW, Fail2Ban e mais.

6. **Diagnóstico de Segurança (Opcional)**  
   Para verificar o estado de segurança sem fazer alterações:
   ```bash
   sudo ./zero-initial.sh
   ```
   > Apenas diagnóstico (não faz alterações) de portas abertas, configurações do SSH, UFW, etc.

6. **Setup Automatizado do CapRover**  
   Use o script principal para instalar, limpar ambiente Docker e configurar CapRover totalmente automatizado:
   ```bash
   export CAPROVER_ADMIN_PASS=suasenha
   export CAPROVER_ROOT_DOMAIN=seudominio.com
   export CAPROVER_ADMIN_EMAIL=seu@email.com
   sudo ./setup-caprover.sh --force
   ```
   - **--force**: Executa sem confirmações interativas (ideal para automação/CI).
   - As variáveis de ambiente permitem configurar domínio, senha e e-mail do admin automaticamente no wizard inicial via CLI.

## Scripts Principais

### zerup-scurity-setup.sh
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
sudo ./zerup-scurity-setup.sh
```

**Modo Não-Interativo (Avançado):**
```bash
# Modo não-interativo com parâmetros
sudo ./zerup-scurity-setup.sh --port=2222 --user=admin --non-interactive
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

### setup-caprover.sh
- Diagnóstico do sistema e Docker
- Backup e validação do volume `/captain`
- Limpeza agressiva de containers, volumes, redes e serviços Docker antigos
- Liberação e validação das portas críticas (80, 443, 3000, 996, 7946, 4789, 2377)
- Instala todas as dependências necessárias (Docker, Node.js, CLI CapRover, utilitários)
- Executa o container CapRover com as melhores práticas
- Automatiza o wizard inicial do CapRover via CLI (`caprover serversetup`)
- Diagnóstico pós-instalação, logs e troubleshooting automático

## Pré-requisitos
- Debian 12+ (bookworm) ou compatível
- Permissão root (sudo)
- Acesso à internet

## Variáveis de Ambiente Importantes
| Variável                 | Descrição                                    |
|-------------------------|-----------------------------------------------|
| CAPROVER_ADMIN_PASS     | Senha do admin CapRover (obrigatório)         |
| CAPROVER_ROOT_DOMAIN    | Domínio root do painel CapRover               |
| CAPROVER_ADMIN_EMAIL    | E-mail do admin CapRover                      |

> Se não definir, valores padrão seguros serão usados, mas recomenda-se sempre definir as suas variáveis.

## Troubleshooting
- O script faz diagnóstico automático se detectar falha na inicialização do CapRover (ex: tela 'firewall-passed').
- Logs detalhados são salvos em `install.log` e rotacionados.
- Checagem e correção automática de permissões do volume `/captain`.
- Mensagens claras orientam o usuário em caso de erro.

## Dicas para Automação/Infraestrutura como Código
- Integre estes scripts em pipelines CI/CD, Terraform, Ansible, etc.
- Use o modo `--force` e variáveis de ambiente para automação 100% sem interação manual.
- Scripts idempotentes: podem ser executados múltiplas vezes sem causar problemas.

## Referências
- [CapRover Documentação Oficial](https://caprover.com/docs/)
- [CapRover Troubleshooting](https://caprover.com/docs/troubleshooting.html)
- Scripts auxiliares: `validate-postreboot.sh` (diagnóstico pós-reboot), `zero-initial.sh` (hardening e diagnóstico de segurança)

---

Se precisar de exemplos avançados, integração com DNS, SSL, backups ou monitoramento, consulte as recomendações no topo do script principal ou peça suporte!

## Para Contribuidores
Consulte sempre o arquivo [AGENTS.md](./AGENTS.md) para seguir o padrão obrigatório de documentação, estrutura e mensagens em todos os scripts deste projeto.
