# 🐧 Полная установка Telegram Ticket Bot на Ubuntu 24.04

Пошаговое руководство для развертывания бота на чистом Ubuntu 24.04 LTS сервере.

## 📋 Предварительные требования

- **Ubuntu 24.04 LTS** (чистая установка)
- **VPS/Сервер** с минимум 2GB RAM, 20GB диска
- **Root или sudo доступ**
- **Доменное имя** (например, через DuckDNS)

---

## 🔧 Шаг 1: Подготовка системы

### 1.1 Обновление системы

```bash
# Обновляем пакеты
sudo apt update && sudo apt upgrade -y

# Устанавливаем базовые утилиты
sudo apt install -y curl wget git nano htop unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
```

### 1.2 Настройка временной зоны

```bash
# Устанавливаем временную зону
sudo timedatectl set-timezone Europe/Moscow

# Проверяем
timedatectl status
```

### 1.3 Создание пользователя для бота (рекомендуется)

```bash
# Создаем пользователя
sudo adduser botuser

# Добавляем в группу sudo
sudo usermod -aG sudo botuser

# Переключаемся на пользователя
sudo su - botuser
```

---

## 🐳 Шаг 2: Установка Docker

### 2.1 Установка Docker Engine

```bash
# Удаляем старые версии (если есть)
sudo apt remove -y docker docker-engine docker.io containerd runc

# Добавляем официальный GPG ключ Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавляем репозиторий Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновляем индекс пакетов
sudo apt update

# Устанавливаем Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверяем установку
docker --version
```

### 2.2 Настройка прав Docker

```bash
# Добавляем текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиниваемся (или используем newgrp)
newgrp docker

# Проверяем работу Docker
docker run hello-world
```

### 2.3 Установка Docker Compose (если не установлен)

```bash
# Проверяем версию Docker Compose
docker compose version

# Если не установлен, устанавливаем отдельно
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

## 🔒 Шаг 3: Настройка безопасности

### 3.1 Настройка UFW (Uncomplicated Firewall)

```bash
# Устанавливаем UFW (если не установлен)
sudo apt install -y ufw

# Сбрасываем правила к умолчанию
sudo ufw --force reset

# Настраиваем базовые правила
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Разрешаем SSH (ВАЖНО: сделайте это перед включением UFW!)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Разрешаем HTTP и HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Включаем firewall
sudo ufw --force enable

# Проверяем статус
sudo ufw status verbose
```

### 3.2 Установка и настройка Fail2ban

```bash
# Устанавливаем Fail2ban
sudo apt install -y fail2ban

# Создаем локальную конфигурацию
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Редактируем конфигурацию
sudo nano /etc/fail2ban/jail.local
```

Добавьте в `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
# Запрещаем IP на 1 час после 5 неудачных попыток
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
```

```bash
# Перезапускаем Fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Проверяем статус
sudo fail2ban-client status
```

---

## 🌐 Шаг 4: Настройка домена (DuckDNS)

### 4.1 Регистрация на DuckDNS

1. Перейдите на https://www.duckdns.org/
2. Войдите через GitHub/Google
3. Создайте поддомен (например: `mybot.duckdns.org`)
4. Запишите ваш **токен** и **домен**

### 4.2 Настройка автообновления IP

```bash
# Создаем скрипт обновления
mkdir -p ~/scripts
nano ~/scripts/duck.sh
```

Добавьте в файл:

```bash
#!/bin/bash
# Замените YOUR_DOMAIN и YOUR_TOKEN на ваши данные
echo url="https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns.log -K -
```

```bash
# Делаем скрипт исполняемым
chmod +x ~/scripts/duck.sh

# Тестируем
~/scripts/duck.sh

# Добавляем в crontab для автообновления каждые 5 минут
crontab -e
```

Добавьте строку в crontab:

```
*/5 * * * * /home/botuser/scripts/duck.sh >/dev/null 2>&1
```

---

## 📂 Шаг 5: Скачивание и настройка проекта

### 5.1 Клонирование репозитория

```bash
# Переходим в домашнюю директорию
cd ~

# Клонируем проект
git clone https://github.com/okidoki888/telegram-ticket-bot.git

# Переходим в папку проекта
cd telegram-ticket-bot

# Проверяем содержимое
ls -la
```

### 5.2 Настройка переменных окружения

```bash
# Копируем пример конфигурации
cp env.example .env

