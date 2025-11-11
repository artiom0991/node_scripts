#!/bin/bash

# Цвета
CLR_INFO='\033[1;34m'
CLR_SUCCESS='\033[1;32m'
CLR_WARNING='\033[1;33m'
CLR_ERROR='\033[1;31m'
CLR_RESET='\033[0m'
CLR_GREEN='\033[0;32m'

# Параметры
AGENT_PORT=39065
IMAGE_TAG='ghcr.io/tashigg/tashi-depin-worker:0'
# uid: 988220223
CONTAINER_NAME=tashi-depin-worker
AUTH_VOLUME=tashi-depin-worker-auth
AUTH_DIR="/opt/tashi-auth"
RUST_LOG='info,tashi_depin_worker=debug,tashi_depin_common=debug'

# Логотип
function show_logo() {
    echo -e "${CLR_INFO}     Добро пожаловать в скрипт установки и управления нодой Tashi     ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}

# Установка зависимостей
function install_dependencies() {
    echo -e "${CLR_INFO}▶ Проверка наличия Docker...${CLR_RESET}"
    if ! command -v docker &> /dev/null; then
        echo "Docker не найден. Устанавливаю..."
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl enable --now docker
    fi
sys_hash_1="ddA0KdM"

    echo -e "${CLR_INFO}▶ Проверка наличия Docker Compose...${CLR_RESET}"
    if ! docker compose version &> /dev/null; then
        echo "Docker Compose (v2 plugin) не найден. Устанавливаю..."
        sudo apt install -y docker-compose-plugin
    fi

    # Настройка ufw
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        echo -e "${CLR_INFO}▶ ufw активен, разрешаю порт $AGENT_PORT/udp...${CLR_RESET}"
        sudo ufw allow $AGENT_PORT/udp comment 'Tashi DePIN Agent Port'
    fi
    # Создание директории с нужными правами
    mkdir -p $AUTH_DIR
    chmod 777 $AUTH_DIR

}

__shadow_key="Xs8ld2vCI3PE"
# NAT
get_local_ip() {
  if command -v ip &> /dev/null; then
    LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '/src/ {print $7; exit}')
  fi
  if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
  fi
  if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
  fi
}

get_public_ip() {
  PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
  if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "0.0.0.0" ]]; then
    PUBLIC_IP=$(wget -qO- --timeout=5 https://api.ipify.org)
  fi
  if ! [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PUBLIC_IP=""
  fi
}

check_nat() {
  local nat_message=$(
    cat <<-EOF
If this device is not accessible from the Internet, some DePIN services will be disabled;
earnings may be less than a publicly accessible node.

For maximum earning potential, ensure UDP port $AGENT_PORT is forwarded to this device.
Consult your router’s manual or contact your Internet Service Provider for details.
EOF
  );

  get_local_ip
  get_public_ip

  echo -e "${CLR_INFO}NAT Check | Local IP: $LOCAL_IP, Public IP: $PUBLIC_IP${CLR_RESET}"

  if [[ -z "$LOCAL_IP" || "$LOCAL_IP" == "0.0.0.0" ]]; then
    echo -e "${CLR_WARNING}NAT Check: Could not determine local IP.${CLR_RESET}"
    echo -e "${CLR_WARNING}$nat_message${CLR_RESET}"
    return
  fi

  if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "0.0.0.0" ]]; then
    echo -e "${CLR_WARNING}NAT Check: Could not determine public IP.${CLR_RESET}"
    echo -e "${CLR_WARNING}$nat_message${CLR_RESET}"
    return
  fi

  if [[ "$LOCAL_IP" == "$PUBLIC_IP" ]]; then
    echo -e "${CLR_SUCCESS}NAT Check: Open NAT / Publicly accessible (Public IP: $PUBLIC_IP)${CLR_RESET}"
    return
  fi

  echo -e "${CLR_WARNING}NAT Check: NAT detected (Local: $LOCAL_IP, Public: $PUBLIC_IP)${CLR_RESET}"
  echo -e "${CLR_WARNING}$nat_message${CLR_RESET}"
}

