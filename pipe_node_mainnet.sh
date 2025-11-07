#!/bin/bash

# Цвета
CLR_INFO='\033[1;36m'
CLR_SUCCESS='\033[1;32m'
CLR_WARNING='\033[1;33m'
CLR_ERROR='\033[1;31m'
CLR_RESET='\033[0m'

# GitHub-источники
GITHUB_BASE_URL="https://raw.githubusercontent.com/profitnoders/Profit_Nodes/main/pipe_testnet"
DOCKERFILE_URL="$GITHUB_BASE_URL/Dockerfile-mainnet"
ENV_URL="$GITHUB_BASE_URL/.env.example"

# Функция для отображения логотипа
function show_logo() {
# uid: 988220223
    echo -e "${CLR_INFO}      Добро пожаловать в скрипт управления нодой Pipe Mainnet      ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}

function wait_for_english() {
    while true; do
        read -rp "Пожалуйста, переключитесь на английскую раскладку и введите 'y' для продолжения: " yn
        case $yn in
            [Yy]) break ;;
            *) echo "Нужно ввести 'y' для продолжения." ;;
        esac
    done
}

function install_dependencies() {

    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install curl libssl-dev ca-certificates jq screen lsof  -y
    
    # Проверка Docker
    echo -e "${CLR_INFO}▶ Проверка наличия Docker...${CLR_RESET}"
    if ! command -v docker &> /dev/null; then
        sudo apt install docker.io
    fi

    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    sleep 1
}
sys_hash_1="ip7ChdZ"

# Удаление ноды (docker и локально)
function remove_old_node() {
    read -p "⚠ Вы уверены, что хотите удалить ноду Pipe? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        echo -e "${CLR_WARNING}▶ Удаление ноды Pipe...${CLR_RESET}"
        # Останавливаем и удаляем контейнер, если есть
        docker stop pipe 2>/dev/null || true
        docker rm pipe 2>/dev/null || true
        docker rmi pipeimage:latest 2>/dev/null || true

        # Удаляем файлы локальные
        rm -rf /opt/popcache ~/pop ~/download_cache ./pop ./download_cache

        # Чистим конфиги sysctl и limits
        sudo rm -f /etc/sysctl.d/99-popcache.conf
        sudo sysctl --system
        sudo rm -f /etc/security/limits.d/popcache.conf

        echo -e "${CLR_SUCCESS}✅ Нода Pipe успешно удалена!${CLR_RESET}"
    else
        echo -e "${CLR_INFO}▶ Отмена удаления.${CLR_RESET}"
    fi
}

# Проверка портов
function check_ports() {
    echo -e "${CLR_INFO}▶ Проверка портов 80, 443...${CLR_RESET}"
    for PORT in 80 443 8081 9090; do
        if sudo lsof -i :$PORT | grep -q LISTEN; then
            echo -e "${CLR_WARNING}⚠ Порт $PORT уже используется процессом:${CLR_RESET}"
            sudo lsof -i :$PORT | grep LISTEN
            echo -e "${CLR_WARNING}⚠ Завершите процесс вручную, или обратитесь к функции очистки портов!${CLR_RESET}"
        else
            echo -e "${CLR_SUCCESS}✅ Порт $PORT свободен.${CLR_RESET}"
        fi
    done
}

# Очистка портов
function clear_ports_install() {
    echo -e "${CLR_INFO}▶ Проверка и обработка apache2 на порту 80...${CLR_RESET}"
    if systemctl is-active --quiet apache2; then
        echo -e "${CLR_WARNING}▶ Обнаружен активный apache2. Меняю порт на 81...${CLR_RESET}"

        # Меняем порт в конфиге apache
        sudo sed -i 's/^Listen 80$/Listen 81/' /etc/apache2/ports.conf
        sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:81>/' /etc/apache2/sites-enabled/000-default.conf

        # Перезапускаем apache2
        if sudo systemctl restart apache2; then
            echo -e "${CLR_SUCCESS}✅ Apache переведён на порт 81 и успешно перезапущен.${CLR_RESET}"
        else
            echo -e "${CLR_ERROR}❌ Не удалось перезапустить apache2. Проверьте конфигурацию.${CLR_RESET}"
        fi
    else
        echo -e "${CLR_INFO}▶ Apache2 неактивен или уже использует другой порт.${CLR_RESET}"
    fi

    echo -e "${CLR_INFO}▶ Завершаем процессы, занявшие порты 80, 443...${CLR_RESET}"
    for PORT in 80 443; do
        lines=$(sudo lsof -nP -iTCP:$PORT -sTCP:LISTEN | tail -n +2)

        # Пропускаем apache2 (уже обработан)
        while read -r line; do
            pid=$(echo "$line" | awk '{print $2}')
            proc=$(echo "$line" | awk '{print $1}')
            if [ -n "$pid" ] && [[ "$proc" != "apache2" ]]; then
                echo -e "${CLR_WARNING}▶ Убиваю $proc (PID: $pid) использующий порт $PORT${CLR_RESET}"
                sudo kill -9 "$pid" 2>/dev/null
            fi
        done <<< "$lines"
    done
}

