# 🚀 Быстрый старт Telegram Ticket Bot

## За 5 минут до запуска

### 1. Подготовка (1 мин)

```bash
# Клонируйте репозиторий
git clone https://github.com/okidoki888/telegram-ticket-bot.git
cd telegram-ticket-bot

# Скопируйте конфигурацию
cp env.example .env
```

### 2. Настройка .env (2 мин)

Отредактируйте `.env` файл с вашими данными:

```bash
# Обязательные параметры
BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz  # От @BotFather
DOMAIN=mybot.duckdns.org                           # Ваш домен
CHAT_ID=-1002333320642                             # ID вашей группы
SINK_TOPIC_ID=6                                    # Тред для заявок
DB_PASSWORD=StrongPassword123                      # Пароль БД
SSL_EMAIL=your@email.com                          # Email для SSL
```

### 3. Развертывание (2 мин)

```bash
# Автоматическое развертывание
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Скрипт автоматически:
- ✅ Проверит зависимости
- ✅ Создаст SSL сертификат
- ✅ Запустит все сервисы
- ✅ Настроит мониторинг

## Проверка работы

### Быстрая проверка

```bash
# Статус сервисов
docker-compose ps

# Здоровье бота
curl https://ваш-домен.duckdns.org/health

# Логи
docker-compose logs -f telegram-bot
```

### Тест в Telegram

1. **Отправьте сообщение** в один из исходных тредов
2. **Поставьте реакцию** на сообщение
3. **Проверьте** появление в треде назначения

## Мониторинг

- 📊 **Grafana**: `https://ваш-домен.duckdns.org/grafana/`
- 📈 **Prometheus**: `https://ваш-домен.duckdns.org/prometheus/`
- ❤️ **Здоровье**: `https://ваш-домен.duckdns.org/health`

**Логин**: указан в `.env` как `MONITORING_AUTH_USER`  
**Пароль**: автоматически сгенерирован и показан при развертывании

## Управление

```bash
# Логи
docker-compose logs -f

# Перезапуск
docker-compose restart

# Бэкап
./scripts/backup.sh

# Обновление
./scripts/update.sh
```

## Если что-то пошло не так

### Проблемы с доменом

```bash
# Проверьте DNS
nslookup ваш-домен.duckdns.org

# Обновите IP в DuckDNS
curl "https://www.duckdns.org/update?domains=ваш-домен&token=ваш-токен&ip="
```

### Проблемы с ботом

```bash
# Проверьте токен
curl "https://api.telegram.org/botВАШ_ТОКЕН/getMe"

# Проверьте webhook
curl "https://api.telegram.org/botВАШ_ТОКЕН/getWebhookInfo"
```

### Проблемы с Docker

```bash
# Перезапуск с пересборкой
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Дальнейшая настройка

📚 **Подробная документация**: [INSTALL.md](INSTALL.md)  
🎯 **Использование**: [USAGE.md](USAGE.md)  
🔧 **Конфигурация**: [README.md](README.md)

---

**Поздравляем! 🎉 Ваш Telegram Ticket Bot готов к работе!**
