from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime
import uuid

class InitialConditionRequest(BaseModel):
    condition: str = Field(..., description="Initial eye-related condition or symptoms")

class QuestionOption(BaseModel):
    text: str = Field(..., description="Option text")
    is_other: bool = Field(default=False, description="Whether this is the 'Other' option")

class FollowUpQuestion(BaseModel):
    question: str = Field(..., description="Follow-up question text")
    options: List[QuestionOption] = Field(..., description="Answer options for the question")

class QuestionsResponse(BaseModel):
    questions: List[FollowUpQuestion] = Field(..., description="Generated follow-up questions")

class UserAnswer(BaseModel):
    question_index: int = Field(..., description="Index of the question being answered")
    selected_option: Optional[str] = Field(None, description="Selected predefined option")
    custom_answer: Optional[str] = Field(None, description="Custom answer if 'Other' was selected")

class AnswersRequest(BaseModel):
    initial_condition: str = Field(..., description="Original condition")
    answers: List[UserAnswer] = Field(..., description="User's answers to follow-up questions")

class DoctorRecommendation(BaseModel):
    doctor_type: str = Field(..., description="Recommended doctor type")
    reasoning: str = Field(..., description="Brief reasoning for the recommendation")

class FinalResponse(BaseModel):
    doctor: DoctorRecommendation = Field(..., description="Doctor recommendation")
    summary_for_doctor: str = Field(..., description="Medical summary for the doctor")

class AgentState(BaseModel):
    initial_condition: str = ""
    questions: List[FollowUpQuestion] = []
    answers: List[UserAnswer] = []
    rag_context: List[str] = []
    doctor_recommendation: Optional[DoctorRecommendation] = None
    summary: str = ""
    current_step: str = "start"

class RAGDocument(BaseModel):
    content: str = Field(..., description="Document content")
    score: float = Field(..., description="Similarity score")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Document metadata")

# New models for iterative questioning system

class SessionStartRequest(BaseModel):
    condition: str = Field(..., description="Initial eye-related condition or symptoms")

class ConversationHistory(BaseModel):
    question: str = Field(..., description="Previously asked question")
    answer: str = Field(..., description="User's answer")
    timestamp: datetime = Field(default_factory=datetime.now, description="When this Q&A occurred")

class ConfidenceScore(BaseModel):
    overall_confidence: float = Field(..., ge=0.0, le=1.0, description="Overall diagnostic confidence (0-1)")
    doctor_confidence: Dict[str, float] = Field(..., description="Confidence scores for each doctor type")
    reasoning: str = Field(..., description="Explanation of confidence assessment")

class SessionState(BaseModel):
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()), description="Unique session identifier")
    initial_condition: str = Field(..., description="Initial condition")
    conversation_history: List[ConversationHistory] = Field(default_factory=list, description="Question-answer history")
    confidence_score: ConfidenceScore = Field(..., description="Current confidence assessment")
    current_leading_doctor: str = Field(..., description="Currently most likely doctor type")
    is_complete: bool = Field(default=False, description="Whether diagnosis is complete")
    created_at: datetime = Field(default_factory=datetime.now, description="Session creation time")
    updated_at: datetime = Field(default_factory=datetime.now, description="Last update time")

class NextQuestionRequest(BaseModel):
    session_id: str = Field(..., description="Session identifier")
    answer: str = Field(..., description="Answer to the previous question")

class NextQuestionResponse(BaseModel):
    session_id: str = Field(..., description="Session identifier")
    question: Optional[FollowUpQuestion] = Field(None, description="Next question to ask, None if complete")
    confidence_score: ConfidenceScore = Field(..., description="Current confidence assessment")
    is_complete: bool = Field(..., description="Whether questioning is complete")
    doctor_recommendation: Optional[DoctorRecommendation] = Field(None, description="Final recommendation if complete")
    summary_for_doctor: Optional[str] = Field(None, description="Medical summary if complete")
    conversation_history: List[ConversationHistory] = Field(..., description="Current conversation history")

class SessionStartResponse(BaseModel):
    session_id: str = Field(..., description="New session identifier")
    first_question: FollowUpQuestion = Field(..., description="First question to ask")
    confidence_score: ConfidenceScore = Field(..., description="Initial confidence assessment")
