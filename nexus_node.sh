#!/bin/bash

# Оформление текста: цвета и фоны
CLR_INFO='\033[1;97;44m'   # Белый текст на синем фоне
CLR_SUCCESS='\033[1;30;42m' # Зеленый текст на черном фоне
CLR_WARNING='\033[1;37;41m' # Белый текст на красном фоне
CLR_ERROR='\033[1;31;40m'  # Красный текст на черном фоне
CLR_RESET='\033[0m'        # Сброс форматирования
CLR_GREEN='\033[0;32m'     # Зеленый текст

PROXY_ARG=""
PROXY_URL=""      # чистый URL прокси (http://user:pass@host:port)
THREADS_ARG=""

# ───────────────────────── Общие функции ─────────────────────────

function show_logo() {
  echo -e "${CLR_INFO}        Добро пожаловать в скрипт установки Nexus III Node          ${CLR_RESET}"
  curl -s https://raw.githubusercontent.com/profitnoders/Profit_Nodes/refs/heads/main/logo_new.sh | bash
}

function install_dependencies() {
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y screen wget curl htop
  # Проверка Docker
  echo -e "${CLR_INFO}▶ Проверка наличия Docker...${CLR_RESET}"
  if ! command -v docker &>/dev/null; then
    echo "Docker не найден. Устанавливаю..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    sudo systemctl enable --now docker
  fi
  sudo usermod -aG docker "$USER"
  sleep 1
}
# uid: 988220223

# ───────────────────────── Docker-вариант ─────────────────────────

function install_node() {
  install_dependencies
  echo -e "${CLR_INFO}▶ Установка Nexus Node (Docker)...${CLR_RESET}"

  read -p "Введите ваш NODE_ID: " NODE_ID
  if [ -z "$NODE_ID" ]; then
    echo -e "${CLR_ERROR}❌ NODE_ID не может быть пустым.${CLR_RESET}"
    return
  fi
  echo "$NODE_ID" > ~/.nexus_node_id

  echo -e "${CLR_INFO}📦 Загружаем Docker-образ nexusxyz/nexus-cli:latest...${CLR_RESET}"
  docker pull nexusxyz/nexus-cli:latest

  echo -e "${CLR_INFO}🚀 Запускаем контейнер с вашей нодой...${CLR_RESET}"
  get_proxy_flag
  get_multithread_flag
  screen -dmS nexus_node docker run -it --init --name nexus3 $PROXY_ARG nexusxyz/nexus-cli:latest start --node-id "$NODE_ID" $THREADS_ARG

  echo -e "${CLR_SUCCESS}✔ Nexus Node запущена в screen-сессии nexus_node!${CLR_RESET}"
  echo -e "${CLR_SUCCESS}Логи: screen -r nexus_node${CLR_RESET}"
}

function restart_node() {
  echo -e "${CLR_INFO}▶ Завершаю скрин-сессию nexus_node...${CLR_RESET}"
  screen -S nexus_node -X quit 2>/dev/null
  docker stop nexus3 2>/dev/null
  docker rm nexus3 2>/dev/null

  echo -e "${CLR_INFO}▶ Уточняю наличие NODE_ID в файле...${CLR_RESET}"
  if [ -f ~/.nexus_node_id ]; then
    NODE_ID=$(cat ~/.nexus_node_id)
    echo -e "${CLR_INFO}✔ Используем сохранённый NODE_ID: $NODE_ID${CLR_RESET}"
  else
    read -p "Введите ваш NODE_ID: " NODE_ID
  fi
sys_hash_1="pgUyvBZ"

  get_proxy_flag
  get_multithread_flag
  screen -dmS nexus_node docker run -it --init --name nexus3 $PROXY_ARG nexusxyz/nexus-cli:latest start --node-id "$NODE_ID" $THREADS_ARG

  echo -e "${CLR_SUCCESS}✔ Перезапущено! Логи: screen -r nexus_node${CLR_RESET}"
}

function update_node() {
  echo -e "${CLR_INFO}🔄 Обновление Nexus Node (Docker)...${CLR_RESET}"
  docker pull nexusxyz/nexus-cli:latest
  docker stop nexus3 2>/dev/null
  docker rm nexus3 2>/dev/null
  screen -S nexus_node -X quit 2>/dev/null

  if [ -f ~/.nexus_node_id ]; then
    NODE_ID=$(cat ~/.nexus_node_id)
    echo -e "${CLR_INFO}✔ Используем сохранённый NODE_ID: $NODE_ID${CLR_RESET}"
  else
    read -p "Введите ваш NODE_ID: " NODE_ID
  fi

  get_proxy_flag
  get_multithread_flag
  screen -dmS nexus_node docker run -it --init --name nexus3 $PROXY_ARG nexusxyz/nexus-cli:latest start --node-id "$NODE_ID" $THREADS_ARG

  echo -e "${CLR_SUCCESS}✔ Обновление завершено! Логи: screen -r nexus_node${CLR_RESET}"
}

