#!/bin/bash
#
# Nome do Arquivo: run_tests.sh
#
# Descrição:
#   Script para testar a instalação e execução dos scripts de segurança
#   em um ambiente limpo do Debian.
#
# Dependências:
#   - Docker (para teste em container isolado)
#   - curl (para baixar a imagem do Debian)
#
# Uso:
#   ./run_tests.sh [opções]
#
# Opções:
#   --clean    Remove containers e imagens após os testes
#   --verbose  Exibe saída detalhada
#   --help     Exibe esta ajuda
#
# Autor: Equipe de Segurança
# Versão: 1.0.0
# Data: 2025-07-07

set -euo pipefail

# Cores para formatação
readonly COLOR_RESET="\e[0m"
readonly COLOR_RED="\e[31m"
readonly COLOR_GREEN="\e[32m"
readonly COLOR_YELLOW="\e[33m"
readonly COLOR_BLUE="\e[34m"

# Variáveis de controle
CLEAN_AFTER=false
VERBOSE=false
CONTAINER_NAME="debian-security-test"
TEST_DIR="/tmp/security-scripts"

#
# log
#
# Descrição:
#   Exibe mensagens de log formatadas.
#
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "${level}" in
        debug)
            ${VERBOSE} && echo -e "[${timestamp}] [DEBUG] ${message}" >&2
            ;;
        info)
            echo -e "[${timestamp}] [INFO] ${message}"
            ;;
        success)
            echo -e "[${timestamp}] ${COLOR_GREEN}[SUCCESS]${COLOR_RESET} ${message}"
            ;;
        warning)
            echo -e "[${timestamp}] ${COLOR_YELLOW}[WARNING]${COLOR_RESET} ${message}" >&2
            ;;
        error)
            echo -e "[${timestamp}] ${COLOR_RED}[ERROR]${COLOR_RESET} ${message}" >&2
            ;;
        *)
            echo -e "[${timestamp}] [${level^^}] ${message}" >&2
            ;;
    esac
}

#
# check_docker
#
# Descrição:
#   Verifica se o Docker está instalado e em execução.
#
check_docker() {
    if ! command -v docker &> /dev/null; then
        log "error" "Docker não está instalado"
        log "info" "Instale o Docker com: https://docs.docker.com/engine/install/"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log "error" "Docker não está em execução"
        log "info" "Inicie o serviço do Docker e tente novamente"
        return 1
    fi
    
    log "success" "Docker está instalado e em execução"
    return 0
}

#
# build_test_image
#
# Descrição:
#   Constrói a imagem de teste baseada no Debian.
#
build_test_image() {
    log "info" "Construindo imagem de teste..."
    
    local dockerfile="${TEST_DIR}/Dockerfile.test"
    
    # Criar Dockerfile temporário
    cat > "${dockerfile}" << 'EOF'
FROM debian:bookworm-slim

# Instalar dependências básicas
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório para os scripts
RUN mkdir -p /security
WORKDIR /security

# Copiar scripts para o container
COPY . .

# Definir permissões
RUN chmod +x *.sh

# Ponto de entrada para testes
ENTRYPOINT ["/bin/bash"]
EOF
    
    # Construir a imagem
    if ! docker build -f "${dockerfile}" -t "${CONTAINER_NAME}-image" "${TEST_DIR}" > /dev/null 2>&1; then
        log "error" "Falha ao construir a imagem de teste"
        return 1
    fi
    
    log "success" "Imagem de teste construída com sucesso"
    return 0
}

#
# run_tests
#
# Descrição:
#   Executa os testes no container.
#
run_tests() {
    log "info" "Iniciando testes no container..."
    
    # Comandos para executar no container
    local test_commands=(
        "echo '=== Teste de Dependências ==='"
        "./check_dependencies.sh --list"
        "echo '\\n=== Teste de Inicialização ==='"
        "source ./init_environment.sh --verbose"
        "echo '\\n=== Teste de Módulos ==='"
        "./security_setup.sh --ssh --dry-run"
        "./security_setup.sh --firewall --dry-run"
        "./security_setup.sh --fail2ban --dry-run"
    )
    
    # Executar comandos no container
    if ! docker run --rm -it \
        --name "${CONTAINER_NAME}" \
        -v "${PWD}:/security" \
        -w /security \
        "${CONTAINER_NAME}-image" \
        /bin/bash -c "${test_commands[*]}"; then
        log "error" "Falha ao executar os testes no container"
        return 1
    fi
    
    log "success" "Testes concluídos com sucesso"
    return 0
}

#
# clean_up
#
# Descrição:
#   Remove recursos criados durante os testes.
#
clean_up() {
    log "info" "Limpando recursos..."
    
    # Parar e remover container se existir
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
        docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    fi
    
    # Remover imagem se existir
    if docker images --format '{{.Repository}}' | grep -q "^${CONTAINER_NAME}-image$"; then
        docker rmi "${CONTAINER_NAME}-image" > /dev/null 2>&1 || true
    fi
    
    # Remover diretório temporário
    if [ -d "${TEST_DIR}" ]; then
        rm -rf "${TEST_DIR}" > /dev/null 2>&1 || true
    fi
    
    log "success" "Limpeza concluída"
    return 0
}

#
# show_help
#
# Descrição:
#   Exibe a mensagem de ajuda.
#
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo "Executa testes de instalação em um container Docker limpo do Debian."
    echo
    echo "Opções:"
    echo "  --clean    Remove containers e imagens após os testes"
    echo "  --verbose  Exibe saída detalhada"
    echo "  --help     Exibe esta ajuda"
    echo
    echo "Exemplos:"
    echo "  # Executar testes básicos"
    echo "  $0"
    echo
    echo "  # Executar testes e limpar recursos"
    echo "  $0 --clean"
    echo
    echo "  # Modo verboso"
    echo "  $0 --verbose"
}

#
# parse_arguments
#
# Descrição:
#   Processa os argumentos da linha de comando.
#
parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --clean)
                CLEAN_AFTER=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log "error" "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

#
# main
#
# Descrição:
#   Função principal do script.
#
main() {
    # Processar argumentos
    parse_arguments "$@"
    
    log "info" "Iniciando testes de instalação"
    
    # Verificar se o Docker está disponível
    if ! check_docker; then
        exit 1
    fi
    
    # Criar diretório temporário
    mkdir -p "${TEST_DIR}"
    
    # Copiar scripts para o diretório temporário
    cp -r . "${TEST_DIR}/"
    
    # Construir e executar testes
    if ! build_test_image || ! run_tests; then
        log "error" "Falha durante a execução dos testes"
        clean_up
        exit 1
    fi
    
    # Limpar recursos se solicitado
    if [ "${CLEAN_AFTER}" = true ]; then
        clean_up
    fi
    
    log "success" "Todos os testes foram concluídos com sucesso"
    return 0
}

# Executar a função principal
main "$@"
