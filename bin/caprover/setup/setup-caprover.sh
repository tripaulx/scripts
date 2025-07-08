#!/bin/bash

########################################################################
# Script Name: setup-caprover.sh
# Version:    1.0.0
# Date:       2025-07-06
# Author:     Flavio Almeida Paulino - Tribeca Digital
#
# Description:
#   Reinstalação, diagnóstico e limpeza profunda do ambiente CapRover
#   em hosts Debian/Linux. Remove completamente containers, serviços
#   swarm, volumes, redes, resíduos e executa todos os diagnósticos e
#   validações necessárias para garantir ambiente limpo e pronto para
#   nova instalação CapRover.
#
# Usage:
#   # Fluxo recomendado para novo servidor:
#   # 1. Execute o script de preparação inicial:
#   sudo ./initial-setup.sh
#   # 2. Exemplo de uso automatizado com setup inicial via CapRover CLI:
#   export CAPROVER_ADMIN_PASS=suasenha
#   export CAPROVER_ROOT_DOMAIN=seudominio.com
#   export CAPROVER_ADMIN_EMAIL=seu@email.com
#   sudo ./setup-caprover.sh --force
#
# Exit codes:
#   0 - Sucesso completo
#   1 - Falha crítica (docker não inicia, permissão, disco insuficiente, portas ocupadas, etc)
#
# Prerequisites:
#   - Debian 12+ (bookworm) ou compatível
#   - Docker Engine instalado e ativo
#   - Permissão root
#
# Steps performed by this script:
#   1. Diagnóstico OS e Docker info antes de qualquer operação destrutiva
#   2. Diagnóstico de portas, containers e serviços swarm
#   3. Backup seguro do /captain se existir
#   4. Limpeza completa (containers, serviços, swarm, volumes, diretório)
#   5. Criação e validação do diretório /captain
#   6. Liberação de portas via UFW
#   7. Docker prune agressivo
#   8. Execução CapRover com mapeamento explícito de portas
#   9. Diagnóstico pós-start, logs, relatórios finais
#
# See Also:
#   - https://caprover.com/docs/troubleshooting.html
#   - https://github.com/caprover/caprover
#
# INSTRUÇÃO PARA AGENTES DE IA:
#   - A documentação do script deve estar sempre atualizada e refletir fielmente o comportamento e as melhorias implementadas.
#   - Nunca remova nenhuma etapa deste script, sem informar ou perguntar ao usuário que solicitou ajustes.
#   - Apenas adicione validações ou inspeções extras, caso necessário.
#   - Não altere comandos sem necessidade comprovada.
#   - Sempre use o modo de mapeamento explícito de portas (-p), nunca --network host.
#   - Utilize mensagens claras, banners visuais e timestamps para informar o usuário humano sobre cada etapa crítica do processo.
#   - Sempre solicite confirmação explícita do usuário antes de operações destrutivas.
#   - Garanta checagem de root antes de executar comandos sensíveis.
#   - Realize diagnóstico pós-limpeza para garantir ambiente limpo.
#   - Implemente rotação de logs para facilitar auditoria.
#   - Use teste robusto de escrita/leitura em volumes críticos.
#   - Priorize a experiência do usuário humano com feedbacks visuais e mensagens detalhadas sobre o status de cada etapa.
########################################################################

set -e

# Verifica versão do Bash
if [ "$(bash --version | head -n1 | grep -oE '[0-9]+')" -lt 4 ]; then
  echo -e "\033[0;31m[ERRO] Bash 4.0+ é obrigatório. Instale com 'brew install bash' (macOS) ou 'sudo apt install bash' (Linux).\033[0m"
  exit 1
fi

SCRIPT_ROOT="$(cd "$(dirname "$0")"/../../.. && pwd)"
"${SCRIPT_ROOT}/src/security/core/check_dependencies.sh" --install

LOGFILE="install.log"
# Rotaciona log antigo
if [ -f "$LOGFILE" ]; then
    mv "$LOGFILE" "${LOGFILE}.bak"