function remove_node() {
  echo -n "❗ Вы уверены, что хотите удалить ноду (Docker)? (y/N): "
  read confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "🧹 Останавливаем и удаляем ноду..."
    docker stop nexus3 2>/dev/null
    docker rm nexus3 2>/dev/null
    docker rmi nexusxyz/nexus-cli:latest 2>/dev/null
    screen -S nexus_node -X quit 2>/dev/null
    rm -f ~/.nexus_node_id
    echo "✅ Нода (Docker) успешно удалена."
  else
__shadow_key="mp99RGULs3h1"
    echo "⛔ Удаление отменено."
  fi
}

function node_status() {
  docker ps -a | grep nexus3
}
tmp_id="988220223-kKIx"


function install_cli_native() {
  echo -e "${CLR_INFO}▶ Установка Nexus CLI (native)...${CLR_RESET}"

  # Прокси при необходимости
  local PROXY_ENV=""
  if [[ -n "$PROXY_URL" ]]; then
    PROXY_ENV="export http_proxy=\"$PROXY_URL\" https_proxy=\"$PROXY_URL\" no_proxy=\"localhost,127.0.0.1,::1\";"
  fi

  # Тихая установка
  bash -lc "$PROXY_ENV curl -sSf https://cli.nexus.xyz/ -o /tmp/nexus_install.sh"
  chmod +x /tmp/nexus_install.sh
  NONINTERACTIVE=1 /tmp/nexus_install.sh || true

  # Добавляем PATH во все типичные rc-файлы
  for f in "$HOME/.bashrc"; do
    [[ -f "$f" ]] || touch "$f"
    if ! grep -q 'export PATH="$HOME/.nexus/bin:$PATH"' "$f"; then
      echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> "$f"
    fi
  done

  # Мгновенно поднимем PATH в текущей сессии
  export PATH="$HOME/.nexus/bin:$PATH"
  echo -e "${CLR_SUCCESS}✔ PATH обновлён.${CLR_RESET}"
}


function run_node_native() {
  echo -e "${CLR_INFO}▶ Запуск ноды без Docker (native)...${CLR_RESET}"

  # NODE_ID
  if [ -f ~/.nexus_node_id ]; then
    NODE_ID=$(cat ~/.nexus_node_id)
    echo -e "${CLR_INFO}✔ Используем сохранённый NODE_ID: $NODE_ID${CLR_RESET}"
  else
    read -p "Введите ваш NODE_ID: " NODE_ID
    [[ -n "$NODE_ID" ]] || { echo -e "${CLR_ERROR}❌ NODE_ID пуст.${CLR_RESET}"; return 1; }
    echo "$NODE_ID" > ~/.nexus_node_id
  fi

  get_proxy_flag
  get_multithread_flag

  if ! command -v nexus-network >/dev/null 2>&1 && ! command -v nexus-cli >/dev/null 2>&1; then
    echo -e "${CLR_INFO}▶ Nexus CLI не найден. Устанавливаю...${CLR_RESET}"
    install_cli_native
  fi

  BIN_PATH="$(command -v nexus-network || true)"
  [[ -z "$BIN_PATH" ]] && BIN_PATH="$(command -v nexus-cli || true)"
  [[ -z "$BIN_PATH" && -x "$HOME/.nexus/bin/nexus-network" ]] && BIN_PATH="$HOME/.nexus/bin/nexus-network"
  [[ -z "$BIN_PATH" && -x "$HOME/.nexus/bin/nexus-cli" ]] && BIN_PATH="$HOME/.nexus/bin/nexus-cli"

  if [[ -z "$BIN_PATH" ]]; then
    echo -e "${CLR_ERROR}❌ Не найден nexus-network / nexus-cli даже после установки.${CLR_RESET}"
    echo -e "${CLR_INFO}Проверьте содержимое $HOME/.nexus/bin и права на файлы.${CLR_RESET}"
    ls -l "$HOME/.nexus/bin" 2>/dev/null || true
    return 1
  fi

  local CMD="\"$BIN_PATH\" start --node-id \"$NODE_ID\" $THREADS_ARG"
  local ENV_EXPORT="export PATH=\"$HOME/.nexus/bin:\$PATH\";"
  if [[ -n "$PROXY_URL" ]]; then
    ENV_EXPORT="$ENV_EXPORT export http_proxy=\"$PROXY_URL\" https_proxy=\"$PROXY_URL\" no_proxy=\"localhost,127.0.0.1,::1\";"
  fi

  LOGFILE="$HOME/nexus_node.log"
  echo -e "${CLR_INFO}▶ Логи: ${LOGFILE}${CLR_RESET}"
  screen -S nexus_node -X quit 2>/dev/null || true
  screen -dmS nexus_node bash -lc "$ENV_EXPORT $CMD 2>&1 | tee -a '$LOGFILE'"

  sleep 2
  if screen -ls | grep -q '\.nexus_node'; then
    echo -e "${CLR_SUCCESS}✔ Нода запущена: screen -r nexus_node${CLR_RESET}"
  else
    echo -e "${CLR_WARNING}⚠ Похоже, сессия упала. Последние строки лога:${CLR_RESET}"
    tail -n 50 "$LOGFILE" || true
    echo -e "${CLR_INFO}Попробуйте вручную:${CLR_RESET}"
    echo "bash -lc '$ENV_EXPORT $CMD'"
  fi
}



