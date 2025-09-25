# Telegram Ticket Bot

Автономный Docker-сервис для автоматической обработки заявок в Telegram группах через реакции.

## Возможности

- 🎯 Автоматическое переносение заявок в выделенный тред при добавлении реакции
- 📊 Логирование в PostgreSQL и Google Sheets
- 🔐 SSL/TLS шифрование через Let's Encrypt
- 📈 Мониторинг через Prometheus и Grafana
- 🚀 Автоматические бэкапы и обновления
- 🐳 Полностью контейнеризированное решение

## Быстрый старт

1. Клонируйте репозиторий:
```bash
git clone <repo-url>
cd telegram-ticket-bot
```

2. Скопируйте и отредактируйте конфигурацию:
```bash
cp .env.example .env
nano .env
```

3. Запустите развертывание:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Структура проекта

```
telegram-ticket-bot/
├── bot/                    # Основной код бота
├── nginx/                  # Nginx конфигурация
├── database/              # SQL схемы и миграции
├── monitoring/            # Prometheus и Grafana
├── scripts/               # Скрипты развертывания
├── docker-compose.yml     # Docker Compose конфигурация
└── .env                   # Переменные окружения
```

## Мониторинг

- **Логи**: `docker-compose logs -f telegram-bot`
- **Метрики**: `https://your-domain.duckdns.org/grafana/`
- **Здоровье**: `https://your-domain.duckdns.org/health`

## Бэкапы

Автоматические бэкапы выполняются ежедневно в 3:00:
```bash
# Ручной бэкап
./scripts/backup.sh

# Восстановление
./scripts/restore.sh /path/to/backup
```

## Обновление

```bash
./scripts/update.sh
```

## Настройка

1. **Получите токен бота**: @BotFather в Telegram
2. **Настройте webhook**: Бот автоматически настроит webhook при запуске
3. **Добавьте бота в группу**: С правами администратора
4. **Настройте переменные в .env**: Все необходимые параметры

## Безопасность

- SSL сертификаты автоматически обновляются через Let's Encrypt
- Базы данных защищены паролями
- Мониторинг доступен только по авторизации
- Webhook защищен секретным токеном

## Логирование

Все действия логируются в:
- PostgreSQL (структурированные данные)
- Google Sheets (опционально)
- Файлы логов (./logs/)
- Метрики в Prometheus

## Поддержка

При возникновении проблем:
1. Проверьте логи: `docker-compose logs -f`
2. Проверьте здоровье сервисов: `docker-compose ps`
3. Перезапустите сервисы: `docker-compose restart`
