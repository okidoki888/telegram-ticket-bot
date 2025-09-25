#!/bin/bash

# =============================================================================
# Telegram Bot Backup Script
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

# Настройки
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="telegram_bot_backup_$DATE"

# Создаем директорию для бэкапов
mkdir -p "$BACKUP_DIR"

# Функция бэкапа базы данных
backup_database() {
    log_info "Создание бэкапа базы данных..."
    
    # Загружаем переменные окружения
    if [ -f ".env" ]; then
        source .env
    else
        log_error "Файл .env не найден!"
        exit 1
    fi
    
    # Создаем дамп базы данных
    docker-compose exec -T postgres pg_dump \
        -U bot_user \
        -d telegram_bot \
        --no-password \
        > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"
    
    log_success "Бэкап базы данных создан: ${BACKUP_NAME}_database.sql"
}

# Функция бэкапа конфигурации
backup_config() {
    log_info "Создание бэкапа конфигурации..."
    
    # Создаем архив с конфигурационными файлами
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_config.tar.gz" \
        .env \
        docker-compose.yml \
        nginx/nginx.conf \
        bot/credentials/ \
        2>/dev/null || true
    
    log_success "Бэкап конфигурации создан: ${BACKUP_NAME}_config.tar.gz"
}

# Функция бэкапа логов
backup_logs() {
    log_info "Создание бэкапа логов..."
    
    # Создаем архив с логами
    if [ -d "logs" ]; then
        tar -czf "$BACKUP_DIR/${BACKUP_NAME}_logs.tar.gz" logs/
        log_success "Бэкап логов создан: ${BACKUP_NAME}_logs.tar.gz"
    else
        log_warning "Директория logs не найдена"
    fi
}

# Функция бэкапа SSL сертификатов
backup_ssl() {
    log_info "Создание бэкапа SSL сертификатов..."
    
    if [ -d "certbot/conf" ]; then
        tar -czf "$BACKUP_DIR/${BACKUP_NAME}_ssl.tar.gz" certbot/conf/
        log_success "Бэкап SSL создан: ${BACKUP_NAME}_ssl.tar.gz"
    else
        log_warning "SSL сертификаты не найдены"
    fi
}

# Функция создания полного архива
create_full_backup() {
    log_info "Создание полного архива бэкапа..."
    
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}_full.tar.gz" \
        "${BACKUP_NAME}_database.sql" \
        "${BACKUP_NAME}_config.tar.gz" \
        "${BACKUP_NAME}_logs.tar.gz" \
        "${BACKUP_NAME}_ssl.tar.gz" \
        2>/dev/null || true
    
    # Удаляем отдельные файлы
    rm -f "${BACKUP_NAME}_database.sql" \
          "${BACKUP_NAME}_config.tar.gz" \
          "${BACKUP_NAME}_logs.tar.gz" \
          "${BACKUP_NAME}_ssl.tar.gz"
    
    cd ..
    
    log_success "Полный бэкап создан: ${BACKUP_NAME}_full.tar.gz"
}

# Функция очистки старых бэкапов
cleanup_old_backups() {
    log_info "Очистка старых бэкапов..."
    
    # Оставляем только последние 7 бэкапов
    cd "$BACKUP_DIR"
    ls -t telegram_bot_backup_*_full.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f
    cd ..
    
    log_success "Старые бэкапы очищены"
}

# Функция отображения информации о бэкапе
show_backup_info() {
    backup_file="$BACKUP_DIR/${BACKUP_NAME}_full.tar.gz"
    
    if [ -f "$backup_file" ]; then
        size=$(du -h "$backup_file" | cut -f1)
        log_success "Бэкап завершен успешно!"
        echo
        echo "📁 Файл: $backup_file"
        echo "📏 Размер: $size"
        echo "📅 Дата: $(date)"
        echo
        echo "🔄 Восстановление: ./scripts/restore.sh $backup_file"
    else
        log_error "Файл бэкапа не найден!"
        exit 1
    fi
}

# Главная функция
main() {
    echo "================================================"
    echo "💾 Telegram Bot Backup Script"
    echo "================================================"
    echo
    
    # Проверяем, что Docker Compose запущен
    if ! docker-compose ps | grep -q "Up"; then
        log_error "Docker Compose сервисы не запущены!"
        log_info "Запустите сервисы: docker-compose up -d"
        exit 1
    fi
    
    backup_database
    backup_config
    backup_logs
    backup_ssl
    create_full_backup
    cleanup_old_backups
    show_backup_info
}

# Запуск
main "$@"
