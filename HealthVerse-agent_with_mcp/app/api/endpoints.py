from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
import asyncio

from app.core.session_manager import session_manager
from app.services.question_service import question_service

class InitialSymptomsRequest(BaseModel):
    symptoms: str = Field(..., description="The user's initial eye symptoms")
    user_history: Optional[str] = Field(None, description="User's medical history - helps generate more relevant questions (optional)")

class AnswerRequest(BaseModel):
    session_id: str = Field(..., description="Session ID")
    question_id: str = Field(..., description="ID of the question being answered")
    option_id: str = Field(..., description="ID of the selected option")
    custom_text: Optional[str] = Field(None, description="Custom text for 'Other' option")

class SessionResponse(BaseModel):
    session_id: str = Field(..., description="Unique session identifier")
    question: Optional[Dict[str, Any]] = Field(None, description="Current question with options")
    initial_guess: Optional[str] = Field(None, description="Initial doctor type guess")
    is_completed: bool = Field(..., description="Whether the assessment is completed")
    questions_answered: int = Field(..., description="Number of questions answered so far")
    total_questions: int = Field(..., description="Total questions in session")
    error: Optional[bool] = Field(None, description="Whether there was an error")
    error_message: Optional[str] = Field(None, description="Error message for invalid input")
    detected_language: Optional[str] = Field(None, description="Detected language of user input")

class HistoryRequest(BaseModel):
    session_id: str = Field(..., description="Session ID")
    medical_history: str = Field(..., description="User's medical history")

class SessionHistoryResponse(BaseModel):
    session_id: str = Field(..., description="Session ID")
    conversation_history: List[Dict[str, Any]] = Field(..., description="Full conversation history")
    updated: bool = Field(..., description="Whether history was updated")

router = APIRouter(prefix="/health-assessment", tags=["health-assessment"])

def cleanup_sessions():
    cleaned = session_manager.cleanup_expired_sessions()
    if cleaned > 0:
        print(f"Cleaned up {cleaned} expired sessions")

