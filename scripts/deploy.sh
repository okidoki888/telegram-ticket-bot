#!/bin/bash

# =============================================================================
# Telegram Bot Deployment Script
# =============================================================================

set -e  # Выход при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
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

# Проверка root прав
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Не запускайте этот скрипт под root!"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    # Проверяем Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен!"
        log_info "Установите Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Проверяем Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не установлен!"
        log_info "Установите Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Проверяем права на Docker
    if ! docker ps &> /dev/null; then
        log_error "Нет прав для работы с Docker!"
        log_info "Добавьте пользователя в группу docker: sudo usermod -aG docker $USER"
        log_info "Затем перелогиньтесь или выполните: newgrp docker"
        exit 1
    fi
    
    log_success "Все зависимости установлены"
}

# Проверка конфигурации
check_config() {
    log_info "Проверка конфигурации..."
    
    if [ ! -f ".env" ]; then
        log_error "Файл .env не найден!"
        log_info "Скопируйте env.example в .env и настройте параметры:"
        log_info "cp env.example .env"
        log_info "nano .env"
        exit 1
    fi
    
    # Загружаем переменные из .env
    source .env
    
    # Проверяем обязательные параметры
    if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ]; then
        log_error "BOT_TOKEN не настроен в .env"
        exit 1
    fi
    
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "your-domain.duckdns.org" ]; then
        log_error "DOMAIN не настроен в .env"
        exit 1
    fi
    
    if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" = "secure_random_password_here" ]; then
        log_error "DB_PASSWORD не настроен в .env"
        exit 1
    fi
    
    log_success "Конфигурация валидна"
}

# Создание необходимых директорий
create_directories() {
    log_info "Создание директорий..."
    
    mkdir -p logs
    mkdir -p bot/credentials
    mkdir -p certbot/conf
    mkdir -p certbot/www
    mkdir -p nginx/.htpasswd
    
    # Устанавливаем правильные права
    chmod 755 logs
    chmod 700 bot/credentials
    chmod 755 certbot/conf
    chmod 755 certbot/www
    
    log_success "Директории созданы"
}

# Генерация паролей для мониторинга
generate_monitoring_passwords() {
    log_info "Генерация паролей для мониторинга..."
    
    # Загружаем переменные из .env
    source .env
    
    # Генерируем пароль если не задан
    if [ -z "$MONITORING_AUTH_PASS" ]; then
        MONITORING_AUTH_PASS=$(openssl rand -base64 12)
        log_info "Сгенерирован пароль для мониторинга: $MONITORING_AUTH_PASS"
        
        # Обновляем .env файл
        sed -i "s/MONITORING_AUTH_PASS=/MONITORING_AUTH_PASS=$MONITORING_AUTH_PASS/" .env
    fi
    
    # Создаем .htpasswd файл для Nginx
    echo "$MONITORING_AUTH_USER:$(openssl passwd -apr1 $MONITORING_AUTH_PASS)" > nginx/.htpasswd
    
    log_success "Пароли настроены"
}

# Получение SSL сертификата
setup_ssl() {
    log_info "Настройка SSL сертификата..."
    
    source .env
    
    # Проверяем, есть ли уже сертификат
    if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
        log_warning "SSL сертификат уже существует"
        return
    fi
    
    # Временно запускаем nginx без SSL для получения сертификата
    log_info "Запуск временного web-сервера для получения SSL..."
    
    # Создаем временную конфигурацию nginx
    cat > nginx/nginx-temp.conf << EOF
events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name $DOMAIN;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    # Запускаем временный nginx
    docker run -d --name nginx-temp \
        -p 80:80 \
        -v "$(pwd)/nginx/nginx-temp.conf:/etc/nginx/nginx.conf:ro" \
        -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
        nginx:alpine
    
    # Ждем немного
    sleep 5
    
    # Получаем сертификат
    docker run --rm \
        -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
        -v "$(pwd)/certbot/www:/var/www/certbot" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$SSL_EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN"
    
    # Останавливаем временный nginx
    docker stop nginx-temp
    docker rm nginx-temp
    
    # Удаляем временную конфигурацию
    rm nginx/nginx-temp.conf
    
    log_success "SSL сертификат получен"
}

