import os
from dotenv import load_dotenv
from typing import List
import json

load_dotenv()

class Config:
    # Gemini AI Configuration
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    GEMINI_EMBEDDING_MODEL = os.getenv("GEMINI_EMBEDDING_MODEL", "models/text-embedding-004")
    GEMINI_REASONING_MODEL = os.getenv("GEMINI_REASONING_MODEL", "gemini-2.0-flash")
    
    # Qdrant Configuration
    QDRANT_ENDPOINT = os.getenv("QDRANT_ENDPOINT")
    QDRANT_CLUSTER_KEY = os.getenv("QDRANT_CLUSTER_KEY")
    QDRANT_CLUSTER_ID = os.getenv("QDRANT_CLUSTER_ID")
    QDRANT_COLLECTION_NAME = os.getenv("QDRANT_COLLECTION_NAME", "healthverse_cases")
    
    # Agent Behavior Configuration
    CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", 0.85))
    MAX_ITERATIONS = int(os.getenv("MAX_ITERATIONS", 6))
    TOP_K_SEARCH = int(os.getenv("TOP_K_SEARCH", 5))
    
    # MCQ Configuration
    MCQS_PER_ITERATION = int(os.getenv("MCQS_PER_ITERATION", 1))
    MCQ_OPTIONS_COUNT = int(os.getenv("MCQ_OPTIONS_COUNT", 4))
    
    # FastAPI Configuration
    HOST = os.getenv("API_HOST", "0.0.0.0")
    PORT = int(os.getenv("API_PORT", 8000))
    DEBUG = os.getenv("API_RELOAD", "false").lower() == "true"
    LOG_LEVEL = os.getenv("API_LOG_LEVEL", "info")
    
    # CORS Configuration
    ALLOWED_ORIGINS = ["http://localhost:3000", "http://127.0.0.1:3000"]
    
    # Eye Specialists (restricted list)
    ALLOWED_DOCTORS = [
        "Ophthalmologist",
        "Optometrist", 
        "Optician",
        "Ocular Surgeon"
    ]
    
    @classmethod
    def validate(cls):
        """Validate required configuration"""
        required_vars = [
            "GEMINI_API_KEY",
            "QDRANT_ENDPOINT",
            "QDRANT_CLUSTER_KEY"
        ]
        
        missing = []
        for var in required_vars:
            if not getattr(cls, var):
                missing.append(var)
        
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

config = Config()
