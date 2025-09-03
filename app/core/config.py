import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class Settings(BaseSettings):
    """Application settings"""
    # API settings
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8080"))
    API_RELOAD: bool = os.getenv("API_RELOAD", "false").lower() == "true"
    API_LOG_LEVEL: str = os.getenv("API_LOG_LEVEL", "info")
    
    # Gemini settings
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_EMBEDDING_MODEL: str = os.getenv("GEMINI_EMBEDDING_MODEL", "models/text-embedding-004")
    GEMINI_REASONING_MODEL: str = os.getenv("GEMINI_REASONING_MODEL", "gemini-2.0-flash")
    
    # Qdrant settings
    QDRANT_CLUSTER_KEY: str = os.getenv("QDRANT_CLUSTER_KEY", "")
    QDRANT_CLUSTER_ID: str = os.getenv("QDRANT_CLUSTER_ID", "")
    QDRANT_ENDPOINT: str = os.getenv("QDRANT_ENDPOINT", "")
    QDRANT_COLLECTION_NAME: str = os.getenv("QDRANT_COLLECTION_NAME", "")
    
    # Agent settings
    CONFIDENCE_THRESHOLD: float = float(os.getenv("CONFIDENCE_THRESHOLD", "0.85"))
    MAX_ITERATIONS: int = int(os.getenv("MAX_ITERATIONS", "6"))
    TOP_K_SEARCH: int = int(os.getenv("TOP_K_SEARCH", "5"))
    
    # MCQ settings
    MCQS_PER_ITERATION: int = int(os.getenv("MCQS_PER_ITERATION", "1"))
    MCQ_OPTIONS_COUNT: int = int(os.getenv("MCQ_OPTIONS_COUNT", "4"))
    
    class Config:
        env_file = ".env"

# Create settings instance
settings = Settings()