"""
Обработчики реакций на сообщения
"""

import re
import asyncio
from typing import List, Dict, Any, Optional
import structlog
from aiogram import Dispatcher
from aiogram.types import MessageReactionUpdated, ReactionTypeEmoji
from aiogram.exceptions import TelegramAPIError

from config import settings
from database.models import TicketLog
from utils.telegram_helpers import (
    get_thread_id_by_reply_probe,
    forward_message_to_sink,
    copy_message_to_sink,
    detect_media_type,
    is_reaction_added
)
from utils.sheets import log_to_google_sheets
from utils.metrics import metrics

logger = structlog.get_logger()


def setup_reaction_handlers(dp: Dispatcher):
    """Настройка обработчиков реакций"""
    dp.message_reaction.register(handle_message_reaction)


async def handle_message_reaction(reaction_update: MessageReactionUpdated):
    """
    Основной обработчик реакций на сообщения
    
    Логика:
    1. Проверяем, что реакция добавлена в нужном чате
    2. Определяем thread ID через пробный reply
    3. Проверяем фильтры (source topics, pattern)
    4. Переносим сообщение в sink topic
    5. Логируем в базу данных и Google Sheets
    """
    
    try:
        # Метрики
        metrics.reactions_received_total.inc()
        
        # Базовые проверки
        if not reaction_update.chat or reaction_update.chat.id != settings.chat_id:
            if settings.debug_verbose:
                logger.debug("Reaction not from target chat", chat_id=reaction_update.chat.id if reaction_update.chat else None)
            return
        
        if reaction_update.user and reaction_update.user.is_bot:
            if settings.debug_verbose:
                logger.debug("Reaction from bot user, ignoring")
            return
        
        # Проверяем, что реакция была добавлена
        if not is_reaction_added(reaction_update.old_reaction, reaction_update.new_reaction):
            if settings.debug_verbose:
                logger.debug("No new reaction added")
            return
        
        chat_id = reaction_update.chat.id
        message_id = reaction_update.message_id
        user_id = reaction_update.user.id if reaction_update.user else None
        
        logger.info(
            "Processing reaction",
            chat_id=chat_id,
            message_id=message_id,
            user_id=user_id
        )
        
        # Определяем thread ID
        thread_id = await get_thread_id_by_reply_probe(chat_id, message_id)
        if not thread_id:
            if settings.debug_verbose:
                logger.warning("Could not determine thread ID", message_id=message_id)
            return
        
        # Проверяем, что это не sink topic
        if thread_id == settings.sink_topic_id:
            if settings.debug_verbose:
                logger.debug("Reaction in sink topic, ignoring", thread_id=thread_id)
            return
        
        # Проверяем source topics фильтр
        if settings.enforce_source_topics and thread_id not in settings.source_topic_ids:
            if settings.debug_verbose:
                logger.debug(
                    "Thread not in source topics",
                    thread_id=thread_id,
                    source_topics=settings.source_topic_ids
                )
            return
        
        # Дедупликация
        dedup_key = f"processed:{chat_id}:{message_id}"
        if await is_already_processed(dedup_key):
            logger.debug("Message already processed", dedup_key=dedup_key)
            return
        
        # Переносим сообщение
        transferred_message, message_text, media_type = await transfer_message(
            chat_id, message_id, thread_id
        )
        
        if not transferred_message:
            logger.error("Failed to transfer message")
            return
        
        # Проверяем паттерн заявки
        if not is_ticket_message(message_text):
            if settings.debug_verbose:
                logger.debug("Message doesn't match ticket pattern", text=message_text[:100])
            return
        
        # Отправляем подтверждение в исходный тред (опционально)
        if settings.reply_ack:
            await send_ack_reply(chat_id, message_id, thread_id)
        
        # Логируем в базу данных
        await log_to_database(
            chat_id=chat_id,
            source_message_id=message_id,
            sink_message_id=transferred_message.message_id,
            source_thread_id=thread_id,
            sink_thread_id=settings.sink_topic_id,
            user_id=user_id,
            message_text=message_text,
            media_type=media_type
        )
        
        # Логируем в Google Sheets (опционально)
        if settings.google_spreadsheet_id:
            await log_to_google_sheets(
                message_text=message_text,
                media_type=media_type,
                source_thread=thread_id,
                sink_thread=settings.sink_topic_id,
                user_id=user_id
            )
        
        # Отмечаем как обработанное
        await mark_as_processed(dedup_key)
        
        # Метрики
        metrics.tickets_processed_total.inc()
        
        logger.info(
            "Ticket processed successfully",
            source_thread=thread_id,
            sink_thread=settings.sink_topic_id,
            message_id=message_id,
            transferred_id=transferred_message.message_id
        )
        
    except Exception as e:
        logger.error(f"Error processing reaction: {e}", exc_info=True)
        metrics.reaction_errors_total.inc()