# Редактируем конфигурацию
nano .env
```

**Обязательно настройте эти параметры в `.env`:**

```bash
# ===========================================
# TELEGRAM CONFIGURATION
# ===========================================
BOT_TOKEN=YOUR_BOT_TOKEN_FROM_BOTFATHER
SECRET_TOKEN=your_secure_random_string_here
DOMAIN=your-domain.duckdns.org
WEBHOOK_URL=https://your-domain.duckdns.org/webhook

# Chat and thread settings
CHAT_ID=-1002333320642  # ID вашей Telegram группы
SINK_TOPIC_ID=6         # ID треда для заявок
SOURCE_TOPIC_IDS=658,653,652,670,666,656,663,5,665,664,5798,654,671,667,659,657,5006,668,5001,662,661

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
DB_PASSWORD=create_strong_password_here

# ===========================================
# EMAIL FOR SSL CERTIFICATES
# ===========================================
SSL_EMAIL=your-email@example.com

# ===========================================
# MONITORING
# ===========================================
GRAFANA_PASSWORD=strong_grafana_password
```

### 5.3 Генерация надежных паролей

```bash
# Генерируем случайные пароли
echo "DB_PASSWORD: $(openssl rand -base64 32)"
echo "SECRET_TOKEN: $(openssl rand -base64 24)"
echo "GRAFANA_PASSWORD: $(openssl rand -base64 16)"
```

---

## 🤖 Шаг 6: Настройка Telegram бота

### 6.1 Создание бота

1. Найдите **@BotFather** в Telegram
2. Отправьте `/newbot`
3. Следуйте инструкциям
4. Сохраните **токен бота** (формат: `123456789:ABCdef...`)

### 6.2 Получение ID чата и тредов

1. Добавьте **@userinfobot** в вашу группу
2. Отправьте сообщение в группу
3. Переслайте это сообщение боту в личные сообщения
4. Получите `chat_id` и `message_thread_id`

### 6.3 Настройка прав бота

1. Добавьте вашего бота в группу
2. Дайте боту права **администратора** с разрешениями:
   - ✅ Отправка сообщений
   - ✅ Удаление сообщений  
   - ✅ Чтение всех сообщений

---

## 🚀 Шаг 7: Развертывание

### 7.1 Создание необходимых директорий

```bash
# Создаем директории
mkdir -p logs bot/credentials certbot/conf certbot/www

# Устанавливаем права
chmod 755 logs
chmod 700 bot/credentials
chmod 755 certbot/conf certbot/www
```

### 7.2 Запуск автоматического развертывания

```bash
# Делаем скрипт исполняемым
chmod +x scripts/deploy.sh

# Запускаем развертывание
./scripts/deploy.sh
```

**Скрипт автоматически:**
- Проверит зависимости
- Создаст SSL сертификат через Let's Encrypt
- Соберет и запустит все Docker контейнеры
- Настроит webhook для бота
- Проверит работоспособность

### 7.3 Ручное развертывание (если автоскрипт не работает)

```bash
# Создаем сети и volume
docker network create bot-network 2>/dev/null || true

# Сначала получаем SSL сертификат
docker run --rm -p 80:80 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly \
  --standalone \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  -d your-domain.duckdns.org

# Собираем и запускаем контейнеры
docker-compose build
docker-compose up -d

# Ждем запуска
sleep 30

# Проверяем статус
docker-compose ps
```

---

## ✅ Шаг 8: Проверка работоспособности

### 8.1 Проверка контейнеров

```bash
# Статус всех контейнеров
docker-compose ps

# Логи бота
docker-compose logs telegram-bot

# Проверка здоровья
curl -k https://your-domain.duckdns.org/health
```

### 8.2 Проверка SSL

```bash
# Проверка SSL сертификата
openssl s_client -connect your-domain.duckdns.org:443 -servername your-domain.duckdns.org

# Или через curl
curl -I https://your-domain.duckdns.org/health
```

### 8.3 Проверка webhook

```bash
# Проверка webhook в Telegram
curl "https://api.telegram.org/botYOUR_BOT_TOKEN/getWebhookInfo"
```

### 8.4 Тестирование бота

1. Отправьте сообщение в один из исходных тредов
2. Поставьте реакцию на сообщение
3. Проверьте появление сообщения в треде назначения
4. Убедитесь в получении подтверждения "Закрыто"

---

## 📊 Шаг 9: Мониторинг и логи

### 9.1 Доступ к мониторингу

**URLs:**
- **Grafana**: `https://your-domain.duckdns.org/grafana/`
- **Prometheus**: `https://your-domain.duckdns.org/prometheus/`
- **Метрики**: `https://your-domain.duckdns.org/metrics`

