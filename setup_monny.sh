#!/bin/bash

MONNY_SERVICE_FILE="/etc/systemd/system/monny.service"
MONNY_SCRIPT="/usr/local/bin/monny"
MONNY_PYTHON_SCRIPT="/usr/local/bin/monitor_container.py"
MONNY_VENV="/usr/local/monny_venv"
STATUS_FILE="/usr/local/bin/container_statuses.json"

# Проверка на уже установленный сервис
if [ -f "$MONNY_SERVICE_FILE" ]; then
    echo "Сервис monny уже установлен."
    read -p "Хотите переустановить его? (y/n): " REINSTALL
    if [ "$REINSTALL" != "y" ]; then
        echo "Переустановка отменена."
        exit 0
    fi

    if [ -f "$MONNY_PYTHON_SCRIPT" ]; then
        TELEGRAM_BOT_TOKEN=$(grep "TELEGRAM_BOT_TOKEN" "$MONNY_PYTHON_SCRIPT" | cut -d'"' -f2)
        TELEGRAM_CHAT_ID=$(grep "TELEGRAM_CHAT_ID" "$MONNY_PYTHON_SCRIPT" | cut -d'"' -f2)
    fi

    read -p "Сохранить ли предыдущие значения TELEGRAM BOT API и CHAT ID? (y/n): " SAVE_TELEGRAM
    if [ "$SAVE_TELEGRAM" != "y" ]; then
        unset TELEGRAM_BOT_TOKEN
        unset TELEGRAM_CHAT_ID
    fi

    # Остановка и удаление старого сервиса
    systemctl stop monny.service
    systemctl disable monny.service
    rm "$MONNY_SERVICE_FILE"
    rm "$MONNY_SCRIPT"
    rm "$MONNY_PYTHON_SCRIPT"
    rm -rf "$MONNY_VENV"
    rm -f "$STATUS_FILE"
    systemctl daemon-reload
    echo "Старый сервис monny удален."
fi

# Проверка, установлен ли Docker
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Устанавливаем Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker уже установлен. Пропускаем установку..."
fi

# Проверка, установлен ли Python и pip
if ! command -v python3 &> /dev/null
then
    echo "Python3 не установлен. Устанавливаем Python3..."
    apt-get update
    apt-get install -y python3 python3-venv
else
    echo "Python3 уже установлен. Пропускаем установку..."
fi

# Создание виртуальной среды
python3 -m venv "$MONNY_VENV"
source "$MONNY_VENV/bin/activate"

# Обновление pip
pip install --upgrade pip

# Установка необходимых Python-библиотек
pip install docker requests

# Сообщение о том, что будет установлено
echo "Сейчас будет установлен сервис мониторинга Docker контейнеров."
echo "Этот сервис будет проверять состояние всех контейнеров и отправлять уведомления в Telegram, если какой-то контейнер не работает."

# Ввод данных для Telegram, если они не сохранены
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    read -p "Введите TELEGRAM_BOT_TOKEN: " TELEGRAM_BOT_TOKEN
fi
if [ -z "$TELEGRAM_CHAT_ID" ]; then
    read -p "Введите TELEGRAM_CHAT_ID: " TELEGRAM_CHAT_ID
fi

# Загрузка основного скрипта мониторинга контейнеров с GitHub
curl -o "$MONNY_PYTHON_SCRIPT" https://raw.githubusercontent.com/DigneZzZ/monny-docker/main/monitor_container.py

# Вставка переменных в скрипт
sed -i "s/YOUR_TELEGRAM_BOT_TOKEN/${TELEGRAM_BOT_TOKEN}/" "$MONNY_PYTHON_SCRIPT"
sed -i "s/YOUR_TELEGRAM_CHAT_ID/${TELEGRAM_CHAT_ID}/" "$MONNY_PYTHON_SCRIPT"

# Сделать скрипт исполняемым
chmod +x "$MONNY_PYTHON_SCRIPT"

# Создание файла службы Systemd
cat << EOF > "$MONNY_SERVICE_FILE"
[Unit]
Description=Monitor Docker Containers

[Service]
Environment="TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"
Environment="TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
ExecStart=$MONNY_VENV/bin/python $MONNY_PYTHON_SCRIPT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка конфигурации Systemd
systemctl daemon-reload

# Включение и запуск службы
systemctl enable monny.service
systemctl start monny.service

# Создание скрипта управления
cat << 'EOF' > "$MONNY_SCRIPT"
#!/bin/bash

case "$1" in
    start)
        systemctl start monny.service
        ;;
    stop)
        systemctl stop monny.service
        ;;
    restart)
        systemctl restart monny.service
        ;;
    status)
        systemctl status monny.service
        echo "Состояние контейнеров:"
        /usr/local/monny_venv/bin/python /usr/local/bin/monitor_container.py status
        ;;
    uninstall)
        systemctl stop monny.service
        systemctl disable monny.service
        rm /etc/systemd/system/monny.service
        rm /usr/local/bin/monny
        rm /usr/local/bin/monitor_container.py
        rm -rf /usr/local/monny_venv
        rm -f /usr/local/bin/container_statuses.json
        systemctl daemon-reload
        echo "monny сервис и скрипты удалены."
        ;;
    help)
        echo "Доступные команды:"
        echo "  start      - Запуск сервиса"
        echo "  stop       - Остановка сервиса"
        echo "  restart    - Перезапуск сервиса"
        echo "  status     - Проверка статуса сервиса и состояния контейнеров"
        echo "  uninstall  - Удаление сервиса и связанных скриптов"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|uninstall|help}"
        exit 1
esac
EOF

# Сделать скрипт управления исполняемым
chmod +x "$MONNY_SCRIPT"

deactivate

echo "Установка завершена. Используйте команду 'monny' для управления службой."