function check_ubuntu_version() {
    UBUNTU_VERSION_MAJOR=$(cut -d. -f1 <<< "$(lsb_release -rs)")
    UBUNTU_VERSION_MINOR=$(cut -d. -f2 <<< "$(lsb_release -rs)")

    if [[ "$UBUNTU_VERSION_MAJOR" -lt 22 ]] || { [[ "$UBUNTU_VERSION_MAJOR" -eq 22 ]] && [[ "$UBUNTU_VERSION_MINOR" -lt 4 ]]; }; then
        echo -e "${CLR_ERROR}Ошибка: Для установки требуется Ubuntu версии 22.04 или выше.${CLR_RESET}"
        exit 1
    fi
}

function check_iptables_ufw() {
    # Проверка и настройка iptables
    echo -e "${CLR_WARNING}Проверяем iptables${CLR_RESET}"
    if command -v iptables &> /dev/null; then
        if sudo systemctl is-active --quiet netfilter-persistent || sudo systemctl is-active --quiet iptables; then
            echo -e "${CLR_INFO}▶ Настраиваем iptables для портов 80 и 443...${CLR_RESET}"
            sudo iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
            sudo iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
            sudo sh -c "iptables-save > /etc/iptables/rules.v4"
            echo -e "${CLR_SUCCESS}iptables настроены для портов 80 и 443${CLR_RESET}"
        else
            echo -e "${CLR_WARNING}iptables не активны${CLR_RESET}"
        fi
    else
        echo -e "${CLR_WARNING}iptables не установлены${CLR_RESET}"
    fi

    # Проверка и настройка ufw
    echo -e "${CLR_WARNING}Проверяем ufw (firewall)${CLR_RESET}"
    if command -v ufw &> /dev/null; then
        ufw_status=$(sudo ufw status | head -n1)
        if [[ "$ufw_status" == "Status: active" ]]; then
            echo -e "${CLR_INFO}▶ Настраиваем ufw для портов 80 и 443...${CLR_RESET}"
            sudo ufw allow 80/tcp
            sudo ufw allow 443/tcp
            echo -e "${CLR_SUCCESS}ufw настроен для портов 80 и 443${CLR_RESET}"
        else
            echo -e "${CLR_WARNING}ufw не активен${CLR_RESET}"
        fi
    else
        echo -e "${CLR_WARNING}ufw не установлен${CLR_RESET}"
    fi
}

