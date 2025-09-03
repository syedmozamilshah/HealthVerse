import os
import math
from dotenv import load_dotenv
from mcp.server import FastMCP
from typing import List, Optional
from pydantic import BaseModel

# Import our ophthalmology tools
from tools.ophthalmology_tools import (
    Question, UserAnswer, DoctorIdentification, QdrantResult, DoctorSummary,
    generate_followup_question, identify_doctor, query_qdrant, generate_doctor_summary
)

# Load environment variables
load_dotenv()

# Initialize MCP server
mcp = FastMCP("OphthalmologyAssistant")

# Define MCP tools
@mcp.tool()
def generate_question(condition: str, previous_answers: Optional[List[dict]] = None) -> dict:
    """
    Generate a follow-up question with answer options based on the user's eye condition.
    
    Args:
        condition: The user's initial eye condition or symptom
        previous_answers: List of previous questions and answers (if any)
        
    Returns:
        A question object with the question text and answer options
    """
    # Convert previous_answers to UserAnswer objects if provided
    user_answers = None
    if previous_answers:
        user_answers = [UserAnswer(**answer) for answer in previous_answers]
    
    # Generate the question
    question = generate_followup_question(condition, user_answers)
    
    # Return as dict for JSON serialization
    return question.dict()

@mcp.tool()
def identify_eye_doctor(condition: str, answers: List[dict]) -> dict:
    """
    Identify the most appropriate eye specialist based on the condition and answers.
    
    Args:
        condition: The user's initial eye condition or symptom
        answers: List of questions and answers provided by the user
        
    Returns:
        A doctor identification object with the doctor type, confidence score, and reasoning
    """
    # Convert answers to UserAnswer objects
    user_answers = [UserAnswer(**answer) for answer in answers]
    
    # Identify the doctor
    doctor_id = identify_doctor(condition, user_answers)
    
    # Return as dict for JSON serialization
    return doctor_id.dict()

@mcp.tool()
def search_medical_knowledge(condition: str, answers: List[dict]) -> List[dict]:
    """
    Search the Qdrant vector store for relevant medical information.
    
    Args:
        condition: The user's initial eye condition or symptom
        answers: List of questions and answers provided by the user
        
    Returns:
        A list of relevant medical documents
    """
    # Convert answers to UserAnswer objects
    user_answers = [UserAnswer(**answer) for answer in answers]
    
    # Query Qdrant
    results = query_qdrant(condition, user_answers)
    
    # Return as list of dicts for JSON serialization
    return [result.dict() for result in results]

@mcp.tool()
def create_doctor_summary(condition: str, answers: List[dict], doctor_type: str, qdrant_results: List[dict]) -> dict:
    """
    Generate a comprehensive summary for the doctor based on all available information.
    
    Args:
        condition: The user's initial eye condition or symptom
        answers: List of questions and answers provided by the user
        doctor_type: The identified doctor type
        qdrant_results: List of relevant medical documents from Qdrant
        
    Returns:
        A doctor summary object with the summary, confidence score, and other details
    """
    # Convert answers to UserAnswer objects
    user_answers = [UserAnswer(**answer) for answer in answers]
    
    # Convert qdrant_results to QdrantResult objects
    qdrant_docs = [QdrantResult(**result) for result in qdrant_results]
    
    # Generate the summary
    summary = generate_doctor_summary(condition, user_answers, doctor_type, qdrant_docs)
    
    # Return as dict for JSON serialization
    return summary.dict()

if __name__ == "__main__":
    # Run the MCP server (default stdio transport)
    mcp.run()