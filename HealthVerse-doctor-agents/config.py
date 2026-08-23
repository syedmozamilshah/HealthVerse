"""
config.py - Central configuration loaded from environment variables.
"""
import os
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
GROQ_BASE_URL: str = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
GROQ_MODEL: str = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")

API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
API_PORT: int = int(os.getenv("API_PORT", "8001"))
API_RELOAD: bool = os.getenv("API_RELOAD", "true").lower() == "true"

ALLOWED_ORIGINS: list[str] = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:5257,http://localhost:5000"
).split(",")

# How many recent conversation turns to include in context (each turn = 1 user + 1 assistant)
MAX_CONTEXT_TURNS: int = int(os.getenv("MAX_CONTEXT_TURNS", "10"))
