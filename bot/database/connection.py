"""
Подключение к базе данных
"""

import asyncio
from contextlib import asynccontextmanager
from typing import AsyncGenerator
import asyncpg
import structlog
from config import settings

logger = structlog.get_logger()

# Глобальный пул соединений
_db_pool: asyncpg.Pool = None


async def init_db():
    """Инициализация пула соединений к базе данных"""
    global _db_pool
    
    try:
        _db_pool = await asyncpg.create_pool(
            settings.database_url,
            min_size=2,
            max_size=10,
            command_timeout=60,
            server_settings={
                'jit': 'off',
                'application_name': 'telegram_ticket_bot'
            }
        )
        
        # Проверяем соединение
        async with _db_pool.acquire() as conn:
            await conn.fetchval('SELECT 1')
            
        logger.info("Database connection pool initialized")
        
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


async def close_db():
    """Закрытие пула соединений"""
    global _db_pool
    
    if _db_pool:
        await _db_pool.close()
        logger.info("Database connection pool closed")


@asynccontextmanager
async def get_db_connection() -> AsyncGenerator[asyncpg.Connection, None]:
    """Получение соединения с базой данных"""
    if not _db_pool:
        raise RuntimeError("Database pool not initialized")
    
    async with _db_pool.acquire() as connection:
        try:
            yield connection
        except Exception as e:
            logger.error(f"Database operation failed: {e}")
            raise


async def test_connection() -> bool:
    """Тестирование соединения с базой данных"""
    try:
        async with get_db_connection() as conn:
            await conn.fetchval('SELECT 1')
        return True
    except Exception as e:
        logger.error(f"Database connection test failed: {e}")
        return False


async def execute_query(query: str, *args):
    """Выполнение SQL запроса"""
    async with get_db_connection() as conn:
        return await conn.execute(query, *args)


async def fetch_one(query: str, *args):
    """Получение одной записи"""
    async with get_db_connection() as conn:
        return await conn.fetchrow(query, *args)


async def fetch_all(query: str, *args):
    """Получение всех записей"""
    async with get_db_connection() as conn:
        return await conn.fetch(query, *args)
