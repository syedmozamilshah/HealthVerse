from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
import asyncio
from contextlib import asynccontextmanager

from src.core.config import config
from src.models.models import (
    SessionStartRequest,
    SessionStartResponse,
    NextQuestionRequest,
    NextQuestionResponse
)
from src.core.agent import ophthalmology_agent
from src.services.qdrant_service import qdrant_service
from src.services.session_manager import session_manager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    try:
        config.validate()
        logger.info("Configuration validated successfully")
        
        # Initialize Qdrant collection
        try:
            await qdrant_service.initialize_collection()
            logger.info("Qdrant collection initialized")
        except Exception as e:
            logger.warning(f"Qdrant initialization failed: {str(e)}")
            logger.warning("Running in development mode with limited functionality")
        
        logger.info("Application startup complete")
    except Exception as e:
        logger.error(f"Startup failed: {str(e)}")
        raise
    
    yield
    
    # Shutdown
    logger.info("Application shutdown complete")

# Initialize FastAPI app
app = FastAPI(
    title="Ophthalmology Assistant API",
    description="AI-powered assistant for ophthalmology consultations using LangGraph and Google Gemini",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint for health check"""
    return {"message": "Ophthalmology Assistant API is running"}

@app.get("/favicon.ico")
async def favicon():
    """Handle favicon requests to avoid 404 errors"""
    return {"message": "No favicon configured"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "services": {
            "qdrant": "connected",
            "gemini": "configured"
        }
    }

# Batch workflow endpoints removed - only iterative workflow supported

@app.get("/api/allowed-doctors")
async def get_allowed_doctors():
    """Get the list of allowed doctor types"""
    return {
        "allowed_doctors": config.ALLOWED_DOCTORS,
        "descriptions": {
            "Ophthalmologist": "General eye doctor for diagnosis, surgery, and disease management",
            "Optometrist": "Eye examination, vision correction, prescription of glasses/contact lenses",
            "Optician": "Fits and dispenses glasses or contact lenses",
            "Ocular Surgeon": "Specialist in surgical procedures for eye conditions"
        }
    }

# Iterative Questioning Endpoints

@app.post("/api/iterative/start", response_model=SessionStartResponse)
async def start_iterative_session(request: SessionStartRequest):
    """
    Start a new iterative questioning session
    
    This endpoint begins an iterative conversation where questions are asked
    one at a time based on the user's previous answers. The AI dynamically
    determines when enough information has been gathered.
    """
    try:
        logger.info(f"Starting iterative session for condition: {request.condition}")
        
        response = await session_manager.start_session(request)
        
        logger.info(f"Started session {response.session_id} with confidence {response.confidence_score.overall_confidence:.2f}")
        return response
        
    except Exception as e:
        logger.error(f"Error starting iterative session: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to start session: {str(e)}"
        )

@app.post("/api/iterative/next", response_model=NextQuestionResponse)
async def get_next_question(request: NextQuestionRequest):
    """
    Process user answer and get next question or final recommendation
    
    This endpoint processes the user's answer to the previous question,
    updates confidence scores, and either provides the next question
    or finalizes the session with a doctor recommendation.
    """
    try:
        logger.info(f"Processing answer for session {request.session_id}")
        
        response = await session_manager.process_answer_and_get_next_question(request)
        
        if response.is_complete:
            logger.info(f"Session {request.session_id} completed with recommendation: {response.doctor_recommendation.doctor_type}")
        else:
            logger.info(f"Generated next question for session {request.session_id}")
            
        return response
        
    except ValueError as e:
        logger.error(f"Session not found: {str(e)}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error processing answer: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process answer: {str(e)}"
        )

@app.get("/api/iterative/session/{session_id}")
async def get_session_status(session_id: str):
    """
    Get current session status and conversation history
    
    This endpoint allows retrieving the current state of a session,
    including conversation history and confidence scores.
    """
    try:
        session = await session_manager.get_session(session_id)
        
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
            
        return {
            "session_id": session.session_id,
            "initial_condition": session.initial_condition,
            "conversation_history": session.conversation_history,
            "confidence_score": session.confidence_score,
            "current_leading_doctor": session.current_leading_doctor,
            "is_complete": session.is_complete,
            "created_at": session.created_at,
            "updated_at": session.updated_at
        }
        
    except Exception as e:
        logger.error(f"Error retrieving session {session_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve session: {str(e)}")

@app.post("/api/add-knowledge")
async def add_knowledge_document(content: str, metadata: dict = None):
    """
    Add a document to the knowledge base (for testing/admin purposes)
    
    This endpoint allows adding medical knowledge documents to the Qdrant vector store.
    """
    try:
        success = await qdrant_service.add_document(content, metadata)
        
        if success:
            return {"message": "Document added successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to add document")
            
    except Exception as e:
        logger.error(f"Error adding document: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to add document: {str(e)}")

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"detail": "An unexpected error occurred"}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=config.DEBUG
    )
