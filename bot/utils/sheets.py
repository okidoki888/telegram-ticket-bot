"""
Интеграция с Google Sheets для логирования
"""

import os
import json
from datetime import datetime
from typing import Optional, Dict, Any
import structlog
import gspread
from google.oauth2.service_account import Credentials

from config import settings
from utils.metrics import metrics

logger = structlog.get_logger()


class GoogleSheetsLogger:
    """Класс для логирования в Google Sheets"""
    
    def __init__(self):
        self.client = None
        self.sheet = None
        self._init_sheets()
    
    def _init_sheets(self):
        """Инициализация клиента Google Sheets"""
        try:
            if not settings.google_spreadsheet_id:
                logger.info("Google Sheets not configured")
                return
            
            if not os.path.exists(settings.google_credentials_path):
                logger.warning(f"Google credentials not found: {settings.google_credentials_path}")
                return
            
            # Настройка авторизации
            scope = [
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/drive'
            ]
            
            credentials = Credentials.from_service_account_file(
                settings.google_credentials_path,
                scopes=scope
            )
            
            self.client = gspread.authorize(credentials)
            
            # Открываем таблицу
            spreadsheet = self.client.open_by_key(settings.google_spreadsheet_id)
            self.sheet = spreadsheet.worksheet(settings.google_sheet_name)
            
            # Проверяем заголовки
            self._ensure_headers()
            
            logger.info("Google Sheets integration initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize Google Sheets: {e}")
            self.client = None
            self.sheet = None
    
    def _ensure_headers(self):
        """Проверка и создание заголовков в таблице"""
        try:
            headers = [
                'Дата/Время',
                'Тред-источник', 
                'Тред-назначение',
                'ID пользователя',
                'Тип медиа',
                'Текст сообщения',
                'Статус'
            ]
            
            # Проверяем первую строку
            first_row = self.sheet.row_values(1)
            
            if not first_row or first_row != headers:
                # Вставляем заголовки
                self.sheet.insert_row(headers, 1)
                logger.info("Headers added to Google Sheets")
                
        except Exception as e:
            logger.error(f"Failed to ensure headers: {e}")
    
    async def log_ticket(
        self,
        message_text: str,
        media_type: str,
        source_thread: int,
        sink_thread: int,
        user_id: Optional[int] = None
    ):
        """Логирование заявки в Google Sheets"""
        
        if not self.sheet:
            return
        
        try:
            # Подготавливаем данные
            now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            row_data = [
                now,
                str(source_thread),
                str(sink_thread),
                str(user_id) if user_id else 'Неизвестно',
                media_type,
                message_text[:500] + ('...' if len(message_text) > 500 else ''),  # Ограничиваем длину
                'Обработано'
            ]
            
            # Добавляем строку
            self.sheet.append_row(row_data)
            
            metrics.google_sheets_writes_total.inc()
            
            logger.debug("Ticket logged to Google Sheets",
                        source_thread=source_thread,
                        sink_thread=sink_thread)
            
        except Exception as e:
            logger.error(f"Failed to log to Google Sheets: {e}")
            metrics.google_sheets_errors_total.inc()
    
    def get_stats(self) -> Dict[str, Any]:
        """Получение статистики из Google Sheets"""
        
        if not self.sheet:
            return {}
        
        try:
            # Получаем все данные
            all_values = self.sheet.get_all_values()
            
            if len(all_values) <= 1:  # Только заголовки
                return {'total_tickets': 0}
            
            # Подсчитываем статистику
            total_tickets = len(all_values) - 1  # Исключаем заголовки
            
            # Группируем по тредам-источникам
            source_threads = {}
            media_types = {}
            
            for row in all_values[1:]:  # Пропускаем заголовки
                if len(row) >= 5:
                    source_thread = row[1]
                    media_type = row[4]
                    
                    source_threads[source_thread] = source_threads.get(source_thread, 0) + 1
                    media_types[media_type] = media_types.get(media_type, 0) + 1
            
            return {
                'total_tickets': total_tickets,
                'source_threads': source_threads,
                'media_types': media_types
            }
            
        except Exception as e:
            logger.error(f"Failed to get stats from Google Sheets: {e}")
            return {}


# Глобальные переменные для Google Sheets
_sheets_logger: Optional[GoogleSheetsLogger] = None


def init_google_sheets() -> Optional[GoogleSheetsLogger]:
    """Инициализация Google Sheets логгера"""
    global _sheets_logger
    
    try:
        _sheets_logger = GoogleSheetsLogger()
        return _sheets_logger
    except Exception as e:
        logger.error(f"Failed to initialize Google Sheets logger: {e}")
        return None


def get_sheets_logger() -> Optional[GoogleSheetsLogger]:
    """Получение Google Sheets логгера"""
    return _sheets_logger


async def log_to_google_sheets(
    message_text: str,
    media_type: str,
    source_thread: int,
    sink_thread: int,
    user_id: Optional[int] = None
):
    """Вспомогательная функция для логирования в Google Sheets"""
    
    if _sheets_logger:
        await _sheets_logger.log_ticket(
            message_text=message_text,
            media_type=media_type,
            source_thread=source_thread,
            sink_thread=sink_thread,
            user_id=user_id
        )


def create_credentials_template():
    """Создание шаблона credentials файла"""
    template = {
        "type": "service_account",
        "project_id": "your-project-id",
        "private_key_id": "your-private-key-id",
        "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR-PRIVATE-KEY\n-----END PRIVATE KEY-----\n",
        "client_email": "your-service-account@your-project.iam.gserviceaccount.com",
        "client_id": "your-client-id",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
    }
    
    return json.dumps(template, indent=2)
