"""
Session Finalizer
=================

This tool determines when the AI agent is satisfied with the information gathered
and can confidently make a doctor recommendation. It evaluates:
- Information completeness
- Confidence scores
- Diagnostic clarity
- Question-answer quality

It also generates final recommendations and summaries.
"""

import logging
import json
from typing import Tuple, List
from langchain_google_genai import ChatGoogleGenerativeAI

from src.models.models import (
    SessionState, DoctorRecommendation, ConfidenceScore,
    ConversationHistory
)
from src.core.config import config

logger = logging.getLogger(__name__)

class SessionFinalizer:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model=config.GEMINI_REASONING_MODEL,
            google_api_key=config.GEMINI_API_KEY,
            temperature=0.2  # Low temperature for consistent decision making
        )
        
        # Satisfaction criteria weights
        self.satisfaction_criteria = {
            "confidence_threshold": 0.75,      # Minimum confidence for satisfaction
            "information_completeness": 0.8,   # How complete is the medical picture
            "diagnostic_clarity": 0.7,         # How clear is the diagnosis direction
            "question_efficiency": 0.6         # Are we getting diminishing returns
        }
    
    async def assess_agent_satisfaction(
        self, 
        session: SessionState,
        proposed_next_question: str = ""
    ) -> Tuple[bool, str, float]:
        """
        Assess whether the AI agent is satisfied with the information gathered.
        
        Returns:
            - is_satisfied: Boolean indicating if agent is satisfied
            - reasoning: String explaining the satisfaction assessment
            - satisfaction_score: Float from 0-1 indicating level of satisfaction
        """
        try:
            # Build comprehensive assessment context
            assessment_context = self._build_assessment_context(session, proposed_next_question)
            
            # Use LLM to assess satisfaction
            satisfaction_result = await self._llm_assess_satisfaction(assessment_context)
            
            logger.info(f"Agent satisfaction assessment: {satisfaction_result['is_satisfied']} "
                       f"(score: {satisfaction_result['satisfaction_score']:.2f})")
            
            return (
                satisfaction_result["is_satisfied"],
                satisfaction_result["reasoning"],
                satisfaction_result["satisfaction_score"]
            )
            
        except Exception as e:
            logger.error(f"Error assessing agent satisfaction: {str(e)}")
            # Conservative fallback - continue asking if unsure
            return False, "Unable to assess satisfaction, continuing with questions", 0.3
    
    async def finalize_session(
        self, 
        session: SessionState
    ) -> Tuple[DoctorRecommendation, str]:
        """Generate final doctor recommendation and medical summary"""
        try:
            # Generate comprehensive medical summary
            summary = await self._generate_medical_summary(session)
            
            # Generate final doctor recommendation with detailed reasoning
            doctor_recommendation = await self._generate_final_recommendation(session)
            
            logger.info(f"Session finalized with recommendation: {doctor_recommendation.doctor_type}")
            
            return doctor_recommendation, summary
            
        except Exception as e:
            logger.error(f"Error finalizing session: {str(e)}")
            # Fallback recommendation
            fallback_recommendation = DoctorRecommendation(
                doctor_type=session.current_leading_doctor,
                reasoning=f"Based on conversation analysis, {session.current_leading_doctor} "
                         f"appears most appropriate for {session.initial_condition}"
            )
            
            fallback_summary = (
                f"Patient presents with: {session.initial_condition}\n"
                f"Conversation covered {len(session.conversation_history)} key areas.\n"
                f"Recommendation: {session.current_leading_doctor}"
            )
            
            return fallback_recommendation, fallback_summary
    
    def _build_assessment_context(self, session: SessionState, proposed_question: str = "") -> str:
        """Build context for satisfaction assessment"""
        context = f"""
MEDICAL CONSULTATION SESSION ASSESSMENT

Initial Condition: {session.initial_condition}

Current Confidence Levels:
- Overall Confidence: {session.confidence_score.overall_confidence:.2f}
- Leading Doctor: {session.current_leading_doctor}

Doctor Confidence Distribution:
"""
        for doctor, score in session.confidence_score.doctor_confidence.items():
            context += f"- {doctor}: {score:.2f}\n"
        
        context += f"\nConversation History ({len(session.conversation_history)} exchanges):\n"
        
        for i, entry in enumerate(session.conversation_history):
            if entry.answer:  # Only include completed exchanges
                context += f"Q{i+1}: {entry.question}\n"
                context += f"A{i+1}: {entry.answer}\n\n"
        
        if proposed_question:
            context += f"Proposed Next Question: {proposed_question}\n"
        
        return context
    
    async def _llm_assess_satisfaction(self, context: str) -> dict:
        """Use LLM to assess whether enough information has been gathered"""
        
        prompt = f"""
        You are a medical AI assistant evaluating whether sufficient information has been gathered 
        to make a confident eye care specialist recommendation.
        
        Analyze the following consultation session:
        
        {context}
        
        Evaluate the following criteria:
        
        1. INFORMATION COMPLETENESS: Do we have enough medical details about:
           - Symptom characteristics and severity
           - Timeline and progression
           - Impact on daily life
           - Relevant medical history
        
        2. DIAGNOSTIC CLARITY: Is there sufficient information to:
           - Distinguish between different specialist needs
           - Understand urgency level
           - Identify key symptoms that guide specialist choice
        
        3. CONFIDENCE LEVEL: Are the confidence scores indicating:
           - Clear leading recommendation
           - Sufficient certainty for patient guidance
           - Diminishing returns from additional questions
        
        4. QUESTION EFFICIENCY: Would asking more questions:
           - Provide significantly more diagnostic value
           - Help differentiate between specialists
           - Or are we reaching diminishing returns
        
        Based on your analysis, determine if the AI agent should be SATISFIED with the 
        information gathered and proceed with final recommendation.
        
        Return ONLY a JSON object in this format:
        {{
            "is_satisfied": true/false,
            "satisfaction_score": 0.85,
            "reasoning": "Detailed explanation of satisfaction assessment",
            "information_gaps": ["Any significant information still missing"],
            "confidence_assessment": "Assessment of current confidence levels"
        }}
        
        IMPORTANT:
        - Be decisive but thorough in your assessment
        - Consider patient experience (don't over-question)
        - Balance thoroughness with efficiency
        - Return only the JSON object
        """
        
        try:
            response = self.llm.invoke(prompt)
            
            # Clean and parse response
            content = response.content.strip()
            if content.startswith('```json'):
                content = content[7:]
            if content.endswith('```'):
                content = content[:-3]
            content = content.strip()
            
            result = json.loads(content)
            
            # Validate and normalize result
            return {
                "is_satisfied": bool(result.get("is_satisfied", False)),
                "satisfaction_score": max(0.0, min(1.0, float(result.get("satisfaction_score", 0.5)))),
                "reasoning": str(result.get("reasoning", "Unable to assess satisfaction")),
                "information_gaps": result.get("information_gaps", []),
                "confidence_assessment": str(result.get("confidence_assessment", ""))
            }
            
        except (json.JSONDecodeError, ValueError, KeyError) as e:
            logger.error(f"Failed to parse satisfaction assessment: {e}")
            logger.error(f"Raw response: {response.content}")
            
            # Conservative fallback
            return {
                "is_satisfied": False,
                "satisfaction_score": 0.3,
                "reasoning": "Unable to properly assess satisfaction, continuing with questions for safety",
                "information_gaps": ["Assessment failed"],
                "confidence_assessment": "Unable to assess"
            }
    
    async def _generate_medical_summary(self, session: SessionState) -> str:
        """Generate comprehensive medical summary for the doctor"""
        
        # Build conversation summary
        conversation_summary = ""
        for i, entry in enumerate(session.conversation_history):
            if entry.answer:
                conversation_summary += f"Q{i+1}: {entry.question}\nA{i+1}: {entry.answer}\n\n"
        
        prompt = f"""
        Generate a concise but comprehensive medical summary for an eye care specialist based on this patient consultation.
        
        Initial Condition: {session.initial_condition}
        
        Patient Responses:
        {conversation_summary}
        
        Final Confidence Assessment:
        - Overall Confidence: {session.confidence_score.overall_confidence:.2f}
        - Recommended Specialist: {session.current_leading_doctor}
        
        Create a professional medical summary that includes:
        1. Chief complaint and presenting symptoms
        2. Key clinical details gathered
        3. Timeline and progression
        4. Severity and impact assessment
        5. Relevant negatives or additional context
        6. Clinical reasoning for specialist recommendation
        
        Format as a professional medical note suitable for specialist referral.
        Keep it concise but comprehensive (2-3 paragraphs maximum).
        """
        
        try:
            response = self.llm.invoke(prompt)
            return response.content.strip()
            
        except Exception as e:
            logger.error(f"Error generating medical summary: {str(e)}")
            return f"Patient presents with {session.initial_condition}. " \
                   f"Based on {len(session.conversation_history)} consultation exchanges, " \
                   f"recommend evaluation by {session.current_leading_doctor}."
    
    async def _generate_final_recommendation(self, session: SessionState) -> DoctorRecommendation:
        """Generate final doctor recommendation with detailed reasoning"""
        
        prompt = f"""
        Based on this complete medical consultation session, provide a final specialist recommendation.
        
        Initial Condition: {session.initial_condition}
        
        Final Confidence Scores:
        {json.dumps(session.confidence_score.doctor_confidence, indent=2)}
        
        Overall Confidence: {session.confidence_score.overall_confidence:.2f}
        Current Leading Recommendation: {session.current_leading_doctor}
        
        Provide a final recommendation that explains:
        1. Which eye care specialist is most appropriate
        2. Clear reasoning based on the consultation
        3. Any urgency considerations
        4. What the patient should expect
        
        Return ONLY a JSON object:
        {{
            "doctor_type": "Specific specialist type",
            "reasoning": "Detailed explanation of why this specialist is recommended based on the patient's specific situation"
        }}
        """
        
        try:
            response = self.llm.invoke(prompt)
            
            # Clean and parse response
            content = response.content.strip()
            if content.startswith('```json'):
                content = content[7:]
            if content.endswith('```'):
                content = content[:-3]
            content = content.strip()
            
            result = json.loads(content)
            
            return DoctorRecommendation(
                doctor_type=result.get("doctor_type", session.current_leading_doctor),
                reasoning=result.get("reasoning", f"Based on consultation analysis, {session.current_leading_doctor} is recommended")
            )
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"Error parsing final recommendation: {str(e)}")
            return DoctorRecommendation(
                doctor_type=session.current_leading_doctor,
                reasoning=f"Based on consultation analysis and confidence scores, {session.current_leading_doctor} is the most appropriate specialist"
            )