async def transfer_message(chat_id: int, message_id: int, source_thread_id: int) -> tuple:
    """Перенос сообщения в sink topic"""
    
    try:
        if settings.close_transfer_mode == "copy":
            result = await copy_message_to_sink(
                chat_id, message_id, settings.sink_topic_id, silent=True
            )
        else:  # forward
            result = await forward_message_to_sink(
                chat_id, message_id, settings.sink_topic_id, silent=True
            )
        
        if not result:
            return None, "", ""
        
        # Извлекаем текст и тип медиа
        message_text = (result.text or result.caption or "").strip()
        media_type = detect_media_type(result)
        
        return result, message_text, media_type
        
    except TelegramAPIError as e:
        logger.error(f"Telegram API error during transfer: {e}")
        return None, "", ""


def is_ticket_message(text: str) -> bool:
    """Проверка, является ли сообщение заявкой"""
    if not text or not settings.ticket_pattern:
        return True  # Если паттерн не задан, принимаем все
    
    try:
        return bool(re.search(settings.ticket_pattern, text, re.IGNORECASE))
    except re.error:
        logger.error(f"Invalid ticket pattern: {settings.ticket_pattern}")
        return True


async def send_ack_reply(chat_id: int, message_id: int, thread_id: int):
    """Отправка подтверждения в исходный тред"""
    try:
        from main import app
        bot = app.state.bot
        
        await bot.send_message(
            chat_id=chat_id,
            text="✅ Закрыто",
            message_thread_id=thread_id,
            reply_to_message_id=message_id
        )
    except Exception as e:
        logger.warning(f"Failed to send ACK reply: {e}")


async def log_to_database(
    chat_id: int,
    source_message_id: int,
    sink_message_id: int,
    source_thread_id: int,
    sink_thread_id: int,
    user_id: Optional[int],
    message_text: str,
    media_type: str
):
    """Логирование в базу данных"""
    try:
        from database.connection import get_db_connection
        
        async with get_db_connection() as conn:
            await conn.execute("""
                INSERT INTO ticket_logs (
                    chat_id, source_message_id, sink_message_id,
                    source_thread_id, sink_thread_id, user_id,
                    message_text, media_type, created_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
            """, 
                chat_id, source_message_id, sink_message_id,
                source_thread_id, sink_thread_id, user_id,
                message_text[:1000], media_type  # Ограничиваем длину текста
            )
            
    except Exception as e:
        logger.error(f"Failed to log to database: {e}")


# Простое кеширование в памяти для дедупликации
_processed_cache = set()
_cache_max_size = 10000


async def is_already_processed(key: str) -> bool:
    """Проверка, была ли заявка уже обработана"""
    return key in _processed_cache


async def mark_as_processed(key: str):
    """Отметка заявки как обработанной"""
    global _processed_cache
    
    _processed_cache.add(key)
    
    # Ограничиваем размер кеша
    if len(_processed_cache) > _cache_max_size:
        # Удаляем половину старых записей
        _processed_cache = set(list(_processed_cache)[_cache_max_size // 2:])