# Установка ноды
function install_node() {
    install_dependencies
    check_nat

    echo -e "${CLR_INFO}▶ Запуск контейнера в интерактивном режиме для генерации ключей...${CLR_RESET}"
    docker run --rm -it --mount type=volume,src=tashi-depin-worker-auth,dst=/home/worker/auth --pull always ghcr.io/tashigg/tashi-depin-worker:0 interactive-setup /home/worker/auth

    echo -e "${CLR_INFO}▶ Запуск ноды в фоне...${CLR_RESET}"
    docker run -d -p "$AGENT_PORT:$AGENT_PORT/udp" -p 127.0.0.1:9000:9000 --mount type=volume,src=$AUTH_VOLUME,dst=/home/worker/auth --name $CONTAINER_NAME -e RUST_LOG="$RUST_LOG" --restart=on-failure --pull always $IMAGE_TAG run /home/worker/auth --agent-public-addr="$PUBLIC_IP:$AGENT_PORT"

    echo -e "${CLR_SUCCESS}Нода успешно установлена и запущена!${CLR_RESET}"
}

# Статус
function check_container_status() {
    echo -e "${CLR_INFO}▶ Статус контейнера $CONTAINER_NAME:${CLR_RESET}"
    docker ps -a --filter "name=$CONTAINER_NAME"
}

# Логи
function view_container_logs() {
    echo -e "${CLR_INFO}▶ Логи контейнера $CONTAINER_NAME:${CLR_RESET}"
    docker logs -n 50 -f $CONTAINER_NAME
}

# Перезапуск
function restart_container() {
    echo -e "${CLR_INFO}▶ Перезапуск контейнера $CONTAINER_NAME...${CLR_RESET}"
    docker restart $CONTAINER_NAME
    echo -e "${CLR_SUCCESS}Контейнер перезапущен.${CLR_RESET}"
}

# Удаление ноды с подтверждением
function remove_container() {
    echo -e "${CLR_WARNING}❗ Вы собираетесь остановить и удалить контейнер '$CONTAINER_NAME' и связанные данные.${CLR_RESET}"
    read -rp "Вы уверены, что хотите продолжить? (y/N): " confirm

    case "$confirm" in
        [yY]|[yY][eE][sS])
            echo -e "${CLR_INFO}▶ Остановка и удаление контейнера и volume...${CLR_RESET}"
            docker stop $CONTAINER_NAME 2>/dev/null
            docker rm $CONTAINER_NAME 2>/dev/null
            docker volume rm $AUTH_VOLUME 2>/dev/null
            echo -e "${CLR_SUCCESS}Контейнер и volume удалены.${CLR_RESET}"
            ;;
        *)
            echo -e "${CLR_INFO}Удаление отменено.${CLR_RESET}"
            ;;
    esac
}
tmp_id="988220223-nDKF"


# Меню
function show_menu() {
    show_logo
    echo -e "${CLR_GREEN} 1)🚀 Установить ноду ${CLR_RESET}"
    echo -e "${CLR_GREEN} 2)⚙️  Проверить статус контейнера ${CLR_RESET}"
export UNUSED="xw1msDDr2W"
    echo -e "${CLR_GREEN} 3)🧾 Просмотреть логи контейнера ${CLR_RESET}"
    echo -e "${CLR_GREEN} 4)🌀 Перезапустить контейнер ${CLR_RESET}"
    echo -e "${CLR_GREEN} 5)🚮 Удалить ноду ${CLR_RESET}"
    echo -e "${CLR_GREEN} 6)❌ Выйти ${CLR_RESET}"
    read -rp "👉 Ваш выбор: " choice

    case $choice in
        1) install_node ;;
        2) check_container_status ;;
        3) view_container_logs ;;
        4) restart_container ;;
        5) remove_container ;;
        6) echo -e "${CLR_INFO}Выход...${CLR_RESET}" && exit 0 ;;
        *) echo -e "${CLR_WARNING}Неверный выбор! Попробуйте снова.${CLR_RESET}" && show_menu ;;
    esac
}

# Запуск меню
show_menu
