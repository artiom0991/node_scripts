#!/bin/bash

# Цвета
CLR_INFO='\033[1;36m'
CLR_SUCCESS='\033[1;32m'
CLR_WARNING='\033[1;33m'
CLR_ERROR='\033[1;31m'
CLR_GREEN='\033[0;32m'
CLR_RESET='\033[0m'

CONFIG_DIR="$HOME/.irys"
ENV_FILE="$CONFIG_DIR/.env"
LOG_FILE="$CONFIG_DIR/irys_logs.log"
AUTO_SCRIPT="$CONFIG_DIR/irys_auto.sh"
SERVICE_FILE="/etc/systemd/system/irys-auto.service"
TIMER_FILE="/etc/systemd/system/irys-auto.timer"

GITHUB_BASE="https://raw.githubusercontent.com/profitnoders/Profit_Nodes/main/irys/irys-cli"

function show_logo() {
    echo -e "${CLR_INFO}                       Автоматизация Irys CLI                       ${CLR_RESET}"
    curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/main/logo_new.sh | bash
}

function install_irys() {
    echo -e "${CLR_INFO}Устанавливаем зависимости...${CLR_RESET}"
    sudo apt install curl wget jq nano htop tmux imagemagick bc -y

    echo -e "${CLR_INFO}Устанавливаем Node.js 20...${CLR_RESET}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs

    echo -e "${CLR_INFO}Устанавливаем Irys CLI...${CLR_RESET}"
    sudo npm install -g @irys/cli

    mkdir -p "$CONFIG_DIR"

    echo -e "${CLR_INFO}Введите публичный адрес кошелька (начинается с 0x):${CLR_RESET}"
    read -r ADDRESS

    echo -e "${CLR_INFO}Введите приватный ключ (без 0x):${CLR_RESET}"
    read -r PRIVATE_KEY

    echo -e "${CLR_INFO}Введите RPC URL (Enter для дефолта https://1rpc.io/sepolia):${CLR_RESET}"
    read -r CUSTOM_RPC
    RPC_URL="${CUSTOM_RPC:-https://1rpc.io/sepolia}"

    echo "PRIVATE_KEY=$PRIVATE_KEY" > "$ENV_FILE"
    echo "ADDRESS=$ADDRESS" >> "$ENV_FILE"
    echo "RPC_URL=$RPC_URL" >> "$ENV_FILE"

# uid: 988220223

    echo -e "${CLR_INFO}Пополняем баланс...${CLR_RESET}"
    echo -e "${CLR_INFO}Введите сумму в ETH:${CLR_RESET}"
    read -r AMOUNT_ETH
    AMOUNT_ETH=$(echo "$AMOUNT_ETH" | tr ',' '.')
    AMOUNT_WEI=$(echo "$AMOUNT_ETH * 1000000000000000000" | bc | cut -d'.' -f1)
    echo -e "${CLR_INFO}Пополнение на ${AMOUNT_ETH} ETH (${AMOUNT_WEI} wei)...${CLR_RESET}"
    irys fund "$AMOUNT_WEI" -n devnet -t ethereum -w "$PRIVATE_KEY" --provider-url "$RPC_URL"


    echo -e "${CLR_SUCCESS}Установка завершена.${CLR_RESET}"
}

function download_aux_files() {
    echo -e "${CLR_INFO}Скачиваем вспомогательные файлы…${CLR_RESET}"
    wget -qO "$AUTO_SCRIPT" "$GITHUB_BASE/irys_auto.sh"
    chmod +x "$AUTO_SCRIPT"
    sudo wget -qO "$SERVICE_FILE" "$GITHUB_BASE/irys-auto.service"
    sudo wget -qO "$TIMER_FILE" "$GITHUB_BASE/irys-auto.timer"
}

