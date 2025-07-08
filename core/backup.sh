#!/bin/bash
# ===================================================================
# Arquivo: core/backup.sh
# Descrição: Funções para backup e rollback de configurações
# ===================================================================

# Carregar funções utilitárias
# shellcheck source=utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Variáveis globais
BACKUP_DIR="/var/backups/zerup"
ROLLBACK_DIR="/var/backups/zerup/rollback"
CURRENT_BACKUP=""

# Inicializar o sistema de backup
init_backup_system() {
    log "INFO" "Inicializando sistema de backup..."
    
    # Criar diretórios de backup se não existirem
    mkdir -p "$BACKUP_DIR" "$ROLLBACK_DIR"
    
    # Definir permissões seguras
    chmod 700 "$BACKUP_DIR"
    chmod 700 "$ROLLBACK_DIR"
    
    # Criar backup atual com timestamp
    CURRENT_BACKUP="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CURRENT_BACKUP"
    
    log "DEBUG" "Diretório de backup atual: $CURRENT_BACKUP"
}

# Criar backup de um arquivo
backup_file() {
    local src_file=$1
    local backup_file
    
    # Verificar se o arquivo de origem existe
    if [ ! -e "$src_file" ]; then
        log "WARN" "Arquivo de origem não encontrado para backup: $src_file"
        return 1
    fi
    
    # Criar estrutura de diretórios no backup
    local file_dir
    file_dir=$(dirname "$src_file" | sed 's/^\///')
    mkdir -p "${CURRENT_BACKUP}/${file_dir}"
    
    # Definir nome do arquivo de backup
    backup_file="${CURRENT_BACKUP}/${src_file}.bak"
    
    # Fazer backup do arquivo
    log "DEBUG" "Fazendo backup de $src_file para $backup_file"
    
    if ! cp -a "$src_file" "$backup_file"; then
        log "ERROR" "Falha ao criar backup de $src_file"
        return 1
    fi
    
    log "INFO" "Backup criado: $backup_file"
    echo "$backup_file"
    return 0
}

# Criar backup de um diretório
backup_directory() {
    local src_dir=$1
    local backup_dir
    
    # Verificar se o diretório de origem existe
    if [ ! -d "$src_dir" ]; then
        log "WARN" "Diretório de origem não encontrado para backup: $src_dir"
        return 1
    fi
    
    # Criar estrutura de diretórios no backup
    local dir_name
    dir_name=$(basename "$src_dir")
    backup_dir="${CURRENT_BACKUP}/${dir_name}_backup"
    
    # Fazer backup do diretório
    log "DEBUG" "Fazendo backup do diretório $src_dir para $backup_dir"
    
    if ! cp -a "$src_dir" "$backup_dir"; then
        log "ERROR" "Falha ao criar backup do diretório $src_dir"
        return 1
    fi
    
    log "INFO" "Backup de diretório criado: $backup_dir"
    echo "$backup_dir"
    return 0
}

# Criar ponto de restauração (snapshot)
create_restore_point() {
    local name=$1
    local description=${2:-"Ponto de restauração criado em $(date)"}
    local snapshot_dir="${ROLLBACK_DIR}/${name}_$(date +%Y%m%d_%H%M%S)"
    
    log "INFO" "Criando ponto de restauração: $name"
    
    # Criar diretório do snapshot
    mkdir -p "$snapshot_dir"
    
    # Criar arquivo de metadados
    cat > "${snapshot_dir}/metadata" <<- EOF
NAME="$name"
TIMESTAMP=$(date +%s)
DESCRIPTION="$description"
CREATED_BY=$(whoami)
CREATED_FROM=$(hostname)
EOF
    
    log "DEBUG" "Ponto de restauração criado em: $snapshot_dir"
    echo "$snapshot_dir"
    return 0
}

