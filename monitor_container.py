#!/usr/bin/env python3

import docker
import requests
import os
import sys

# Переменные для Telegram
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')

# Инициализация Docker клиента
client = docker.from_env()

# Функция для отправки уведомления в Telegram
def send_telegram_message(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    data = {"chat_id": TELEGRAM_CHAT_ID, "text": message}
    requests.post(url, data=data)

# Функция для обработки событий Docker
def handle_event(event):
    status = event['status']
    container_name = event['Actor']['Attributes']['name']
    message = f"Контейнер {container_name} изменил статус: {status}"
    send_telegram_message(message)

# Функция для вывода статуса контейнеров
def print_containers_status():
    containers = client.containers.list(all=True)
    for container in containers:
        status = container.status
        if status == "running":
            print(f"\033[32mКонтейнер {container.name}: {status}\033[0m")  # Зеленый цвет для running
        else:
            print(f"\033[31mКонтейнер {container.name}: {status}\033[0m")  # Красный цвет для не-running

# Проверка аргументов командной строки
if len(sys.argv) > 1 and sys.argv[1] == "status":
    print_containers_status()
    sys.exit(0)

# Первоначальная проверка и уведомление
containers = client.containers.list(all=True)
for container in containers:
    status = container.status
    send_telegram_message(f"Первоначальный статус контейнера {container.name}: {status}")

# Основной цикл обработки событий Docker
for event in client.events(decode=True):
    handle_event(event)
