import sys
import logging
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from backend.ai.config import settings
from backend.ai.database.connection import init_ai_database_tables, close_connection_pool
from backend.ai.rag.retriever import rag_retriever
from backend.ai.api.router import router as ai_router

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("alpha_x_ai")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("=========================================")
    logger.info("🚀 ALPHA X PYTHON AI COACH BACKEND STARTUP")
    logger.info(f"🛡️  Environment: {settings.ENVIRONMENT}")
    logger.info(f"🌐 Host: {settings.HOST}:{settings.PORT}")
    logger.info("=========================================")

    try:
        init_ai_database_tables()
        indexed_count = rag_retriever.reindex_all_documents()
        logger.info(f"✔ RAG Knowledge Base ready ({indexed_count} chunks indexed)")
        logger.info("✔ PostgreSQL Neon connection verified")
    except Exception as e:
        logger.error(f"Startup initialization notice: {e}")

    yield

    # Shutdown
    logger.info("Shutting down Alpha X AI Coach Backend...")
    close_connection_pool()

app = FastAPI(
    title="Alpha X Gym — Master AI Coach",
    description="Dedicated Python AI Intelligence Backend for Alpha X Gym",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS Middleware (Supports Flutter Web, Mobile native, and Localhost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount AI Router
app.include_router(ai_router)

@app.get("/")
def root():
    return {
        "service": "Alpha X Python AI Coach Backend",
        "status": "online",
        "endpoints": {
            "health": "/api/v1/ai/health",
            "chat": "/api/v1/ai/chat",
            "summary": "/api/v1/ai/summary",
            "proposals": "/api/v1/ai/proposals",
        },
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.ai.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
