import uvicorn
import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
if __name__ == "__main__":
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))    
    from app.api.endpoints import router as health_assessment_router
    from app.core.config import settings
else:
    from app.api.endpoints import router as health_assessment_router
    from app.core.config import settings

app = FastAPI(
    title="Health Assessment API",
    description="Intelligent health assessment system with session management, RAG-powered question generation, and multi-user support",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_assessment_router)
@app.get("/")
async def root():
    return {
        "message": "Welcome to the Health Assessment API",
        "version": "2.0.0",
        "features": [
            "Session-based assessments",
            "RAG-powered question generation", 
            "Multi-user support",
            "Intelligent doctor recommendations"
        ],
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        app,
        host=settings.API_HOST,
        port=port, 
        reload=settings.API_RELOAD,
        log_level=settings.API_LOG_LEVEL
    )