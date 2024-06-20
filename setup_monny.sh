#!/bin/bash

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
python3 -m venv /root/monny_venv
source /root/monny_venv/bin/activate

# Установка необходимых Python-библиотек
pip install docker requests

# Сообщение о том, что будет установлено
echo "Сейчас будет установлен сервис мониторинга Docker контейнеров."
echo "Этот сервис будет проверять состояние всех контейнеров и отправлять уведомления в Telegram, если какой-то контейнер не работает."

# Ввод данных для Telegram
read -p "Введите TELEGRAM_BOT_TOKEN: " TELEGRAM_BOT_TOKEN
read -p "Введите TELEGRAM_CHAT_ID: " TELEGRAM_CHAT_ID

# Проверка на уже установленный сервис
if systemctl list-units --full -all | grep -Fq 'monny.service'; then
    read -p "Сервис monny уже установлен. Хотите переустановить его? (y/n): " REINSTALL
    if [ "$REINSTALL" != "y" ]; then
        echo "Переустановка отменена."
        deactivate
        exit 0
    fi

    # Остановка и удаление старого сервиса
    systemctl stop monny.service
    systemctl disable monny.service
    rm /etc/systemd/system/monny.service
    rm /usr/local/bin/monny
    rm /root/monitor_container.py
    rm -rf /root/monny_venv
    systemctl daemon-reload
    echo "Старый сервис monny удален."
fi

# Загрузка основного скрипта мониторинга контейнеров с GitHub
curl -o /root/monitor_container.py https://raw.githubusercontent.com/DigneZzZ/monny-docker/main/monitor_container.py

# Вставка переменных в скрипт
sed -i "s/YOUR_TELEGRAM_BOT_TOKEN/${TELEGRAM_BOT_TOKEN}/" /root/monitor_container.py
sed -i "s/YOUR_TELEGRAM_CHAT_ID/${TELEGRAM_CHAT_ID}/" /root/monitor_container.py

# Сделать скрипт исполняемым
chmod +x /root/monitor_container.py

# Создание файла службы Systemd
cat << EOF > /etc/systemd/system/monny.service
[Unit]
Description=Monitor Docker Containers

[Service]
Environment="TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"
Environment="TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
ExecStart=/root/monny_venv/bin/python /root/monitor_container.py
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
cat << 'EOF' > /usr/local/bin/monny
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
        /root/monny_venv/bin/python /root/monitor_container.py status
        ;;
    uninstall)
        systemctl stop monny.service
        systemctl disable monny.service
        rm /etc/systemd/system/monny.service
        rm /usr/local/bin/monny
        rm /root/monitor_container.py
        rm -rf /root/monny_venv
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
chmod +x /usr/local/bin/monny

deactivate

echo "Установка завершена. Используйте команду 'monny' для управления службой."