**Учетные данные для мониторинга указаны в `.env` файле**

### 9.2 Полезные команды для мониторинга

```bash
# Просмотр логов
docker-compose logs -f telegram-bot

# Статус сервисов
docker-compose ps

# Использование ресурсов
docker stats

# Размер логов
du -sh logs/

# Проверка места на диске
df -h
```

---

## 🛠 Шаг 10: Обслуживание

### 10.1 Автоматические бэкапы

```bash
# Создание бэкапа
./scripts/backup.sh

# Настройка автоматических бэкапов (каждый день в 3:00)
crontab -e
```

Добавьте строку:

```
0 3 * * * /home/botuser/telegram-ticket-bot/scripts/backup.sh >/dev/null 2>&1
```

### 10.2 Обновление системы

```bash
# Обновление проекта
./scripts/update.sh

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Перезапуск если нужно
sudo reboot
```

### 10.3 Мониторинг лог файлов

```bash
# Настройка ротации логов
sudo nano /etc/logrotate.d/telegram-bot
```

Добавьте:

```
/home/botuser/telegram-ticket-bot/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
```

---

## 🔧 Шаг 11: Настройка автозапуска

### 11.1 Создание systemd сервиса

```bash
# Создаем сервис
sudo nano /etc/systemd/system/telegram-bot.service
```

Добавьте:

```ini
[Unit]
Description=Telegram Ticket Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/botuser/telegram-ticket-bot
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
User=botuser
Group=botuser

[Install]
WantedBy=multi-user.target
```

```bash
# Включаем автозапуск
sudo systemctl enable telegram-bot.service

# Проверяем статус
sudo systemctl status telegram-bot.service
```

---

## 🐛 Шаг 12: Устранение неполадок

### 12.1 Проблемы с Docker

```bash
# Проверка статуса Docker
sudo systemctl status docker

# Перезапуск Docker
sudo systemctl restart docker

# Очистка неиспользуемых ресурсов
docker system prune -f
```

### 12.2 Проблемы с SSL

```bash
# Проверка сертификатов
sudo docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates

# Обновление сертификатов
sudo docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" -v "$(pwd)/certbot/www:/var/www/certbot" certbot/certbot renew --dry-run
```

### 12.3 Проблемы с портами

```bash
# Проверка занятых портов
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Остановка конфликтующих сервисов
sudo systemctl stop apache2 nginx
sudo systemctl disable apache2 nginx
```

### 12.4 Проблемы с правами

```bash
# Исправление прав на файлы
sudo chown -R botuser:botuser /home/botuser/telegram-ticket-bot
chmod +x scripts/*.sh
```

---

## 📚 Дополнительные настройки

### Google Sheets интеграция (опционально)

1. Создайте проект в [Google Cloud Console](https://console.cloud.google.com/)
2. Включите Google Sheets API
3. Создайте Service Account
4. Скачайте JSON ключ
5. Поместите ключ в `bot/credentials/google-credentials.json`
6. Добавьте Service Account в вашу таблицу с правами редактора

### Настройка алертов

```bash
# Установка mailutils для email уведомлений
sudo apt install -y mailutils

# Скрипт проверки здоровья
nano ~/scripts/health-check.sh
```

```bash
#!/bin/bash
DOMAIN="your-domain.duckdns.org"
if ! curl -f -s "https://$DOMAIN/health" > /dev/null; then
    echo "Bot is down!" | mail -s "Telegram Bot Alert" your-email@example.com
fi
```

```bash
chmod +x ~/scripts/health-check.sh

# Добавляем в crontab (проверка каждые 5 минут)
crontab -e
```

```
*/5 * * * * /home/botuser/scripts/health-check.sh >/dev/null 2>&1
```

---

## 🎉 Готово!

После выполнения всех шагов у вас будет:

- ✅ **Полностью настроенный Ubuntu 24.04** сервер
- ✅ **Работающий Telegram бот** с автоматической обработкой заявок
- ✅ **SSL шифрование** через Let's Encrypt
- ✅ **Мониторинг** через Grafana и Prometheus
- ✅ **Автоматические бэкапы** и обновления
- ✅ **Безопасная конфигурация** с firewall и fail2ban
- ✅ **Автозапуск** при перезагрузке сервера

**Ваш бот доступен по адресу:**
**https://your-domain.duckdns.org** 🚀

**Для поддержки обращайтесь к документации в репозитории:**
**https://github.com/okidoki888/telegram-ticket-bot**