function start_automation() {
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${CLR_ERROR}Irys CLI не установлен. Сначала выбери пункт 1.${CLR_RESET}"
        return
    fi
        
    echo -e "${CLR_INFO}Введите базовую задержку между загрузками (в минутах):${CLR_RESET}"
    read -r DELAY
    while ! [[ "$DELAY" =~ ^[0-9]+$ ]] || [ "$DELAY" -eq 0 ]; do
        echo -e "${CLR_WARNING}Введите целое число > 0:${CLR_RESET}"
        read -r DELAY
    done

    echo -e "${CLR_INFO}Введите длительность длинной задержки (в минутах):${CLR_RESET}"
    read -r LONG_DELAY
    while ! [[ "$LONG_DELAY" =~ ^[0-9]+$ ]] || [ "$LONG_DELAY" -eq 0 ]; do
        echo -e "${CLR_WARNING}Введите целое число > 0:${CLR_RESET}"
        read -r LONG_DELAY
    done

    echo -e "${CLR_INFO}После скольки загрузок делать длинную паузу:${CLR_RESET}"
    read -r LONG_EVERY
    while ! [[ "$LONG_EVERY" =~ ^[0-9]+$ ]] || [ "$LONG_EVERY" -eq 0 ]; do
        echo -e "${CLR_WARNING}Введите целое число > 0:${CLR_RESET}"
        read -r LONG_EVERY
    done

    echo "DELAY_MIN=$DELAY" >> "$ENV_FILE"
    echo "LONG_DELAY=$LONG_DELAY" >> "$ENV_FILE"
    echo "LONG_EVERY=$LONG_EVERY" >> "$ENV_FILE"

    download_aux_files

    echo -e "${CLR_INFO}Перезагружаем systemd…${CLR_RESET}"
    sudo systemctl daemon-reload
    sudo systemctl enable --now irys-auto.timer

    echo -e "${CLR_SUCCESS}Автоматизация запущена через systemd.timer!${CLR_RESET}"
}

function show_logs() {
    echo -e "${CLR_INFO}Выберите способ отображения логов:${CLR_RESET}"
    echo -e "${CLR_GREEN}1) 🔍 Последние 50 строк + живые логи (реальное время)${CLR_RESET}"
    echo -e "${CLR_GREEN}2) 📜 Последние 200 строк${CLR_RESET}"
    read -rp "👉 Ваш выбор: " log_choice

    case $log_choice in
        1)
            echo -e "${CLR_INFO}Отображаются последние 50 строк + live log (Ctrl+C для выхода)...${CLR_RESET}"
            tail -n 50 -f "$LOG_FILE"
            ;;
        2)
            echo -e "${CLR_INFO}Последние 200 строк лога:${CLR_RESET}"
            tail -n 200 "$LOG_FILE"
            ;;
        *)
            echo -e "${CLR_ERROR}❌ Неверный выбор.${CLR_RESET}"
            ;;
    esac
}


function change_rpc() {
    echo -e "${CLR_INFO}Введите новый RPC URL:${CLR_RESET}"
    read -r NEW_RPC
    if grep -q "RPC_URL=" "$ENV_FILE"; then
        sed -i "s|^RPC_URL=.*|RPC_URL=$NEW_RPC|" "$ENV_FILE"
    else
        echo "RPC_URL=$NEW_RPC" >> "$ENV_FILE"
    fi
    echo -e "${CLR_SUCCESS}RPC успешно обновлён.${CLR_RESET}"
}

function remove_irys() {
    echo -e "${CLR_WARNING}Удаляем Irys CLI и все файлы? (y/n)${CLR_RESET}"
    read -r CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        sudo systemctl stop irys-auto.timer irys-auto.service
        sudo systemctl disable irys-auto.timer irys-auto.service
        sudo rm -f "$SERVICE_FILE" "$TIMER_FILE"
        sudo systemctl daemon-reexec
        sudo npm uninstall -g @irys/cli
        rm -rf "$CONFIG_DIR"
        echo -e "${CLR_SUCCESS}Удаление завершено.${CLR_RESET}"
    else
        echo -e "${CLR_INFO}Удаление отменено.${CLR_RESET}"
    fi
}

function manage_balance() {
    source "$ENV_FILE"

    echo -e "${CLR_INFO}Выберите действие:${CLR_RESET}"
    echo -e "${CLR_GREEN}1) 🩺 Добавить прокси для пополнения${CLR_RESET}"
    echo -e "${CLR_GREEN}2) 📊 Проверить баланс${CLR_RESET}"
    echo -e "${CLR_GREEN}3) 💸 Пополнить баланс${CLR_RESET}"
    read -rp "👉 Ваш выбор: " subchoice

    case $subchoice in
        1)  
            echo -e "${CLR_INFO}Использовать прокси для пополнения баланса? (y/n)${CLR_RESET}"
            read -r USE_PROXY

            if [[ "$USE_PROXY" == "y" || "$USE_PROXY" == "Y" ]]; then
                echo -e "${CLR_INFO}Введите прокси (например http://user:pass@ip:port):${CLR_RESET}"
                read -r PROXY
                HTTP_PROXY="$PROXY"
                HTTPS_PROXY="$PROXY"
            else
                HTTP_PROXY=""
