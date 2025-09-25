#!/bin/bash

# =============================================================================
# Telegram Bot Update Script
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция создания бэкапа перед обновлением
backup_before_update() {
    log_info "Создание бэкапа перед обновлением..."
    
    if [ -f "./scripts/backup.sh" ]; then
        chmod +x ./scripts/backup.sh
        ./scripts/backup.sh
        log_success "Бэкап создан"
    else
        log_warning "Скрипт бэкапа не найден, пропускаем..."
    fi
}

# Функция получения обновлений из Git
pull_updates() {
    log_info "Получение обновлений из Git..."
    
    if [ -d ".git" ]; then
        # Сохраняем локальные изменения
        git stash push -m "Auto-stash before update $(date)"
        
        # Получаем обновления
        git pull origin main || git pull origin master
        
        log_success "Обновления получены"
    else
        log_warning "Это не Git репозиторий, пропускаем git pull"
    fi
}

# Функция проверки изменений в конфигурации
check_config_changes() {
    log_info "Проверка изменений в конфигурации..."
    
    # Проверяем изменения в env.example
    if [ -f "env.example" ] && [ -f ".env" ]; then
        # Извлекаем ключи из обоих файлов
        env_keys=$(grep -E '^[A-Z_]+=.*' .env | cut -d'=' -f1 | sort)
        example_keys=$(grep -E '^[A-Z_]+=.*' env.example | cut -d'=' -f1 | sort)
        
        # Проверяем новые ключи
        new_keys=$(comm -13 <(echo "$env_keys") <(echo "$example_keys"))
        
        if [ -n "$new_keys" ]; then
            log_warning "Обнаружены новые параметры конфигурации:"
            echo "$new_keys"
            log_info "Добавьте их в .env файл из env.example"
            
            # Показываем пользователю что нужно добавить
            for key in $new_keys; do
                value=$(grep "^$key=" env.example | cut -d'=' -f2-)
                echo "  $key=$value"
            done
            
            read -p "Продолжить обновление? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Обновление отменено пользователем"
                exit 1
            fi
        fi
    fi
}

# Функция обновления контейнеров
update_containers() {
    log_info "Обновление Docker контейнеров..."
    
    # Останавливаем сервисы
    log_info "Остановка сервисов..."
    docker-compose down
    
    # Обновляем образы
    log_info "Обновление базовых образов..."
    docker-compose pull
    
    # Пересобираем наши образы
    log_info "Пересборка пользовательских образов..."
    docker-compose build --no-cache telegram-bot nginx
    
    # Запускаем сервисы
    log_info "Запуск обновленных сервисов..."
    docker-compose up -d
    
    log_success "Контейнеры обновлены"
}

# Функция проверки здоровья после обновления
health_check_after_update() {
    log_info "Проверка здоровья сервисов после обновления..."
    
    # Ждем запуска сервисов
    log_info "Ожидание запуска сервисов..."
    sleep 30
    
    # Проверяем статус контейнеров
    log_info "Статус контейнеров:"
    docker-compose ps
    
    # Загружаем переменные окружения
    if [ -f ".env" ]; then
        source .env
    fi
    
    # Проверяем health endpoints
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Попытка $attempt/$max_attempts: проверка https://$DOMAIN/health"
        
        if curl -f -s "https://$DOMAIN/health" > /dev/null 2>&1; then
            log_success "Сервис здоров!"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "Сервис не отвечает после обновления!"
                log_info "Проверьте логи: docker-compose logs"
                exit 1
            fi
            
            log_warning "Сервис еще не готов, ждем..."
            sleep 10
            ((attempt++))
        fi
    done
    
    # Проверяем логи на критические ошибки
    log_info "Проверка логов на критические ошибки..."
    critical_errors=$(docker-compose logs --tail=100 | grep -i "critical\|fatal" | wc -l)
    
    if [ "$critical_errors" -eq 0 ]; then
        log_success "Критические ошибки не найдены"
    else
        log_warning "Найдено $critical_errors критических ошибок в логах"
        log_info "Просмотр логов: docker-compose logs telegram-bot"
    fi
}

# Функция очистки старых образов
cleanup_old_images() {
    log_info "Очистка старых Docker образов..."
    
    # Удаляем неиспользуемые образы
    docker image prune -f
    
    log_success "Старые образы очищены"
}

# Функция проверки обновлений зависимостей
check_dependency_updates() {
    log_info "Проверка обновлений зависимостей..."
    
    # Проверяем обновления Python пакетов
    if [ -f "bot/requirements.txt" ]; then
        log_info "Проверка обновлений Python пакетов..."
        docker run --rm -v "$(pwd)/bot:/app" python:3.11-slim sh -c "
            cd /app && 
            pip install --quiet pip-check-updates && 
            pip-check-updates requirements.txt
        " 2>/dev/null || log_info "pip-check-updates не доступен"
    fi
}

# Функция отката в случае проблем
rollback() {
    log_error "Обнаружены проблемы после обновления!"
    log_info "Выполняется откат к предыдущей версии..."
    
    # Откатываем Git изменения
    if [ -d ".git" ]; then
        git reset --hard HEAD~1
    fi
    
    # Перезапускаем с предыдущей конфигурацией
    docker-compose down
    docker-compose up -d
    
    log_warning "Откат выполнен. Проверьте логи и повторите обновление позже."
}

# Функция отображения финальной информации
show_update_info() {
    log_success "Обновление завершено успешно!"
    echo
    echo "=== Информация об обновлении ==="
    echo "📅 Дата обновления: $(date)"
    
    # Показываем версию Git если доступна
    if [ -d ".git" ]; then
        echo "📝 Последний коммит: $(git log -1 --oneline)"
    fi
    
    # Показываем статус сервисов
    echo "🔄 Статус сервисов:"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}"
    
    echo
    echo "=== Полезные команды ==="
    echo "📋 Логи: docker-compose logs -f"
    echo "📊 Статус: docker-compose ps"
    echo "🔄 Перезапуск: docker-compose restart"
    echo "📈 Мониторинг: https://$DOMAIN/grafana/"
    echo
}

# Главная функция
main() {
    echo "================================================"
    echo "🔄 Telegram Bot Update Script"
    echo "================================================"
    echo
    
    # Проверяем наличие Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не найден!"
        exit 1
    fi
    
    # Устанавливаем trap для отката в случае ошибки
    trap 'rollback' ERR
    
    backup_before_update
    pull_updates
    check_config_changes
    check_dependency_updates
    update_containers
    health_check_after_update
    cleanup_old_images
    
    # Убираем trap после успешного обновления
    trap - ERR
    
    show_update_info
}

# Запуск с обработкой ошибок
if main "$@"; then
    exit 0
else
    log_error "Обновление не удалось!"
    exit 1
fi
