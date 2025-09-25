# Установка Telegram Ticket Bot

Пошаговое руководство по установке и настройке автономного Docker-сервиса для обработки заявок в Telegram.

## Предварительные требования

### Системные требования

- **VPS/Сервер** с Ubuntu 20.04+ или Debian 11+
- **RAM**: минимум 2GB, рекомендуется 4GB
- **Диск**: минимум 20GB свободного места
- **Процессор**: 2+ ядра
- **Доступ в интернет** с портами 80, 443

### Программное обеспечение

- Docker 20.10+
- Docker Compose 2.0+
- Git
- Curl

## 1. Подготовка сервера

### Обновление системы

```bash
sudo apt update && sudo apt upgrade -y
```

### Установка Docker

```bash
# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогинивание
newgrp docker
```

### Установка Docker Compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Установка дополнительных утилит

```bash
sudo apt install -y git curl htop nano ufw fail2ban
```

## 2. Настройка безопасности

### Firewall

```bash
# Базовая настройка UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### Fail2ban

```bash
# Настройка fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## 3. Настройка DNS

### DuckDNS (если используете)

1. Зарегистрируйтесь на [DuckDNS](https://www.duckdns.org/)
2. Создайте поддомен
3. Настройте IP адрес вашего сервера
4. Запишите токен и домен для дальнейшей настройки

## 4. Создание Telegram бота

### Создание бота

1. Найдите [@BotFather](https://t.me/BotFather) в Telegram
2. Отправьте команду `/newbot`
3. Следуйте инструкциям для создания бота
4. Сохраните токен бота (выглядит как `123456789:ABCdefGHIjklmnopQRSTuvwxyz`)

### Настройка прав бота

1. Добавьте бота в вашу Telegram группу
2. Дайте боту права администратора с разрешениями:
   - Удаление сообщений
   - Отправка сообщений
   - Чтение всех сообщений

### Получение ID чата и тредов

Используйте [@userinfobot](https://t.me/userinfobot) в вашей группе для получения:
- ID группы (chat_id)
- ID тредов (topic_id)

## 5. Клонирование и настройка проекта

### Клонирование репозитория

```bash
cd ~
git clone https://github.com/yourusername/telegram-ticket-bot.git
cd telegram-ticket-bot
```

### Настройка конфигурации

```bash
# Копирование файла конфигурации
cp env.example .env

# Редактирование конфигурации
nano .env
```

### Обязательные параметры в .env:

```bash
# Telegram
BOT_TOKEN=ваш_токен_бота
DOMAIN=ваш-домен.duckdns.org
WEBHOOK_URL=https://ваш-домен.duckdns.org/webhook

# Chat и треды
CHAT_ID=-1002333320642  # ID вашей группы
SINK_TOPIC_ID=6         # ID треда для заявок
SOURCE_TOPIC_IDS=658,653,652  # ID тредов-источников

# Безопасность
DB_PASSWORD=надежный_пароль_для_бд
SECRET_TOKEN=секретный_токен_webhook
SSL_EMAIL=ваш@email.com

# Мониторинг
GRAFANA_PASSWORD=пароль_для_grafana
```

## 6. Настройка Google Sheets (опционально)

### Создание Service Account

1. Перейдите в [Google Cloud Console](https://console.cloud.google.com/)
2. Создайте проект или выберите существующий
3. Включите Google Sheets API
4. Создайте Service Account
5. Скачайте JSON ключ
6. Поместите файл как `bot/credentials/google-credentials.json`

### Настройка таблицы

1. Создайте Google Sheets таблицу
2. Скопируйте ID таблицы из URL
3. Добавьте email Service Account с правами редактора
4. Укажите ID таблицы в `.env` файле

## 7. Развертывание

### Автоматическое развертывание

```bash
# Сделать скрипт исполняемым
chmod +x scripts/deploy.sh

# Запустить развертывание
./scripts/deploy.sh
```

Скрипт автоматически:
- Проверит зависимости
- Создаст необходимые директории
- Получит SSL сертификат
- Соберет и запустит контейнеры
- Проверит работоспособность

### Ручное развертывание

Если автоматический скрипт не работает:

```bash
# Создание директорий
mkdir -p logs bot/credentials certbot/conf certbot/www

# Получение SSL сертификата
docker run --rm -p 80:80 -v "$(pwd)/certbot/conf:/etc/letsencrypt" -v "$(pwd)/certbot/www:/var/www/certbot" certbot/certbot certonly --standalone --email ваш@email.com --agree-tos -d ваш-домен.duckdns.org

# Сборка и запуск
docker-compose build
docker-compose up -d
```

## 8. Проверка работоспособности

### Проверка статуса контейнеров

```bash
docker-compose ps
```

### Проверка логов

```bash
# Все логи
docker-compose logs

# Логи конкретного сервиса
docker-compose logs telegram-bot
```

### Проверка endpoints

```bash
# Здоровье сервиса
curl https://ваш-домен.duckdns.org/health

# Webhook info
curl "https://api.telegram.org/botВАШ_ТОКЕН/getWebhookInfo"
```

### Доступ к мониторингу

- **Grafana**: https://ваш-домен.duckdns.org/grafana/
- **Prometheus**: https://ваш-домен.duckdns.org/prometheus/

Логин/пароль для мониторинга указаны в `.env` файле.

## 9. Тестирование бота

1. Отправьте сообщение в один из исходных тредов
2. Поставьте любую реакцию на сообщение
3. Проверьте, что сообщение появилось в треде-назначении
4. Проверьте логи и мониторинг

## 10. Резервное копирование

### Автоматический бэкап

```bash
# Создание бэкапа
./scripts/backup.sh

# Настройка cron для ежедневных бэкапов
crontab -e

# Добавить строку для ежедневного бэкапа в 3:00
0 3 * * * /path/to/telegram-ticket-bot/scripts/backup.sh
```

### Восстановление из бэкапа

```bash
./scripts/restore.sh ./backups/telegram_bot_backup_YYYYMMDD_HHMMSS_full.tar.gz
```

## 11. Обновление

```bash
./scripts/update.sh
```

## Устранение неполадок

### Проблемы с SSL

```bash
# Проверка сертификатов
sudo certbot certificates

# Обновление сертификатов
sudo certbot renew --dry-run
```

### Проблемы с Docker

```bash
# Перезапуск всех сервисов
docker-compose restart

# Полная пересборка
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Проблемы с webhook

```bash
# Проверка webhook
curl "https://api.telegram.org/botВАШ_ТОКЕН/getWebhookInfo"

# Установка webhook вручную
curl -X POST "https://api.telegram.org/botВАШ_ТОКЕН/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://ваш-домен.duckdns.org/webhook","secret_token":"ваш_секретный_токен"}'
```

## Поддержка

Если у вас возникли проблемы:

1. Проверьте логи: `docker-compose logs -f`
2. Проверьте статус: `docker-compose ps`
3. Проверьте конфигурацию в `.env`
4. Убедитесь, что все порты открыты
5. Проверьте DNS настройки

## Рекомендации по production

1. **Регулярные обновления**: Обновляйте систему и Docker образы
2. **Мониторинг места**: Настройте алерты на заполнение диска
3. **Бэкапы**: Автоматизируйте создание бэкапов
4. **Логи**: Настройте ротацию логов
5. **Безопасность**: Регулярно меняйте пароли и ключи
