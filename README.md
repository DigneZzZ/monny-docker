# monny-docker
Monitoring docker container and notify in telegram

```
bash <(curl -L -s https://raw.githubusercontent.com/DigneZzZ/monny-docker/main/setup_monny.sh)
```
![image](https://github.com/DigneZzZ/monny-docker/assets/50312583/0360a73b-a742-4cfa-b33c-ca119e376b60)
###
### Первые 3 сообщения  - события на момент запуска скрипта.

### Вторые 2 собщения - событие изменений статуса.
При установке вам необходимо будет ввести TelegramBotID и ChatID. ChatID это место куда бот будет писать сообщения. В моем случае это отдельный Канал (только для меня) где сидят мои боты и шлют уведомления при необходимости.

Сервис установит автоматически все необходимые зависимости для работы Python скрипта.

Чтобы посмотреть перечень доступных команд: *monny help*

Чтобы удалить сервис из системы: *monny uninstall*

Чтобы остановить сервис (если вдруг вам спамит слишком много, например, в случае долго рестарта): *monny stop*

Чтобы запустить: *monny start*

В принципе на это основной функционал заканчивается 🙂

Если понравилось и хотели бы еще увидеть возможность выбирать контейнеры для мониторинга, пишите постараюсь реализовать.
