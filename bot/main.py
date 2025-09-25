"""
Главный модуль Telegram бота для обработки заявок
"""

import asyncio
import logging
import sys
from contextlib import asynccontextmanager
from typing import Dict, Any

import structlog
import sentry_sdk
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse, Response
import uvicorn
from aiogram import Bot, Dispatcher
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiogram.types import Update

from config import settings
from database.connection import init_db, close_db
from handlers.reactions import setup_reaction_handlers
from utils.metrics import setup_metrics, metrics
from utils.telegram_helpers import setup_webhook
from utils.sheets import GoogleSheetsLogger


# Настройка логирования
structlog.configure(
    processors=[structlog.dev.ConsoleRenderer()],
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

# Настройка Sentry для мониторинга ошибок
if settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn)

# Инициализация бота и диспетчера
bot = Bot(token=settings.bot_token)
dp = Dispatcher()

# Настройка handlers
setup_reaction_handlers(dp)

# Настройка метрик
setup_metrics()

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Жизненный цикл приложения"""
    # Startup
    logger.info("Starting Telegram Bot Service")
    
    # Инициализация базы данных
    await init_db()
    
    # Настройка webhook
    webhook_url = f"{settings.webhook_url}"
    await setup_webhook(bot, webhook_url, settings.secret_token)
    
    # Инициализация Google Sheets (если настроено)
    if settings.google_spreadsheet_id:
        try:
            sheets_logger = GoogleSheetsLogger()
            app.state.sheets_logger = sheets_logger
            logger.info("Google Sheets logger initialized")
        except Exception as e:
            logger.warning(f"Failed to initialize Google Sheets: {e}")
    
    logger.info("Bot started successfully")
    
    yield
    
    # Shutdown
    logger.info("Shutting down bot")
    await close_db()
    await bot.session.close()


# Создание FastAPI приложения
app = FastAPI(
    title="Telegram Ticket Bot",
    description="Automated ticket processing for Telegram groups",
    version="1.0.0",
    lifespan=lifespan
)

# Глобальные переменные для бота
app.state.bot = bot
app.state.dp = dp


@app.get("/health")
async def health_check():
    """Проверка здоровья сервиса"""
    try:
        # Проверка соединения с ботом
        bot_info = await bot.get_me()
        
        # Проверка базы данных
        from database.connection import test_connection
        db_status = await test_connection()
        
        return {
            "status": "healthy",
            "bot": {
                "username": bot_info.username,
                "id": bot_info.id
            },
            "database": "connected" if db_status else "disconnected",
            "version": "1.0.0"
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {e}")


@app.post("/webhook")
async def webhook_handler(request: Request, background_tasks: BackgroundTasks):
    """Обработчик webhook от Telegram"""
    try:
        # Проверка секретного токена
        secret_token = request.headers.get("X-Telegram-Bot-Api-Secret-Token")
        if secret_token != settings.secret_token:
            logger.warning("Invalid secret token in webhook request")
            raise HTTPException(status_code=403, detail="Invalid secret token")
        
        # Получение обновления
        body = await request.json()
        update = Update.model_validate(body)
        
        # Метрики
        metrics.webhook_requests_total.inc()
        
        # Обработка в фоне
        background_tasks.add_task(process_update, update)
        
        return {"status": "ok"}
    
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        metrics.webhook_errors_total.inc()
        raise HTTPException(status_code=400, detail=str(e))


async def process_update(update: Update):
    """Обработка обновления от Telegram"""
    try:
        await dp.feed_update(bot, update)
        metrics.updates_processed_total.inc()
    except Exception as e:
        logger.error(f"Failed to process update: {e}")
        metrics.update_errors_total.inc()


@app.get("/metrics")
async def get_metrics():
    """Эндпоинт для метрик Prometheus"""
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    
    return Response(
        generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


@app.get("/")
async def root():
    """Корневой эндпоинт"""
    return {
        "service": "Telegram Ticket Bot",
        "version": "1.0.0",
        "status": "running"
    }


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Глобальный обработчик исключений"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    
    if settings.sentry_dsn:
        sentry_sdk.capture_exception(exc)
    
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )


if __name__ == "__main__":
    # Настройка логирования
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper()),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler("/app/logs/bot.log")
        ]
    )
    
    # Запуск сервера
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level.lower(),
        access_log=True
    )