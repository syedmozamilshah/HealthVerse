from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field

from agents.ophthalmology.agent import OphthalmologyAgent

# Define API models
class ConditionRequest(BaseModel):
    condition: str = Field(..., description="The user's initial eye condition or symptom")

class AnswerRequest(BaseModel):
    question: str = Field(..., description="The question that was asked")
    answer: str = Field(..., description="The user's answer to the question")
    is_custom: bool = Field(False, description="Whether this is a custom answer (from 'Other' option)")

class QuestionResponse(BaseModel):
    question_text: str = Field(..., description="The text of the follow-up question")
    options: List[str] = Field(..., description="List of possible answer options including 'Other'")

class DoctorResponse(BaseModel):
    doctor_type: str = Field(..., description="The identified doctor type")
    confidence: float = Field(..., description="Confidence score for the identification")
    reasoning: str = Field(..., description="Reasoning behind the doctor identification")

class SummaryResponse(BaseModel):
    doctor_type: str = Field(..., description="The identified doctor type")
    summary: str = Field(..., description="Medical summary for the doctor")
    confidence: float = Field(..., description="Overall confidence in the recommendation")
    key_symptoms: List[str] = Field(..., description="Key symptoms identified")
    recommended_tests: Optional[List[str]] = Field(None, description="Recommended tests if applicable")

# Create router
router = APIRouter(prefix="/ophthalmology", tags=["ophthalmology"])

# Dependency to get the ophthalmology agent
def get_ophthalmology_agent():
    """Simple function to create agent without async initialization"""
    from mcp_server.tools.ophthalmology_tools import (
        generate_followup_question,
        identify_doctor,
        query_qdrant,
        generate_doctor_summary,
        UserAnswer,
        QdrantResult
    )
    
    agent = {
        'generate_question': generate_followup_question,
        'identify_doctor': identify_doctor,
        'query_qdrant': query_qdrant,
        'generate_summary': generate_doctor_summary,
        'UserAnswer': UserAnswer,
        'QdrantResult': QdrantResult
    }
    return agent

# API endpoints
@router.post("/condition", response_model=QuestionResponse)
def submit_condition(request: ConditionRequest, agent: dict = Depends(get_ophthalmology_agent)):
    """Submit the initial eye condition and get the first follow-up question"""
    try:
        # Generate the first question using the tool directly
        question = agent['generate_question'](request.condition)
        
        return QuestionResponse(
            question_text=question.question_text,
            options=question.options
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/answer", response_model=Dict[str, Any])
def submit_answer(request: AnswerRequest, agent: dict = Depends(get_ophthalmology_agent)):
    """Submit an answer to a question and get the next step"""
    try:
        # For now, return a mock response with the next question
        # In a real implementation, this would track session state
        
        # Generate a follow-up question based on the previous answer
        previous_answers = [agent['UserAnswer'](
            question=request.question,
            answer=request.answer,
            is_custom=request.is_custom
        )]
        
        # Mock condition for demo purposes
        condition = "Eye condition from previous step"
        next_question = agent['generate_question'](condition, previous_answers)
        
        return {
            "next_step": "question",
            "question": {
                "question_text": next_question.question_text,
                "options": next_question.options
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/identify-doctor", response_model=DoctorResponse)
def identify_doctor_endpoint(request: List[AnswerRequest], condition: str, agent: dict = Depends(get_ophthalmology_agent)):
    """Identify the most appropriate doctor based on the condition and answers"""
    try:
        # Convert the answers to UserAnswer objects
        user_answers = [agent['UserAnswer'](
            question=answer.question,
            answer=answer.answer,
            is_custom=answer.is_custom
        ) for answer in request]
        
        # Identify the doctor using the tool
        doctor_id = agent['identify_doctor'](condition, user_answers)
        
        return DoctorResponse(
            doctor_type=doctor_id.doctor_type,
            confidence=doctor_id.confidence,
            reasoning=doctor_id.reasoning
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/summary", response_model=SummaryResponse)
def generate_summary_endpoint(request: List[AnswerRequest], condition: str, doctor_type: str, agent: dict = Depends(get_ophthalmology_agent)):
    """Generate a comprehensive summary for the doctor"""
    try:
        # Convert the answers to UserAnswer objects
        user_answers = [agent['UserAnswer'](
            question=answer.question,
            answer=answer.answer,
            is_custom=answer.is_custom
        ) for answer in request]
        
        # Query Qdrant for relevant information
        qdrant_results = agent['query_qdrant'](condition, user_answers)
        
        # Generate the summary using the tool
        summary = agent['generate_summary'](condition, user_answers, doctor_type, qdrant_results)
        
        return SummaryResponse(
            doctor_type=summary.doctor_type,
            summary=summary.summary,
            confidence=summary.confidence,
            key_symptoms=summary.key_symptoms,
            recommended_tests=summary.recommended_tests
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/complete", response_model=Dict[str, Any])
def complete_flow(condition: str, answers: List[AnswerRequest], agent: dict = Depends(get_ophthalmology_agent)):
    """Run the complete ophthalmology assistant flow"""
    try:
        # Convert the answers to UserAnswer objects
        user_answers = [agent['UserAnswer'](
            question=answer.question,
            answer=answer.answer,
            is_custom=answer.is_custom
        ) for answer in answers]
        
        # Step 1: Identify the doctor
        doctor_id = agent['identify_doctor'](condition, user_answers)
        
        # Step 2: Query Qdrant for relevant information
        qdrant_results = agent['query_qdrant'](condition, user_answers)
        
        # Step 3: Generate the summary
        summary = agent['generate_summary'](condition, user_answers, doctor_id.doctor_type, qdrant_results)
        
        return {
            "condition": condition,
            "answers": [{
                "question": ua.question,
                "answer": ua.answer,
                "is_custom": ua.is_custom
            } for ua in user_answers],
            "doctor_identification": {
                "doctor_type": doctor_id.doctor_type,
                "confidence": doctor_id.confidence,
                "reasoning": doctor_id.reasoning
            },
            "doctor_summary": {
                "doctor_type": summary.doctor_type,
                "summary": summary.summary,
                "confidence": summary.confidence,
                "key_symptoms": summary.key_symptoms,
                "recommended_tests": summary.recommended_tests
            },
            "error": None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))