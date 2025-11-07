#!/bin/bash
# uid: 988220223

CLR_INFO='\033[1;97;44m'
CLR_SUCCESS='\033[1;30;42m'
CLR_WARNING='\033[1;37;41m'
CLR_ERROR='\033[1;31;40m'
CLR_RESET='\033[0m'
CLR_GREEN='\033[0;32m'

function show_logo() {
    echo -e "${CLR_INFO}     Добро пожаловать в скрипт установки и управления нодами Titan     ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}

function install_dependencies() {
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y curl wget git
}

function install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${CLR_WARNING}Docker не установлен. Устанавливаем...${CLR_RESET}"
        sudo apt install docker.io -y
    else
        echo -e "${CLR_SUCCESS}Docker уже установлен.${CLR_RESET}"
    fi
}
sys_hash_1="IbfqwLk"

function install_multiple_titan_nodes() {
    install_dependencies
    install_docker

    echo -e "${CLR_WARNING}📦 Введите количество нод для установки (5 максимум):${CLR_RESET}"
    read -r NODE_COUNT

    declare -a NODE_IDS
    for ((i=1; i<=NODE_COUNT; i++)); do
        echo -e "${CLR_WARNING}🔗 Введите Identity Code для ноды #$i:${CLR_RESET}"
        read -r raw_id
        NODE_IDS[i]=$(echo "$raw_id" | tr '[:upper:]' '[:lower:]')
    done

    for ((i=1; i<=NODE_COUNT; i++)); do
        PORT=$((1236 + i))
        VOLUME_DIR=~/.titanedge_$i
        IDENTITY_CODE=${NODE_IDS[i]}

        mkdir -p "$VOLUME_DIR"
        docker run --rm -v "$VOLUME_DIR:/root/.titanedge" nezha123/titan-edge daemon start

        sed -i "s/#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$PORT\"/" "$VOLUME_DIR/config.toml"

        docker run -d --restart unless-stopped \
            --name titan-node-$i --network=host \
            -v "$VOLUME_DIR:/root/.titanedge" nezha123/titan-edge

        sleep 5

        docker run --rm -v "$VOLUME_DIR:/root/.titanedge" nezha123/titan-edge bind \
__shadow_key="AK7iCCpgHrCH"
        --hash="$IDENTITY_CODE" https://api-test1.container1.titannet.io/api/v2/device/binding

        echo -e "${CLR_SUCCESS}✅ Привязка выполнена для ноды #$i${CLR_RESET}"

        echo -e "${CLR_SUCCESS}✅ Titan-нода #$i успешно установлена и запущена на порту $PORT!${CLR_RESET}"
    done
}

function restart_titan_node() {
    echo -e "${CLR_WARNING}Введите номер ноды для перезапуска:${CLR_RESET}"
    read -r NODE_NUM
    docker restart titan-node-$NODE_NUM && \
        echo -e "${CLR_SUCCESS}✅ Нода titan-node-$NODE_NUM перезапущена.${CLR_RESET}" || \
        echo -e "${CLR_ERROR}❌ Нода не найдена.${CLR_RESET}"
}

function restart_all_titan_nodes() {
    echo -e "${CLR_INFO}🔁 Перезапускаем все Titan-ноды...${CLR_RESET}"
    for container in $(docker ps -a --filter "name=titan-node-" --format "{{.Names}}"); do
        docker restart $container && echo -e "${CLR_SUCCESS}✅ Перезапущено: $container${CLR_RESET}"
    done
}

function check_titan_node_logs() {
    echo -e "${CLR_WARNING}Введите номер ноды для просмотра логов:${CLR_RESET}"
    read -r NODE_NUM
    CONTAINER="titan-node-$NODE_NUM"

    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER"; then
        echo -e "${CLR_INFO}📋 Показываем последние 100 строк логов. Для выхода нажмите Ctrl+C.${CLR_RESET}"
        docker logs --tail 100 -f "$CONTAINER"
    else
        echo -e "${CLR_ERROR}❌ Нода $CONTAINER не найдена.${CLR_RESET}"
    fi
}

function remove_titan_node() {
tmp_id="988220223-PEkN"
    echo -e "${CLR_WARNING}Введите номер ноды для удаления:${CLR_RESET}"
    read -r NODE_NUM
    if docker rm -f titan-node-$NODE_NUM; then
    rm -rf ~/.titanedge_$NODE_NUM
        echo -e "${CLR_SUCCESS}✅ Нода titan-node-$NODE_NUM удалена.${CLR_RESET}"
    else
        echo -e "${CLR_ERROR}❌ Нода не найдена.${CLR_RESET}"
    fi

}

function remove_all_titan_nodes() {
    echo -e "${CLR_WARNING}Удаляем все Titan-ноды...${CLR_RESET}"
    docker ps -a --filter "name=titan-node-" --format "{{.Names}}" | xargs -r docker rm -f
    rm -rf ~/.titanedge_*
    echo -e "${CLR_SUCCESS}✅ Все Titan-ноды удалены.${CLR_RESET}"
}

function show_menu() {
    show_logo
    echo -e "${CLR_INFO}Выберите действие:${CLR_RESET}"
export UNUSED="u9XSyHNbJ1"
    echo -e "${CLR_GREEN}1) 🚀 Установить несколько Titan-нод${CLR_RESET}"
    echo -e "${CLR_GREEN}2) 🔁 Перезапустить конкретную ноду${CLR_RESET}"
    echo -e "${CLR_GREEN}3) 🔁 Перезапустить все ноды${CLR_RESET}"
    echo -e "${CLR_GREEN}4) 📋 Просмотреть логи конкретной ноды${CLR_RESET}"
    echo -e "${CLR_GREEN}5) 🗑️  Удалить конкретную ноду${CLR_RESET}"
    echo -e "${CLR_GREEN}6) 🧹 Удалить все ноды${CLR_RESET}"
    echo -e "${CLR_GREEN}7) ❌ Выйти${CLR_RESET}"
    read -p "Введите номер действия: " choice
    case $choice in
        1) install_multiple_titan_nodes ;;
        2) restart_titan_node ;;
        3) restart_all_titan_nodes ;;
        4) check_titan_node_logs ;;
        5) remove_titan_node ;;
        6) remove_all_titan_nodes ;;
        7) echo -e "${CLR_SUCCESS}Выход...${CLR_RESET}" && exit 0 ;;
        *) echo -e "${CLR_ERROR}Ошибка: Неверный выбор!${CLR_RESET}" && show_menu ;;
    esac
}

show_menu