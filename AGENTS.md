# Guia de Padrão de Documentação e Estrutura de Scripts

Este documento orienta agentes (IA e humanos) sobre o padrão obrigatório para documentação e estrutura de scripts neste projeto. Siga rigorosamente para garantir legibilidade, manutenção e automação confiável.

---

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

## 2. Comentários e Mensagens
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

## 4. Estrutura de Código e Boas Práticas
- Separe claramente blocos de diagnóstico, instalação, configuração, limpeza, etc.
- Use funções para tarefas reutilizáveis ou blocos longos.
- Prefira sempre mapeamento explícito de portas em comandos Docker.
- Rotacione logs e registre tudo relevante para auditoria.

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
chmod +x initial-setup.sh setup-caprover.sh validate-postreboot.sh zero-initial.sh

# 1. Preparação inicial do sistema
sudo ./initial-setup.sh

# 2. (Opcional) Reinicie o servidor
sudo reboot

# 3. Diagnóstico pós-reboot
sudo ./validate-postreboot.sh

# 4. Diagnóstico e hardening de segurança
sudo ./zero-initial.sh

# 5. Setup CapRover automatizado
export CAPROVER_ADMIN_PASS=suasenha
export CAPROVER_ROOT_DOMAIN=seudominio.com
export CAPROVER_ADMIN_EMAIL=seu@email.com
sudo ./setup-caprover.sh --force
```

> Consulte o README.md para detalhes de cada etapa e recomendações de segurança.

## 7. Orientações para Agentes (IA ou Humanos)
- Siga SEMPRE este padrão ao criar ou alterar scripts.
- Prefira clareza e robustez à concisão excessiva.
- Priorize sempre a experiência do usuário humano.
- Ao automatizar, trate exceções e informe claramente o status de cada etapa.
- Atualize este guia se novos padrões forem adotados.

---

Dúvidas ou sugestões? Consulte o responsável pelo projeto ou abra uma issue/documentação complementar.
