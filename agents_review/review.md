# Índice de Aprendizados, Problemas e Soluções

Este arquivo serve como índice para todos os aprendizados, problemas e soluções documentados durante o desenvolvimento do projeto.

## Como usar
- Antes de cada commit importante, registre aqui:
  - Data
  - Descrição do problema (ex: falha no ShellCheck, erro no GitHub Actions, etc)
  - Solução aplicada
  - Aprendizado/takeaway
  - Link para arquivo detalhado, se aplicável

## Exemplos

### 2025-07-07
- **Problema:** Shell scripts não passavam no ShellCheck devido a variáveis não citadas e uso de cat desnecessário.
- **Solução:** Refatoração completa, inclusão de ShellCheck no CI, atualização do AGENTS.md.
- **Aprendizado:** Automatizar sempre a revisão e registrar cada lição aprendida para evitar recorrência.
- **Arquivo detalhado:** [2025-07-07-shellcheck-refactor.md](2025-07-07-shellcheck-refactor.md)

### 2025-07-08
- **Problema:** Persistência de avisos ShellCheck (SC2181, SC2046, SC2086, SC2317, SC1091) em múltiplos módulos, dificultando CI/CD limpo e revisão de código.
- **Solução:** Correção incremental e modular de todos os blocos afetados, padronização de quoting, checagem direta de exit code, remoção de código inatingível e revisão dos includes dinâmicos. Todos os scripts agora passam limpos pelo ShellCheck, exceto SC1091 (aceito por design do projeto).
- **Aprendizado:** Revisão contínua e modular reduz riscos, acelera validação e evita regressões. Documentar cada ciclo de aprendizado facilita manutenção e onboarding.
- **Arquivo detalhado:** [2025-07-07-shellcheck-refactor.md](2025-07-07-shellcheck-refactor.md)

### 2025-07-08
- **Problema:** Scripts de configuração (`configure_users.sh` e `configure_updates.sh`) falhavam no CI ao tentar importar arquivos utilitários devido a caminhos relativos inconsistentes.
- **Solução:** Padronização dos comandos de `source` para uso de caminhos absolutos robustos, com logging do caminho e erro claro, garantindo compatibilidade local e CI/CD.
- **Aprendizado:** Sempre garantir sourcing robusto e documentar o caminho tentado para facilitar debug em ambientes variados. Documentação e logging são essenciais para rastreabilidade e manutenção do pipeline.

### 2025-07-08
- **Problema:** Colaboradores eventualmente esqueciam de registrar aprendizados, problemas e soluções no `agents_review/review.md` antes de commits ou PRs, prejudicando rastreabilidade e cultura de melhoria contínua.
- **Solução:** Reforço explícito no `AGENTS.md` (checklist obrigatório) e no `README.md` (seção destacada) de que toda alteração relevante DEVE ser documentada no `review.md` antes de qualquer commit ou PR, seguindo o padrão do índice.
- **Aprendizado:** Documentação disciplinada e visível é essencial para qualidade, rastreabilidade e onboarding eficiente. O fluxo de revisão e aprendizado deve ser obrigatório e auditável para todo o time.

### 2025-07-08
- **Problema:** Necessidade de documentar próximos passos e checklist ShellCheck/sourcing robusto para garantir continuidade após reinício do computador.
- **Solução:** Documentação de próximos passos e checklist para garantir continuidade após reinício do computador.
- **Aprendizado:** Documentação disciplinada e visível é essencial para qualidade, rastreabilidade e onboarding eficiente.

## [2025-07-08] ShellCheck & Sourcing - Próximos Passos

**Resumo do ciclo:**
- Corrigir sourcing de core/utils.sh, core/validations.sh, core/security.sh em scripts como fail2ban.sh, trocando por security_utils.sh e *_utils.sh padronizados.
- Padronizar sourcing em todos os módulos para usar apenas utilitários existentes.
- Corrigir sourcing em configure_users.sh, configure_ufw.sh, configure_fail2ban.sh, configure_ssh.sh, etc.
- Revisar sourcing nos utilitários para garantir uso correto de security_utils.sh.
- Executar ShellCheck e validar ausência de SC1091.
- Documentar cada ciclo no agents_review antes de commit/PR.

**Arquivos prioritários:**
- modules/fail2ban/fail2ban.sh
- src/security/modules/users/configure_users.sh
- src/security/modules/firewall/configure_ufw.sh
- src/security/modules/fail2ban/configure_fail2ban.sh
- src/security/modules/ssh/configure_ssh.sh
- utilitários associados (*_utils.sh)

Checklist para retomada após reinício:
- [ ] Corrigir sourcing dos scripts listados
- [ ] Validar com ShellCheck
- [ ] Atualizar documentação de revisão
- [ ] Confirmar CI limpo

---

Adicione sempre novas entradas acima desta linha.
