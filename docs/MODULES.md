# Referência de Módulos e Scripts

> [Voltar para o README](../README.md)

Este documento lista todos os scripts e módulos do projeto, com uma breve descrição e referência de uso.

## bin/
- **setup**: Script principal de configuração inicial do servidor.
- **check-deps**: Verifica e instala dependências essenciais.
- **caprover/setup/**: Scripts para instalação e configuração do CapRover.
- **caprover/validate/**: Scripts para validação pós-instalação do CapRover.
- **security/harden/**: Scripts de hardening de segurança.
- **security/diagnose/**: Scripts de diagnóstico de segurança.

## core/
- **backup.sh**: Funções de backup e restauração.
- **security.sh**: Funções centrais de segurança.
- **utils.sh**: Utilitários compartilhados.
- **validations.sh**: Funções de validação de ambiente e dependências.

## modules/
- **fail2ban/**: Scripts para configuração e validação do Fail2Ban.
- **ssh/**: Scripts para configuração e validação do SSH.
- **ufw/**: Scripts para configuração e validação do UFW (firewall).

## tests/
- **run-tests.sh**: Executa todos os testes automatizados.
- **test-*.sh**: Testes unitários e de integração para módulos principais.

> Se algum script não estiver listado aqui, ele pode ser legado, experimental ou precisar de documentação. Scripts não documentados serão movidos para a pasta `archive/`.
