FROM nginx:alpine

# Установка дополнительных утилит
RUN apk add --no-cache openssl apache2-utils

# Копирование конфигурации
COPY nginx.conf /etc/nginx/nginx.conf

# Создание директорий
RUN mkdir -p /etc/nginx/ssl /var/www/certbot

# Создание базового .htpasswd файла (будет перезаписан при запуске)
RUN echo "monitoring:\$apr1\$salt\$hash" > /etc/nginx/.htpasswd

# Проверка здоровья
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/nginx-health || exit 1

EXPOSE 80 443
