import uvicorn
import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Add the parent directory to sys.path when running the file directly
if __name__ == "__main__":
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))    
    from app.api.endpoints import router as ophthalmology_router
    from app.core.config import settings
else:
    from app.api.endpoints import router as ophthalmology_router
    from app.core.config import settings

# Create FastAPI app
app = FastAPI(
    title="Ophthalmology Assistant API",
    description="API for the autonomous ophthalmology assistant system",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(ophthalmology_router)

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "Welcome to the Ophthalmology Assistant API",
        "docs": "/docs"
    }

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    # Run the FastAPI app
    uvicorn.run(
        app,
        host=settings.API_HOST,
        port=8080,  # Hardcoded port to avoid conflicts
        reload=settings.API_RELOAD,
        log_level=settings.API_LOG_LEVEL
    )