"""
Session Manager Service for Iterative Questioning System
======================================================

This service manages conversation sessions, confidence scoring,
and iterative question generation for the HealthVerse system.
"""

from typing import Dict, Optional
import logging
from datetime import datetime

from src.models.models import (
    SessionState, ConfidenceScore, ConversationHistory,
    SessionStartRequest, NextQuestionRequest, NextQuestionResponse,
    SessionStartResponse, FollowUpQuestion, QuestionOption,
    DoctorRecommendation
)
from src.core.config import config

logger = logging.getLogger(__name__)

class SessionManager:
    def __init__(self):
        # In-memory session storage (in production, use Redis or database)
        self.sessions: Dict[str, SessionState] = {}
        
        # Dynamic questioning parameters
        self.min_confidence_threshold = 0.75  # Minimum confidence for completion
        self.high_confidence_threshold = 0.9   # High confidence for early completion
        self.satisfaction_threshold = 0.8      # Agent satisfaction threshold
        self.max_questions = 8  # Safety limit to prevent endless questioning
        self.min_questions = 3  # Minimum questions before allowing completion
    
    async def start_session(self, request: SessionStartRequest) -> SessionStartResponse:
        """Start a new iterative questioning session"""
        try:
            # Generate initial confidence assessment
            initial_confidence = await self._calculate_initial_confidence(request.condition)
            
            # Create new session
            session = SessionState(
                initial_condition=request.condition,
                confidence_score=initial_confidence,
                current_leading_doctor=self._get_leading_doctor(initial_confidence.doctor_confidence)
            )
            
            # Store session
            self.sessions[session.session_id] = session
            
            # Generate first question
            first_question = await self._generate_next_question(session)
            
            logger.info(f"Started new session {session.session_id} with initial confidence {initial_confidence.overall_confidence:.2f}")
            
            return SessionStartResponse(
                session_id=session.session_id,
                first_question=first_question,
                confidence_score=initial_confidence
            )
            
        except Exception as e:
            logger.error(f"Error starting session: {str(e)}")
            raise
    
    async def process_answer_and_get_next_question(self, request: NextQuestionRequest) -> NextQuestionResponse:
        """Process user answer and determine next question or completion"""
        try:
            # Get session
            session = self.sessions.get(request.session_id)
            if not session:
                raise ValueError(f"Session {request.session_id} not found")
            
            # Add answer to conversation history
            if session.conversation_history:
                # Update the last question with the answer
                last_entry = session.conversation_history[-1]
                last_entry.answer = request.answer
            
            # Update session timestamp
            session.updated_at = datetime.now()
            
            # Calculate new confidence based on answer
            updated_confidence = await self._update_confidence_with_answer(session, request.answer)
            session.confidence_score = updated_confidence
            session.current_leading_doctor = self._get_leading_doctor(updated_confidence.doctor_confidence)
            
            # Check if we should continue or complete
            should_continue = await self._should_continue_questioning(session)
            
            if not should_continue:
                # Complete the session
                session.is_complete = True
                doctor_recommendation, summary = await self._finalize_session(session)
                
                logger.info(f"Completed session {session.session_id} with final confidence {updated_confidence.overall_confidence:.2f}")
                
                return NextQuestionResponse(
                    session_id=session.session_id,
                    question=None,
                    confidence_score=updated_confidence,
                    is_complete=True,
                    doctor_recommendation=doctor_recommendation,
                    summary_for_doctor=summary,
                    conversation_history=session.conversation_history
                )
            else:
                # Generate next question
                next_question = await self._generate_next_question(session)
                
                return NextQuestionResponse(
                    session_id=session.session_id,
                    question=next_question,
                    confidence_score=updated_confidence,
                    is_complete=False,
                    doctor_recommendation=None,
                    summary_for_doctor=None,
                    conversation_history=session.conversation_history
                )
                
        except Exception as e:
            logger.error(f"Error processing answer for session {request.session_id}: {str(e)}")
            raise
    
    async def get_session(self, session_id: str) -> Optional[SessionState]:
        """Get session by ID"""
        return self.sessions.get(session_id)
    
    async def _calculate_initial_confidence(self, condition: str) -> ConfidenceScore:
        """Calculate initial confidence based on the initial condition"""
        try:
            # Import here to avoid circular imports
            from src.tools.confidence_calculator import ConfidenceCalculator
            
            calculator = ConfidenceCalculator()
            return await calculator.calculate_initial_confidence(condition)
            
        except Exception as e:
            logger.error(f"Error calculating initial confidence: {str(e)}")
            # Fallback to basic confidence
            return ConfidenceScore(
                overall_confidence=0.3,
                doctor_confidence={
                    "Ophthalmologist": 0.4,
                    "Optometrist": 0.3,
                    "Optician": 0.2,
                    "Ocular Surgeon": 0.1
                },
                reasoning="Initial assessment based on condition keywords"
            )
    
    async def _update_confidence_with_answer(self, session: SessionState, answer: str) -> ConfidenceScore:
        """Update confidence score based on new answer"""
        try:
            from src.tools.confidence_calculator import ConfidenceCalculator
            
            calculator = ConfidenceCalculator()
            return await calculator.update_confidence_with_answer(
                session.initial_condition,
                session.conversation_history,
                answer
            )
            
        except Exception as e:
            logger.error(f"Error updating confidence: {str(e)}")
            # Return current confidence as fallback
            return session.confidence_score
    
    async def _should_continue_questioning(self, session: SessionState) -> bool:
        """Determine if we should ask another question based on dynamic criteria"""
        num_questions = len([entry for entry in session.conversation_history if entry.answer])
        
        # Always ask minimum number of questions regardless of confidence
        if num_questions < self.min_questions:
            logger.info(f"Continuing questioning - only {num_questions}/{self.min_questions} questions asked so far")
            return True
        
        # Safety limit - never exceed max questions
        if num_questions >= self.max_questions:
            logger.info(f"Stopping due to max question limit ({self.max_questions})")
            return False
        
        # Check agent satisfaction using AI assessment
        try:
            from src.tools.session_finalizer import SessionFinalizer
            finalizer = SessionFinalizer()
            is_satisfied, reasoning, satisfaction_score = await finalizer.assess_agent_satisfaction(session)
            
            if is_satisfied and satisfaction_score >= self.satisfaction_threshold:
                logger.info(f"Agent satisfied with information gathered (score: {satisfaction_score:.2f}): {reasoning}")
                return False
            
            # Also check confidence thresholds
            if session.confidence_score.overall_confidence >= self.min_confidence_threshold:
                leading_doctor_confidence = max(session.confidence_score.doctor_confidence.values())
                if leading_doctor_confidence >= self.high_confidence_threshold:
                    logger.info(f"High confidence in leading doctor recommendation ({leading_doctor_confidence:.2f})")
                    return False
            
            logger.info(f"Continuing questioning - satisfaction: {satisfaction_score:.2f}, confidence: {session.confidence_score.overall_confidence:.2f}")
            return True
            
        except Exception as e:
            logger.error(f"Error assessing satisfaction, using fallback logic: {str(e)}")
            # Fallback to confidence-only logic
            return session.confidence_score.overall_confidence < self.min_confidence_threshold
    
    async def _generate_next_question(self, session: SessionState) -> FollowUpQuestion:
        """Generate the next question based on current session state"""
        try:
            from src.tools.iterative_question_generator import IterativeQuestionGenerator
            
            generator = IterativeQuestionGenerator()
            return await generator.generate_next_question(
                session.initial_condition,
                session.conversation_history,
                session.confidence_score,
                session.current_leading_doctor
            )
            
        except Exception as e:
            logger.error(f"Error generating next question: {str(e)}")
            # Fallback question
            return FollowUpQuestion(
                question="Can you describe any additional symptoms you're experiencing?",
                options=[
                    QuestionOption(text="No additional symptoms", is_other=False),
                    QuestionOption(text="Mild additional symptoms", is_other=False),
                    QuestionOption(text="Significant additional symptoms", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
    
    async def _finalize_session(self, session: SessionState) -> tuple[DoctorRecommendation, str]:
        """Generate final recommendation and summary"""
        try:
            from src.tools.session_finalizer import SessionFinalizer
            
            finalizer = SessionFinalizer()
            return await finalizer.finalize_session(session)
            
        except Exception as e:
            logger.error(f"Error finalizing session: {str(e)}")
            # Fallback recommendation
            doctor_recommendation = DoctorRecommendation(
                doctor_type=session.current_leading_doctor,
                reasoning=f"Based on the conversation, {session.current_leading_doctor} is recommended"
            )
            summary = f"Patient presents with {session.initial_condition}. Requires evaluation by {session.current_leading_doctor}."
            return doctor_recommendation, summary
    
    def _get_leading_doctor(self, doctor_confidence: Dict[str, float]) -> str:
        """Get the doctor type with highest confidence"""
        return max(doctor_confidence.items(), key=lambda x: x[1])[0]
    
    def cleanup_old_sessions(self, max_age_hours: int = 24):
        """Remove old sessions to prevent memory leaks"""
        current_time = datetime.now()
        expired_sessions = [
            session_id for session_id, session in self.sessions.items()
            if (current_time - session.updated_at).total_seconds() > (max_age_hours * 3600)
        ]
        
        for session_id in expired_sessions:
            del self.sessions[session_id]
            
        if expired_sessions:
            logger.info(f"Cleaned up {len(expired_sessions)} expired sessions")

# Global session manager instance
session_manager = SessionManager()
