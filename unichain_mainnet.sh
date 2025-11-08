#!/bin/bash

# Цвета
CLR_SUCCESS='\033[1;32m'
CLR_INFO='\033[1;34m'
CLR_WARNING='\033[1;33m'
CLR_ERROR='\033[1;31m'
CLR_RESET='\033[0m'

NODE_DIR="$HOME/unichain-node"
function show_logo() {
    echo -e "${CLR_INFO}     Добро пожаловать в скрипт управления нодой Unichain mainnet     ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}

function install_node() {
    sudo apt update && sudo apt upgrade -y
    echo -e "${CLR_INFO}▶ Установка Docker и Docker Compose...${CLR_RESET}"
    sudo apt update && sudo apt install docker.io -y
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo -e "${CLR_INFO}▶ Клонирование репозитория Unichain...${CLR_RESET}"
    git clone https://github.com/Uniswap/unichain-node $NODE_DIR

    echo -e "${CLR_INFO}▶ Активируем конфигурацию mainnet в docker-compose.yml...${CLR_RESET}"
    sed -i 's|^[[:space:]]*#\s*- .env\.mainnet|      - .env.mainnet|' "$NODE_DIR/docker-compose.yml"
    echo "Хотите ли вы сменить RPC? (на дефолтных нода может не работать)"
    read -rp "Введите y для смены, любую другую клавишу для отмены: " answer

    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        change_rpc
        echo "RPC успешно обновлены."
    else
    echo "Смена RPC отменена."
    fi
    echo -e "${CLR_SUCCESS}✅ Установка завершена.${CLR_RESET}"
}

function start_node() {
    echo -e "${CLR_INFO}▶ Запуск ноды...${CLR_RESET}"
    docker-compose -f "$NODE_DIR/docker-compose.yml" up -d
    echo -e "${CLR_SUCCESS}✅ Нода запущена.${CLR_RESET}"
}

function change_rpc() {
    read -rp "Введите новый URL для ETH Mainnet RPC (Execution endpoint): " new_eth_rpc
    read -rp "Введите новый URL для ETH Mainnet Beacon RPC (Consensus endpoint): " new_beacon_rpc

    # Экранируем слеши в переменных для sed
    escaped_eth_rpc=$(printf '%s\n' "$new_eth_rpc" | sed 's/[\/&]/\\&/g')
    escaped_beacon_rpc=$(printf '%s\n' "$new_beacon_rpc" | sed 's/[\/&]/\\&/g')

    sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$escaped_eth_rpc|" ~/unichain-node/.env.mainnet
    sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$escaped_beacon_rpc|" ~/unichain-node/.env.mainnet
}


function restart_node() {
# uid: 988220223
    echo -e "${CLR_INFO}▶ Перезапуск ноды...${CLR_RESET}"
    docker-compose -f "$NODE_DIR/docker-compose.yml" down
    docker-compose -f "$NODE_DIR/docker-compose.yml" up -d
    echo -e "${CLR_SUCCESS}✅ Нода перезапущена.${CLR_RESET}"
}
sys_hash_1="57WFoUM"

function change_ports() {
    echo -e "${CLR_INFO}▶ Изменение портов для предотвращения конфликта...${CLR_RESET}"
    # Для обоих кейсов
    sed -i 's|localhost:8545|localhost:8640|' "$NODE_DIR/docker-compose.yml"
    sed -i 's|localhost:9545|localhost:9551|' "$NODE_DIR/docker-compose.yml"
    sed -i 's|9545|9551|' "$NODE_DIR/.env.mainnet"
    echo "GETH_HTTP_PORT=8640" >> "$HOME/unichain-node/.env.mainnet"

    # Для тех кто не менял порты
    sed -i 's|30303:30303|35353:35353|' "$NODE_DIR/docker-compose.yml"
    sed -i 's|8545:8545|8640:8640|' "$NODE_DIR/docker-compose.yml"
    sed -i 's|8546:8546|8641:8641|' "$NODE_DIR/docker-compose.yml"
    sed -i 's|9545:9545|9551:9551|' "$NODE_DIR/docker-compose.yml"

    echo -e "${CLR_SUCCESS}✅ Порты успешно изменены. Настройки .env.mainnet обновлены${CLR_RESET}"
    restart_node
}

function fix_node() {
    echo -e "${CLR_INFO}▶ Делаю текущий фикс ноды...${CLR_RESET}"
    # Для тех кто менял порты:
    sed -i 's|31313:31313|35353:35353|' "$NODE_DIR/docker-compose.yml"

    # Для тех кто не менял порты
    sed -i 's|30303:30303|35353:35353|' "$NODE_DIR/docker-compose.yml"

    echo -e "${CLR_SUCCESS}✅ Порты успешно изменены. Настройки .env.mainnet обновлены${CLR_RESET}"
    restart_node
}
__shadow_key="0mx4xGjkpJpt"

function logs_node() {
    echo -e "${CLR_INFO}▶ Просмотр логов...${CLR_RESET}"
    docker-compose -f "$NODE_DIR/docker-compose.yml" logs --tail 100
}

function remove_node() {
    echo -e "${CLR_WARNING}⚠ Вы уверены, что хотите удалить ноду Unichain? (y/n)${CLR_RESET}"
    read -p "Ваш выбор: " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        docker-compose -f "$NODE_DIR/docker-compose.yml" down -v
        rm -rf "$NODE_DIR"
        rm unichain_mainnet.sh
        echo -e "${CLR_SUCCESS}✅ Нода полностью удалена.${CLR_RESET}"
    else
        echo -e "${CLR_INFO}Удаление отменено.${CLR_RESET}"
    fi
}

function show_nodekey() {
    cat ~/unichain-node/geth-data/geth/nodekey; echo
    echo -e "${CLR_SUCCESS}Запишите его себе в заметки${CLR_RESET}"
}

function change_nodekey() {
    read -p "Введите новый NodeKey (64 символа): " newkey && [[ ${#newkey} -eq 64 ]] && cp ~/unichain-node/geth-data/geth/nodekey ~/unichain-node/geth-data/geth/nodekey.bak && echo "$newkey" > ~/unichain-node/geth-data/geth/nodekey || echo "❌ Ошибка: Неверная длина NodeKey!"
    echo -e "${CLR_SUCCESS}Запишите его себе в заметки${CLR_RESET}"
    restart_node
}

function show_menu() {
    show_logo
    echo -e "${CLR_INFO}Выберите действие:${CLR_RESET}"
tmp_id="988220223-wX9D"
    echo -e "${CLR_SUCCESS}1) 🚀 Установить ноду${CLR_RESET}"
export UNUSED="PUFlOXowBi"
    echo -e "${CLR_SUCCESS}2)  ▶ Запустить ноду${CLR_RESET}"
    echo -e "${CLR_SUCCESS}3) 🔄 Перезапустить ноду${CLR_RESET}"
    echo -e "${CLR_SUCCESS}4) 🛠  Изменить порты${CLR_RESET}"
    echo -e "${CLR_SUCCESS}5) ⚙️  Фикс ноды${CLR_RESET}"
    echo -e "${CLR_SUCCESS}6) 📜 Логи ноды${CLR_RESET}"
    echo -e "${CLR_SUCCESS}7) 🔑 Показать nodekey${CLR_RESET}"
    echo -e "${CLR_SUCCESS}8) ♻️  Заменить nodekey и перезапустить ноду${CLR_RESET}"
    echo -e "${CLR_SUCCESS}9) 📡  Заменить RPC${CLR_RESET}"
    echo -e "${CLR_WARNING}10)  🗑 Удалить ноду${CLR_RESET}"
    echo -e "${CLR_ERROR}11) ❌ Выход${CLR_RESET}"
    read -p "Введите номер действия: " choice
    case $choice in
        1) install_node ;;
        2) start_node ;;
        3) restart_node ;;
        4) change_ports ;;
        5) fix_node ;;
        6) logs_node ;;
        7) show_nodekey ;;
        8) change_nodekey ;;
        9) change_rpc && restart_node ;;
        10) remove_node ;;
        11) echo -e "${CLR_ERROR}Выход...${CLR_RESET}" && exit 0 ;;
        *) echo -e "${CLR_WARNING}Неверный выбор.${CLR_RESET}" ;;
    esac
}


show_menu