# Сборка и запуск контейнеров
deploy_containers() {
    log_info "Сборка и развертывание контейнеров..."
    
    # Останавливаем старые контейнеры если есть
    docker-compose down 2>/dev/null || true
    
    # Собираем образы
    log_info "Сборка образов..."
    docker-compose build --no-cache
    
    # Запускаем контейнеры
    log_info "Запуск контейнеров..."
    docker-compose up -d
    
    # Ждем пока контейнеры запустятся
    log_info "Ожидание запуска сервисов..."
    sleep 30
    
    log_success "Контейнеры запущены"
}

# Проверка здоровья сервисов
health_check() {
    log_info "Проверка здоровья сервисов..."
    
    source .env
    
    # Проверяем статус контейнеров
    log_info "Статус контейнеров:"
    docker-compose ps
    
    # Проверяем health endpoints
    services=(
        "https://$DOMAIN/health"
        "https://$DOMAIN/metrics"
    )
    
    for service in "${services[@]}"; do
        log_info "Проверка $service..."
        if curl -f -s "$service" > /dev/null; then
            log_success "$service - OK"
        else
            log_warning "$service - недоступен"
        fi
    done
    
    # Проверяем логи на ошибки
    log_info "Проверка логов на ошибки..."
    error_count=$(docker-compose logs --tail=100 | grep -i error | wc -l)
    if [ "$error_count" -eq 0 ]; then
        log_success "Ошибок в логах не найдено"
    else
        log_warning "Найдено $error_count ошибок в логах"
        log_info "Просмотр логов: docker-compose logs"
    fi
}

# Настройка webhook
setup_webhook() {
    log_info "Настройка webhook..."
    
    source .env
    
    # Ждем пока бот запустится
    sleep 10
    
    # Проверяем что webhook настроен
    webhook_info=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
    webhook_url=$(echo "$webhook_info" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$webhook_url" = "$WEBHOOK_URL" ]; then
        log_success "Webhook настроен корректно: $webhook_url"
    else
        log_warning "Webhook может быть настроен неправильно"
        log_info "Ожидаемый: $WEBHOOK_URL"
        log_info "Текущий: $webhook_url"
    fi
}

# Отображение финальной информации
show_final_info() {
    log_success "Развертывание завершено!"
    echo
    echo "=== Информация о сервисе ==="
    source .env
    echo "🌐 Основной URL: https://$DOMAIN"
    echo "📊 Grafana: https://$DOMAIN/grafana/"
    echo "📈 Prometheus: https://$DOMAIN/prometheus/"
    echo "🔧 Метрики: https://$DOMAIN/metrics"
    echo "❤️  Статус: https://$DOMAIN/health"
    echo
    echo "👤 Логин мониторинга: $MONITORING_AUTH_USER"
    echo "🔑 Пароль мониторинга: $MONITORING_AUTH_PASS"
    echo
    echo "=== Полезные команды ==="
    echo "📋 Логи: docker-compose logs -f"
    echo "📊 Статус: docker-compose ps"
    echo "🔄 Перезапуск: docker-compose restart"
    echo "🛑 Остановка: docker-compose down"
    echo "🧹 Бэкап: ./scripts/backup.sh"
    echo "🔄 Обновление: ./scripts/update.sh"
    echo
    log_success "Сервис готов к работе!"
}

# Главная функция
main() {
    echo "================================================"
    echo "🤖 Telegram Bot Deployment Script"
    echo "================================================"
    echo
    
    check_root
    check_dependencies
    check_config
    create_directories
    generate_monitoring_passwords
    setup_ssl
    deploy_containers
    health_check
    setup_webhook
    show_final_info
}

# Запуск с обработкой ошибок
if main "$@"; then
    exit 0
else
    log_error "Развертывание не удалось!"
    log_info "Проверьте логи: docker-compose logs"
    exit 1
fi
