import uuid
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum

class SessionStatus(Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    EXPIRED = "expired"

@dataclass
class Question:
    id: str
    text: str
    options: List[Dict[str, str]]  
    
@dataclass
class Answer:
    question_id: str
    option_id: str
    option_text: str
    custom_text: Optional[str] = None 
@dataclass
class Session:
    session_id: str
    initial_symptoms: str
    questions: List[Question] = field(default_factory=list)
    answers: List[Answer] = field(default_factory=list)
    current_question_index: int = 0
    initial_guess: Optional[str] = None 
    is_completed: bool = False
    created_at: float = field(default_factory=time.time)
    last_activity: float = field(default_factory=time.time)
    status: SessionStatus = SessionStatus.ACTIVE
    max_questions: int = 5
    user_history: Optional[str] = None
    detected_language: Optional[str] = None  # Stores the detected language (english, urdu, roman_urdu)  

class SessionManager:
    def __init__(self, session_timeout: int = 3600):  
        self.sessions: Dict[str, Session] = {}
        self.session_timeout = session_timeout
    
    def create_session(self, initial_symptoms: str, user_history: Optional[str] = None, detected_language: Optional[str] = None) -> str:
        session_id = str(uuid.uuid4())
        session = Session(
            session_id=session_id,
            initial_symptoms=initial_symptoms,
            user_history=user_history,
            detected_language=detected_language
        )
        self.sessions[session_id] = session
        return session_id
    
    def get_session(self, session_id: str) -> Optional[Session]:
        if session_id not in self.sessions:
            return None
        
        session = self.sessions[session_id]
        
        if time.time() - session.last_activity > self.session_timeout:
            session.status = SessionStatus.EXPIRED
            return session
        
        session.last_activity = time.time()
        return session
    
    def add_question(self, session_id: str, question_text: str, options: List[str]) -> bool:
        session = self.get_session(session_id)
        if not session or session.status != SessionStatus.ACTIVE:
            return False
        
        question_id = f"q{len(session.questions) + 1}"
        formatted_options = []
        for i, option in enumerate(options, 1):
            formatted_options.append({
                "id": str(i),
                "text": option
            })
        
        question = Question(
            id=question_id,
            text=question_text,
            options=formatted_options
        )
        
        session.questions.append(question)
        return True
    
    def add_answer(self, session_id: str, question_id: str, option_id: str, custom_text: Optional[str] = None) -> bool:
        session = self.get_session(session_id)
        if not session or session.status != SessionStatus.ACTIVE:
            return False
        
        question = next((q for q in session.questions if q.id == question_id), None)
        if not question:
            return False
        
        option = next((o for o in question.options if o["id"] == option_id), None)
        if not option:
            return False
        
        answer = Answer(
            question_id=question_id,
            option_id=option_id,
            option_text=option["text"],
            custom_text=custom_text
        )
        
        session.answers.append(answer)
        session.current_question_index += 1
        
        if session.current_question_index >= session.max_questions:
            session.is_completed = True
            session.status = SessionStatus.COMPLETED
        
        return True
    
    def set_doctor_guess(self, session_id: str, doctor_type: str) -> bool:
        session = self.get_session(session_id)
        if not session:
            return False
        
        session.initial_guess = doctor_type
        return True
    
    def set_detected_language(self, session_id: str, language: str) -> bool:
        """Set the detected language for a session."""
        session = self.get_session(session_id)
        if not session:
            return False
        
        session.detected_language = language
        return True
    
    def get_detected_language(self, session_id: str) -> Optional[str]:
        """Get the detected language for a session."""
        session = self.get_session(session_id)
        if not session:
            return None
        return session.detected_language
    
    def get_session_summary(self, session_id: str) -> Optional[Dict[str, Any]]:
        session = self.get_session(session_id)
        if not session:
            return None
        
        current_question = None
        if not session.is_completed and session.current_question_index < len(session.questions):
            question = session.questions[session.current_question_index]
            current_question = {
                "id": question.id,
                "text": question.text,
                "options": question.options
            }
        
        return {
            "session_id": session_id,
            "initial_symptoms": session.initial_symptoms,
            "current_question": current_question,
            "questions_answered": len(session.answers),
            "total_questions": len(session.questions),
            "initial_guess": session.initial_guess,
            "is_completed": session.is_completed,
            "status": session.status.value,
            "user_history": session.user_history,
            "detected_language": session.detected_language
        }
    
    def get_conversation_history(self, session_id: str) -> Optional[List[Dict[str, Any]]]:
        session = self.get_session(session_id)
        if not session:
            return None
        
        history = []
        for i, (question, answer) in enumerate(zip(session.questions, session.answers)):
            history.append({
                "question_id": question.id,
                "question_text": question.text,
                "question_options": question.options,
                "answer_option_id": answer.option_id,
                "answer_text": answer.option_text,
                "custom_answer": answer.custom_text,
                "order": i + 1
            })
        
        return history
    
    def cleanup_expired_sessions(self):
        current_time = time.time()
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if current_time - session.last_activity > self.session_timeout:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            del self.sessions[session_id]
        
        return len(expired_sessions)

session_manager = SessionManager()
