import os
import json
import asyncio
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field

# Import RAG functionality
try:
    from rag.qdrant.client import QdrantManager
    RAG_AVAILABLE = True
except ImportError:
    RAG_AVAILABLE = False
    print("Warning: RAG functionality not available")

# Models for tool inputs and outputs
class Question(BaseModel):
    question_text: str = Field(..., description="The text of the follow-up question")
    options: List[str] = Field(..., description="List of possible answer options including 'Other'")

class UserAnswer(BaseModel):
    question: str = Field(..., description="The question that was asked")
    answer: str = Field(..., description="The user's answer to the question")
    is_custom: bool = Field(False, description="Whether this is a custom answer (from 'Other' option)")

class DoctorIdentification(BaseModel):
    doctor_type: str = Field(..., description="The identified doctor type")
    confidence: float = Field(..., description="Confidence score for the identification")
    reasoning: str = Field(..., description="Reasoning behind the doctor identification")

class QdrantResult(BaseModel):
    document_id: str = Field(..., description="ID of the retrieved document")
    content: str = Field(..., description="Content of the retrieved document")
    relevance_score: float = Field(..., description="Relevance score of the document")

class DoctorSummary(BaseModel):
    doctor_type: str = Field(..., description="The identified doctor type")
    summary: str = Field(..., description="Medical summary for the doctor")
    confidence: float = Field(..., description="Overall confidence in the recommendation")
    key_symptoms: List[str] = Field(..., description="Key symptoms identified")
    recommended_tests: Optional[List[str]] = Field(None, description="Recommended tests if applicable")

# Tool implementations
def generate_followup_question(condition: str, previous_answers: Optional[List[UserAnswer]] = None, rag_context: Optional[str] = None) -> Question:
    """Generate a follow-up question with answer options based on the user's condition, previous answers, and RAG context."""
    # In a real implementation, this would call the Gemini model with RAG context
    # For now, we'll return context-aware responses
    
    if not previous_answers:
        # First question - use RAG context to inform the question
        if rag_context and "emergency" in rag_context.lower():
            return Question(
                question_text="How severe is your eye pain on a scale of 1-10?",
                options=["1-3 (Mild)", "4-6 (Moderate)", "7-10 (Severe)", "No pain", "Other"]
            )
        else:
            return Question(
                question_text="How long have you been experiencing this eye condition?",
                options=["Less than 24 hours", "1-7 days", "1-4 weeks", "More than a month", "Other"]
            )
    else:
        # Subsequent questions based on previous answers and RAG context
        last_answer = previous_answers[-1]
        
        if "pain" in condition.lower() or any("pain" in a.answer.lower() for a in previous_answers):
            if rag_context and "glaucoma" in rag_context.lower():
                return Question(
                    question_text="Do you see halos around lights or have nausea with the eye pain?",
                    options=["Yes, both symptoms", "Only halos", "Only nausea", "Neither", "Other"]
                )
            else:
                return Question(
                    question_text="On a scale of 1-10, how would you rate your eye pain?",
                    options=["1-3 (Mild)", "4-6 (Moderate)", "7-10 (Severe)", "No pain, just discomfort", "Other"]
                )
        elif "vision" in condition.lower() or any("vision" in a.answer.lower() for a in previous_answers):
            return Question(
                question_text="Is your vision affected in one eye or both eyes?",
                options=["Left eye only", "Right eye only", "Both eyes", "Vision is not affected", "Other"]
            )
        else:
            return Question(
                question_text="Are you experiencing any sensitivity to light?",
                options=["Yes, severe", "Yes, moderate", "Yes, mild", "No", "Other"]
            )

def identify_doctor(condition: str, answers: List[UserAnswer], rag_context: Optional[str] = None) -> DoctorIdentification:
    """Identify the most appropriate eye specialist based on the condition, answers, and RAG context."""
    # In a real implementation, this would call the Gemini model with RAG context
    # For now, we'll use enhanced rule-based approach with RAG context
    
    # Convert everything to lowercase for easier matching
    condition_lower = condition.lower()
    answers_text = " ".join([a.answer.lower() for a in answers])
    combined_text = condition_lower + " " + answers_text
    
    # Use RAG context to inform decision
    if rag_context:
        rag_lower = rag_context.lower()
        
        # Emergency cases from RAG
        if "emergency" in rag_lower or "immediate" in rag_lower:
            return DoctorIdentification(
                doctor_type="Ophthalmologist",
                confidence=0.95,
                reasoning="Based on medical knowledge, this condition requires immediate attention from an ophthalmologist due to emergency indicators."
            )
        
        # High urgency cases
        if "high" in rag_lower and "urgency" in rag_lower:
            return DoctorIdentification(
                doctor_type="Ophthalmologist",
                confidence=0.90,
                reasoning="Medical knowledge indicates this condition has high urgency and should be evaluated by an ophthalmologist."
            )
        
        # Optometrist cases from RAG
        if "optometrist" in rag_lower and "low" in rag_lower:
            return DoctorIdentification(
                doctor_type="Optometrist",
                confidence=0.85,
                reasoning="Based on medical knowledge, this condition can be effectively managed by an optometrist."
            )
    
    # Fallback to rule-based approach
    if any(term in combined_text for term in ["surgery", "trauma", "accident", "severe pain", "7-10"]):
        return DoctorIdentification(
            doctor_type="Ocular Surgeon",
            confidence=0.85,
            reasoning="The symptoms suggest a condition that may require surgical intervention."
        )
    elif any(term in combined_text for term in ["infection", "disease", "inflammation", "redness", "discharge"]):
        return DoctorIdentification(
            doctor_type="Ophthalmologist",
            confidence=0.78,
            reasoning="The symptoms indicate a possible eye disease or infection requiring medical treatment."
        )
    elif any(term in combined_text for term in ["glasses", "contacts", "blurry", "focus", "prescription"]):
        return DoctorIdentification(
            doctor_type="Optometrist",
            confidence=0.92,
            reasoning="The symptoms suggest vision correction issues that an optometrist can address."
        )
    else:
        return DoctorIdentification(
            doctor_type="Optician",
            confidence=0.65,
            reasoning="The symptoms are mild and may be related to glasses or contact lenses fitting."
        )

