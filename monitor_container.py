#!/usr/bin/env python3

import docker
import requests
import os
import sys
import json

# Переменные для Telegram
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
STATUS_FILE = "/usr/local/bin/container_statuses.json"
TRACKED_CONTAINERS_FILE = "/usr/local/bin/tracked_containers.json"

# Инициализация Docker клиента
client = docker.from_env()

# Функция для отправки уведомления в Telegram
def send_telegram_message(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    data = {"chat_id": TELEGRAM_CHAT_ID, "text": message}
    response = requests.post(url, data=data)
    if response.status_code != 200:
        print(f"Ошибка отправки сообщения в Telegram: {response.status_code}, {response.text}")

# Функция для загрузки состояния контейнеров
def load_statuses():
    if os.path.exists(STATUS_FILE):
        with open(STATUS_FILE, 'r') as file:
            return json.load(file)
    return {}

# Функция для сохранения состояния контейнеров
def save_statuses(statuses):
    with open(STATUS_FILE, 'w') as file:
        json.dump(statuses, file)

# Функция для загрузки отслеживаемых контейнеров
def load_tracked_containers():
    if os.path.exists(TRACKED_CONTAINERS_FILE):
        with open(TRACKED_CONTAINERS_FILE, 'r') as file:
            return json.load(file)
    return []

# Функция для сохранения отслеживаемых контейнеров
def save_tracked_containers(tracked_containers):
    with open(TRACKED_CONTAINERS_FILE, 'w') as file:
        json.dump(tracked_containers, file)

# Функция для добавления контейнера в отслеживаемые
def add_tracked_container(container_name):
    tracked_containers = load_tracked_containers()
    if container_name not in tracked_containers:
        tracked_containers.append(container_name)
        save_tracked_containers(tracked_containers)
        print(f"Контейнер {container_name} добавлен в отслеживаемые.")
    else:
        print(f"Контейнер {container_name} уже отслеживается.")

# Функция для вывода списка отслеживаемых контейнеров
def list_tracked_containers():
    tracked_containers = load_tracked_containers()
    if tracked_containers:
        print("Отслеживаемые контейнеры:")
        for container in tracked_containers:
            print(f"- {container}")
    else:
        print("Список отслеживаемых контейнеров пуст.")

# Функция для обработки событий Docker
def handle_event(event):
    status = event['status']
    container_name = event['Actor']['Attributes']['name']
    tracked_containers = load_tracked_containers()
    if container_name in tracked_containers:
        message = f"Контейнер {container_name} изменил статус: {status}"
        send_telegram_message(message)

# Функция для вывода и отправки статуса контейнеров
def print_and_send_containers_status():
    statuses = load_statuses()
    current_statuses = {}
    tracked_containers = load_tracked_containers()
    containers = client.containers.list(all=True)
    for container in containers:
        status = container.status
        current_statuses[container.name] = status
        if container.name in tracked_containers:
            if container.name not in statuses or statuses[container.name] != status:
                send_telegram_message(f"Контейнер {container.name}: {status}")
            if status == "running":
                print(f"\033[32mКонтейнер {container.name}: {status}\033[0m")  # Зеленый цвет для running
            else:
                print(f"\033[31mКонтейнер {container.name}: {status}\033[0m")  # Красный цвет для не-running
    save_statuses(current_statuses)

# Проверка аргументов командной строки
if len(sys.argv) > 1:
    if sys.argv[1] == "status":
        print_and_send_containers_status()
    elif sys.argv[1] == "add" and len(sys.argv) > 2:
        add_tracked_container(sys.argv[2])
    elif sys.argv[1] == "list":
        list_tracked_containers()
    else:
        print("Неверная команда.")
    sys.exit(0)

# Первоначальная проверка и уведомление
print_and_send_containers_status()

# Основной цикл обработки событий Docker
for event in client.events(decode=True):
    handle_event(event)
