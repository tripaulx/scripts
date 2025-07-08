# Guia de Padrão de Documentação e Estrutura de Scripts

> **ATENÇÃO:**
> Este projeto segue o [Unified Development and Operations Guide](../STYLE_GUIDE.md) com regras rígidas de estilo, tamanho e modularização para scripts, Python e documentação.
>
> **Limites obrigatórios:**
> - **Shell scripts e arquivos Markdown:**
>   - Máximo: **600 linhas** (refatoração obrigatória se exceder)
>   - Refatorar a partir de 400 linhas
>   - Chunks para IA: até 300 linhas
> - **Python:**
>   - Máximo: 500 linhas por arquivo
>   - Refatorar a partir de 300 linhas
>   - Chunks para IA: até 200 linhas
>
> **Markdowns extensos devem ser divididos em múltiplos arquivos.**
> Sempre mantenha documentação modular, clara e atualizada.
>
> Consulte o STYLE_GUIDE.md para detalhes e exemplos.
>
> **Arquivamento de scripts/documentação:**
> Scripts ou arquivos não documentados, obsoletos ou redundantes devem ser movidos para a pasta `archive/` (em vez de serem deletados diretamente). Documente o motivo do arquivamento em um README dentro de `archive/`.

---

## Navegação
- [Módulos e Scripts](MODULES.md)
- [Testes](TESTS.md)
- [Glossário](GLOSSARY.md)
- [CI/CD](CI.md)

## 1. Cabeçalho Obrigatório
Todo script deve começar com um bloco de cabeçalho bem estruturado, incluindo:

```bash
########################################################################
# Script Name: nome_do_script.sh
# Version:    x.y.z
# Date:       AAAA-MM-DD
# Author:     Nome ou Equipe
#
# Description:
#   Breve descrição do propósito e funcionamento do script.
#
# Usage:
#   # Exemplo de uso, incluindo variáveis de ambiente se aplicável
#   export VAR1=valor
#   sudo ./nome_do_script.sh --param
#
# Exit codes:
#   0 - Sucesso completo
#   1 - Falha crítica (explique possíveis causas)
#
# Prerequisites:
#   - Sistema operacional e versão
#   - Dependências (ex: Docker, Node.js, etc)
#   - Permissão root
#
# Steps performed by this script:
#   1. Passo a passo resumido das etapas
#   2. ...
#
# See Also:
#   - Links úteis (documentação oficial, troubleshooting, etc)
########################################################################
```

## 2. Limites de Tamanho e Modularização

### 2.1 Tamanho Máximo de Arquivos
- **600 linhas**: Limite absoluto para qualquer arquivo de código fonte
  - Se um arquivo se aproximar de 400 linhas, já deve ser considerada a modularização
  - Arquivos que ultrapassarem 600 linhas devem ser imediatamente refatorados

### 2.2 Tamanho de Chunks de Análise
- **300 linhas**: Tamanho máximo recomendado para chunks de análise
  - Facilita revisão de código
  - Melhora a legibilidade
  - Permite melhor paralelização de tarefas

### 2.3 Diretrizes de Modularização
1. **Separação por Responsabilidade**: Divida o código em módulos lógicos
2. **Funções Específicas**: Cada função deve ter uma única responsabilidade
3. **Arquivos de Módulos**: Use a estrutura de pastas para organizar funcionalidades relacionadas
4. **Documentação Clara**: Cada módulo deve ter documentação adequada

### 2.4 Documentação Detalhada de Código

#### Para Funções:
```bash
#
# Nome da Função
#
# Descrição: 
#   Descrição clara e concisa do propósito da função.
#
# Parâmetros:
#   $1 - Descrição do primeiro parâmetro
#   $2 - Descrição do segundo parâmetro
#
# Retorno:
#   - 0 em caso de sucesso
#   - Código de erro em caso de falha
#
# Exemplo:
#   nome_da_função "param1" "param2"
#
function nome_da_função() {
    local param1="$1"
    local param2="$2"
    
    # Lógica da função aqui
    
    return 0
}
```

#### Para Chunks/Blocos de Código:
```bash
#
# BLOCO: Nome Descritivo do Bloco
#
# Propósito:
#   Explicação detalhada do que este bloco de código faz
#   e por que ele é necessário no contexto maior.
#
# Contexto:
#   - Estado esperado do sistema antes da execução
#   - Dependências externas ou requisitos
#   - Efeitos colaterais conhecidos
#
# Exceções:
#   - Como erros são tratados
#   - Códigos de retorno específicos
#
# Exemplo de Uso:
#   Inclua um exemplo prático de como usar ou testar o bloco
#

# Código do bloco aqui
```

#### Para Arquivos:
```bash
#!/bin/bash
#
# Nome do Arquivo: nome_do_arquivo.sh
#
# Descrição:
#   Visão geral do propósito e funcionalidade principal do arquivo.
#   Inclua contexto sobre onde este arquivo se encaixa na arquitetura.
#
# Estrutura:
#   1. Seção de imports e dependências
#   2. Constantes e configurações globais
#   3. Definição de funções
#   4. Fluxo principal de execução
#
# Uso:
#   ./nome_do_arquivo.sh [opções] <argumentos>
#
# Opções:
#   -h  Mostra esta ajuda
#   -v  Modo verboso
#
# Autor: Nome <email@exemplo.com>
# Data:  AAAA-MM-DD
# Versão: 1.0.0
#
# Histórico de Alterações:
#   AAAA-MM-DD - Nome - Descrição breve da alteração
#
```

