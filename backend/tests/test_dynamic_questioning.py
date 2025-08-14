"""
Test Suite for Dynamic Questioning System
=========================================

This test suite verifies that the dynamic questioning system works correctly:
- Questions are generated one at a time based on context
- Confidence scores increase with more information
- Agent satisfaction determines stopping points
- System respects minimum and maximum question limits
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

from src.services.session_manager import SessionManager
from src.tools.iterative_question_generator import IterativeQuestionGenerator
from src.tools.session_finalizer import SessionFinalizer
from src.tools.confidence_calculator import ConfidenceCalculator
from src.models.models import (
    SessionStartRequest, NextQuestionRequest, 
    SessionState, ConfidenceScore, ConversationHistory,
    FollowUpQuestion, QuestionOption
)

class TestDynamicQuestioning:
    """Test the dynamic questioning system"""
    
    @pytest.fixture
    def session_manager(self):
        return SessionManager()
    
    @pytest.fixture
    def question_generator(self):
        return IterativeQuestionGenerator()
    
    @pytest.fixture
    def session_finalizer(self):
        return SessionFinalizer()
    
    @pytest.fixture
    def confidence_calculator(self):
        return ConfidenceCalculator()
    
    @pytest.fixture
    def mock_confidence_score(self):
        return ConfidenceScore(
            overall_confidence=0.6,
            doctor_confidence={
                "Ophthalmologist": 0.5,
                "Optometrist": 0.3,
                "Optician": 0.15,
                "Ocular Surgeon": 0.05
            },
            reasoning="Test confidence score"
        )
    
    @pytest.fixture
    def mock_high_confidence_score(self):
        return ConfidenceScore(
            overall_confidence=0.95,
            doctor_confidence={
                "Ophthalmologist": 0.9,
                "Optometrist": 0.05,
                "Optician": 0.03,
                "Ocular Surgeon": 0.02
            },
            reasoning="High confidence test score"
        )

    @pytest.mark.asyncio
    async def test_session_starts_with_initial_question(self, session_manager):
        """Test that a session starts and generates the first question"""
        request = SessionStartRequest(condition="I have red, itchy eyes")
        
        with patch.object(session_manager, '_calculate_initial_confidence') as mock_confidence, \
             patch.object(session_manager, '_generate_next_question') as mock_question:
            
            mock_confidence.return_value = ConfidenceScore(
                overall_confidence=0.4,
                doctor_confidence={"Ophthalmologist": 0.6, "Optometrist": 0.4},
                reasoning="Initial assessment"
            )
            
            mock_question.return_value = FollowUpQuestion(
                question="How long have you had these symptoms?",
                options=[
                    QuestionOption(text="Less than 24 hours", is_other=False),
                    QuestionOption(text="1-3 days", is_other=False),
                    QuestionOption(text="More than a week", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
            
            response = await session_manager.start_session(request)
            
            assert response.session_id is not None
            assert response.first_question is not None
            assert response.first_question.question == "How long have you had these symptoms?"
            assert len(response.first_question.options) == 4
            assert response.confidence_score.overall_confidence == 0.4

    @pytest.mark.asyncio
    async def test_confidence_increases_with_answers(self, session_manager):
        """Test that confidence increases as more answers are provided"""
        # Create initial session state
        session = SessionState(
            initial_condition="Blurry vision",
            conversation_history=[
                ConversationHistory(question="How severe is the blurriness?", answer="Moderate")
            ]
        )
        
        session_manager.sessions[session.session_id] = session
        
        with patch.object(session_manager, '_update_confidence_with_answer') as mock_update:
            # Mock increasing confidence
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.75,  # Higher than initial
                doctor_confidence={"Optometrist": 0.7, "Ophthalmologist": 0.3},
                reasoning="Updated with answer"
            )
            
            with patch.object(session_manager, '_should_continue_questioning', return_value=True), \
                 patch.object(session_manager, '_generate_next_question') as mock_next_q:
                
                mock_next_q.return_value = FollowUpQuestion(
                    question="Do you wear glasses or contacts?",
                    options=[
                        QuestionOption(text="Yes, glasses", is_other=False),
                        QuestionOption(text="Yes, contacts", is_other=False),
                        QuestionOption(text="No", is_other=False),
                        QuestionOption(text="Other", is_other=True)
                    ]
                )
                
                request = NextQuestionRequest(
                    session_id=session.session_id,
                    answer="It's been getting worse over the past month"
                )
                
                response = await session_manager.process_answer_and_get_next_question(request)
                
                assert not response.is_complete
                assert response.confidence_score.overall_confidence == 0.75
                assert response.question is not None

    @pytest.mark.asyncio
    async def test_early_completion_with_high_confidence(self, session_manager):
        """Test that system completes early with very high confidence"""
        session = SessionState(
            initial_condition="Need new glasses prescription",
            conversation_history=[
                ConversationHistory(question="When was your last eye exam?", answer="Over 2 years ago")
            ]
        )
        
        session_manager.sessions[session.session_id] = session
        
        with patch.object(session_manager, '_update_confidence_with_answer') as mock_update, \
             patch.object(session_manager, '_finalize_session') as mock_finalize:
            
            # Mock very high confidence
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.95,
                doctor_confidence={"Optometrist": 0.95, "Ophthalmologist": 0.05},
                reasoning="Very clear optometry case"
            )
            
            mock_finalize.return_value = (
                MagicMock(doctor_type="Optometrist", reasoning="Vision correction needed"),
                "Patient needs routine vision exam and prescription update"
            )
            
            request = NextQuestionRequest(
                session_id=session.session_id,
                answer="Just routine vision changes, no pain or other symptoms"
            )
            
            response = await session_manager.process_answer_and_get_next_question(request)
            
            assert response.is_complete
            assert response.doctor_recommendation.doctor_type == "Optometrist"
            assert response.summary_for_doctor is not None

    @pytest.mark.asyncio
    async def test_agent_satisfaction_determines_completion(self, session_manager):
        """Test that agent satisfaction assessment determines when to stop"""
        session = SessionState(
            initial_condition="Eye pain and discharge",
            conversation_history=[
                ConversationHistory(question="How severe is the pain?", answer="Moderate to severe"),
                ConversationHistory(question="What color is the discharge?", answer="Yellow-green"),
                ConversationHistory(question="How long have you had symptoms?", answer="3 days")
            ]
        )
        
        session_manager.sessions[session.session_id] = session
        
        with patch('src.tools.session_finalizer.SessionFinalizer.assess_agent_satisfaction') as mock_satisfaction, \
             patch.object(session_manager, '_update_confidence_with_answer') as mock_update, \
             patch.object(session_manager, '_finalize_session') as mock_finalize:
            
            # Mock agent satisfaction indicating completion
            mock_satisfaction.return_value = (True, "Sufficient information for diagnosis", 0.85)
            
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.8,
                doctor_confidence={"Ophthalmologist": 0.85, "Optometrist": 0.15},
                reasoning="Clear infection indicators"
            )
            
            mock_finalize.return_value = (
                MagicMock(doctor_type="Ophthalmologist", reasoning="Likely eye infection"),
                "Patient presents with signs of bacterial eye infection"
            )
            
            request = NextQuestionRequest(
                session_id=session.session_id,
                answer="Yes, it's affecting my ability to work"
            )
            
            response = await session_manager.process_answer_and_get_next_question(request)
            
            assert response.is_complete
            mock_satisfaction.assert_called_once()

    @pytest.mark.asyncio
    async def test_respects_minimum_questions(self, session_manager):
        """Test that system asks minimum number of questions even with moderate confidence"""
        session = SessionState(
            initial_condition="Mild eye strain",
            conversation_history=[
                ConversationHistory(question="When do you experience the strain?", answer="After computer work")
            ]
        )
        
        session_manager.sessions[session.session_id] = session
        
        with patch.object(session_manager, '_update_confidence_with_answer') as mock_update, \
             patch.object(session_manager, '_generate_next_question') as mock_next_q:
            
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.7,  # Moderate confidence
                doctor_confidence={"Optometrist": 0.6, "Ophthalmologist": 0.4},
                reasoning="Moderate confidence"
            )
            
            mock_next_q.return_value = FollowUpQuestion(
                question="Do you take regular breaks from screen time?",
                options=[
                    QuestionOption(text="Yes, every hour", is_other=False),
                    QuestionOption(text="Sometimes", is_other=False),
                    QuestionOption(text="Rarely", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
            
            request = NextQuestionRequest(
                session_id=session.session_id,
                answer="Mostly in the evenings"
            )
            
            response = await session_manager.process_answer_and_get_next_question(request)
            
            # Should continue questioning even with moderate confidence 
            # because we haven't reached minimum questions
            assert not response.is_complete
            assert response.question is not None

    @pytest.mark.asyncio
    async def test_respects_maximum_questions_limit(self, session_manager):
        """Test that system stops at maximum question limit"""
        # Create session with many conversation entries (at the limit)
        conversation_history = []
        for i in range(8):  # At the max limit
            conversation_history.append(
                ConversationHistory(question=f"Question {i+1}", answer=f"Answer {i+1}")
            )
        
        session = SessionState(
            initial_condition="Complex eye symptoms",
            conversation_history=conversation_history
        )
        
        session_manager.sessions[session.session_id] = session
        
        with patch.object(session_manager, '_update_confidence_with_answer') as mock_update, \
             patch.object(session_manager, '_finalize_session') as mock_finalize:
            
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.6,  # Still moderate confidence
                doctor_confidence={"Ophthalmologist": 0.5, "Optometrist": 0.5},
                reasoning="Complex case"
            )
            
            mock_finalize.return_value = (
                MagicMock(doctor_type="Ophthalmologist", reasoning="Complex case requiring specialist"),
                "Complex case with multiple symptoms"
            )
            
            request = NextQuestionRequest(
                session_id=session.session_id,
                answer="Additional symptom information"
            )
            
            response = await session_manager.process_answer_and_get_next_question(request)
            
            # Should complete due to max question limit
            assert response.is_complete

    @pytest.mark.asyncio
    async def test_question_generator_adapts_to_context(self, question_generator):
        """Test that question generator creates contextually relevant questions"""
        initial_condition = "Sudden vision loss in right eye"
        conversation_history = [
            ConversationHistory(question="When did this start?", answer="This morning")
        ]
        confidence_score = ConfidenceScore(
            overall_confidence=0.7,
            doctor_confidence={"Ocular Surgeon": 0.6, "Ophthalmologist": 0.4},
            reasoning="Urgent case"
        )
        
        with patch.object(question_generator, '_generate_question_with_llm') as mock_llm:
            mock_llm.return_value = FollowUpQuestion(
                question="Are you experiencing any pain with the vision loss?",
                options=[
                    QuestionOption(text="Severe pain", is_other=False),
                    QuestionOption(text="Mild discomfort", is_other=False),
                    QuestionOption(text="No pain", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
            
            question = await question_generator.generate_next_question(
                initial_condition, conversation_history, confidence_score, "Ocular Surgeon"
            )
            
            assert question is not None
            assert "pain" in question.question.lower()
            mock_llm.assert_called_once()

    @pytest.mark.asyncio
    async def test_information_quality_assessment(self, confidence_calculator):
        """Test that information quality affects confidence calculations"""
        initial_condition = "Eye infection"
        conversation_history = [
            ConversationHistory(question="Symptoms?", answer="Severe redness, yellow discharge, pain for 3 days")
        ]
        
        # Test with detailed, quality answer
        quality_score = confidence_calculator._assess_information_quality(
            initial_condition, conversation_history, "It started gradually and is getting worse each day"
        )
        
        assert quality_score > 0  # Should boost confidence for detailed answer
        
        # Test with vague answer
        quality_score_vague = confidence_calculator._assess_information_quality(
            initial_condition, conversation_history, "Other, not sure"
        )
        
        assert quality_score_vague <= quality_score  # Should be lower for vague answer

    @pytest.mark.asyncio
    async def test_session_finalizer_satisfaction_assessment(self, session_finalizer):
        """Test that session finalizer correctly assesses agent satisfaction"""
        session = SessionState(
            initial_condition="Red, itchy eyes",
            conversation_history=[
                ConversationHistory(question="How long?", answer="2 days"),
                ConversationHistory(question="Any discharge?", answer="Clear, watery"),
                ConversationHistory(question="Any allergies?", answer="Yes, seasonal allergies")
            ],
            confidence_score=ConfidenceScore(
                overall_confidence=0.85,
                doctor_confidence={"Ophthalmologist": 0.7, "Optometrist": 0.3},
                reasoning="Clear allergy case"
            ),
            current_leading_doctor="Ophthalmologist"
        )
        
        with patch.object(session_finalizer, '_llm_assess_satisfaction') as mock_assessment:
            mock_assessment.return_value = {
                "is_satisfied": True,
                "satisfaction_score": 0.9,
                "reasoning": "Clear allergic reaction case with sufficient information",
                "information_gaps": [],
                "confidence_assessment": "High confidence in diagnosis"
            }
            
            is_satisfied, reasoning, score = await session_finalizer.assess_agent_satisfaction(session)
            
            assert is_satisfied is True
            assert score == 0.9
            assert "allergic reaction" in reasoning

    @pytest.mark.asyncio
    async def test_fallback_behavior_on_errors(self, session_manager):
        """Test system behavior when components fail"""
        session = SessionState(
            initial_condition="Test condition",
            conversation_history=[]
        )
        
        session_manager.sessions[session.session_id] = session
        
        # Test fallback when confidence calculation fails
        with patch.object(session_manager, '_update_confidence_with_answer', side_effect=Exception("Test error")), \
             patch.object(session_manager, '_generate_next_question') as mock_question:
            
            mock_question.return_value = FollowUpQuestion(
                question="Fallback question",
                options=[QuestionOption(text="Yes", is_other=False), QuestionOption(text="No", is_other=False)]
            )
            
            request = NextQuestionRequest(session_id=session.session_id, answer="Test answer")
            
            response = await session_manager.process_answer_and_get_next_question(request)
            
            # Should continue despite error
            assert response.question is not None
            assert response.question.question == "Fallback question"

    @pytest.mark.asyncio
    async def test_end_to_end_dynamic_questioning_flow(self, session_manager):
        """Test complete flow from start to finish with dynamic questioning"""
        # Start session
        start_request = SessionStartRequest(condition="Sudden eye pain and vision changes")
        
        with patch.object(session_manager, '_calculate_initial_confidence') as mock_initial, \
             patch.object(session_manager, '_generate_next_question') as mock_question, \
             patch.object(session_manager, '_update_confidence_with_answer') as mock_update, \
             patch('src.tools.session_finalizer.SessionFinalizer.assess_agent_satisfaction') as mock_satisfaction, \
             patch.object(session_manager, '_finalize_session') as mock_finalize:
            
            # Mock initial low confidence
            mock_initial.return_value = ConfidenceScore(
                overall_confidence=0.3,
                doctor_confidence={"Ophthalmologist": 0.5, "Ocular Surgeon": 0.5},
                reasoning="Initial urgent assessment"
            )
            
            mock_question.return_value = FollowUpQuestion(
                question="How severe is the pain?",
                options=[
                    QuestionOption(text="Mild", is_other=False),
                    QuestionOption(text="Severe", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
            
            # Start the session
            start_response = await session_manager.start_session(start_request)
            session_id = start_response.session_id
            
            # Simulate answering questions with increasing confidence
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.6,
                doctor_confidence={"Ocular Surgeon": 0.8, "Ophthalmologist": 0.2},
                reasoning="High urgency indicators"
            )
            
            # First few questions - not satisfied
            mock_satisfaction.return_value = (False, "Need more information", 0.4)
            
            answer_request = NextQuestionRequest(session_id=session_id, answer="Severe, came on suddenly")
            response1 = await session_manager.process_answer_and_get_next_question(answer_request)
            
            assert not response1.is_complete
            
            # Update to high confidence and satisfaction
            mock_update.return_value = ConfidenceScore(
                overall_confidence=0.9,
                doctor_confidence={"Ocular Surgeon": 0.9, "Ophthalmologist": 0.1},
                reasoning="Clear emergency case"
            )
            
            mock_satisfaction.return_value = (True, "Sufficient information for urgent referral", 0.9)
            
            mock_finalize.return_value = (
                MagicMock(doctor_type="Ocular Surgeon", reasoning="Emergency requiring immediate surgical evaluation"),
                "Patient presents with acute onset severe eye pain and vision changes - urgent surgical consultation needed"
            )
            
            answer_request2 = NextQuestionRequest(session_id=session_id, answer="Yes, also seeing flashing lights")
            response2 = await session_manager.process_answer_and_get_next_question(answer_request2)
            
            assert response2.is_complete
            assert response2.doctor_recommendation.doctor_type == "Ocular Surgeon"
            assert "urgent" in response2.summary_for_doctor.lower()

if __name__ == "__main__":
    pytest.main([__file__])
