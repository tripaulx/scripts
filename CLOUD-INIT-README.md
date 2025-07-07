# Configuração Automática de Instâncias no DigitalOcean

Este guia explica como usar o arquivo `cloud-init.yml` para configurar automaticamente uma nova instância no DigitalOcean com todos os scripts necessários.

## Pré-requisitos

- Conta no DigitalOcean
- Acesso à API do DigitalOcean (token)
- Ferramenta `doctl` instalada (opcional, para linha de comando)

## Como Usar

### Método 1: Usando o Painel do DigitalOcean

1. Acesse o [Painel do DigitalOcean](https://cloud.digitalocean.com/)
2. Clique em "Create" > "Droplets"
3. Selecione a imagem do Debian 12
4. Escolha o plano desejado
5. Na seção "Select additional options", marque "User data"
6. Copie o conteúdo do arquivo `cloud-init.yml` para a área de texto
7. Continue com a criação do Droplet normalmente

### Método 2: Usando a API (com doctl)

```bash
# Criar um novo Droplet com cloud-init
doctl compute droplet create \
  --image debian-12-x64 \
  --size s-2vcpu-4gb \
  --region nyc1 \
  --ssh-keys <seu-ssh-key-id> \
  --user-data-file cloud-init.yml \
  nome-do-seu-droplet
```

### Método 3: Usando Terraform

Crie um arquivo `main.tf` com o seguinte conteúdo:

```hcl
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "default" {
  name = "sua-chave-ssh"
}

resource "digitalocean_droplet" "web" {
  image    = "debian-12-x64"
  name     = "web-1"
  region   = "nyc1"
  size     = "s-2vcpu-4gb"
  ssh_keys = [data.digitalocean_ssh_key.default.id]
  
  user_data = file("${path.module}/cloud-init.yml")
}
```

## O que o Script Faz

1. Atualiza os pacotes do sistema
2. Instala dependências necessárias (git, jq, curl)
3. Clona este repositório para `/opt/scripts`
4. Executa a configuração inicial
5. Executa o hardening de segurança
6. Gera um diagnóstico do sistema
7. Salva todos os logs em `/root/setup.log`
8. Configura uma mensagem de boas-vindas informativa

## Verificando o Progresso

Após o login no servidor, você pode verificar o progresso com:

```bash
# Verificar o log em tempo real
sudo tail -f /root/setup.log

# Verificar o status do cloud-init
cloud-init status
```

## Personalização

Você pode personalizar o script `cloud-init.yml` para:

- Adicionar mais pacotes à instalação
- Executar comandos adicionais
- Configurar variáveis de ambiente
- Adicionar usuários adicionais
- Configurar redes adicionais

## Solução de Problemas

Se algo der errado, verifique:

```bash
# Logs do cloud-init
cat /var/log/cloud-init-output.log
cat /var/log/cloud-init.log

# Status dos serviços
systemctl status cloud-init
journalctl -u cloud-init
```

## Segurança

- O script é executado como root
- Certifique-se de que apenas usuários autorizados tenham acesso ao servidor
- Revise os logs regularmente
- Mantenha o sistema atualizado