@router.post("/start", response_model=SessionResponse)
async def start_assessment(request: InitialSymptomsRequest, background_tasks: BackgroundTasks):
    try:
        background_tasks.add_task(cleanup_sessions)
        
        question_result = await question_service.generate_first_question(
            symptoms=request.symptoms,
            user_history=request.user_history
        )
        
        # Check if there was a validation error
        if question_result.get("error"):
            return SessionResponse(
                session_id="",
                question=None,
                initial_guess=None,
                is_completed=False,
                questions_answered=0,
                total_questions=0,
                error=True,
                error_message=question_result.get("error_message"),
                detected_language=question_result.get("detected_language")
            )
        
        session_id = session_manager.create_session(
            initial_symptoms=request.symptoms,
            user_history=request.user_history,
            detected_language=question_result.get("detected_language")
        )
        
        session_manager.add_question(
            session_id=session_id,
            question_text=question_result["question"]["question_text"],
            options=question_result["question"]["options"]
        )
        
        session_manager.set_doctor_guess(
            session_id=session_id,
            doctor_type=question_result["doctor_guess"]
        )
        
        session_summary = session_manager.get_session_summary(session_id)
        
        return SessionResponse(
            session_id=session_summary["session_id"],
            question=session_summary["current_question"],
            initial_guess=session_summary["initial_guess"],
            is_completed=session_summary["is_completed"],
            questions_answered=session_summary["questions_answered"],
            total_questions=session_summary["total_questions"],
            detected_language=question_result.get("detected_language")
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error starting assessment: {str(e)}")

@router.post("/answer", response_model=SessionResponse)
async def submit_answer(request: AnswerRequest):
    try:
        session = session_manager.get_session(request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found or expired")
        
        success = session_manager.add_answer(
            session_id=request.session_id,
            question_id=request.question_id,
            option_id=request.option_id,
            custom_text=request.custom_text
        )
        
        if not success:
            raise HTTPException(status_code=400, detail="Failed to add answer")
        
        session = session_manager.get_session(request.session_id)  
        if not session.is_completed and session.current_question_index < session.max_questions:
            question_result = await question_service.generate_followup_question(session)
            
            session_manager.add_question(
                session_id=request.session_id,
                question_text=question_result["question"]["question_text"],
                options=question_result["question"]["options"]
            )
        
        session_summary = session_manager.get_session_summary(request.session_id)
        
        return SessionResponse(
            session_id=session_summary["session_id"],
            question=session_summary["current_question"],
            initial_guess=session_summary["initial_guess"],
            is_completed=session_summary["is_completed"],
            questions_answered=session_summary["questions_answered"],
            total_questions=session_summary["total_questions"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error submitting answer: {str(e)}")

@router.post("/history", response_model=SessionHistoryResponse)
async def update_user_history(request: HistoryRequest):
    try:
        session = session_manager.get_session(request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found or expired")
        
        session.user_history = request.medical_history
        
        conversation_history = session_manager.get_conversation_history(request.session_id)
        
        return SessionHistoryResponse(
            session_id=request.session_id,
            conversation_history=conversation_history or [],
            updated=True
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error updating history: {str(e)}")

@router.get("/session/{session_id}", response_model=SessionResponse)
async def get_session_status(session_id: str):
    try:
        session_summary = session_manager.get_session_summary(session_id)
        if not session_summary:
            raise HTTPException(status_code=404, detail="Session not found or expired")
        
        return SessionResponse(
            session_id=session_summary["session_id"],
            question=session_summary["current_question"],
            initial_guess=session_summary["initial_guess"],
            is_completed=session_summary["is_completed"],
            questions_answered=session_summary["questions_answered"],
            total_questions=session_summary["total_questions"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting session: {str(e)}")

class InitialConditionRequest(BaseModel):
    session_id: str = Field(..., description="Session ID")

class InitialConditionResponse(BaseModel):
    session_id: str = Field(..., description="Session ID")
    initial_condition_summary: str = Field(..., description="Complete clinical summary in English")
    doctor_recommendation: Optional[str] = Field(None, description="Recommended doctor type")
    chief_complaint: Optional[str] = Field(None, description="Patient's main complaint in English")
    history_of_present_illness: Optional[str] = Field(None, description="Detailed history")
    associated_symptoms: Optional[List[str]] = Field(None, description="Related symptoms")
    medical_history: Optional[str] = Field(None, description="Patient's medical history")
    clinical_assessment: Optional[str] = Field(None, description="Clinical impression")
    confidence_score: Optional[float] = Field(None, description="Confidence in recommendation")
    urgency_level: Optional[str] = Field(None, description="Urgency: Low/Medium/High/Emergency")
    reasoning: Optional[str] = Field(None, description="Reasoning for specialist recommendation")
    recommended_actions: Optional[List[str]] = Field(None, description="Recommended next steps")

@router.post("/initial-condition", response_model=InitialConditionResponse)
async def get_initial_condition_summary(request: InitialConditionRequest):
    """Generate a comprehensive clinical summary in ENGLISH for medical documentation, regardless of assessment language."""
    try:
        session = session_manager.get_session(request.session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found or expired")
        
        # Use LLM to generate comprehensive English clinical summary
        result = await question_service.generate_english_clinical_summary(session)
        
        summary_data = result.get("summary", {})
        
        return InitialConditionResponse(
            session_id=request.session_id,
            initial_condition_summary=summary_data.get("full_summary", ""),
            doctor_recommendation=summary_data.get("recommended_specialist"),
            chief_complaint=summary_data.get("chief_complaint"),
            history_of_present_illness=summary_data.get("history_of_present_illness"),
            associated_symptoms=summary_data.get("associated_symptoms"),
            medical_history=summary_data.get("medical_history"),
            clinical_assessment=summary_data.get("clinical_assessment"),
            confidence_score=summary_data.get("confidence_score"),
            urgency_level=summary_data.get("urgency_level"),
            reasoning=summary_data.get("reasoning"),
            recommended_actions=summary_data.get("recommended_actions")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating initial condition summary: {str(e)}")

@router.get("/session/{session_id}/history", response_model=SessionHistoryResponse)
async def get_conversation_history(session_id: str):
    try:
        conversation_history = session_manager.get_conversation_history(session_id)
        if conversation_history is None:
            raise HTTPException(status_code=404, detail="Session not found or expired")
        
        return SessionHistoryResponse(
            session_id=session_id,
            conversation_history=conversation_history,
            updated=False
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting conversation history: {str(e)}")
