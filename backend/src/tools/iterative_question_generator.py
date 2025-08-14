"""
Iterative Question Generator
============================

This tool generates relevant follow-up questions one at a time based on:
- Initial condition
- Conversation history
- Current confidence scores
- Leading doctor recommendation

The system adapts questions dynamically rather than using a fixed set.
"""

import logging
import json
from typing import List, Optional
from langchain_google_genai import ChatGoogleGenerativeAI

from src.models.models import (
    FollowUpQuestion, QuestionOption, ConfidenceScore, 
    ConversationHistory
)
from src.core.config import config

logger = logging.getLogger(__name__)

class IterativeQuestionGenerator:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model=config.GEMINI_REASONING_MODEL,
            google_api_key=config.GEMINI_API_KEY,
            temperature=0.4  # Moderate temperature for creative but focused questions
        )
        
        # Question templates based on doctor types and common medical inquiry patterns
        self.question_strategies = {
            "ophthalmologist_focus": [
                "What symptoms are you experiencing?",
                "How long have the symptoms been present?",
                "Is there any pain or discomfort?",
                "Have you noticed any changes in vision?",
                "Any discharge or redness?",
                "Any family history of eye problems?",
                "Are you taking any medications?"
            ],
            "optometrist_focus": [
                "How is your vision affected?",
                "Do you have trouble seeing at distance or up close?",
                "When did you last have an eye exam?",
                "Do you wear glasses or contacts?",
                "Any eye strain or headaches?",
                "How long have you noticed vision changes?"
            ],
            "urgency_assessment": [
                "How severe would you rate your symptoms?",
                "Is this affecting your daily activities?",
                "Did the symptoms come on suddenly?",
                "Any recent trauma or injury to the eye?"
            ]
        }
    
    async def generate_next_question(
        self, 
        initial_condition: str, 
        conversation_history: List[ConversationHistory],
        current_confidence: ConfidenceScore,
        leading_doctor: str
    ) -> FollowUpQuestion:
        """Generate the next most relevant question based on current context"""
        try:
            # Build context for question generation
            context = self._build_context_string(
                initial_condition, 
                conversation_history, 
                current_confidence, 
                leading_doctor
            )
            
            # Generate question using LLM
            question = await self._generate_question_with_llm(context, leading_doctor)
            
            # Add the question to conversation history for tracking
            if conversation_history is not None:
                conversation_history.append(ConversationHistory(
                    question=question.question,
                    answer=""  # Will be filled when user responds
                ))
            
            logger.info(f"Generated question focusing on {leading_doctor}: {question.question[:50]}...")
            return question
            
        except Exception as e:
            logger.error(f"Error generating next question: {str(e)}")
            # Return a fallback question
            return self._get_fallback_question(conversation_history)
    
    def _build_context_string(
        self, 
        initial_condition: str, 
        conversation_history: List[ConversationHistory],
        current_confidence: ConfidenceScore,
        leading_doctor: str
    ) -> str:
        """Build comprehensive context for question generation"""
        context = f"Initial condition: {initial_condition}\n\n"
        
        if conversation_history and len(conversation_history) > 0:
            context += "Previous conversation:\n"
            for i, entry in enumerate(conversation_history):
                if entry.answer:  # Only include completed Q&A pairs
                    context += f"Q{i+1}: {entry.question}\n"
                    context += f"A{i+1}: {entry.answer}\n\n"
        
        context += f"Current leading doctor recommendation: {leading_doctor}\n"
        context += f"Current overall confidence: {current_confidence.overall_confidence:.2f}\n"
        context += f"Doctor confidence scores:\n"
        for doctor, score in current_confidence.doctor_confidence.items():
            context += f"  - {doctor}: {score:.2f}\n"
        
        return context
    
    async def _generate_question_with_llm(self, context: str, leading_doctor: str) -> FollowUpQuestion:
        """Use LLM to generate a targeted question"""
        
        prompt = f"""
        You are a medical AI assistant helping to gather information for an eye care consultation.
        
        Based on the following context, generate ONE highly relevant follow-up question that will help:
        1. Increase diagnostic confidence
        2. Differentiate between different eye care specialists
        3. Gather the most important missing information
        
        Context:
        {context}
        
        Current leading recommendation: {leading_doctor}
        
        Generate a question that will help confirm or refine this recommendation. The question should:
        - Be specific and medical relevant
        - Have 3-4 multiple choice options plus "Other"
        - Help distinguish between different types of eye care needs
        - Focus on symptoms, timeline, severity, or relevant medical history
        
        Return ONLY a JSON object in this exact format:
        {{
            "question": "Your specific question here?",
            "options": [
                {{"text": "Option 1", "is_other": false}},
                {{"text": "Option 2", "is_other": false}},
                {{"text": "Option 3", "is_other": false}},
                {{"text": "Other", "is_other": true}}
            ]
        }}
        
        IMPORTANT:
        - Make the question specific to the current situation
        - Avoid repeating questions already asked
        - Focus on the most diagnostically valuable information
        - Do NOT use asterisks or markdown formatting
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
            
            # Create QuestionOption objects
            options = []
            for opt in result.get("options", []):
                options.append(QuestionOption(
                    text=opt.get("text", ""),
                    is_other=opt.get("is_other", False)
                ))
            
            question = FollowUpQuestion(
                question=result.get("question", "Can you provide more details about your symptoms?"),
                options=options
            )
            
            return question
            
        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Failed to parse LLM question response: {e}")
            logger.error(f"Raw response: {response.content}")
            return self._get_fallback_question(None)
    
    def _get_fallback_question(self, conversation_history: Optional[List[ConversationHistory]]) -> FollowUpQuestion:
        """Generate a fallback question when LLM fails"""
        
        # Determine what type of fallback based on conversation length
        history_length = len(conversation_history) if conversation_history else 0
        
        if history_length == 0:
            # First question - focus on severity
            return FollowUpQuestion(
                question="How would you describe the severity of your symptoms?",
                options=[
                    QuestionOption(text="Mild - minimal impact on daily activities", is_other=False),
                    QuestionOption(text="Moderate - some impact on daily activities", is_other=False),
                    QuestionOption(text="Severe - significant impact on daily activities", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
        elif history_length == 1:
            # Second question - focus on timeline
            return FollowUpQuestion(
                question="How long have you been experiencing these symptoms?",
                options=[
                    QuestionOption(text="Less than 24 hours", is_other=False),
                    QuestionOption(text="1-7 days", is_other=False),
                    QuestionOption(text="More than a week", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
        else:
            # Later questions - focus on specific symptoms
            return FollowUpQuestion(
                question="Are you experiencing any additional symptoms?",
                options=[
                    QuestionOption(text="No additional symptoms", is_other=False),
                    QuestionOption(text="Pain or discomfort", is_other=False),
                    QuestionOption(text="Vision changes", is_other=False),
                    QuestionOption(text="Other", is_other=True)
                ]
            )
