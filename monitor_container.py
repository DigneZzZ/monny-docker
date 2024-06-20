#!/usr/bin/env python3

import docker
import requests
import os

# Переменные для Telegram (будут заменены скриптом установки)
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

# Основной цикл обработки событий Docker
for event in client.events(decode=True):
    handle_event(event)
