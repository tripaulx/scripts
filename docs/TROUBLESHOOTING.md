# Troubleshooting & FAQ

> [Voltar para o README](../README.md)

## Troubleshooting

### Problemas Comuns

#### Falha na Inicialização do CapRover
- Verifique os logs em tempo real: `docker service logs captain-captain --tail 100 --follow`
- Verifique se todas as portas necessárias estão abertas: `sudo netstat -tuln`
- Confirme se o domínio está apontando para o IP correto

#### Problemas de Conexão SSH
- Verifique se o serviço SSH está rodando: `sudo systemctl status ssh`
- Confirme se a porta SSH está aberta no firewall: `sudo ufw status`
- Verifique se o IP não está bloqueado pelo Fail2Ban: `sudo fail2ban-client status`

#### Logs Importantes
- Logs do sistema: `/var/log/syslog`
- Logs de autenticação: `/var/log/auth.log`
- Logs do Docker: `journalctl -u docker.service`
- Logs do CapRover: `docker service logs captain-captain`
- Logs do UFW: `journalctl -u ufw`
- Logs do Fail2Ban: `journalctl -u fail2ban`

### Ferramentas de Diagnóstico

O script principal inclui ferramentas avançadas para diagnóstico:

1. **Verificar Portas Abertas**
   - Lista todas as portas em uso e por quais processos

2. **Verificar Logs do Sistema**
   - Acesso rápido aos logs de sistema, autenticação e serviços

3. **Testar Configuração de Segurança**
   - Verifica a configuração de todos os módulos de segurança
   - Gera relatório detalhado de possíveis problemas

4. **Atualizar Scripts**
   - Verifica e aplica atualizações dos scripts

### Mensagens de Erro Comuns

1. **"Porta já em uso"**
   - Solução: Use `lsof -i :PORTA` para identificar o processo e encerrá-lo ou escolha outra porta.

2. **"Permissão negada"**
   - Solução: Execute o script com `sudo` ou como usuário root.

3. **Falha no Fail2Ban**
   - Verifique se há erros de configuração: `sudo fail2ban-client -x -f start`
   - Confirme se os arquivos de log estão acessíveis

4. **Problemas com UFW**
   - Verifique se o UFW está ativo: `sudo ufw status`
   - Se necessário, desative e reative: `sudo ufw disable && sudo ufw enable`

### Logs Detalhados
- Logs do script principal: `/var/log/security_hardening_*.log`
- Logs de instalação do CapRover: `install.log`
- Backups de configurações: `/var/backups/security/`

### Recuperação de Desastres

#### Rollback de Configurações
O sistema mantém backups automáticos das configurações alteradas. Para reverter:

1. Acesse o menu principal: `sudo ./main.sh`
2. Selecione a opção "Reverter Alterações (Rollback)"
3. Escolha o backup desejado

#### Recuperação de Acesso SSH
Se você perdeu o acesso SSH:

1. Acesse o servidor via console (KVM, VNC, IPMI, etc.)
2. Faça login como root
3. Verifique o status do serviço SSH: `systemctl status ssh`
4. Verifique as regras de firewall: `ufw status`
5. Verifique se o Fail2Ban não está bloqueando seu IP: `fail2ban-client status`
6. Se necessário, restaure o acesso temporariamente:
   ```bash
   ufw allow 22/tcp
   fail2ban-client set sshd unbanip SEU_IP
   systemctl restart ssh
   ```

#### Restauração do CapRover
Se o painel do CapRover não estiver acessível:

1. Verifique os logs do serviço: `docker service logs captain-captain`
2. Verifique se os containers estão rodando: `docker ps -a`
3. Se necessário, reinicie o serviço:
   ```bash
   docker service scale captain-captain=0
   docker service scale captain-captain=1
   ```
4. Verifique o status do cluster Docker: `docker node ls`

### Suporte Adicional

Para suporte adicional, consulte:
- [Documentação do CapRover](https://caprover.com/docs/)
- [Documentação do UFW](https://help.ubuntu.com/community/UFW)
- [Documentação do Fail2Ban](https://www.fail2ban.org/wiki/index.php/Main_Page)

Se o problema persistir, colete as seguintes informações antes de entrar em contato com o suporte:
1. Saída de `uname -a`
2. Versão do Docker: `docker --version`
3. Logs relevantes (conforme listado acima)
4. Comportamento esperado vs. comportamento observado
