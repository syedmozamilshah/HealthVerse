"""
main.py — Entry point for HealthVerse Doctor Specialist Agents
"""
import logging
import sys
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import API_HOST, API_PORT, API_RELOAD, ALLOWED_ORIGINS, GROQ_MODEL
from api.chat_routes import router as chat_router

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


# ── Startup / Shutdown ────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=" * 60)
    logger.info("  HealthVerse Doctor Specialist Agents — Starting Up")
    logger.info(f"  Model: {GROQ_MODEL}")
    logger.info(f"  Specialists: ophthalmologist, optometrist, optician, ocularist")
    logger.info("=" * 60)
    yield
    logger.info("HealthVerse Doctor Specialist Agents — Shutting Down")


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="HealthVerse Doctor Specialist Agents",
    description=(
        "Unified multi-specialist eye-care AI system for doctors. "
        "Powered by LangGraph ReAct agents with GPT-OSS-120B."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow .NET backend to call this service
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)

# Routes
app.include_router(chat_router)


# ── Health endpoints ──────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {
        "service": "HealthVerse Doctor Specialist Agents",
        "status": "running",
        "specialists": ["ophthalmologist", "optometrist", "optician", "ocularist"],
    }

@app.get("/health")
async def health():
    return {"status": "healthy"}


# ── Dev runner ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=API_HOST,
        port=API_PORT,
        reload=API_RELOAD,
        log_level="info",
    )
