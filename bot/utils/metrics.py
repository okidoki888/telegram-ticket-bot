"""
Метрики для мониторинга
"""

from prometheus_client import Counter, Histogram, Gauge, start_http_server
import structlog

logger = structlog.get_logger()


class BotMetrics:
    """Класс для хранения метрик бота"""
    
    def __init__(self):
        # Счетчики
        self.webhook_requests_total = Counter(
            'telegram_bot_webhook_requests_total',
            'Total number of webhook requests received'
        )
        
        self.webhook_errors_total = Counter(
            'telegram_bot_webhook_errors_total', 
            'Total number of webhook errors'
        )
        
        self.reactions_received_total = Counter(
            'telegram_bot_reactions_received_total',
            'Total number of reactions received'
        )
        
        self.reaction_errors_total = Counter(
            'telegram_bot_reaction_errors_total',
            'Total number of reaction processing errors'
        )
        
        self.updates_processed_total = Counter(
            'telegram_bot_updates_processed_total',
            'Total number of updates processed successfully'
        )
        
        self.update_errors_total = Counter(
            'telegram_bot_update_errors_total',
            'Total number of update processing errors'
        )
        
        self.tickets_processed_total = Counter(
            'telegram_bot_tickets_processed_total',
            'Total number of tickets processed successfully'
        )
        
        self.tickets_rejected_total = Counter(
            'telegram_bot_tickets_rejected_total',
            'Total number of tickets rejected (filters)',
            ['reason']
        )
        
        self.google_sheets_writes_total = Counter(
            'telegram_bot_google_sheets_writes_total',
            'Total number of Google Sheets write operations'
        )
        
        self.google_sheets_errors_total = Counter(
            'telegram_bot_google_sheets_errors_total',
            'Total number of Google Sheets errors'
        )
        
        # Гистограммы для времени обработки
        self.reaction_processing_duration = Histogram(
            'telegram_bot_reaction_processing_duration_seconds',
            'Time spent processing reactions'
        )
        
        self.database_operation_duration = Histogram(
            'telegram_bot_database_operation_duration_seconds',
            'Time spent on database operations',
            ['operation']
        )
        
        # Гаугеры для текущего состояния
        self.active_connections = Gauge(
            'telegram_bot_active_connections',
            'Number of active database connections'
        )
        
        self.processed_messages_cache_size = Gauge(
            'telegram_bot_processed_messages_cache_size',
            'Size of the processed messages cache'
        )
        
        self.bot_uptime_seconds = Gauge(
            'telegram_bot_uptime_seconds',
            'Bot uptime in seconds'
        )


# Глобальный объект метрик
metrics = BotMetrics()


def setup_metrics():
    """Настройка метрик"""
    logger.info("Metrics initialized")


def record_reaction_processing_time(duration: float):
    """Запись времени обработки реакции"""
    metrics.reaction_processing_duration.observe(duration)


def record_database_operation_time(operation: str, duration: float):
    """Запись времени выполнения операции с БД"""
    metrics.database_operation_duration.labels(operation=operation).observe(duration)


def update_cache_size(size: int):
    """Обновление размера кеша"""
    metrics.processed_messages_cache_size.set(size)


def increment_rejection_counter(reason: str):
    """Увеличение счетчика отклоненных заявок"""
    metrics.tickets_rejected_total.labels(reason=reason).inc()
