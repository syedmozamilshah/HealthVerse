"""
Confidence Calculator for Medical Diagnosis
==========================================

This tool calculates and updates confidence scores for doctor recommendations
based on symptom analysis and conversation progression.
"""

import logging
import json
from typing import List, Dict
from langchain_google_genai import ChatGoogleGenerativeAI

from src.models.models import ConfidenceScore, ConversationHistory
from src.core.config import config

logger = logging.getLogger(__name__)

class ConfidenceCalculator:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model=config.GEMINI_REASONING_MODEL,
            google_api_key=config.GEMINI_API_KEY,
            temperature=0.2  # Lower temperature for more consistent confidence scoring
        )
        
        # Keyword-based confidence boosters for different doctor types
        self.doctor_keywords = {
            "Ophthalmologist": [
                "infection", "disease", "serious", "medical", "treatment", "diagnosis",
                "severe", "complications", "medication", "urgent", "red eye", "discharge"
            ],
            "Optometrist": [
                "blurry", "vision", "glasses", "contacts", "prescription", "reading",
                "distance", "eye strain", "headache", "focus", "clarity"
            ],
            "Optician": [
                "fitting", "adjustment", "frame", "lens", "broken", "repair",
                "comfort", "size", "style", "dispense"
            ],
            "Ocular Surgeon": [
                "surgery", "surgical", "operation", "cataract", "retinal", "tumor",
                "emergency", "trauma", "injury", "severe damage"
            ]
        }
    
    async def calculate_initial_confidence(self, condition: str) -> ConfidenceScore:
        """Calculate initial confidence based on the reported condition"""
        try:
            # Use keyword analysis for initial assessment
            keyword_confidence = self._analyze_keywords(condition)
            
            # Use LLM for more sophisticated analysis
            llm_confidence = await self._llm_confidence_analysis(condition, [])
            
            # Combine keyword and LLM confidence (weighted average)
            combined_confidence = self._combine_confidence_scores(keyword_confidence, llm_confidence, 0.3, 0.7)
            
            logger.info(f"Initial confidence calculated: {combined_confidence.overall_confidence:.2f}")
            return combined_confidence
            
        except Exception as e:
            logger.error(f"Error calculating initial confidence: {str(e)}")
            # Return default confidence distribution
            return ConfidenceScore(
                overall_confidence=0.3,
                doctor_confidence={
                    "Ophthalmologist": 0.4,
                    "Optometrist": 0.3,
                    "Optician": 0.2,
                    "Ocular Surgeon": 0.1
                },
                reasoning="Default initial confidence distribution"
            )
    
    async def update_confidence_with_answer(
        self, 
        initial_condition: str, 
        conversation_history: List[ConversationHistory],
        new_answer: str
    ) -> ConfidenceScore:
        """Update confidence based on new answer"""
        try:
            # Combine all information for analysis
            full_context = self._build_context_string(initial_condition, conversation_history, new_answer)
            
            # Analyze with keywords
            keyword_confidence = self._analyze_keywords(full_context)
            
            # Use LLM for sophisticated analysis
            llm_confidence = await self._llm_confidence_analysis(initial_condition, conversation_history, new_answer)
            
            # As conversation progresses, rely more on LLM analysis
            conversation_length = len(conversation_history)
            keyword_weight = max(0.1, 0.4 - (conversation_length * 0.05))  # Decrease keyword weight
            llm_weight = 1.0 - keyword_weight
            
            combined_confidence = self._combine_confidence_scores(keyword_confidence, llm_confidence, keyword_weight, llm_weight)
            
            # Apply conversation length boost to overall confidence (more nuanced)
            # Boost diminishes as we get more answers to prevent over-confidence
            # Reduced boost values to ensure multiple questions are needed
            if conversation_length <= 3:
                length_boost = min(0.08, conversation_length * 0.03)  # 3% per early answer (reduced from 5%)
            else:
                length_boost = 0.09 + min(0.06, (conversation_length - 3) * 0.015)  # 1.5% per later answer (reduced from 2%)
            
            combined_confidence.overall_confidence = min(0.7, combined_confidence.overall_confidence + length_boost)
            
            # Add information quality assessment with reduced boost
            info_quality_boost = self._assess_information_quality(initial_condition, conversation_history, new_answer) * 0.6  # Reduce boost by 40%
            combined_confidence.overall_confidence = min(0.7, combined_confidence.overall_confidence + info_quality_boost)
            
            logger.info(f"Updated confidence: {combined_confidence.overall_confidence:.2f} after {conversation_length + 1} exchanges")
            return combined_confidence
            
        except Exception as e:
            logger.error(f"Error updating confidence: {str(e)}")
            # Return a modest confidence boost as fallback
            return ConfidenceScore(
                overall_confidence=0.5,
                doctor_confidence={
                    "Ophthalmologist": 0.4,
                    "Optometrist": 0.3,
                    "Optician": 0.2,
                    "Ocular Surgeon": 0.1
                },
                reasoning="Fallback confidence after processing answer"
            )
    
    def _analyze_keywords(self, text: str) -> ConfidenceScore:
        """Analyze text using keyword matching for each doctor type"""
        text_lower = text.lower()
        doctor_scores = {}
        
        for doctor_type, keywords in self.doctor_keywords.items():
            score = 0.0
            matched_keywords = []
            
            for keyword in keywords:
                if keyword in text_lower:
                    score += 0.15  # Each keyword adds 15% confidence
                    matched_keywords.append(keyword)
            
            doctor_scores[doctor_type] = min(1.0, score)
        
        # Normalize scores so they sum to 1.0
        total_score = sum(doctor_scores.values())
        if total_score > 0:
            doctor_scores = {k: v / total_score for k, v in doctor_scores.items()}
        else:
            # Default equal distribution
            doctor_scores = {k: 0.25 for k in self.doctor_keywords.keys()}
        
        # Overall confidence based on best match
        overall_confidence = max(doctor_scores.values())
        
        return ConfidenceScore(
            overall_confidence=overall_confidence,
            doctor_confidence=doctor_scores,
            reasoning="Keyword-based confidence analysis"
        )
    
    async def _llm_confidence_analysis(
        self, 
        initial_condition: str, 
        conversation_history: List[ConversationHistory],
        new_answer: str = ""
    ) -> ConfidenceScore:
        """Use LLM to analyze confidence based on medical reasoning"""
        try:
            # Build context for LLM
            context = f"Initial condition: {initial_condition}\n\n"
            
            if conversation_history:
                context += "Conversation history:\n"
                for i, entry in enumerate(conversation_history):
                    context += f"Q{i+1}: {entry.question}\n"
                    context += f"A{i+1}: {entry.answer}\n\n"
            
            if new_answer:
                context += f"New answer: {new_answer}\n"
            
            prompt = f"""
            As a medical AI assistant, analyze the following patient information and provide confidence scores for eye specialist recommendations.
            
            {context}
            
            Analyze this information and provide confidence scores for each specialist type:
            1. Ophthalmologist - General eye doctor for medical treatment and diagnosis
            2. Optometrist - Vision correction and primary eye care
            3. Optician - Eyewear fitting and dispensing
            4. Ocular Surgeon - Surgical procedures for serious eye conditions
            
            Consider:
            - Severity and complexity of symptoms
            - Need for medical vs. corrective intervention
            - Urgency of the condition
            - Specific symptoms and their implications
            
            Return ONLY a JSON object in this exact format:
            {{
                "overall_confidence": 0.75,
                "doctor_confidence": {{
                    "Ophthalmologist": 0.45,
                    "Optometrist": 0.35,
                    "Optician": 0.15,
                    "Ocular Surgeon": 0.05
                }},
                "reasoning": "Brief explanation of the confidence assessment"
            }}
            
            IMPORTANT: 
            - Overall confidence should be between 0.0 and 1.0
            - Doctor confidence scores should sum to approximately 1.0
            - Do NOT use asterisks or markdown formatting
            - Return only the JSON object
            """
            
            response = self.llm.invoke(prompt)
            
            try:
                # Clean response
                content = response.content.strip()
                if content.startswith('```json'):
                    content = content[7:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                result = json.loads(content)
                
                # Validate and normalize the result
                overall_confidence = float(result.get("overall_confidence", 0.5))
                overall_confidence = max(0.0, min(1.0, overall_confidence))  # Clamp to [0,1]
                
                doctor_confidence = result.get("doctor_confidence", {})
                
                # Ensure all doctor types are present
                for doctor_type in self.doctor_keywords.keys():
                    if doctor_type not in doctor_confidence:
                        doctor_confidence[doctor_type] = 0.25
                
                # Normalize doctor confidence scores
                total_doctor_confidence = sum(doctor_confidence.values())
                if total_doctor_confidence > 0:
                    doctor_confidence = {
                        k: max(0.0, min(1.0, v / total_doctor_confidence)) 
                        for k, v in doctor_confidence.items()
                    }
                
                reasoning = result.get("reasoning", "AI-based medical analysis")
                
                return ConfidenceScore(
                    overall_confidence=overall_confidence,
                    doctor_confidence=doctor_confidence,
                    reasoning=reasoning
                )
                
            except (json.JSONDecodeError, ValueError) as e:
                logger.error(f"Failed to parse LLM confidence response: {e}")
                logger.error(f"Raw response: {response.content}")
                raise
            
        except Exception as e:
            logger.error(f"Error in LLM confidence analysis: {str(e)}")
            # Return fallback confidence
            return ConfidenceScore(
                overall_confidence=0.5,
                doctor_confidence={
                    "Ophthalmologist": 0.4,
                    "Optometrist": 0.3,
                    "Optician": 0.2,
                    "Ocular Surgeon": 0.1
                },
                reasoning="Fallback due to LLM analysis error"
            )
    
    def _assess_information_quality(self, initial_condition: str, conversation_history: List[ConversationHistory], new_answer: str) -> float:
        """Assess the quality and diagnostic value of information gathered"""
        try:
            quality_score = 0.0
            
            # Check for specific medical details in answers
            quality_indicators = [
                "severe", "mild", "moderate", "sudden", "gradual", "days", "weeks", "months",
                "pain", "burning", "itching", "discharge", "swelling", "redness",
                "vision", "blurry", "clear", "double", "loss", "improvement",
                "medication", "surgery", "injury", "trauma", "family history"
            ]
            
            recent_answers = [new_answer] + [entry.answer for entry in conversation_history[-2:] if entry.answer]
            
            for answer in recent_answers:
                if answer:
                    answer_lower = answer.lower()
                    # Award points for detailed, specific answers
                    if len(answer.split()) > 3:  # More than 3 words
                        quality_score += 0.02
                    
                    # Award points for medical detail keywords
                    for indicator in quality_indicators:
                        if indicator in answer_lower:
                            quality_score += 0.01
                    
                    # Penalize vague responses
                    vague_responses = ["other", "maybe", "not sure", "don't know", "unclear"]
                    for vague in vague_responses:
                        if vague in answer_lower:
                            quality_score -= 0.01
            
            return max(0.0, min(0.1, quality_score))  # Cap at 10% boost
            
        except Exception as e:
            logger.error(f"Error assessing information quality: {str(e)}")
            return 0.0
    
    def _build_context_string(self, initial_condition: str, conversation_history: List[ConversationHistory], new_answer: str = "") -> str:
        """Build a comprehensive context string from all available information"""
        context = f"Initial condition: {initial_condition}\n\n"
        
        if conversation_history:
            context += "Conversation:\n"
            for i, entry in enumerate(conversation_history):
                if entry.answer:  # Only include completed Q&A pairs
                    context += f"Q{i+1}: {entry.question}\n"
                    context += f"A{i+1}: {entry.answer}\n\n"
        
        if new_answer:
            context += f"Latest answer: {new_answer}\n"
        
        return context
    
    def _combine_confidence_scores(self, score1: ConfidenceScore, score2: ConfidenceScore, weight1: float, weight2: float) -> ConfidenceScore:
        """Combine two confidence scores with given weights"""
        # Normalize weights
        total_weight = weight1 + weight2
        w1 = weight1 / total_weight if total_weight > 0 else 0.5
        w2 = weight2 / total_weight if total_weight > 0 else 0.5
        
        # Combine overall confidence
        combined_overall = (score1.overall_confidence * w1) + (score2.overall_confidence * w2)
        
        # Combine doctor confidences
        combined_doctor_confidence = {}
        all_doctors = set(score1.doctor_confidence.keys()) | set(score2.doctor_confidence.keys())
        
        for doctor in all_doctors:
            conf1 = score1.doctor_confidence.get(doctor, 0.0)
            conf2 = score2.doctor_confidence.get(doctor, 0.0)
            combined_doctor_confidence[doctor] = (conf1 * w1) + (conf2 * w2)
        
        # Create combined reasoning
        reasoning = f"Combined analysis (weights: {w1:.2f}/{w2:.2f}) - {score1.reasoning} + {score2.reasoning}"
        
        return ConfidenceScore(
            overall_confidence=combined_overall,
            doctor_confidence=combined_doctor_confidence,
            reasoning=reasoning
        )
