# Estratégia de Testes

> [Voltar para o README](../README.md)

Este documento explica como rodar os testes, o que cada teste cobre e boas práticas para garantir a qualidade do projeto.

## Como Executar os Testes

```bash
./tests/run-tests.sh
```

## Estrutura dos Testes

- **test-common.sh**: Testes de funções utilitárias comuns.
- **test-fail2ban-config.sh**: Testes de configuração do Fail2Ban.
- **test-ssh-config.sh**: Testes de configuração do SSH.
- **test-utils.sh**: Testes de utilitários do core.
- **test-validations.sh**: Testes de validações de ambiente e dependências.

## Boas Práticas
- Escreva testes para cada novo módulo ou função.
- Use nomes descritivos para scripts de teste.
- Mantenha os testes atualizados conforme o código evolui.
- Use `shellcheck` para garantir a qualidade dos scripts.