fi
exec > >(tee -a "$LOGFILE") 2>&1

# Checagem de root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR][$(date '+%Y-%m-%d %H:%M:%S')] Por favor, execute como root."
    exit 1
fi

# Checagem de pré-requisitos essenciais (apenas alerta, não instala)
for BIN in docker node npm caprover; do
    if ! command -v "$BIN" >/dev/null 2>&1; then
        echo "[ERRO][$(date '+%Y-%m-%d %H:%M:%S')] Dependência obrigatória não encontrada: $BIN. Por favor, execute o script de setup inicial antes deste!"
        exit 1
    fi
    echo "[OK][$(date '+%Y-%m-%d %H:%M:%S')] Dependência encontrada: $BIN"
done

# Parâmetro --force para automação
FORCE=0
for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
        FORCE=1
    fi
    # pode adicionar outros parâmetros aqui futuramente
done

# Loga usuário executor
echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Script iniciado por: $(whoami)"

# Confirmação do usuário
if [[ $FORCE -eq 0 ]]; then
    read -p "⚠️  Confirma que deseja limpar TODO o ambiente Docker deste servidor? (y/N): " CONFIRMA
    if [[ ! "$CONFIRMA" =~ ^[Yy]$ ]]; then
        echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Operação cancelada pelo usuário."
        exit 0
    fi
else
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Modo --force ativado: pulando confirmação do usuário."
fi

CAPTAIN_NAME="captain"
PORTAS=(80 443 3000 996 7946 4789 2377)
MIN_DISK_GB=2

TIMESTAMP() { date '+%Y-%m-%d %H:%M:%S'; }

banner() {
    echo "\n====================================================="
    echo "$1"
    echo "====================================================="
}

echo ""
banner "🌟 == 🚀 Reinicialização do CapRover em $(hostname -I | awk '{print $1}') == 🌟"
START_TIME=$(TIMESTAMP)
echo "🗒️  Início: $START_TIME"
IP_PUBLICO=$(hostname -I | awk '{print $1}')

# Diagnóstico OS
echo ""
echo "🖥️  Diagnóstico do Sistema:"
echo "  - Hostname: $(hostname)"
echo "  - Kernel: $(uname -a)"
echo "  - Uptime: $(uptime -p)"
echo "  - Distribuição: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME)"

# Diagnóstico docker info
echo ""
echo "🐳 Diagnóstico Docker (docker info):"
docker info | head -20

# 14. Lista todos containers e serviços para auditoria
echo ""
echo "📋 Containers Docker existentes:"
docker ps -a

echo ""
echo "📋 Serviços Docker Swarm existentes:"
docker service ls || echo "(Swarm inativo)"

# Snapshot dos logs do Docker para auditoria
DOCKER_LOG_SNAPSHOT="docker_logs_snapshot_$(date +%Y%m%d%H%M%S).log"
echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Salvando snapshot dos logs do Docker em $DOCKER_LOG_SNAPSHOT..."
journalctl -u docker > "$DOCKER_LOG_SNAPSHOT" 2>/dev/null || docker logs $(docker ps -q) > "$DOCKER_LOG_SNAPSHOT" 2>/dev/null || echo "[WARN][$(date '+%Y-%m-%d %H:%M:%S')] Não foi possível capturar logs do Docker."

# 15. Backup opcional do /captain se existir
if [ -d /captain ]; then
    BACKUP_NAME="/captain_backup_$(date +%Y%m%d%H%M%S)"
    echo ""
    echo "🗄️  Backup do volume /captain para $BACKUP_NAME"
    cp -a /captain "$BACKUP_NAME"
fi

# 16. Checa arquivos herdados
if [ -d /etc/caprover ]; then
    echo "⚠️  Atenção: arquivos herdados em /etc/caprover encontrados!"
fi

# 1. Validação Docker
echo ""
echo "🐳 Validando Docker..."
if ! systemctl is-active --quiet docker; then
    echo "❗ Docker não está rodando. Tentando iniciar..."
    systemctl start docker
    sleep 2
    if ! systemctl is-active --quiet docker; then
        echo "🛑 Docker NÃO iniciou. Saindo."
        exit 1
    fi
