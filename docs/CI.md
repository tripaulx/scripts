# Integração Contínua (CI) e Automação

> [Voltar para o README](../README.md)

Este documento explica como funciona a automação, testes e integração contínua do projeto.

## CI com GitHub Actions
- Todos os pushes e pull requests executam testes automatizados e lint dos scripts.
- O workflow está definido em `.github/workflows/ci.yml`.
- O merge é bloqueado se houver falhas nos testes ou lint.

## Como rodar localmente

```bash
./tests/run-tests.sh
shellcheck **/*.sh
```

## Boas práticas
- Sempre escreva testes para novos scripts.
- Use `shellcheck` antes de commitar.
- Mantenha a cobertura de testes alta.