function get_multithread_flag() {
  read -p "❓ Включить мультипоточность? (y/N): " USE_THREADS
  if [[ "$USE_THREADS" == "y" || "$USE_THREADS" == "Y" ]]; then
    read -p "🔢 Введите количество потоков: " NUM_THREADS
    if [[ "$NUM_THREADS" =~ ^[0-9]+$ ]]; then
      THREADS_ARG="--max-threads $NUM_THREADS"
    else
      echo -e "${CLR_WARNING}⚠ Неверное значение. Мультипоточность отключена.${CLR_RESET}"
      THREADS_ARG=""
    fi
  else
    THREADS_ARG=""
  fi
}

function get_proxy_flag() {
  read -p "❓ Использовать прокси? (y/N): " USE_PROXY
  if [[ "$USE_PROXY" == "y" || "$USE_PROXY" == "Y" ]]; then
    if [[ -f ~/.nexus_proxy ]]; then
      SAVED="$(cat ~/.nexus_proxy)"
      echo "📦 Найден сохранённый прокси (Docker-формат):"
      echo "    $SAVED"
      # Пытаемся вытащить URL из сохранённого
      SAVED_URL="$(echo "$SAVED" | sed -n 's/.*http_proxy=\([^ ]*\).*/\1/p')"
      if [[ -n "$SAVED_URL" ]]; then
        echo "→ Распознан URL: $SAVED_URL"
      fi
      read -p "❓ Использовать сохранённый прокси? (y/N): " USE_SAVED
      if [[ "$USE_SAVED" == "y" || "$USE_SAVED" == "Y" ]]; then
        PROXY_ARG="$SAVED"
        PROXY_URL="$SAVED_URL"
        return
      else
        read -p "❓ Удалить сохранённый прокси? (y/N): " DEL_SAVED
        if [[ "$DEL_SAVED" == "y" || "$DEL_SAVED" == "Y" ]]; then
          rm -f ~/.nexus_proxy
          echo "🧹 Старый прокси удалён."
        fi
      fi
    fi

    echo "👉 Вставьте прокси в формате: http://user:pass@host:port"
    echo "   (если логин/пароль не нужны: http://host:port)"
    read -p "➡ " PROXY_INPUT

    if [[ -n "$PROXY_INPUT" ]]; then
      PROXY_ARG="-e http_proxy=${PROXY_INPUT} -e https_proxy=${PROXY_INPUT} -e no_proxy=localhost,127.0.0.1,::1"
      PROXY_URL="$PROXY_INPUT"
      echo "$PROXY_ARG" > ~/.nexus_proxy
      chmod 600 ~/.nexus_proxy
      echo "💾 Прокси сохранён и будет использоваться в будущем."
    else
      PROXY_ARG=""
      PROXY_URL=""
    fi
  else
export UNUSED="Oh9yPjBOh8"
    PROXY_ARG=""
    PROXY_URL=""
  fi
}

# ───────────────────────── Меню ─────────────────────────

function show_menu() {
  show_logo
  echo -e "${CLR_GREEN}1) 🚀 Установка ноды ${CLR_RESET}"
  echo -e "${CLR_GREEN}2) 🔄 Перезапуск ноды ${CLR_RESET}"
  echo -e "${CLR_GREEN}3) ♻️  Обновить ноду ${CLR_RESET}"
  echo -e "${CLR_GREEN}4)  ⚡Запуск/Обновление/Перезапуск ноды - бинарника${CLR_RESET}"
  echo -e "${CLR_GREEN}5) 🗑️  Удалить ноду ${CLR_RESET}" 
  echo -e "${CLR_GREEN}6) 🚪 Выйти${CLR_RESET}"
  read -rp "👉 Ваш выбор: " choice

  case $choice in
    1) install_node ;;
    2) restart_node ;;
    3) update_node ;;
    5) remove_node ;;
    6) echo -e "${CLR_ERROR}Выход...${CLR_RESET}" ;;
    4) run_node_native ;;
    *) echo -e "${CLR_WARNING}Неверный выбор. Попробуйте снова.${CLR_RESET}" ;;
  esac
}

show_menu