fi
echo "✅ Docker rodando."

# 2. Permissão docker.sock
echo ""
echo "🔒 Checando permissão em /var/run/docker.sock..."
if ! [ -r /var/run/docker.sock ]; then
    echo "🛑 Permissão insuficiente para acessar /var/run/docker.sock."
    exit 1
fi
echo "✅ Permissão OK."

# 3. Espaço em disco
banner "💾 Checando espaço em disco..."
DISK_FREE=$(df -BG / | awk 'NR==2 {gsub(/G/,""); print $4}')
DOCKER_DISK=$(df -BG /var/lib/docker 2>/dev/null | awk 'NR==2 {gsub(/G/,""); print $4}')
if (( DISK_FREE < MIN_DISK_GB )); then
    echo "🛑 Espaço em disco insuficiente no root: ${DISK_FREE}GB livres."
    exit 1
fi
if [ -n "$DOCKER_DISK" ] && (( DOCKER_DISK < MIN_DISK_GB )); then
    echo "🛑 Espaço insuficiente em /var/lib/docker: ${DOCKER_DISK}GB livres."
    exit 1
fi
echo "✅ Espaço suficiente em / e /var/lib/docker."

# 20. Diagnóstico processos usando portas críticas (lsof/netstat)
echo ""
echo "🔍 Diagnóstico de processos ocupando portas críticas:"
for P in "${PORTAS[@]}"; do
    echo "Porta $P:"
    lsof -i :$P || echo "   - Porta $P livre."
done

