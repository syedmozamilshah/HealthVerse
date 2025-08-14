from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
import asyncio
from contextlib import asynccontextmanager

from src.core.config import config
from src.models.models import (
    InitialConditionRequest, 
    QuestionsResponse, 
    AnswersRequest, 
    FinalResponse,
    UserAnswer
)
from src.core.agent import ophthalmology_agent
from src.services.qdrant_service import qdrant_service

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
        await qdrant_service.initialize_collection()
        logger.info("Qdrant collection initialized")
        
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

@app.post("/api/generate-questions", response_model=QuestionsResponse)
async def generate_questions(request: InitialConditionRequest):
    """
    Generate follow-up questions based on initial condition
    
    This endpoint takes the user's initial eye-related condition and generates
    3-5 follow-up questions with dynamic answer options using the LLM.
    """
    try:
        logger.info(f"Generating questions for condition: {request.condition}")
        
        # Generate questions using the agent
        questions = await ophthalmology_agent.generate_questions(request.condition)
        
        response = QuestionsResponse(questions=questions)
        logger.info(f"Successfully generated {len(questions)} questions")
        
        return response
        
    except Exception as e:
        logger.error(f"Error generating questions: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to generate questions: {str(e)}"
        )

@app.post("/api/process-answers", response_model=FinalResponse)
async def process_answers(request: AnswersRequest):
    """
    Process user answers and generate final recommendation
    
    This endpoint processes the user's answers to follow-up questions,
    uses RAG to retrieve relevant medical context, identifies the most
    appropriate doctor type, and generates a medical summary.
    """
    try:
        logger.info(f"Processing answers for condition: {request.initial_condition}")
        
        # Process the complete flow using the agent
        final_state = await ophthalmology_agent.process_complete_flow(
            initial_condition=request.initial_condition,
            answers=request.answers
        )
        
        # Create the final response
        response = FinalResponse(
            doctor=final_state.doctor_recommendation,
            summary_for_doctor=final_state.summary
        )
        
        logger.info(f"Successfully processed answers, recommended: {final_state.doctor_recommendation.doctor_type}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing answers: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process answers: {str(e)}"
        )

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
