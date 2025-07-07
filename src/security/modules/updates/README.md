# Módulo de Atualizações

## Visão Geral
Este módulo é responsável por gerenciar atualizações do sistema operacional e pacotes, incluindo:

- Verificação de atualizações de segurança disponíveis
- Instalação de atualizações de segurança
- Gerenciamento de atualizações do kernel
- Configuração de atualizações automáticas
- Gerenciamento de reinicializações após atualizações

## Estrutura de Diretórios

```
updates/
├── package_managers/    # Funções de gerenciamento de pacotes
│   ├── common.sh        # Funções comuns a todos os gerenciadores
│   ├── apt_utils.sh     # Funções específicas para APT (Debian/Ubuntu)
│   ├── yum_utils.sh     # Funções específicas para YUM (RHEL/CentOS)
│   └── dnf_utils.sh     # Funções específicas para DNF (Fedora)
├── kernel/              # Funções relacionadas ao kernel
│   ├── kernel_updates.sh # Verificação de atualizações do kernel
│   └── reboot_utils.sh  # Gerenciamento de reinicializações
├── automatic/           # Atualizações automáticas
│   └── unattended_upgrades.sh # Configuração de atualizações automáticas
├── update_utils.sh      # Ponto de entrada principal do módulo
└── README.md            # Este arquivo
```

## Como Usar

### Carregando o Módulo

Para usar as funções deste módulo em seus scripts, basta carregar o arquivo principal:

```bash
# No seu script
source "/caminho/para/updates/update_utils.sh"
```

### Exemplos de Uso

#### 1. Verificar Atualizações de Segurança

```bash
# Verificar atualizações de segurança disponíveis
if security_updates=$(get_security_updates); then
    echo "Atualizações de segurança disponíveis:"
    echo "$security_updates"
else
    echo "Nenhuma atualização de segurança disponível."
fi
```

#### 2. Instalar Atualizações de Segurança

```bash
# Instalar atualizações de segurança (modo interativo)
install_security_updates

# Instalar atualizações de segurança (modo não interativo)
install_security_updates "yes"
```

#### 3. Verificar Atualizações do Kernel

```bash
# Verificar se há atualizações do kernel disponíveis
if check_kernel_updates; then
    echo "Atualizações do kernel disponíveis!"
    
    # Obter a versão atual do kernel
    current_kernel=$(get_current_kernel_version)
    echo "Versão atual do kernel: $current_kernel"
    
    # Obter atualizações disponíveis
    updates=$(get_available_kernel_updates)
    echo "Atualizações disponíveis:"
    echo "$updates"
    
    # Verificar se é necessário reiniciar
    if is_reboot_required; then
        echo "Reinicialização necessária para aplicar as atualizações."
    fi
else
    echo "Nenhuma atualização do kernel disponível."
fi
```

#### 4. Gerenciar Atualizações Automáticas

```bash
# Habilitar atualizações automáticas
install_unattended_upgrades "yes"  # 'yes' para instalar dependências automaticamente

# Verificar status das atualizações automáticas
if get_unattended_upgrades_status; then
    echo "Atualizações automáticas estão ativadas."
else
    echo "Atualizações automáticas não estão ativadas."
fi

# Desativar atualizações automáticas
disable_unattended_upgrades
```

#### 5. Gerenciar Reinicializações

```bash
# Verificar se é necessário reiniciar
if reboot_if_required; then
    # Agendar reinicialização em 10 minutos
    schedule_reboot "+10" "Reinicialização agendada para aplicar atualizações de segurança."
    
    # Opcional: Cancelar reinicialização agendada
    # cancel_scheduled_reboot
fi
```

## Funções Principais

### Gerenciamento de Pacotes
- `detect_package_manager`: Detecta o gerenciador de pacotes do sistema
- `update_package_list`: Atualiza a lista de pacotes disponíveis
- `get_security_updates`: Lista atualizações de segurança disponíveis
- `install_security_updates`: Instala atualizações de segurança

### Gerenciamento do Kernel
- `check_kernel_updates`: Verifica se há atualizações do kernel disponíveis
- `get_current_kernel_version`: Obtém a versão atual do kernel
- `get_available_kernel_updates`: Lista atualizações do kernel disponíveis

### Reinicialização
- `reboot_if_required`: Verifica se é necessário reiniciar
- `schedule_reboot`: Agenda uma reinicialização
- `cancel_scheduled_reboot`: Cancela uma reinicialização agendada
- `is_reboot_required`: Verifica silenciosamente se é necessário reiniciar

### Atualizações Automáticas
- `install_unattended_upgrades`: Configura atualizações automáticas
- `disable_unattended_upgrades`: Desativa atualizações automáticas
- `get_unattended_upgrades_status`: Verifica o status das atualizações automáticas

## Requisitos

- Bash 4.0 ou superior
- Privilégios de superusuário (root) para a maioria das operações
- Gerenciador de pacotes suportado (APT, YUM, DNF, etc.)

## Logs

Todas as operações são registradas no arquivo de log padrão configurado em `security_utils.sh`.

## Notas de Versão

### 2.0.0 (2025-07-07)
- Refatoração completa do módulo
- Separação em submódulos lógicos
- Melhor documentação e exemplos
- Suporte a múltiplos gerenciadores de pacotes

### 1.0.0 (2025-07-06)
- Versão inicial do módulo
- Funcionalidades básicas de gerenciamento de atualizações
