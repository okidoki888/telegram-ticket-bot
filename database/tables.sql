-- Таблицы для Telegram Ticket Bot

-- ============================================================================
-- ОСНОВНЫЕ ТАБЛИЦЫ
-- ============================================================================

-- Таблица для логирования обработанных заявок
CREATE TABLE IF NOT EXISTS telegram_bot.ticket_logs (
    id BIGSERIAL PRIMARY KEY,
    chat_id BIGINT NOT NULL,
    source_message_id BIGINT NOT NULL,
    sink_message_id BIGINT NOT NULL,
    source_thread_id INTEGER NOT NULL,
    sink_thread_id INTEGER NOT NULL,
    user_id BIGINT,
    message_text TEXT,
    media_type VARCHAR(50) DEFAULT 'text',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Индексы
    CONSTRAINT unique_source_message UNIQUE (chat_id, source_message_id)
);

-- Комментарии к полям
COMMENT ON TABLE telegram_bot.ticket_logs IS 'Лог всех обработанных заявок';
COMMENT ON COLUMN telegram_bot.ticket_logs.chat_id IS 'ID чата Telegram';
COMMENT ON COLUMN telegram_bot.ticket_logs.source_message_id IS 'ID исходного сообщения';
COMMENT ON COLUMN telegram_bot.ticket_logs.sink_message_id IS 'ID сообщения в sink треде';
COMMENT ON COLUMN telegram_bot.ticket_logs.source_thread_id IS 'ID исходного треда';
COMMENT ON COLUMN telegram_bot.ticket_logs.sink_thread_id IS 'ID целевого треда';
COMMENT ON COLUMN telegram_bot.ticket_logs.user_id IS 'ID пользователя, поставившего реакцию';
COMMENT ON COLUMN telegram_bot.ticket_logs.message_text IS 'Текст сообщения';
COMMENT ON COLUMN telegram_bot.ticket_logs.media_type IS 'Тип медиа (text, photo, video, etc.)';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_ticket_logs_chat_id ON telegram_bot.ticket_logs(chat_id);
CREATE INDEX IF NOT EXISTS idx_ticket_logs_created_at ON telegram_bot.ticket_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_ticket_logs_source_thread ON telegram_bot.ticket_logs(source_thread_id);
CREATE INDEX IF NOT EXISTS idx_ticket_logs_user_id ON telegram_bot.ticket_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_ticket_logs_media_type ON telegram_bot.ticket_logs(media_type);

-- ============================================================================
-- ТАБЛИЦЫ КОНФИГУРАЦИИ
-- ============================================================================

-- Таблица настроек бота
CREATE TABLE IF NOT EXISTS telegram_bot.bot_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(20) DEFAULT 'string', -- string, integer, boolean, json
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE telegram_bot.bot_settings IS 'Настройки бота, изменяемые через API';

-- Вставляем базовые настройки
INSERT INTO telegram_bot.bot_settings (setting_key, setting_value, setting_type, description) VALUES
    ('debug_mode', 'true', 'boolean', 'Режим отладки'),
    ('max_message_length', '4000', 'integer', 'Максимальная длина сообщения для логирования'),
    ('rate_limit_requests', '100', 'integer', 'Лимит запросов в минуту'),
    ('auto_cleanup_days', '30', 'integer', 'Автоочистка логов старше N дней')
ON CONFLICT (setting_key) DO NOTHING;

-- ============================================================================
-- ТАБЛИЦЫ МОНИТОРИНГА
-- ============================================================================