# 4. Checagem de portas em uso
echo ""
echo "🛡️  Checando portas em uso..."
PORTA_BLOQUEADA=0
for P in "${PORTAS[@]}"; do
    RETRY=0
    MAX_RETRY=3
    while [ $RETRY -le $MAX_RETRY ]; do
        PROC_INFO=$(ss -ltnp | grep -w ":$P" | grep -v "docker-proxy" | grep -v "caprover" | grep -v "dockerd" || true)
        if [ -z "$PROC_INFO" ]; then
            if [ $RETRY -gt 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Porta $P liberada após tentativa(s)."
            fi
            break
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛑 Porta $P ocupada por processo externo (tentativa $((RETRY+1))):"
        echo "$PROC_INFO"
        PID=$(echo "$PROC_INFO" | awk -F',' '{print $2}' | awk -F'=' '{print $2}' | awk '{print $1}')
        if [ -n "$PID" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tentando finalizar processo PID=$PID usando porta $P..."
            kill -9 $PID && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processo $PID finalizado." || echo "[$(date '+%Y-%m-%d %H:%M:%S')] Falha ao finalizar processo $PID."
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Não foi possível identificar o PID do processo. Libere manualmente a porta $P."
            PORTA_BLOQUEADA=1
            break
        fi
        sleep 2
        RETRY=$((RETRY+1))
    done
    # Checagem final após tentativas
    PROC_INFO_FINAL=$(ss -ltnp | grep -w ":$P" | grep -v "docker-proxy" | grep -v "caprover" | grep -v "dockerd" || true)
    if [ -n "$PROC_INFO_FINAL" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Porta $P ainda ocupada após $MAX_RETRY tentativas. Libere manualmente antes de continuar."
        PORTA_BLOQUEADA=1
    fi
done
if (( PORTA_BLOQUEADA > 0 )); then
    echo "❗ Não foi possível liberar todas as portas críticas. Libere manualmente e execute novamente."
    echo "🔧 Dica: Use 'lsof -i :PORTA' para encontrar processos."
    exit 1
fi
echo "✅ Todas as portas críticas estão livres ou ocupadas pelo Docker/CapRover."

# 5. Limpeza containers/serviços/networks/volumes Captain e Swarm
echo ""
echo "🧹 Limpando resíduos Captain/Swarm..."

# Remove containers Captain/CapRover (independente do modo de execução)
echo "🧹 Removendo containers Captain/CapRover..."
docker ps -a --format "{{.ID}}\t{{.Names}}" | grep -E "$CAPTAIN_NAME|caprover" | awk '{print $1}' | xargs -r docker rm -f || true

# Remove qualquer serviço swarm Captain/CapRover
echo "🧹 Removendo serviços Swarm Captain/CapRover..."
docker service ls --format "{{.ID}}\t{{.Name}}" | grep -E "$CAPTAIN_NAME|caprover" | awk '{print $1}' | xargs -r docker service rm || true

# Remove swarm e arquivos residuais
docker swarm leave --force || true
rm -rf /var/lib/docker/swarm

# Remove volumes/networks Captain/CapRover
docker volume ls --format "{{.Name}}" | grep -E "$CAPTAIN_NAME|caprover" | xargs -r docker volume rm || true
docker network ls --format "{{.Name}}" | grep -E "$CAPTAIN_NAME|caprover" | xargs -r docker network rm || true

# Remove diretório de dados Captain
rm -rf /captain
sleep 2

echo "✅ Ambiente limpo."

# Diagnóstico pós-limpeza
echo ""
banner "📋 Diagnóstico pós-limpeza"
echo "Containers restantes:"
docker ps -a

echo "Serviços Swarm restantes:"
docker service ls || echo "(Swarm inativo)"

echo "Volumes restantes:"
docker volume ls

echo "Networks restantes:"
docker network ls

# 6. Criar volume de dados novamente, valida permissões
echo "📂 Validando/criando diretório de volume: /captain"
if [ -d /captain ]; then
    echo "   - Diretório /captain já existe."
else
    mkdir -p /captain
    echo "   - Diretório /captain criado."
fi
# Corrige dono e permissão para UID 1000 (CapRover)
echo "🔧 Garantindo que /captain pertence ao UID 1000 (CapRover) e permissão 755..."
chown -R 1000:1000 /captain
chmod -R 755 /captain
ls -ld /captain
ls -l /captain
OWNER_UID=$(stat -c "%u" /captain)
if [ "$OWNER_UID" != "1000" ]; then
    echo "🛑 Falha ao ajustar proprietário do volume /captain para UID 1000. Verifique permissões e tente novamente."
    exit 1
fi

# 19. Teste de escrita/leitura no /captain
banner "📝 Testando escrita/leitura em /captain"
TESTFILE=/captain/testfile
if dd if=/dev/urandom of=$TESTFILE bs=1M count=1 status=none && cat $TESTFILE > /dev/null; then
    echo "✅ Escrita/leitura OK em /captain"
    rm -f $TESTFILE
else
    echo "🛑 Falha ao testar escrita/leitura em /captain"
    exit 1
fi

# 7. UFW libera as portas necessárias
echo ""
echo "🔓 Liberando portas via UFW..."
ufw allow 80,443,3000,996,7946,4789,2377/tcp || true
ufw allow 7946,4789,2377/udp || true

# 8. Docker system prune (limpeza agressiva)
echo ""
echo "🗑️ Limpando imagens/parada/volumes não usados (docker system prune)..."
docker system prune -af --volumes

# 9. Executa o novo Captain
echo ""
echo "🚢 Executando novo container CapRover..."
docker run -d \
    --restart=always \
    --name captain \
    -p 80:80 -p 443:443 -p 3000:3000 -p 996:996 -p 7946:7946 -p 4789:4789 -p 2377:2377 \
    -v /captain:/captain \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e ACCEPTED_TERMS=true \
    -e MAIN_NODE_IP_ADDRESS="$IP_PUBLICO" \
    -e BY_PASS_PROXY_CHECK='TRUE' \
    caprover/caprover

# 10. Inspeciona volume logo após o start
echo ""
echo "🗂 Conteúdo do volume /captain após start:"
ls -la /captain

# 11. Espera e checa inicialização
echo ""
echo "⏳ Aguardando CapRover iniciar (60s) =="
for i in {60..0..10}; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏱️  Aguardando... $i segundos restantes"
    sleep 10
done

echo ""
echo "🔍 Testando se porta 3000 está ativa =="
PORTA_OK=false
if ss -ltnp | grep ':3000' > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Porta 3000 escutando"
    PORTA_OK=true
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Porta 3000 NÃO está escutando"
fi

echo ""
echo "\n🌐 Testando acesso HTTP via curl =="
HTTP_RESPONSE=$(curl -s "http://$IP_PUBLICO:3000")
if echo "$HTTP_RESPONSE" | grep -q 'firewall-passed'; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ CapRover exibiu tela 'firewall-passed'. Diagnóstico automático iniciado."
    banner "🩺 Diagnóstico automático CapRover (firewall-passed)"
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Coletando últimos 100 logs do container CapRover:"
    docker logs --tail=100 captain || echo "⚠️ Não foi possível obter os logs do container."
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Diagnóstico de permissões do volume /captain:"
    ls -ld /captain
    ls -l /captain
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Diagnóstico de portas escutando (ss -ltnp):"
    ss -ltnp
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Diagnóstico de containers ativos:"
    docker ps
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Possíveis causas:"
    echo " - Alguma porta crítica (80, 443, 996, 7946, 4789, 2377) não está realmente liberada para o container CapRover."
    echo " - O volume /captain está com permissão inadequada."
    echo " - O CapRover não conseguiu inicializar algum serviço interno."
    echo " - Verifique os logs acima para detalhes."
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] Fim do diagnóstico automático."
    PORTA_OK=false
elif curl -s "http://$IP_PUBLICO:3000" > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ CapRover respondendo"
    PORTA_OK=true
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ CapRover não respondeu via HTTP. Verifique os logs abaixo."
    PORTA_OK=false
fi

echo ""
echo "📄 Últimos logs do container: =="
docker logs --tail=50 captain || echo "⚠️ Não foi possível obter os logs do container."

# Setup inicial automatizado via CapRover CLI
if [[ "$PORTA_OK" = true ]]; then
    echo ""
    echo "🚀 Automatizando wizard inicial via CapRover CLI..."
    # Variáveis de ambiente esperadas
    ADMIN_PASS="${CAPROVER_ADMIN_PASS:-changeme123}"
    ROOT_DOMAIN="${CAPROVER_ROOT_DOMAIN:-example.com}"
    ADMIN_EMAIL="${CAPROVER_ADMIN_EMAIL:-admin@example.com}"
    # Executa setup automatizado
    caprover serversetup \
      --caproverUrl "http://$IP_PUBLICO:3000" \
      --rootDomain "$ROOT_DOMAIN" \
      --adminPassword "$ADMIN_PASS" \
      --emailAddress "$ADMIN_EMAIL" \
      --newPassword "$ADMIN_PASS" \
      --skipVerifySsl
    SETUP_EXIT=$?
    if [ $SETUP_EXIT -eq 0 ]; then
        echo "✅ Wizard inicial CapRover concluído com sucesso via CLI!"
        echo "  - Domínio configurado: $ROOT_DOMAIN"
        echo "  - Usuário admin: $ADMIN_EMAIL"
        echo "  - Senha: $ADMIN_PASS"
    else
        echo "🛑 Falha ao executar wizard inicial via CLI. Verifique logs acima e tente manualmente via navegador."
    fi
else
    echo "⚠️ CapRover não está ativo, wizard CLI não será executado."
fi

# 24. Relatório final
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo ""
echo "📝 Relatório Final:"
echo "  - Início: $START_TIME"
echo "  - Fim:   $END_TIME"
echo "  - IP Público: $IP_PUBLICO"
echo "  - Portas validadas: ${PORTAS[*]}"
echo ""
if [ "$PORTA_OK" = true ]; then
    echo "== ✅ Finalizado com sucesso. Acesse: http://$IP_PUBLICO:3000 =="
else
    echo "== ❌ Finalizado, mas o CapRover não está acessível na porta 3000. Verifique os logs acima. =="
fi