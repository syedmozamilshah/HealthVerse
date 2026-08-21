from typing import List, Dict, Any, Optional, TypedDict, Annotated
from pydantic import BaseModel, Field

class UserAnswer(BaseModel):
    question: str = Field(..., description="The question that was asked")
    answer: str = Field(..., description="The user's answer to the question")
    is_custom: bool = Field(False, description="Whether this is a custom answer (from 'Other' option)")

class QdrantResult(BaseModel):
    document_id: str = Field(..., description="ID of the retrieved document")
    content: str = Field(..., description="Content of the retrieved document")
    relevance_score: float = Field(..., description="Relevance score of the document")

class OphthalmologyState(TypedDict, total=False):
    condition: Annotated[str, "The user's initial eye condition"]  
    
    current_question: Annotated[Optional[Dict[str, Any]], "Current question being asked"]
    answers: Annotated[List[Dict[str, Any]], "List of all answers received so far"]
    question_count: Annotated[int, "Number of questions asked so far"]
    
    rag_context: Annotated[Optional[str], "Medical context retrieved from RAG system"]
    qdrant_results: Annotated[List[Dict[str, Any]], "Results from Qdrant vector store"]
    
    doctor_identification: Annotated[Optional[Dict[str, Any]], "Identified doctor information"]
    doctor_confidence: Annotated[float, "Confidence in doctor identification"]
    
    doctor_summary: Annotated[Optional[Dict[str, Any]], "Final summary for the doctor"]
    
    max_questions: Annotated[int, "Maximum number of questions to ask"]
    confidence_threshold: Annotated[float, "Threshold for doctor identification confidence"]
    error: Annotated[Optional[str], "Error message if any"]

def create_initial_state(condition: str) -> OphthalmologyState:
    return {
        "condition": condition,
        "current_question": None,
        "answers": [],
        "question_count": 0,
        "rag_context": None,
        "doctor_identification": None,
        "doctor_confidence": 0.0,
        "qdrant_results": [],
        "doctor_summary": None,
        "max_questions": 5, 
        "confidence_threshold": 0.85,  
        "error": None
    }