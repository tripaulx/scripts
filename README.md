# Automação Completa do Setup CapRover

Este repositório contém scripts para provisionamento, diagnóstico, limpeza e automação total da instalação do CapRover em servidores Debian 12+ (ou compatíveis).

## Fluxo Recomendado

1. **Preparação Inicial do Servidor**  
   Execute o script de preparação para garantir um sistema atualizado e pronto:
   ```bash
   sudo ./initial-setup-tripaulx.sh.sh
   ```
   > Dica: Este script pode incluir atualizações, timezone, swap, SSH seguro, etc.

2. **Setup Automatizado do CapRover**  
   Use o script principal para instalar, limpar ambiente Docker e configurar CapRover totalmente automatizado:
   ```bash
   export CAPROVER_ADMIN_PASS=suasenha
   export CAPROVER_ROOT_DOMAIN=seudominio.com
   export CAPROVER_ADMIN_EMAIL=seu@email.com
   sudo ./setup-caprover.sh --force
   ```
   - **--force**: Executa sem confirmações interativas (ideal para automação/CI).
   - As variáveis de ambiente permitem configurar domínio, senha e e-mail do admin automaticamente no wizard inicial via CLI.

## O que o setup-caprover.sh faz
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

---

Se precisar de exemplos avançados, integração com DNS, SSL, backups ou monitoramento, consulte as recomendações no topo do script principal ou peça suporte!

## Para Contribuidores
Consulte sempre o arquivo [AGENTS.md](./AGENTS.md) para seguir o padrão obrigatório de documentação, estrutura e mensagens em todos os scripts deste projeto.