-- Таблица для хранения метрик
CREATE TABLE IF NOT EXISTS monitoring.bot_metrics (
    id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value NUMERIC NOT NULL,
    metric_labels JSONB DEFAULT '{}',
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE monitoring.bot_metrics IS 'Исторические метрики бота';

-- Индексы для метрик
CREATE INDEX IF NOT EXISTS idx_bot_metrics_name ON monitoring.bot_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_bot_metrics_recorded_at ON monitoring.bot_metrics(recorded_at);
CREATE INDEX IF NOT EXISTS idx_bot_metrics_labels ON monitoring.bot_metrics USING GIN(metric_labels);

-- Таблица для логирования ошибок
CREATE TABLE IF NOT EXISTS monitoring.error_logs (
    id BIGSERIAL PRIMARY KEY,
    error_type VARCHAR(100) NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB DEFAULT '{}',
    severity VARCHAR(20) DEFAULT 'error', -- debug, info, warning, error, critical
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE monitoring.error_logs IS 'Лог ошибок приложения';

-- Индексы для логов ошибок
CREATE INDEX IF NOT EXISTS idx_error_logs_type ON monitoring.error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_severity ON monitoring.error_logs(severity);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON monitoring.error_logs(created_at);

-- ============================================================================
-- ФУНКЦИИ И ТРИГГЕРЫ
-- ============================================================================

-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_ticket_logs_updated_at 
    BEFORE UPDATE ON telegram_bot.ticket_logs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bot_settings_updated_at 
    BEFORE UPDATE ON telegram_bot.bot_settings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ПРЕДСТАВЛЕНИЯ ДЛЯ АНАЛИТИКИ
-- ============================================================================

-- Представление для статистики по дням
CREATE OR REPLACE VIEW telegram_bot.daily_stats AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_tickets,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT source_thread_id) as active_threads,
    COUNT(*) FILTER (WHERE media_type = 'text') as text_messages,
    COUNT(*) FILTER (WHERE media_type != 'text') as media_messages
FROM telegram_bot.ticket_logs
GROUP BY DATE(created_at)
ORDER BY date DESC;

COMMENT ON VIEW telegram_bot.daily_stats IS 'Ежедневная статистика обработанных заявок';

-- Представление для статистики по тредам
CREATE OR REPLACE VIEW telegram_bot.thread_stats AS
SELECT 
    source_thread_id,
    COUNT(*) as total_tickets,
    COUNT(DISTINCT user_id) as unique_users,
    MIN(created_at) as first_ticket,
    MAX(created_at) as last_ticket,
    AVG(LENGTH(message_text)) as avg_message_length
FROM telegram_bot.ticket_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY source_thread_id
ORDER BY total_tickets DESC;

COMMENT ON VIEW telegram_bot.thread_stats IS 'Статистика по исходным тредам за последние 30 дней';

-- Представление для топ пользователей
CREATE OR REPLACE VIEW telegram_bot.user_stats AS
SELECT 
    user_id,
    COUNT(*) as total_tickets,
    COUNT(DISTINCT source_thread_id) as threads_used,
    MIN(created_at) as first_ticket,
    MAX(created_at) as last_ticket
FROM telegram_bot.ticket_logs
WHERE user_id IS NOT NULL
    AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY user_id
ORDER BY total_tickets DESC;

COMMENT ON VIEW telegram_bot.user_stats IS 'Статистика активности пользователей за последние 30 дней';

-- ============================================================================
-- ФУНКЦИИ ДЛЯ ОЧИСТКИ ДАННЫХ
-- ============================================================================

-- Функция для очистки старых логов
CREATE OR REPLACE FUNCTION telegram_bot.cleanup_old_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Удаляем старые логи заявок
    DELETE FROM telegram_bot.ticket_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Удаляем старые метрики (храним меньше)
    DELETE FROM monitoring.bot_metrics 
    WHERE recorded_at < NOW() - INTERVAL '1 day' * (days_to_keep / 3);
    
    -- Удаляем старые логи ошибок
    DELETE FROM monitoring.error_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep
        AND severity IN ('debug', 'info');
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION telegram_bot.cleanup_old_logs IS 'Очистка старых логов и метрик';

-- ============================================================================
-- ПРАВА ДОСТУПА
-- ============================================================================

-- Даем права пользователю bot_user
GRANT USAGE ON SCHEMA telegram_bot TO bot_user;
GRANT USAGE ON SCHEMA monitoring TO bot_user;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA telegram_bot TO bot_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA monitoring TO bot_user;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA telegram_bot TO bot_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA monitoring TO bot_user;

-- Права на представления
GRANT SELECT ON ALL TABLES IN SCHEMA telegram_bot TO bot_user;
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring TO bot_user;

-- ============================================================================
-- НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================================================

-- Вставляем тестовую запись для проверки
INSERT INTO telegram_bot.ticket_logs (
    chat_id, source_message_id, sink_message_id, 
    source_thread_id, sink_thread_id, user_id,
    message_text, media_type
) VALUES (
    -1002333320642, 1, 2, 
    658, 6, 123456789,
    'Тестовая заявка для проверки системы', 'text'
) ON CONFLICT (chat_id, source_message_id) DO NOTHING;

-- Записываем информацию о создании схемы
INSERT INTO monitoring.bot_metrics (metric_name, metric_value, metric_labels) VALUES
    ('database_schema_version', 1.0, '{"component": "database", "action": "init"}');

-- Финальная проверка
DO $$
BEGIN
    RAISE NOTICE 'Database schema created successfully!';
    RAISE NOTICE 'Tables created: %', (
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema IN ('telegram_bot', 'monitoring')
    );
END $$;
