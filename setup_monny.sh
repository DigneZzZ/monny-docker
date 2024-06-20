#!/bin/bash

# Проверка, установлен ли Docker
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Устанавливаем Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker уже установлен. Пропускаем установку..."
fi

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
        exit 0
    fi

    # Остановка и удаление старого сервиса
    systemctl stop monny.service
    systemctl disable monny.service
    rm /etc/systemd/system/monny.service
    rm /usr/local/bin/monny
    rm /root/monitor_container.sh
    systemctl daemon-reload
    echo "Старый сервис monny удален."
fi

# Создание основного скрипта мониторинга контейнеров
cat << EOF > /root/monitor_container.sh
#!/bin/bash

# Переменные для Telegram
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
STATUS_FILE="/root/container_statuses.txt"

# Функция для отправки уведомления в Telegram
send_telegram_message() {
    MESSAGE=\$1
    curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" -d chat_id="\${TELEGRAM_CHAT_ID}" -d text="\${MESSAGE}"
}

# Функция для сохранения состояния контейнеров
save_status() {
    echo "\$1:\$2" >> \$STATUS_FILE
}

# Функция для загрузки состояния контейнеров
load_status() {
    if [ -f \$STATUS_FILE ]; then
        grep -E "^$1:" \$STATUS_FILE | cut -d: -f2
    else
        echo "unknown"
    fi
}

# Функция для проверки состояния контейнеров
check_containers_status() {
    CONTAINERS=\$(docker ps -a --format "{{.Names}}")

    > \$STATUS_FILE.tmp
    for CONTAINER in \$CONTAINERS; do
        STATUS=\$(docker inspect -f '{{.State.Status}}' \${CONTAINER})
        PREV_STATUS=\$(load_status \${CONTAINER})
        echo "\${CONTAINER}:\${STATUS}" >> \$STATUS_FILE.tmp
        if [ "\${STATUS}" != "\${PREV_STATUS}" ] && [ "\${STATUS}" != "running" ]; then
            send_telegram_message "Контейнер \${CONTAINER} не в статусе running. Текущий статус: \${STATUS}"
        fi
    done
    mv \$STATUS_FILE.tmp \$STATUS_FILE
}

# Функция для вывода состояния контейнеров
print_containers_status() {
    CONTAINERS=\$(docker ps -a --format "{{.Names}}")
    for CONTAINER in \$CONTAINERS; do
        STATUS=\$(docker inspect -f '{{.State.Status}}' \${CONTAINER})
        if [ "\${STATUS}" == "running" ]; then
            echo -e "\e[32mКонтейнер \${CONTAINER}: \${STATUS}\e[0m"  # Зеленый цвет для running
        else
            echo -e "\e[31mКонтейнер \${CONTAINER}: \${STATUS}\e[0m"  # Красный цвет для не-running
        fi
    done
}

# Основной цикл или вывод статуса
if [ "\$1" == "status" ]; then
    print_containers_status
else
    while true; do
        check_containers_status
        sleep 60  # Проверяем каждую минуту
    done
fi
EOF

# Сделать скрипт исполняемым
chmod +x /root/monitor_container.sh

# Создание файла службы Systemd
cat << EOF > /etc/systemd/system/monny.service
[Unit]
Description=Monitor Docker Containers

[Service]
ExecStart=/root/monitor_container.sh
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
        /root/monitor_container.sh status
        ;;
    uninstall)
        systemctl stop monny.service
        systemctl disable monny.service
        rm /etc/systemd/system/monny.service
        rm /usr/local/bin/monny
        rm /root/monitor_container.sh
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

echo "Установка завершена. Используйте команду 'monny' для управления службой."
