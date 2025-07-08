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

---

Adicione sempre novas entradas acima desta linha.
