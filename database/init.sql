-- Инициализация базы данных для Telegram Ticket Bot

-- Создание пользователя и базы данных (если не существует)
-- Эти команды выполняются автоматически через переменные окружения Docker

-- Настройка расширений
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Настройка часового пояса
SET timezone = 'UTC';

-- Создание схем
CREATE SCHEMA IF NOT EXISTS telegram_bot;
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Комментарии к схемам
COMMENT ON SCHEMA telegram_bot IS 'Основная схема для данных Telegram бота';
COMMENT ON SCHEMA monitoring IS 'Схема для данных мониторинга и метрик';