# Listar pontos de restauração disponíveis
list_restore_points() {
    if [ ! -d "$ROLLBACK_DIR" ] || [ -z "$(ls -A "$ROLLBACK_DIR")" ]; then
        log "INFO" "Nenhum ponto de restauração encontrado."
        return 1
    fi
    
    local count=0
    echo -e "\n${BLUE}=== PONTOS DE RESTAURAÇÃO DISPONÍVEIS ===${NC}"
    
    for dir in "$ROLLBACK_DIR"/*/; do
        if [ -f "${dir}metadata" ]; then
            count=$((count + 1))
            local name timestamp desc
            name=$(grep '^NAME=' "${dir}metadata" | cut -d'=' -f2- | tr -d '"')
            timestamp=$(grep '^TIMESTAMP=' "${dir}metadata" | cut -d'=' -f2-)
            desc=$(grep '^DESCRIPTION=' "${dir}metadata" | cut -d'=' -f2- | tr -d '"')
            
            printf "%2d) %-30s | %s | %s\n" \
                "$count" \
                "$name" \
                "$(date -d "@$timestamp" '+%d/%m/%Y %H:%M:%S')" \
                "$desc"
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        log "INFO" "Nenhum ponto de restauração válido encontrado."
        return 1
    fi
    
    return 0
}

# Restaurar a partir de um backup
restore_backup() {
    local backup_path=$1
    local target_path=$2
    
    # Verificar se o backup existe
    if [ ! -e "$backup_path" ]; then
        log "ERROR" "Arquivo de backup não encontrado: $backup_path"
        return 1
    }
    
    # Verificar se o diretório de destino existe (se for um diretório)
    if [ -d "$backup_path" ] && [ ! -d "$target_path" ]; then
        log "ERROR" "Diretório de destino não encontrado: $target_path"
        return 1
    fi
    
    # Fazer backup do arquivo/diretório atual antes de restaurar
    if [ -e "$target_path" ]; then
        local backup_before_restore
        backup_before_restore="${target_path}.before_restore_$(date +%Y%m%d_%H%M%S)"
        
        log "INFO" "Criando backup de segurança em: $backup_before_restore"
        if ! cp -a "$target_path" "$backup_before_restore"; then
            log "ERROR" "Falha ao criar backup de segurança de $target_path"
            return 1
        fi
    fi
    
    # Restaurar o backup
    log "INFO" "Restaurando $backup_path para $target_path"
    
    if [ -d "$backup_path" ]; then
        # Restaurar diretório
        if ! rsync -a --delete "$backup_path/" "$target_path/"; then
            log "ERROR" "Falha ao restaurar diretório de $backup_path para $target_path"
            return 1
        fi
    else
        # Restaurar arquivo
        if ! cp -a "$backup_path" "$target_path"; then
            log "ERROR" "Falha ao restaurar arquivo de $backup_path para $target_path"
            return 1
        fi
    fi
    
    log "INFO" "Restauração concluída com sucesso: $target_path"
    return 0
}

# Desfazer a última operação (rollback)
rollback_last_operation() {
    if [ -z "$CURRENT_BACKUP" ] || [ ! -d "$CURRENT_BACKUP" ]; then
        log "ERROR" "Nenhum backup recente encontrado para rollback"
        return 1
    fi
    
    log "WARN" "Iniciando rollback da última operação..."
    
    # Encontrar todos os arquivos de backup no diretório atual
    find "$CURRENT_BACKUP" -type f -name "*.bak" | while read -r backup_file; do
        # Extrair o caminho original (removendo o sufixo .bak e o diretório de backup)
        local original_file
        original_file=$(echo "$backup_file" | sed -e "s|^${CURRENT_BACKUP}/||" -e 's/\.bak$//')
        
        # Restaurar o arquivo original
        if [ -e "/$original_file" ]; then
            log "INFO" "Restaurando $original_file a partir do backup"
            if ! cp -a "$backup_file" "/$original_file"; then
                log "ERROR" "Falha ao restaurar $original_file"
                # Continuar com os próximos arquivos mesmo em caso de erro
                continue
            fi
        else
            log "WARN" "Arquivo original não encontrado, não é possível restaurar: /$original_file"
        fi
    done
    
    log "INFO" "Rollback concluído. Verifique se todas as alterações foram revertidas corretamente."
    return 0
}

# Limpar backups antigos
cleanup_old_backups() {
    local max_days=${1:-30}  # Manter backups por 30 dias por padrão
    
    log "INFO" "Removendo backups mais antigos que $max_days dias..."
    
    # Encontrar e remover diretórios de backup antigos
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -mtime +"$max_days" -exec rm -rf {} \;
    
    # Encontrar e remover pontos de restauração antigos
    find "$ROLLBACK_DIR" -maxdepth 1 -type d -name "*_*_*_*" -mtime +"$max_days" -exec rm -rf {} \;
    
    log "INFO" "Limpeza de backups antigos concluída."
    return 0
}

# Exportar funções para que estejam disponíveis em outros scripts
export -f init_backup_system backup_file backup_directory create_restore_point
