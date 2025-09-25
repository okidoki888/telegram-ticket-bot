# 🚀 Настройка GitHub репозитория

## Шаг 1: Создание репозитория на GitHub

1. **Перейдите на GitHub.com** и войдите в свой аккаунт
2. **Нажмите "+" в правом верхнем углу** → "New repository"
3. **Заполните данные репозитория:**
   - **Repository name**: `telegram-ticket-bot`
   - **Description**: `🤖 Automated Telegram ticket processing bot with Docker, monitoring, and production-ready deployment`
   - **Visibility**: Public (или Private по желанию)
   - **⚠️ НЕ ДОБАВЛЯЙТЕ** README, .gitignore, или license (у нас уже есть файлы)

4. **Нажмите "Create repository"**

## Шаг 2: Подключение локального репозитория

После создания репозитория на GitHub, выполните эти команды в терминале:

```bash
# Добавьте remote origin (замените YOUR_USERNAME на ваш GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/telegram-ticket-bot.git

# Пушим код в репозиторий
git push -u origin main
```

## Шаг 3: Настройка репозитория

### Добавление топиков (тегов)
В настройках репозитория добавьте топики:
- `telegram-bot`
- `docker`
- `python`
- `fastapi`
- `postgresql`
- `prometheus`
- `grafana`
- `nginx`
- `automation`
- `monitoring`

### Настройка README
GitHub автоматически отобразит наш README.md как главную страницу репозитория.

### Настройка GitHub Pages (опционально)
Можно настроить GitHub Pages для отображения документации:
1. Settings → Pages
2. Source: Deploy from a branch
3. Branch: main
4. Folder: / (root)

## Шаг 4: Безопасность

### Защита main ветки
1. Settings → Branches
2. Add rule для main ветки
3. Включите:
   - Require pull request reviews
   - Require status checks to pass
   - Restrict pushes to specific people

### Secrets для CI/CD (если планируете)
Settings → Secrets and variables → Actions:
- `BOT_TOKEN` - токен Telegram бота
- `DOCKER_HUB_TOKEN` - для публикации образов
- `VPS_SSH_KEY` - для автодеплоя на сервер

## Шаг 5: Дополнительные файлы

### Лицензия
Добавьте файл LICENSE (рекомендуется MIT или Apache 2.0)

### Contributing Guide
Создайте CONTRIBUTING.md с правилами для контрибьюторов

### Issue Templates
.github/ISSUE_TEMPLATE/ для стандартизации багрепортов

### GitHub Actions (CI/CD)
.github/workflows/ для автоматизации тестирования и деплоя

## Пример команд для настройки:

```bash
# Клонирование репозитория (для других разработчиков)
git clone https://github.com/YOUR_USERNAME/telegram-ticket-bot.git
cd telegram-ticket-bot

# Настройка для разработки
cp env.example .env
# Редактируйте .env файл

# Запуск в development режиме
docker-compose up -d

# Запуск тестов (если добавите)
docker-compose exec telegram-bot python -m pytest

# Деплой на production
./scripts/deploy.sh
```

## Рекомендуемая структура веток:

- `main` - production код
- `develop` - development ветка
- `feature/*` - ветки для новых функций
- `hotfix/*` - ветки для срочных исправлений

## После создания репозитория:

1. **Обновите README.md** с правильными ссылками на ваш репозиторий
2. **Добавьте contributors** если работаете в команде
3. **Настройте webhooks** для интеграции с другими сервисами
4. **Создайте releases** для версионирования

---

**Готово!** 🎉 Ваш Telegram Ticket Bot теперь доступен на GitHub!