def query_qdrant(condition: str, answers: List[UserAnswer]) -> List[QdrantResult]:
    """Query the Qdrant vector store for relevant medical information."""
    if not RAG_AVAILABLE:
        print("❌ RAG functionality not available")
        return []
    
    try:
        # Create search query from condition and answers
        search_query = f"Condition: {condition}. "
        if answers:
            search_query += "Patient responses: "
            for answer in answers:
                search_query += f"{answer.question}: {answer.answer}. "
        
        # Initialize Qdrant manager and search
        qdrant_manager = QdrantManager(use_local=True, use_memory=True, force_cloud=True)
        
        # Run async search in sync context
        try:
            # Check if there's already a running loop
            try:
                loop = asyncio.get_running_loop()
                # Create a task if we're in an async context
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    future = executor.submit(asyncio.run, qdrant_manager.search(search_query))
                    results = future.result(timeout=30)
            except RuntimeError:
                # No running loop, safe to create new one
                results = asyncio.run(qdrant_manager.search(search_query))
        except Exception as e:
            print(f"Error running async search: {e}")
            results = []
        
        # Convert to QdrantResult objects
        qdrant_results = []
        for result in results:
            qdrant_results.append(QdrantResult(
                document_id=result["document_id"],
                content=result["content"],
                relevance_score=result["relevance_score"]
            ))
        
        print(f"✅ Retrieved {len(qdrant_results)} relevant medical cases from Qdrant")
        return qdrant_results
        
    except Exception as e:
        print(f"❌ Error querying Qdrant: {e}")
        return []


def generate_doctor_summary(condition: str, answers: List[UserAnswer], doctor_type: str, qdrant_results: List[QdrantResult]) -> DoctorSummary:
    """Generate a comprehensive summary for the doctor based on all available information."""
    # In a real implementation, this would call the Gemini model
    # For now, we'll create a simple summary
    
    # Extract key symptoms from condition and answers
    combined_text = condition.lower() + " " + " ".join([a.answer.lower() for a in answers])
    
    key_symptoms = []
    if "pain" in combined_text:
        key_symptoms.append("Eye pain")
    if "redness" in combined_text:
        key_symptoms.append("Redness")
    if "blurry" in combined_text or "vision" in combined_text:
        key_symptoms.append("Vision changes")
    if "light" in combined_text and ("sensitive" in combined_text or "sensitivity" in combined_text):
        key_symptoms.append("Photosensitivity")
    if "discharge" in combined_text:
        key_symptoms.append("Discharge")
    if "itchy" in combined_text or "itching" in combined_text:
        key_symptoms.append("Itching")
    
    # If no specific symptoms were extracted, add a generic one
    if not key_symptoms:
        key_symptoms.append("General eye discomfort")
    
    # Generate recommended tests based on doctor type and symptoms
    recommended_tests = []
    if doctor_type == "Ophthalmologist" or doctor_type == "Ocular Surgeon":
        recommended_tests = ["Comprehensive eye exam", "Intraocular pressure test"]
        if "vision" in combined_text:
            recommended_tests.append("Visual field test")
    elif doctor_type == "Optometrist":
        recommended_tests = ["Refraction assessment", "Basic eye health exam"]
    
    # Generate summary text
    summary = f"Patient presents with {', '.join(key_symptoms)}. "
    summary += f"Initial condition reported: {condition}. "
    
    # Add answer information
    for answer in answers:
        summary += f"When asked '{answer.question}', patient responded: '{answer.answer}'. "
    
    # Add relevant information from Qdrant results
    if qdrant_results:
        summary += "\n\nRelevant medical context: "
        for result in qdrant_results[:2]:  # Include only top 2 results
            summary += f"\n- {result.content}"
    
    return DoctorSummary(
        doctor_type=doctor_type,
        summary=summary,
        confidence=0.85,
        key_symptoms=key_symptoms,
        recommended_tests=recommended_tests
    )