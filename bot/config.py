"""
Конфигурация приложения
"""

import os
import re
from typing import List, Optional
from pydantic import Field, validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Настройки приложения"""
    
    # Telegram Bot Settings
    bot_token: str = Field(..., env="BOT_TOKEN")
    webhook_url: str = Field(..., env="WEBHOOK_URL")
    secret_token: str = Field(..., env="SECRET_TOKEN")
    
    # Chat Configuration
    chat_id: int = Field(..., env="CHAT_ID")
    sink_topic_id: int = Field(..., env="SINK_TOPIC_ID")
    source_topic_ids: List[int] = Field(..., env="SOURCE_TOPIC_IDS")
    
    # Bot Behavior
    close_transfer_mode: str = Field(default="copy", env="CLOSE_TRANSFER_MODE")
    reply_ack: bool = Field(default=True, env="REPLY_ACK")
    debug_verbose: bool = Field(default=True, env="DEBUG_VERBOSE")
    enforce_source_topics: bool = Field(default=True, env="ENFORCE_SOURCE_TOPICS")
    ticket_pattern: str = Field(default=r"(^|\n)Заявка:\s*\d+", env="TICKET_PATTERN")
    
    # Database
    database_url: str = Field(..., env="DATABASE_URL")
    redis_url: str = Field(default="redis://redis:6379", env="REDIS_URL")
    
    # Google Sheets (Optional)
    google_spreadsheet_id: Optional[str] = Field(default=None, env="GOOGLE_SPREADSHEET_ID")
    google_sheet_name: str = Field(default="Лист1", env="GOOGLE_SHEET_NAME")
    google_credentials_path: str = Field(default="/app/credentials/google-credentials.json")
    
    # Monitoring
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    sentry_dsn: Optional[str] = Field(default=None, env="SENTRY_DSN")
    
    # Server
    host: str = Field(default="0.0.0.0", env="HOST")
    port: int = Field(default=8000, env="PORT")
    
    @validator("source_topic_ids", pre=True)
    def parse_source_topic_ids(cls, v):
        """Парсинг списка ID тредов из строки"""
        if isinstance(v, str):
            return [int(x.strip()) for x in v.split(",") if x.strip()]
        return v
    
    @validator("ticket_pattern", pre=True)
    def compile_ticket_pattern(cls, v):
        """Компиляция регулярного выражения для проверки заявок"""
        try:
            re.compile(v)
            return v
        except re.error:
            raise ValueError(f"Invalid regex pattern: {v}")
    
    @validator("close_transfer_mode")
    def validate_transfer_mode(cls, v):
        """Валидация режима переноса сообщений"""
        if v not in ["copy", "forward"]:
            raise ValueError("close_transfer_mode must be 'copy' or 'forward'")
        return v
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# Глобальный объект настроек
settings = Settings()

# Вспомогательные функции для валидации
def is_valid_telegram_token(token: str) -> bool:
    """Проверка валидности токена Telegram бота"""
    pattern = r"^\d+:[A-Za-z0-9_-]{35}$"
    return bool(re.match(pattern, token))

def is_valid_chat_id(chat_id: int) -> bool:
    """Проверка валидности ID чата"""
    return chat_id < 0  # Групповые чаты имеют отрицательные ID

# Валидация настроек при импорте
if not is_valid_telegram_token(settings.bot_token):
    raise ValueError("Invalid Telegram bot token format")

if not is_valid_chat_id(settings.chat_id):
    raise ValueError("Invalid chat ID - must be negative for group chats")
