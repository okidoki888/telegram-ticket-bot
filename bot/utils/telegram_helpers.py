"""
Вспомогательные функции для работы с Telegram API
"""

import asyncio
from typing import Optional, List
import structlog
from aiogram import Bot
from aiogram.types import Message, ReactionType, ReactionTypeEmoji
from aiogram.exceptions import TelegramAPIError

from config import settings

logger = structlog.get_logger()

# Глобальный объект бота (будет инициализирован в main.py)
_bot: Optional[Bot] = None


def set_bot(bot: Bot):
    """Установка глобального объекта бота"""
    global _bot
    _bot = bot


async def setup_webhook(bot: Bot, webhook_url: str, secret_token: str):
    """Настройка webhook для бота"""
    try:
        await bot.set_webhook(
            url=webhook_url,
            secret_token=secret_token,
            drop_pending_updates=True
        )
        logger.info("Webhook configured", url=webhook_url)
        
        # Проверяем статус webhook
        webhook_info = await bot.get_webhook_info()
        logger.info("Webhook status", 
                   url=webhook_info.url,
                   pending_updates=webhook_info.pending_update_count)
        
    except Exception as e:
        logger.error(f"Failed to setup webhook: {e}")
        raise


async def get_thread_id_by_reply_probe(chat_id: int, message_id: int) -> Optional[int]:
    """
    Определение thread ID через пробное сообщение-reply
    
    Метод:
    1. Отправляем reply к сообщению
    2. Извлекаем thread ID из ответа
    3. Сразу удаляем пробное сообщение
    """
    if not _bot:
        from main import app
        bot = app.state.bot
    else:
        bot = _bot
    
    try:
        # Отправляем пробное сообщение-reply
        probe_message = await bot.send_message(
            chat_id=chat_id,
            text="🔍",  # Минимальное сообщение
            reply_to_message_id=message_id
        )
        
        # Извлекаем thread ID
        thread_id = probe_message.message_thread_id
        
        # Сразу удаляем пробное сообщение
        try:
            await bot.delete_message(chat_id, probe_message.message_id)
        except Exception as e:
            logger.warning(f"Failed to delete probe message: {e}")
        
        return thread_id
        
    except TelegramAPIError as e:
        logger.error(f"Failed to determine thread ID: {e}")
        return None


async def copy_message_to_sink(
    chat_id: int, 
    message_id: int, 
    sink_topic_id: int, 
    silent: bool = True
) -> Optional[Message]:
    """Копирование сообщения в sink topic"""
    
    if not _bot:
        from main import app
        bot = app.state.bot
    else:
        bot = _bot
    
    try:
        result = await bot.copy_message(
            chat_id=chat_id,
            from_chat_id=chat_id,
            message_id=message_id,
            message_thread_id=sink_topic_id,
            disable_notification=silent
        )
        
        # Получаем скопированное сообщение для логирования
        copied_message = await bot.forward_message(
            chat_id=chat_id,
            from_chat_id=chat_id,
            message_id=result.message_id
        )
        
        return copied_message
        
    except TelegramAPIError as e:
        logger.error(f"Failed to copy message: {e}")
        return None


async def forward_message_to_sink(
    chat_id: int, 
    message_id: int, 
    sink_topic_id: int, 
    silent: bool = True
) -> Optional[Message]:
    """Пересылка сообщения в sink topic"""
    
    if not _bot:
        from main import app
        bot = app.state.bot
    else:
        bot = _bot
    
    try:
        result = await bot.forward_message(
            chat_id=chat_id,
            from_chat_id=chat_id,
            message_id=message_id,
            message_thread_id=sink_topic_id,
            disable_notification=silent
        )
        
        return result
        
    except TelegramAPIError as e:
        logger.error(f"Failed to forward message: {e}")
        return None


def detect_media_type(message: Message) -> str:
    """Определение типа медиа в сообщении"""
    if message.photo:
        return "photo"
    elif message.video:
        return "video"
    elif message.document:
        return "document"
    elif message.audio:
        return "audio"
    elif message.voice:
        return "voice"
    elif message.video_note:
        return "video_note"
    elif message.sticker:
        return "sticker"
    elif message.animation:
        return "animation"
    elif message.location:
        return "location"
    elif message.contact:
        return "contact"
    elif message.poll:
        return "poll"
    elif message.text:
        return "text"
    else:
        return "unknown"


def is_reaction_added(old_reaction: List[ReactionType], new_reaction: List[ReactionType]) -> bool:
    """
    Проверка, была ли добавлена новая реакция
    
    Сравниваем старый и новый списки реакций, чтобы определить,
    была ли добавлена хотя бы одна новая реакция
    """
    if not new_reaction:
        return False
    
    if not old_reaction:
        return len(new_reaction) > 0
    
    # Преобразуем в множества для сравнения
    old_set = set()
    new_set = set()
    
    for reaction in old_reaction:
        if isinstance(reaction, ReactionTypeEmoji):
            old_set.add(reaction.emoji)
    
    for reaction in new_reaction:
        if isinstance(reaction, ReactionTypeEmoji):
            new_set.add(reaction.emoji)
    
    # Проверяем, есть ли новые реакции
    return len(new_set - old_set) > 0


async def send_debug_message(text: str, thread_id: Optional[int] = None):
    """Отправка отладочного сообщения (если включен debug режим)"""
    if not settings.debug_verbose:
        return
    
    if not _bot:
        from main import app
        bot = app.state.bot
    else:
        bot = _bot
    
    try:
        await bot.send_message(
            chat_id=settings.chat_id,
            text=f"🐛 DEBUG: {text}",
            message_thread_id=thread_id or settings.sink_topic_id
        )
    except Exception as e:
        logger.warning(f"Failed to send debug message: {e}")


async def get_message_info(chat_id: int, message_id: int) -> Optional[dict]:
    """Получение информации о сообщении"""
    
    if not _bot:
        from main import app
        bot = app.state.bot
    else:
        bot = _bot
    
    try:
        # Используем метод get_chat для получения информации
        message = await bot.forward_message(
            chat_id=chat_id,
            from_chat_id=chat_id,
            message_id=message_id
        )
        
        # Сразу удаляем forwarded сообщение
        await bot.delete_message(chat_id, message.message_id)
        
        return {
            'text': message.text or message.caption,
            'media_type': detect_media_type(message),
            'date': message.date,
            'from_user': message.from_user.id if message.from_user else None
        }
        
    except Exception as e:
        logger.error(f"Failed to get message info: {e}")
        return None
