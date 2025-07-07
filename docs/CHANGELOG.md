# Registro de Alterações

Este documento lista as principais alterações e melhorias feitas no projeto, ordenadas da mais recente para a mais antiga.

## [Não Liberado] - YYYY-MM-DD

### Adicionado
- Script `harden-ssh.sh` para aplicar configurações de segurança recomendadas ao SSH
- Script `fix-fail2ban.sh` para correção automática de problemas comuns do Fail2Ban
- Documentação detalhada de onboarding e requisitos
- Script de verificação de dependências
- Roteiro de desenvolvimento futuro
- Checklist de configuração de novo servidor
- Estrutura modular para melhor organização do código

### Corrigido
- Erro de sintaxe no script de backup
- Problemas com variáveis readonly no core/utils.sh
- Caminhos incorretos nos scripts de teste

### Alterado
- Melhoria na documentação do README.md
- Aprimoramento das mensagens de log e saída
- Estrutura de diretórios para melhor organização

## [0.1.0] - 2025-07-06

### Adicionado
- Scripts iniciais de configuração de servidor
- Módulos básicos de segurança (SSH, UFW, Fail2Ban)
- Sistema de backup e restauração
- Validações de segurança automatizadas
- Interface de linha de comando interativa

---

## Formato de Versionamento

Este projeto segue o [Versionamento Semântico 2.0.0](https://semver.org/):

- **MAJOR**: Mudanças incompatíveis com versões anteriores
- **MINOR**: Novas funcionalidades compatíveis com versões anteriores
- **PATCH**: Correções de bugs compatíveis com versões anteriores

## Como Contribuir

Para contribuir com o projeto, siga estas etapas:

1. Crie um fork do repositório
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Faça commit das suas alterações (`git commit -m 'Add some AmazingFeature'`)
4. Faça push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para mais detalhes.
