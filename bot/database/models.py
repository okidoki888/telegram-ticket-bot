"""
Модели базы данных
"""

from datetime import datetime
from typing import Optional
from dataclasses import dataclass


@dataclass
class TicketLog:
    """Модель для логирования обработанных заявок"""
    
    id: Optional[int] = None
    chat_id: int = 0
    source_message_id: int = 0
    sink_message_id: int = 0
    source_thread_id: int = 0
    sink_thread_id: int = 0
    user_id: Optional[int] = None
    message_text: str = ""
    media_type: str = ""
    created_at: Optional[datetime] = None
    
    def to_dict(self) -> dict:
        """Конвертация в словарь"""
        return {
            'id': self.id,
            'chat_id': self.chat_id,
            'source_message_id': self.source_message_id,
            'sink_message_id': self.sink_message_id,
            'source_thread_id': self.source_thread_id,
            'sink_thread_id': self.sink_thread_id,
            'user_id': self.user_id,
            'message_text': self.message_text,
            'media_type': self.media_type,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


@dataclass
class BotMetrics:
    """Модель для метрик бота"""
    
    id: Optional[int] = None
    metric_name: str = ""
    metric_value: float = 0.0
    metric_labels: dict = None
    created_at: Optional[datetime] = None
    
    def to_dict(self) -> dict:
        """Конвертация в словарь"""
        return {
            'id': self.id,
            'metric_name': self.metric_name,
            'metric_value': self.metric_value,
            'metric_labels': self.metric_labels or {},
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
