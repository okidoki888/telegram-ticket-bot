# Contributing to Telegram Ticket Bot

Спасибо за интерес к улучшению Telegram Ticket Bot! 🎉

## Как внести вклад

### 🐛 Сообщение об ошибках

Если вы нашли ошибку:

1. **Проверьте**, что ошибка еще не была зарегистрирована в [Issues](https://github.com/YOUR_USERNAME/telegram-ticket-bot/issues)
2. **Создайте новый Issue** с подробным описанием:
   - Версия системы и Docker
   - Шаги для воспроизведения
   - Ожидаемое поведение
   - Фактическое поведение
   - Логи и скриншоты

### 💡 Предложение новых функций

Для новых функций:

1. **Создайте Issue** с меткой "enhancement"
2. **Опишите функцию** и её пользу
3. **Обсудите реализацию** с мейнтейнерами

### 🔧 Отправка кода

#### Подготовка окружения

```bash
# Форкните и клонируйте репозиторий
git clone https://github.com/YOUR_USERNAME/telegram-ticket-bot.git
cd telegram-ticket-bot

# Создайте ветку для изменений
git checkout -b feature/your-feature-name

# Настройте окружение
cp env.example .env
# Отредактируйте .env с тестовыми данными

# Запустите в dev режиме
docker-compose up -d
```

#### Требования к коду

1. **Следуйте PEP 8** для Python кода
2. **Добавляйте docstrings** к новым функциям
3. **Пишите тесты** для новой функциональности
4. **Обновляйте документацию**
5. **Проверяйте типы** с помощью mypy

#### Тестирование

```bash
# Запуск тестов
docker-compose exec telegram-bot python -m pytest

# Проверка типов
docker-compose exec telegram-bot python -m mypy bot/

# Проверка стиля кода
docker-compose exec telegram-bot python -m flake8 bot/

# Проверка безопасности
docker-compose exec telegram-bot python -m bandit -r bot/
```

#### Отправка изменений

1. **Коммиты** должны быть описательными:
   ```bash
   git commit -m "✨ Add support for multiple chat groups
   
   - Extend configuration to support multiple chat IDs
   - Update handlers to process messages from any configured chat
   - Add validation for chat permissions
   - Update documentation with multi-chat setup"
   ```

2. **Пуш и Pull Request**:
   ```bash
   git push origin feature/your-feature-name
   ```
   
3. **Создайте Pull Request** с описанием:
   - Что изменено
   - Зачем это нужно
   - Как протестировать
   - Ссылки на связанные Issues

## Стандарты кода

### Python

```python
"""
Модуль для работы с Telegram API.

Этот модуль содержит функции для отправки сообщений,
обработки webhook'ов и взаимодействия с ботом.
"""

import asyncio
from typing import Optional, List
import structlog

logger = structlog.get_logger()


async def send_message(chat_id: int, text: str) -> Optional[dict]:
    """
    Отправка сообщения в Telegram чат.
    
    Args:
        chat_id: ID целевого чата
        text: Текст сообщения
        
    Returns:
        Ответ от Telegram API или None при ошибке
        
    Raises:
        TelegramAPIError: При ошибке API
    """
    try:
        # Ваш код здесь
        logger.info("Message sent", chat_id=chat_id, length=len(text))
        return result
    except Exception as e:
        logger.error("Failed to send message", error=str(e))
        return None
```

### Docker

- Используйте multi-stage builds для оптимизации
- Запускайтесь от non-root пользователя
- Минимизируйте количество layers

### SQL

- Используйте параметризованные запросы
- Добавляйте индексы для производительности
- Включайте миграции для изменений схемы

## Структура проекта

```
telegram-ticket-bot/
├── bot/                    # Основной код приложения
│   ├── handlers/          # Обработчики Telegram событий
│   ├── database/          # Модели и соединения с БД
│   ├── utils/             # Вспомогательные функции
│   └── config.py          # Конфигурация приложения
├── database/              # SQL схемы и миграции
├── nginx/                 # Конфигурация веб-сервера
├── monitoring/            # Настройки мониторинга
├── scripts/               # Скрипты управления
└── docs/                  # Документация
```

## Типы коммитов

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - новые функции
- `fix:` - исправления ошибок
- `docs:` - изменения в документации
- `style:` - форматирование кода
- `refactor:` - рефакторинг
- `test:` - добавление тестов
- `chore:` - обновления зависимостей

Примеры:
```bash
feat: add support for voice messages processing
fix: resolve memory leak in webhook handler
docs: update installation guide for Ubuntu 22.04
```

## Процесс ревью

1. **Автоматические проверки** должны пройти
2. **Минимум один approve** от мейнтейнера
3. **Все комментарии** должны быть разрешены
4. **Конфликты** должны быть разрешены

## Релизы

Версионирование следует [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH`
- `MAJOR` - breaking changes
- `MINOR` - новые функции (backward compatible)
- `PATCH` - исправления ошибок

## Сообщество

- 💬 **Обсуждения**: используйте GitHub Discussions
- 🐛 **Баги**: создавайте Issues
- 📧 **Прямая связь**: ссылка на ваши контакты

## Лицензия

Отправляя код, вы соглашаетесь на лицензирование под [MIT License](LICENSE).

---

**Спасибо за вклад в развитие проекта!** 🙏