## 3. Comentários e Mensagens
- Use comentários claros antes de blocos lógicos relevantes.
- Sempre explique decisões não triviais.
- Mensagens para o usuário humano devem ser:
  - Informativas, com timestamps (`[INFO][YYYY-MM-DD HH:MM:SS] Mensagem`)
  - Visuais e amigáveis (emojis e banners são bem-vindos)
  - Em português brasileiro

## 3. Tratamento de Exceções e Fluxo Seguro
- Use `set -e` para abortar em erros não tratados.
- Sempre cheque pré-requisitos antes de executar comandos sensíveis.
- Ao detectar erro crítico, imprima mensagem clara e finalize com exit code adequado.
- Nunca sobrescreva variáveis de ambiente ou configurações sem checar o estado atual.
- Em scripts interativos, sempre peça confirmação antes de fazer alterações críticas.
- Mantenha um log detalhado de todas as operações realizadas.
- Implemente rollback ou backup automático antes de alterações destrutivas.

## 4. Estrutura de Código e Boas Práticas
- Separe claramente blocos de diagnóstico, instalação, configuração, limpeza, etc.
- Use funções para tarefas reutilizáveis ou blocos longos.
- Prefira sempre mapeamento explícito de portas em comandos Docker.
- Rotacione logs e registre tudo relevante para auditoria.
- Em scripts interativos, forneça valores padrão seguros e claros.
- Sempre valide entradas do usuário, especialmente em scripts de segurança.
- Documente claramente os parâmetros e opções de linha de comando.
- Mantenha consistência na formatação de mensagens e logs.

## 5. Manutenção e Evolução
- Ao alterar scripts, sempre atualize o cabeçalho e a seção de uso.
- Nunca remova etapas críticas sem consultar o responsável.
- Adicione validações e inspeções extras quando necessário.
- Mantenha exemplos de uso atualizados e funcionais.

## 6. Exemplo de Cabeçalho Completo
```bash
########################################################################
# Script Name: initial-setup.sh
# Version:    1.0.0
# Date:       2025-07-06
# Author:     Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Automação robusta da reinstalação e configuração do ambiente
#   em servidores Debian 12+. Inclui diagnóstico, limpeza, backup,
#   validação de portas, execução do container e automação do wizard.
#
# Usage:
#   export CAPROVER_ADMIN_PASS=suasenha
#   export CAPROVER_ROOT_DOMAIN=seudominio.com
#   export CAPROVER_ADMIN_EMAIL=seu@email.com
#   sudo ./setup-caprover.sh --force
#
# Exit codes:
#   0 - Sucesso completo
#   1 - Falha crítica (docker não inicia, permissão, disco insuficiente, portas ocupadas, etc)
#
# Prerequisites:
#   - Debian 12+ (bookworm) ou compatível
#   - Docker Engine, Node.js, CapRover CLI
#   - Permissão root
#
# Steps performed by this script:
#   1. Diagnóstico do sistema
#   2. Backup e limpeza
#   3. Execução CapRover
#   4. Automação wizard inicial
#   5. Diagnóstico pós-deploy
#
# See Also:
#   - https://caprover.com/docs/
########################################################################
```

## Execução Manual Rápida dos Scripts de Diagnóstico e Segurança

Após provisionar ou atualizar o servidor, execute manualmente:

```sh
# Torne todos os scripts executáveis (se necessário)
chmod +x *.sh

# 1. Preparação inicial do sistema
sudo ./initial-setup.sh

# 2. (Opcional) Reinicie o servidor
sudo reboot

# 3. Diagnóstico pós-reboot
sudo ./validate-postreboot.sh

# 4. Hardening de segurança interativo
sudo ./harden/zerup-scurity-setup.sh

# 5. (Opcional) Apenas diagnóstico de segurança
sudo ./zero-initial.sh

# 6. Setup CapRover automatizado
export CAPROVER_ADMIN_PASS=suasenha
export CAPROVER_ROOT_DOMAIN=seudominio.com
export CAPROVER_ADMIN_EMAIL=seu@email.com
sudo ./setup-caprover.sh --force
```

### Modo Não-Interativo (Avançado)
Para automação, use o modo não-interativo com variáveis de ambiente:

```sh
# Exemplo: Configuração mínima não-interativa
sudo SSH_PORT=2222 SSH_USER=admin ./harden/zerup-scurity-setup.sh --non-interactive

# Exemplo: Configuração completa não-interativa
sudo SSH_PORT=2222 \
  SSH_USER=admin \
  ENABLE_UPDATES=true \
  ENABLE_FAIL2BAN=true \
  ENABLE_UFW=true \
  ./harden/zerup-scurity-setup.sh --non-interactive
```

> Consulte o README.md para detalhes de cada etapa, opções e recomendações de segurança.

## 7. Orientações para Agentes (IA ou Humanos)
- Siga SEMPRE este padrão ao criar ou alterar scripts.
- Prefira clareza e robustez à concisão excessiva.
- Priorize sempre a experiência do usuário humano.
- Ao automatizar, trate exceções e informe claramente o status de cada etapa.
- Em scripts interativos, sempre dê ao usuário a opção de pular etapas.
- Documente claramente os requisitos e dependências.
- Mantenha a compatibilidade com versões anteriores quando possível.
- Atualize este guia se novos padrões forem adotados.

---

Dúvidas ou sugestões? Consulte o responsável pelo projeto ou abra uma issue/documentação complementar.

## Pós-clone: Permissões e Bash
- Execute o script de pós-clone para garantir permissões:
  ```bash
  bash post-clone-setup.sh
  ```
- Verifique se o Bash 4.0+ está instalado:
  ```bash
  bash --version
  # Se for menor que 4, instale com brew install bash (macOS) ou sudo apt install bash (Linux)
  ```
