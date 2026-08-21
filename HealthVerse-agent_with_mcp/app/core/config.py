import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))
    API_RELOAD: bool = os.getenv("API_RELOAD", "false").lower() == "true"
    API_LOG_LEVEL: str = os.getenv("API_LOG_LEVEL", "info")
    
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_BASE_URL: str = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
    GROQ_MODEL: str = os.getenv("GROQ_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")

    OPENROUTER_API_KEY: str = os.getenv("OPENROUTER_API_KEY", "")
    OPENROUTER_BASE_URL: str = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    OPENROUTER_EMBEDDING_MODEL: str = os.getenv("OPENROUTER_EMBEDDING_MODEL", "qwen/qwen3-embedding-8b")
    EMBEDDING_VECTOR_SIZE: int = int(os.getenv("EMBEDDING_VECTOR_SIZE", "4096"))
    
    QDRANT_CLUSTER_KEY: str = os.getenv("QDRANT_CLUSTER_KEY", "")
    QDRANT_CLUSTER_ID: str = os.getenv("QDRANT_CLUSTER_ID", "")
    QDRANT_ENDPOINT: str = os.getenv("QDRANT_ENDPOINT", "")
    QDRANT_COLLECTION_NAME: str = os.getenv("QDRANT_COLLECTION_NAME", "")
    
    CONFIDENCE_THRESHOLD: float = float(os.getenv("CONFIDENCE_THRESHOLD", "0.85"))
    MAX_ITERATIONS: int = int(os.getenv("MAX_ITERATIONS", "6"))
    TOP_K_SEARCH: int = int(os.getenv("TOP_K_SEARCH", "5"))
    
    MCQS_PER_ITERATION: int = int(os.getenv("MCQS_PER_ITERATION", "1"))
    MCQ_OPTIONS_COUNT: int = int(os.getenv("MCQ_OPTIONS_COUNT", "4"))
    
    class Config:
        env_file = ".env"

settings = Settings()