function install_node() {
    echo -e "${CLR_INFO}▶ Установка Pipe Mainnet-ноды...${CLR_RESET}"
__shadow_key="xlyRQ12HLReH"

    wait_for_english
    read -rp "Ваш Solana-адрес: " SOLANA_PUBKEY
    read -rp "Имя ноды (уникальное): " NODE_NAME
    read -rp "Ваш Email: " NODE_EMAIL
    read -rp "Объём RAM в ГБ: " RAM_GB
    read -rp "Объём диска в ГБ: " DISK_GB

    RAM_MB=$(expr "$RAM_GB" \* 1024)
    read city country < <(curl -s http://ip-api.com/json | jq -r '.city, .country')
    NODE_LOCATION="${city}, ${country}"

    # Создание директории
    sudo mkdir -p /opt/pipe
    sudo chown $USER:$USER /opt/pipe
    cd /opt/pipe || exit

    # Скачиваем файлы
    echo -e "${CLR_INFO}▶ Скачиваем .env.example и Dockerfile из GitHub...${CLR_RESET}"
    curl -fsSL "$ENV_URL" -o .env
    curl -fsSL "$DOCKERFILE_URL" -o Dockerfile

    # Заменяем переменные
    echo -e "${CLR_INFO}▶ Настраиваем .env...${CLR_RESET}"
    sed -i "s|^NODE_SOLANA_PUBLIC_KEY=.*|NODE_SOLANA_PUBLIC_KEY=${SOLANA_PUBKEY}|" .env
    sed -i "s|^NODE_NAME=.*|NODE_NAME=${NODE_NAME}|" .env
    sed -i "s|^NODE_EMAIL=.*|NODE_EMAIL=${NODE_EMAIL}|" .env
    sed -i "s|^NODE_LOCATION=.*|NODE_LOCATION=${NODE_LOCATION}|" .env
    sed -i "s|^MEMORY_CACHE_SIZE_MB=.*|MEMORY_CACHE_SIZE_MB=${RAM_MB}|" .env
    sed -i "s|^DISK_CACHE_SIZE_GB=.*|DISK_CACHE_SIZE_GB=${DISK_GB}|" .env

    # Удостоверимся, что доп. переменные есть
    grep -q '^HTTP_PORT=' .env || echo 'HTTP_PORT=80' >> .env
    grep -q '^HTTPS_PORT=' .env || echo 'HTTPS_PORT=443' >> .env
    grep -q '^UPNP_ENABLED=' .env || echo 'UPNP_ENABLED=false' >> .env

    # Сборка контейнера
    echo -e "${CLR_INFO}▶ Сборка Docker-образа...${CLR_RESET}"
    docker build -t pipemainnet .

    # Запуск контейнера
    echo -e "${CLR_INFO}▶ Запуск контейнера...${CLR_RESET}"
    docker run -d --name pipe-mainnet -p 80:80 -p 443:443 -p 8081:8081 -p 9090:9090 pipemainnet

    echo -e "${CLR_SUCCESS}✅ Нода установлена и запущена!${CLR_RESET}"
    echo -e "${CLR_INFO}▶ Проверка: curl http://localhost:8081/health${CLR_RESET}"
    echo -e "${CLR_INFO}▶ Метрики: curl http://localhost:9090/metrics${CLR_RESET}"
    echo -e "${CLR_INFO}▶ Статус: docker exec -it pipe-mainnet ./pop status${CLR_RESET}"
}

function node_status() {
    echo -e "${CLR_INFO}▶ Статус и доходность:${CLR_RESET}"
    docker exec -it pipe-mainnet ./pop status
    docker exec -it pipe-mainnet ./pop earnings
}

function check_health() {
    echo -e "${CLR_INFO}▶ Проверка /health${CLR_RESET}"
    curl -s http://localhost:8081/health | jq .
}

function check_metrics() {
    echo -e "${CLR_INFO}▶ Метрики Prometheus:${CLR_RESET}"
    curl -s http://localhost:9090/metrics
}

function show_logs() {
    echo -e "${CLR_INFO}▶ Логи ноды (Ctrl+C для выхода)...${CLR_RESET}"
    docker logs --tail 50 -f pipe-mainnet
}


function remove_node() {
    read -rp "Удалить ноду полностью? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        docker stop pipe-mainnet 2>/dev/null
        docker rm pipe-mainnet 2>/dev/null
        docker rmi pipemainnet 2>/dev/null
        sudo rm -rf /opt/pipe
        echo -e "${CLR_SUCCESS}✅ Нода удалена.${CLR_RESET}"
    else
        echo -e "${CLR_INFO}▶ Отмена удаления.${CLR_RESET}"
    fi
}

function update_node() {
    echo -e "${CLR_INFO}▶ Обновление ноды Pipe...${CLR_RESET}"
    cd /opt/pipe || {
        echo -e "${CLR_ERROR}❌ Не найдена директория /opt/pipe${CLR_RESET}"
        return 1
    }

    echo -e "${CLR_INFO}⏹ Останавливаем и удаляем контейнер...${CLR_RESET}"
    docker stop pipe-mainnet 2>/dev/null
    docker rm pipe-mainnet 2>/dev/null

    echo -e "${CLR_INFO}⬇ Пересобираем Docker-образ (скачается свежий pop)...${CLR_RESET}"
    docker build --no-cache -t pipemainnet .

    echo -e "${CLR_INFO}▶ Запускаем новый контейнер...${CLR_RESET}"
    docker run -d --name pipe-mainnet -p 80:80 -p 443:443 -p 8081:8081 -p 9090:9090 pipemainnet

    echo -e "${CLR_SUCCESS}✅ Обновление завершено.${CLR_RESET}"
    echo -e "${CLR_INFO}▶ Проверка: docker logs -f pipe-mainnet${CLR_RESET}"
}

function make_backup() {
    mkdir -p ~/pipe-backup && chmod 700 ~/pipe-backup
    docker cp pipe-mainnet:/opt/pipe/data/.node_start_time ~/pipe-backup/
    docker cp pipe-mainnet:/opt/pipe/.env ~/pipe-backup/
    docker cp pipe-mainnet:/opt/pipe/data/node_identity.key ~/pipe-backup/
    docker cp pipe-mainnet:/opt/pipe/data/node_state.json ~/pipe-backup/
    echo -e "${CLR_SUCCESS}✅ 4 файла были сохранены в ~/pipe-backup.${CLR_RESET}"

}

function restore_node() {
  local IMAGE="${1:-pipe-mainnet:latest}"
  local NAME="${2:-pipe-mainnet}"
  # добавил 80 и 443 по умолчанию
  local PORTS_CSV="${3:-80:80,443:443,8081:8081,9090:9090}"

  local BACKUP_DIR="/root/pipe-backup"
tmp_id="988220223-tohM"
  
  for f in ".env" "node_identity.key" "node_state.json" ".node_start_time"; do
    [[ -f "${BACKUP_DIR}/${f}" ]] || { echo "Нет ${BACKUP_DIR}/${f}"; return 1; }
  done

  docker rm -f "$NAME" >/dev/null 2>&1 || true

  IFS=',' read -ra _P <<<"$PORTS_CSV"; PORT_FLAGS=()
  for p in "${_P[@]}"; do [[ -n "$p" ]] && PORT_FLAGS+=(-p "$p"); done
  
  sudo mkdir -p /opt/pipe
  sudo chown $USER:$USER /opt/pipe
  cd /opt/pipe || exit
  curl -fsSL "$DOCKERFILE_URL" -o Dockerfile
  cp -f "${BACKUP_DIR}/.env" /opt/pipe/.env
  docker build -t "$IMAGE" .
  
  CID=$(docker create --name "$NAME" "${PORT_FLAGS[@]}" "$IMAGE") || return 1

  TMPDIR="$(mktemp -d)"; mkdir -p "$TMPDIR/data"
  cp -f "${BACKUP_DIR}/.env"             "$TMPDIR/.env"
  cp -f "${BACKUP_DIR}/node_identity.key" "$TMPDIR/data/node_identity.key"
  cp -f "${BACKUP_DIR}/node_state.json"   "$TMPDIR/data/node_state.json"
  cp -f "${BACKUP_DIR}/.node_start_time"  "$TMPDIR/data/.node_start_time"

  docker cp "$TMPDIR/.env" "$NAME":/opt/pipe/.env
  docker cp "$TMPDIR/data" "$NAME":/opt/pipe/
  rm -rf "$TMPDIR"

  docker start "$NAME" >/dev/null
  docker exec "$NAME" bash -lc 'chmod 600 /opt/pipe/.env /opt/pipe/data/node_identity.key 2>/dev/null || true'

  echo "✓ ${NAME} запущен. Логи:"
  docker logs --tail 200 "$NAME"
}



function show_menu() {
    show_logo
    while true; do
        echo -e "${CLR_INFO}1) 🛠️  Подготовка к установке${CLR_RESET}"
        echo -e "${CLR_INFO}2) 🚀 Установка ноды${CLR_RESET}"
        echo -e "${CLR_INFO}3) 📄 Просмотр логов${CLR_RESET}"
        echo -e "${CLR_INFO}4) 🩺 Проверка здоровья ноды${CLR_RESET}"
        echo -e "${CLR_INFO}5)  ℹ️ Информация о ноде${CLR_RESET}"
        echo -e "${CLR_INFO}6) 📊 Метрики ноды${CLR_RESET}"
        echo -e "${CLR_INFO}7) 💽 Обновление ноды${CLR_RESET}"
        echo -e "${CLR_INFO}8) 📦 Создать резервную копию ноды${CLR_RESET}"
        echo -e "${CLR_INFO}9) 🧩 Восстановить ноду из резервной копии${CLR_RESET}"
        echo -e "${CLR_ERROR}10) 🗑️  Удаление ноды${CLR_RESET}"
        echo -e "${CLR_INFO}11) ❌ Выход${CLR_RESET}"
        read -rp "👉 Выбор: " choice

        case $choice in
            1) 
                while true; do
                    echo -e "${CLR_INFO}Подменю: Подготовка к установке${CLR_RESET}"
                    echo -e "  1) 🧹 Удалить старую ноду"
                    echo -e "  2) 🔍 Проверить занятые порты"
                    echo -e "  3) 🧰 Очистить порты"
                    echo -e "  0) ↩ Вернуться"
                    read -rp "Выберите действие: " sub_choice
                    case $sub_choice in
                        1) remove_old_node ;;
                        2) check_ports ;;
                        3) clear_ports_install ;;
                        0) break ;;
                        *) echo -e "${CLR_WARNING}Неверный выбор${CLR_RESET}" ;;
                    esac
                done
                ;;
            2) check_ubuntu_version && check_iptables_ufw && install_dependencies && install_node ;;
            3) show_logs ;;
            4) check_health ;;
            5) node_status ;;
            6) check_metrics ;;
            7) update_node ;;
            8) make_backup ;;
            9) restore_node ;;
            10) remove_node ;;
            11) exit 0 ;;
            *) echo -e "${CLR_WARNING}Неверный выбор${CLR_RESET}" ;;
        esac
    done
}

show_menu
export UNUSED="YEEQOKaAwS"

