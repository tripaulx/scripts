# Guia de Contribuição

Obrigado por considerar contribuir para este projeto! Este guia fornece informações sobre como contribuir de forma eficaz.

## 📋 Antes de Começar

1. **Leia o Código de Conduta** - Certifique-se de ler e seguir nosso [Código de Conduta](CODE_OF_CONDUCT.md).
2. **Verifique os Problemas** - Antes de começar a trabalhar, verifique se já existe uma issue relacionada ao que você deseja fazer.
3. **Discuta Mudanças Grandes** - Para grandes mudanças, abra uma issue primeiro para discutir a proposta com os mantenedores.

## 🛠 Configuração do Ambiente

1. **Faça um Fork** do repositório
2. **Clone** o repositório para sua máquina local:
   ```bash
   git clone https://github.com/tripaulx/scripts.git
   cd scripts
   ```
3. **Instale as Dependências** (se aplicável):
   ```bash
   ./check-dependencies.sh
   ```
4. **Crie um Branch** para sua feature/correção:
   ```bash
   git checkout -b feature/nome-da-feature
   # ou
   git checkout -b fix/corrigir-bug
   ```

## 🔧 Desenvolvimento

### Padrões de Código

- Siga o estilo de código existente no projeto
- Use nomes descritivos para variáveis e funções
- Documente funções complexas com comentários claros
- Mantenha as linhas em até 80 caracteres

### Testes

1. **Testes Locais** - Certifique-se de que todos os testes passam localmente
2. **Novos Testes** - Adicione testes para novas funcionalidades
3. **Testes de Regressão** - Verifique se as alterações não quebram funcionalidades existentes

### Documentação

Atualize a documentação relevante, incluindo:
- README.md
- CHANGELOG.md
- Documentação de funções/módulos
- Guias de configuração

## 💾 Enviando Mudanças

1. **Faça Commit** das suas alterações:
   ```bash
   git add .
   git commit -m "Descrição clara e concisa das alterações"
   ```

2. **Faça Push** para o seu fork:
   ```bash
   git push origin nome-da-sua-branch
   ```

3. **Abra um Pull Request**
   - Vá para o repositório original no GitHub
   - Clique em "New Pull Request"
   - Selecione sua branch
   - Preencha o template do PR com detalhes sobre suas alterações
   - Adicione capturas de tela ou animações, se aplicável

## 🔍 Revisão de Código

- Os PRs serão revisados por pelo menos um mantenedor
- Esteja preparado para fazer alterações com base no feedback
- Os revisores podem sugerir melhorias ou alternativas

## 📝 Modelo de Pull Request

```markdown
## Descrição

[Descreva as alterações feitas e por quê]

## Tipo de Mudança

Marque com um X as opções que se aplicam:

- [ ] Correção de bug (alteração ininterrupta que corrige um problema)
- [ ] Nova feature (alteração ininterrupta que adiciona funcionalidade)
- [ ] Alteração de documentação (atualizações na documentação)
- [ ] Alteração de quebra (correção ou recurso que faria com que a funcionalidade existente não funcione conforme o esperado)
- [ ] Esta alteração requer uma atualização de documentação

## Como isso foi testado?

[Descreva os testes que você executou para verificar suas alterações]

## Checklist:

- [ ] Meu código segue as diretrizes de estilo deste projeto
- [ ] Executei testes locais e todos passaram
- [ ] Adicionei testes que comprovam minha correção é eficaz ou que meu recurso funciona
- [ ] Atualizei a documentação de acordo
- [ ] Adicionei exemplos à documentação
- [ ] Adicionei uma descrição clara das alterações ao CHANGELOG.md
```

## 📬 Outros Tipos de Contribuições

Você pode contribuir de várias maneiras além do código:

- **Relatar Bugs** - Abra uma issue descrevendo o bug e como reproduzi-lo
- **Solicitar Recursos** - Sugira novas funcionalidades ou melhorias
- **Melhorar Documentação** - Ajude a melhorar a documentação existente
- **Responder a Perguntas** - Ajude outros usuários no GitHub Discussions
- **Traduções** - Ajude a traduzir a documentação para outros idiomas

## 📄 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a [Licença MIT](LICENSE).
