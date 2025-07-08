# Arquitetura e Estrutura do Projeto

> [Voltar para o README](../README.md)

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

## Decisões de Arquitetura

- Estrutura modular para fácil manutenção e expansão
- Scripts principais e módulos separados por responsabilidade
- Documentação detalhada em arquivos separados
- Suporte a automação e integração com ferramentas externas
