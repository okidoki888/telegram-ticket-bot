#!/bin/bash

# =============================================================================
# Telegram Bot Restore Script
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

# Проверка аргументов
if [ $# -eq 0 ]; then
    log_error "Использование: $0 <путь_к_файлу_бэкапа>"
    log_info "Пример: $0 ./backups/telegram_bot_backup_20240315_120000_full.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="./restore_temp"

# Проверка существования файла бэкапа
check_backup_file() {
    log_info "Проверка файла бэкапа..."
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Файл бэкапа не найден: $BACKUP_FILE"
        exit 1
    fi
    
    log_success "Файл бэкапа найден: $BACKUP_FILE"
}

# Создание временной директории для восстановления
create_restore_dir() {
    log_info "Создание временной директории..."
    
    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"
    
    log_success "Временная директория создана: $RESTORE_DIR"
}

# Извлечение архива бэкапа
extract_backup() {
    log_info "Извлечение архива бэкапа..."
    
    cd "$RESTORE_DIR"
    tar -xzf "../$BACKUP_FILE"
    cd ..
    
    log_success "Архив извлечен"
}

# Остановка сервисов
stop_services() {
    log_info "Остановка сервисов..."
    
    docker-compose down
    
    log_success "Сервисы остановлены"
}

# Восстановление базы данных
restore_database() {
    log_info "Восстановление базы данных..."
    
    # Ищем файл дампа базы данных
    db_dump=$(find "$RESTORE_DIR" -name "*_database.sql" | head -1)
    
    if [ -z "$db_dump" ]; then
        log_warning "Дамп базы данных не найден в бэкапе"
        return
    fi
    
    # Запускаем только PostgreSQL для восстановления
    docker-compose up -d postgres
    
    # Ждем запуска PostgreSQL
    log_info "Ожидание запуска PostgreSQL..."
    sleep 15
    
    # Проверяем доступность PostgreSQL
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec postgres pg_isready -U bot_user -d telegram_bot > /dev/null 2>&1; then
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "PostgreSQL не запустился!"
            exit 1
        fi
        
        sleep 2
        ((attempt++))
    done
    
    # Очищаем существующую базу данных
    log_info "Очистка существующей базы данных..."
    docker-compose exec -T postgres psql -U bot_user -d telegram_bot -c "
        DROP SCHEMA IF EXISTS telegram_bot CASCADE;
        DROP SCHEMA IF EXISTS monitoring CASCADE;
    "
    
    # Восстанавливаем из дампа
    log_info "Восстановление из дампа..."
    docker-compose exec -T postgres psql -U bot_user -d telegram_bot < "$db_dump"
    
    # Останавливаем PostgreSQL
    docker-compose stop postgres
    
    log_success "База данных восстановлена"
}

# Восстановление конфигурации
restore_config() {
    log_info "Восстановление конфигурации..."
    
    # Ищем архив конфигурации
    config_archive=$(find "$RESTORE_DIR" -name "*_config.tar.gz" | head -1)
    
    if [ -z "$config_archive" ]; then
        log_warning "Архив конфигурации не найден в бэкапе"
        return
    fi
    
    # Создаем бэкап текущей конфигурации
    log_info "Создание бэкапа текущей конфигурации..."
    backup_current_config_dir="./config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_current_config_dir"
    
    # Сохраняем важные файлы
    [ -f ".env" ] && cp ".env" "$backup_current_config_dir/"
    [ -f "docker-compose.yml" ] && cp "docker-compose.yml" "$backup_current_config_dir/"
    [ -d "nginx" ] && cp -r "nginx" "$backup_current_config_dir/"
    [ -d "bot/credentials" ] && cp -r "bot/credentials" "$backup_current_config_dir/"
    
    # Извлекаем конфигурацию из бэкапа
    log_info "Извлечение конфигурации из бэкапа..."
    tar -xzf "$config_archive" -C .
    
    log_success "Конфигурация восстановлена"
    log_info "Бэкап текущей конфигурации сохранен в: $backup_current_config_dir"
}

# Восстановление логов
restore_logs() {
    log_info "Восстановление логов..."
    
    # Ищем архив логов
    logs_archive=$(find "$RESTORE_DIR" -name "*_logs.tar.gz" | head -1)
    
    if [ -z "$logs_archive" ]; then
        log_warning "Архив логов не найден в бэкапе"
        return
    fi
    
    # Создаем бэкап текущих логов
    if [ -d "logs" ]; then
        mv "logs" "logs_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Извлекаем логи из бэкапа
    tar -xzf "$logs_archive" -C .
    
    log_success "Логи восстановлены"
}

# Восстановление SSL сертификатов
restore_ssl() {
    log_info "Восстановление SSL сертификатов..."
    
    # Ищем архив SSL
    ssl_archive=$(find "$RESTORE_DIR" -name "*_ssl.tar.gz" | head -1)
    
    if [ -z "$ssl_archive" ]; then
        log_warning "Архив SSL не найден в бэкапе"
        return
    fi
    
    # Создаем бэкап текущих сертификатов
    if [ -d "certbot/conf" ]; then
        mv "certbot/conf" "certbot/conf_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Извлекаем сертификаты из бэкапа
    tar -xzf "$ssl_archive" -C .
    
    log_success "SSL сертификаты восстановлены"
}

# Запуск сервисов после восстановления
start_services() {
    log_info "Запуск сервисов..."
    
    docker-compose up -d
    
    # Ждем запуска
    log_info "Ожидание запуска сервисов..."
    sleep 30
    
    log_success "Сервисы запущены"
}

# Проверка здоровья после восстановления
health_check() {
    log_info "Проверка здоровья сервисов..."
    
    # Проверяем статус контейнеров
    log_info "Статус контейнеров:"
    docker-compose ps
    
    # Загружаем переменные окружения
    if [ -f ".env" ]; then
        source .env
        
        # Проверяем health endpoint
        log_info "Проверка health endpoint..."
        max_attempts=10
        attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -f -s "https://$DOMAIN/health" > /dev/null 2>&1; then
                log_success "Сервис здоров!"
                break
            else
                if [ $attempt -eq $max_attempts ]; then
                    log_warning "Сервис не отвечает, но восстановление завершено"
                    log_info "Проверьте логи: docker-compose logs"
                    break
                fi
                
                log_info "Попытка $attempt/$max_attempts: ждем запуска..."
                sleep 10
                ((attempt++))
            fi
        done
    fi
}

# Очистка временных файлов
cleanup() {
    log_info "Очистка временных файлов..."
    
    rm -rf "$RESTORE_DIR"
    
    log_success "Временные файлы очищены"
}

# Отображение информации о восстановлении
show_restore_info() {
    log_success "Восстановление завершено!"
    echo
    echo "=== Информация о восстановлении ==="
    echo "📁 Файл бэкапа: $BACKUP_FILE"
    echo "📅 Дата восстановления: $(date)"
    
    if [ -f ".env" ]; then
        source .env
        echo "🌐 URL сервиса: https://$DOMAIN"
        echo "📊 Мониторинг: https://$DOMAIN/grafana/"
    fi
    
    echo
    echo "=== Статус сервисов ==="
    docker-compose ps --format "table {{.Name}}\t{{.Status}}"
    
    echo
    echo "=== Полезные команды ==="
    echo "📋 Логи: docker-compose logs -f"
    echo "🔄 Перезапуск: docker-compose restart"
    echo "❤️  Здоровье: curl https://$DOMAIN/health"
    echo
    
    log_info "Если возникли проблемы, проверьте логи и при необходимости"
    log_info "восстановите конфигурацию из резервных копий, созданных во время процесса"
}

# Подтверждение восстановления
confirm_restore() {
    echo "================================================"
    echo "⚠️  ВНИМАНИЕ: ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА"
    echo "================================================"
    echo
    log_warning "Это действие заменит текущие данные данными из бэкапа!"
    log_warning "Текущие данные будут сохранены в резервные копии."
    echo
    echo "📁 Файл бэкапа: $BACKUP_FILE"
    echo "📅 Размер: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo
    
    read -p "Продолжить восстановление? (yes/no): " -r
    if [[ ! $REPLY =~ ^(yes|YES)$ ]]; then
        log_info "Восстановление отменено пользователем"
        exit 0
    fi
}

# Главная функция
main() {
    echo "================================================"
    echo "🔄 Telegram Bot Restore Script"
    echo "================================================"
    echo
    
    check_backup_file
    confirm_restore
    create_restore_dir
    extract_backup
    stop_services
    restore_database
    restore_config
    restore_logs
    restore_ssl
    start_services
    health_check
    cleanup
    show_restore_info
}

# Запуск с обработкой ошибок
if main "$@"; then
    exit 0
else
    log_error "Восстановление не удалось!"
    log_info "Проверьте логи и при необходимости восстановите систему вручную"
    exit 1
fi