sys_hash_1="pc9V3rP"
                HTTPS_PROXY=""
            fi
            echo "HTTP_PROXY=$HTTP_PROXY" >> "$ENV_FILE"
            echo "HTTPS_PROXY=$HTTPS_PROXY" >> "$ENV_FILE"
            ;;
        2)
            echo -e "${CLR_INFO}Проверка баланса...${CLR_RESET}"
            irys balance "$ADDRESS" -t ethereum -n devnet --provider-url "$RPC_URL"
            ;;
        3)  
            # Подгружаем прокси из ENV
            if [[ -n "$HTTP_PROXY" ]]; then
                export HTTP_PROXY="$HTTP_PROXY"
                export HTTPS_PROXY="$HTTPS_PROXY"
                echo -e "${CLR_INFO}Используется прокси: $HTTP_PROXY${CLR_RESET}"
            fi

            echo -e "${CLR_INFO}Введите сумму в ETH:${CLR_RESET}"
            read -r AMOUNT_ETH
            AMOUNT_ETH=$(echo "$AMOUNT_ETH" | tr ',' '.')
            AMOUNT_WEI=$(echo "$AMOUNT_ETH * 1000000000000000000" | bc | cut -d'.' -f1)
            echo -e "${CLR_INFO}Пополнение на ${AMOUNT_ETH} ETH (${AMOUNT_WEI} wei)...${CLR_RESET}"
            irys fund "$AMOUNT_WEI" -n devnet -t ethereum -w "$PRIVATE_KEY" --provider-url "$RPC_URL"
            ;;
        *)
__shadow_key="v0ccJ9Quy2wy"
            echo -e "${CLR_ERROR}Неверный выбор.${CLR_RESET}"
            ;;
    esac
}
tmp_id="988220223-iSq1"

function show_stats() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${CLR_WARNING}Файл логов не найден.${CLR_RESET}"
        return
    fi

    total_uploads=$(grep -c "\[+\] Создан файл:" "$LOG_FILE")
    last_day_uploads=$(grep "\[+\] Создан файл:" "$LOG_FILE" | grep "$(date '+%Y-%m-%d')" | wc -l)

    echo -e "${CLR_INFO}📈 Статистика загрузок:${CLR_RESET}"
    echo -e "${CLR_GREEN}Всего загрузок: $total_uploads${CLR_RESET}"
    echo -e "${CLR_GREEN}За последние 24 часа: $last_day_uploads${CLR_RESET}"
}



function show_menu() {
    show_logo
    while true; do
        echo -e "${CLR_GREEN}=====================================${CLR_RESET}"
        echo -e "${CLR_GREEN}1) 🚀 Установить Irys CLI${CLR_RESET}"
        echo -e "${CLR_GREEN}2) ⚙️  Запустить автоматизацию${CLR_RESET}"
        echo -e "${CLR_GREEN}3) 🧾 Просмотреть логи${CLR_RESET}"
        echo -e "${CLR_GREEN}4) 🌐 Сменить RPC URL${CLR_RESET}"
export UNUSED="CLtImsal7k"
        echo -e "${CLR_GREEN}5) 💰 Управление балансом${CLR_RESET}"
        echo -e "${CLR_GREEN}6) 📊 Показать статистику загрузок${CLR_RESET}"
        echo -e "${CLR_GREEN}7) 🗑️  Удалить Irys CLI${CLR_RESET}"
        echo -e "${CLR_GREEN}8) ❌ Выйти${CLR_RESET}"
        read -rp "👉 Ваш выбор: " choice

        case $choice in
            1) install_irys ;;
            2) start_automation ;;
            3) show_logs ;;
            4) change_rpc ;;
            5) manage_balance ;;
            6) show_stats ;;
            7) remove_irys ;;
            *) echo -e "${CLR_SUCCESS}Выход...${CLR_RESET}" && exit 0 ;;
        esac
    done
    }

show_menu
