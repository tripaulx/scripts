# Práticas de Segurança

> [Voltar para o README](../README.md)

## Práticas de Hardening e Auditoria

- Hardening de sistema
- Configuração segura de SSH
- Firewall UFW
- Proteção Fail2Ban
- Auditoria de segurança
- Backup automático de configurações
- Logs detalhados para auditoria

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
