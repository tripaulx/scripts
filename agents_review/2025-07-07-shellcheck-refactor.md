# Aprendizado: ShellCheck, CI/CD e Cultura de Revisão

**Data:** 2025-07-07

## Problema
- Muitos scripts shell não passavam no ShellCheck devido a:
  - Variáveis não citadas
  - Uso de cat/grep/ls desnecessários
  - Testes malformados
  - Falta de documentação/cabeçalho
- Falhas recorrentes no pipeline do GitHub Actions por ausência de integração ShellCheck.

## Solução
- Refatoração completa dos scripts para aderir ao Gallery of Bad Code do ShellCheck.
- Criação de workflow GitHub Actions para rodar ShellCheck em todos os PRs e pushes.
- Criação de script utilitário local para rodar ShellCheck e shfmt.
- Atualização do AGENTS.md com checklist e exemplos obrigatórios.

## Aprendizado
- Automatizar a revisão de shell scripts elimina erros recorrentes e acelera o desenvolvimento.
- Documentar cada lição aprendida e compartilhar com o time evita retrabalho e fortalece a cultura DevOps.
- O registro contínuo de problemas e soluções é essencial para evolução do projeto.

## Referências
- [ShellCheck - Gallery of Bad Code](../docs/ShellCheck%20-%20A%20shell%20script%20static%20analysis%20tool.md)
- [AGENTS.md](../docs/AGENTS.md)
- [Workflow GitHub Actions](../.github/workflows/shellcheck.yml)
