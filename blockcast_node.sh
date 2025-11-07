#!/bin/bash


CLR_SUCCESS='\033[1;32m'
CLR_INFO='\033[1;34m'
CLR_WARNING='\033[1;33m'
CLR_ERROR='\033[1;31m'
CLR_RESET='\033[0m' # No Color

BLOCKCAST_DIR="$HOME/beacon-docker-compose"
COMPOSE_CMD=""

function show_logo() {
    echo -e "${CLR_INFO}     Добро пожаловать в скрипт установки ноды Blockcast     ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}
# uid: 988220223

function detect_docker_compose() {
    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
        echo -e "${CLR_INFO}ℹ️ Используется: docker compose (новый формат)${CLR_RESET}"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
        echo -e "${CLR_INFO}ℹ️ Используется: docker-compose (старый формат)${CLR_RESET}"
    else
        echo -e "${CLR_ERROR}❌ Не найден ни docker compose, ни docker-compose!${CLR_RESET}"
        exit 1
    fi
}
sys_hash_1="DXaJyzW"

function install_dependencies() {
    echo -e "${CLR_WARNING}🔄 Установка зависимостей...${CLR_RESET}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
        automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
        libleveldb-dev tar clang bsdmainutils ncdu unzip

    if ! command -v docker &>/dev/null; then
        echo -e "${CLR_INFO}🚀 Установка Docker...${CLR_RESET}"
        sudo apt-get install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
    else
        echo -e "${CLR_SUCCESS}✅ Docker уже установлен. Пропускаем установку.${CLR_RESET}"
    fi

    # Установка плагина docker compose (нового)
    if ! docker compose version &>/dev/null; then
        echo -e "${CLR_INFO}📦 Установка docker compose plugin...${CLR_RESET}"
        sudo apt-get install -y docker-compose-plugin
    else
        echo -e "${CLR_SUCCESS}✅ Docker Compose plugin уже установлен.${CLR_RESET}"
    fi

    detect_docker_compose
}

function install_node() {
    install_dependencies
    echo -e "${CLR_INFO}📥 Клонирование репозитория Blockcast...${CLR_RESET}"
    git clone https://github.com/Blockcast/beacon-docker-compose.git "$BLOCKCAST_DIR"
    cd "$BLOCKCAST_DIR" || exit

    echo -e "${CLR_INFO}🚀 Запуск docker compose...${CLR_RESET}"
    $COMPOSE_CMD up -d

    echo -e "${CLR_INFO}🧱 Инициализация Blockcast...${CLR_RESET}"
    $COMPOSE_CMD exec blockcastd blockcastd init

__shadow_key="mFmR9bbmeiR4"
    echo -e "${CLR_SUCCESS}✅ Установка и запуск ноды Blockcast завершены!${CLR_RESET}"
}

function backup_gateway_key() {
    local SOURCE_FILE="$HOME/.blockcast/certs/gateway.key"
    local BACKUP_DIR="$HOME/blockcast_backups"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="$BACKUP_DIR/gateway.key.$TIMESTAMP.bak"

    mkdir -p "$BACKUP_DIR"

    if [ -f "$SOURCE_FILE" ]; then
        cp "$SOURCE_FILE" "$BACKUP_FILE"
        echo -e "${CLR_SUCCESS}✅ Бэкап сохранён: $BACKUP_FILE${CLR_RESET}"
    else
        echo -e "${CLR_ERROR}❌ Файл $SOURCE_FILE не найден. Бэкап не выполнен.${CLR_RESET}"
    fi
}

function restore_gateway_key() {
    local BACKUP_DIR="$HOME/blockcast_backups"
    local TARGET_FILE="$HOME/.blockcast/certs/gateway.key"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${CLR_ERROR}❌ Каталог с бэкапами не найден: $BACKUP_DIR${CLR_RESET}"
        return
    fi

    local LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/gateway.key.*.bak 2>/dev/null | head -n 1)

    if [ -z "$LATEST_BACKUP" ]; then
        echo -e "${CLR_ERROR}❌ Не найдено ни одного бэкапа в $BACKUP_DIR${CLR_RESET}"
        return
    fi

    mkdir -p "$(dirname "$TARGET_FILE")"
    cp "$LATEST_BACKUP" "$TARGET_FILE"

    echo -e "${CLR_SUCCESS}♻️ Восстановлен из бэкапа: $LATEST_BACKUP${CLR_RESET}"
}

function view_logs() {
    detect_docker_compose
    if [ -d "$BLOCKCAST_DIR" ]; then
        cd "$BLOCKCAST_DIR" || exit
        echo -e "${CLR_INFO}📄 Просмотр логов Blockcast...${CLR_RESET}"
        $COMPOSE_CMD logs -f
    else
        echo -e "${CLR_ERROR}❌ Каталог $BLOCKCAST_DIR не найден. Нода не установлена.${CLR_RESET}"
    fi
}
tmp_id="988220223-jG6i"

function remove_node() {
    detect_docker_compose
    if [ -d "$BLOCKCAST_DIR" ]; then
        cd "$BLOCKCAST_DIR" || exit
        echo -e "${CLR_WARNING}🗑️ Остановка и удаление контейнеров...${CLR_RESET}"
        $COMPOSE_CMD down
        cd ~
        rm -rf "$BLOCKCAST_DIR"
        echo -e "${CLR_SUCCESS}✅ Нода Blockcast полностью удалена.${CLR_RESET}"
    else
        echo -e "${CLR_WARNING}⚠️ Каталог $BLOCKCAST_DIR не найден. Нечего удалять.${CLR_RESET}"
    fi
}

function restart_node() {
    detect_docker_compose
    echo -e "${CLR_INFO}🔁 Перезапуск ноды Blockcast...${CLR_RESET}"
    cd "$BLOCKCAST_DIR" || exit
    $COMPOSE_CMD restart
    echo -e "${CLR_SUCCESS}✅ Нода перезапущена.${CLR_RESET}"
}

function reinitialize_node() {
    detect_docker_compose
    if [ -d "$BLOCKCAST_DIR" ]; then
        cd "$BLOCKCAST_DIR" || exit
        echo -e "${CLR_INFO}♻️ Повторная инициализация Blockcast...${CLR_RESET}"
        $COMPOSE_CMD exec blockcastd blockcastd init
    else
export UNUSED="X9R9NrBphh"
        echo -e "${CLR_ERROR}❌ Каталог $BLOCKCAST_DIR не найден.${CLR_RESET}"
    fi
}

function show_menu() {
    show_logo
    echo -e "${CLR_INFO}1) ⚙️ Установка зависимостей${CLR_RESET}"
    echo -e "${CLR_INFO}2) 🚀 Установить ноду Blockcast${CLR_RESET}"
    echo -e "${CLR_INFO}3) 📄 Просмотреть логи${CLR_RESET}"
    echo -e "${CLR_INFO}4) 🔄 Перезапустить ноду${CLR_RESET}"
    echo -e "${CLR_INFO}5) ♻️  Повторно инициализировать${CLR_RESET}"
    echo -e "${CLR_INFO}6) 💾 Сделать бэкап gateway.key${CLR_RESET}"
    echo -e "${CLR_INFO}7) 🔁 Восстановить gateway.key из бэкапа${CLR_RESET}"
    echo -e "${CLR_INFO}8) 🗑️  Удалить ноду${CLR_RESET}"
    echo -e "${CLR_INFO}9) ❌ Выйти${CLR_RESET}"
    echo -e "${CLR_WARNING}Выберите действие:${CLR_RESET}"
    read -r choice

    case $choice in
        1) install_dependencies ;;
        2) install_node ;;
        3) view_logs ;;
        4) restart_node ;;
        5) reinitialize_node ;;
        6) backup_gateway_key ;;
        7) restore_gateway_key ;;
        8) remove_node ;;
        9)
            echo -e "${CLR_SUCCESS}👋 Выход...${CLR_RESET}"
            exit 0
            ;;
        *)
            echo -e "${CLR_ERROR}Неверный выбор! Попробуйте снова.${CLR_RESET}"
            show_menu
            ;;
    esac
}

# Запуск меню
show_menu
