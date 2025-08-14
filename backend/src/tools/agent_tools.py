from langchain.tools import BaseTool
from typing import Dict, List, Any, Optional
from pydantic import BaseModel, Field
import json
import logging
from langchain_google_genai import ChatGoogleGenerativeAI
from src.services.qdrant_service import qdrant_service
from src.core.config import config
from src.models.models import FollowUpQuestion, QuestionOption, DoctorRecommendation, UserAnswer, RAGDocument

logger = logging.getLogger(__name__)

# Initialize the LLM
llm = ChatGoogleGenerativeAI(
    model=config.GEMINI_REASONING_MODEL,
    google_api_key=config.GEMINI_API_KEY,
    temperature=0.3
)

class QuestionGenerationInput(BaseModel):
    initial_condition: str = Field(description="Initial eye-related condition or symptoms")

class QuestionGenerationTool(BaseTool):
    name: str = "generate_followup_questions"
    description: str = "Generate 3-5 follow-up questions in layman-friendly language with dynamic answer options"
    
    def _run(self, initial_condition: str) -> Dict[str, Any]:
        try:
            prompt = f"""
            As an ophthalmology assistant, you MUST generate EXACTLY 4 follow-up questions for a user who reported: "{initial_condition}"

            IMPORTANT: Do NOT use asterisks (*), markdown formatting, or any special characters in your response. Use plain text only.

            Generate questions that are:
            1. In simple, layman-friendly language
            2. Relevant to eye conditions and symptoms
            3. Help determine the most appropriate eye specialist (Ophthalmologist, Optometrist, Optician, or Ocular Surgeon)
            4. Cover different aspects of the condition

            For each question, provide exactly 4 answer options: 3 specific options plus 1 "Other" option.
            The options should be comprehensive but easy to understand.

            You MUST return EXACTLY this JSON format with EXACTLY 4 questions:
            {{
                "questions": [
                    {{
                        "question": "How long have you been experiencing these symptoms?",
                        "options": [
                            {{"text": "Less than a week", "is_other": false}},
                            {{"text": "1-4 weeks", "is_other": false}},
                            {{"text": "More than a month", "is_other": false}},
                            {{"text": "Other", "is_other": true}}
                        ]
                    }},
                    {{
                        "question": "How would you describe the severity of your symptoms?",
                        "options": [
                            {{"text": "Mild - does not interfere with daily activities", "is_other": false}},
                            {{"text": "Moderate - sometimes affects daily activities", "is_other": false}},
                            {{"text": "Severe - significantly impacts daily life", "is_other": false}},
                            {{"text": "Other", "is_other": true}}
                        ]
                    }},
                    {{
                        "question": "Are you experiencing any pain or discomfort?",
                        "options": [
                            {{"text": "No pain", "is_other": false}},
                            {{"text": "Mild discomfort", "is_other": false}},
                            {{"text": "Significant pain", "is_other": false}},
                            {{"text": "Other", "is_other": true}}
                        ]
                    }},
                    {{
                        "question": "Have you had any previous eye problems or treatments?",
                        "options": [
                            {{"text": "No previous eye problems", "is_other": false}},
                            {{"text": "Minor issues (glasses, contacts)", "is_other": false}},
                            {{"text": "Previous eye surgery or treatment", "is_other": false}},
                            {{"text": "Other", "is_other": true}}
                        ]
                    }}
                ]
            }}

            CRITICAL: 
            - You must generate EXACTLY 4 questions
            - Do NOT use asterisks or markdown formatting
            - Focus on these categories:
              1. Duration and onset of symptoms
              2. Severity and impact on daily life  
              3. Associated symptoms (pain, discharge, etc.)
              4. Medical history and previous treatments
            
            Customize the specific questions based on the reported condition but maintain the 4-question structure.
            """
            
            response = llm.invoke(prompt)
            
            # Parse the JSON response
            try:
                result = json.loads(response.content)
                return result
            except json.JSONDecodeError:
                # Fallback if JSON parsing fails
                logger.error("Failed to parse LLM response as JSON")
                return {
                    "questions": [
                        {
                            "question": "How long have you been experiencing these symptoms?",
                            "options": [
                                {"text": "Less than a week", "is_other": False},
                                {"text": "1-4 weeks", "is_other": False},
                                {"text": "More than a month", "is_other": False},
                                {"text": "Other", "is_other": True}
                            ]
                        },
                        {
                            "question": "How would you describe the severity of your symptoms?",
                            "options": [
                                {"text": "Mild - doesn't interfere with daily activities", "is_other": False},
                                {"text": "Moderate - sometimes affects daily activities", "is_other": False},
                                {"text": "Severe - significantly impacts daily life", "is_other": False},
                                {"text": "Other", "is_other": True}
                            ]
                        },
                        {
                            "question": "Are you experiencing any pain or discomfort?",
                            "options": [
                                {"text": "No pain", "is_other": False},
                                {"text": "Mild discomfort", "is_other": False},
                                {"text": "Significant pain", "is_other": False},
                                {"text": "Other", "is_other": True}
                            ]
                        },
                        {
                            "question": "Have you had any previous eye problems or treatments?",
                            "options": [
                                {"text": "No previous eye problems", "is_other": False},
                                {"text": "Minor issues (glasses, contacts)", "is_other": False},
                                {"text": "Previous eye surgery or treatment", "is_other": False},
                                {"text": "Other", "is_other": True}
                            ]
                        }
                    ]
                }
                
        except Exception as e:
            logger.error(f"Error generating questions: {str(e)}")
            raise

class DoctorIdentificationInput(BaseModel):
    initial_condition: str = Field(description="Initial condition")
    answers: List[Dict[str, Any]] = Field(description="User answers")

class DoctorIdentificationTool(BaseTool):
    name: str = "identify_doctor_type"
    description: str = "Determine the most appropriate eye specialist from the 4 allowed types only"
    
    def _run(self, initial_condition: str, answers: List[Dict[str, Any]]) -> Dict[str, Any]:
        try:
            # Format answers for the prompt
            formatted_answers = []
            for i, answer in enumerate(answers):
                answer_text = answer.get('selected_option') or answer.get('custom_answer', '')
                formatted_answers.append(f"Q{i+1}: {answer_text}")
            
            answers_text = "\n".join(formatted_answers)
            
            prompt = f"""
            Based on the initial condition and user answers, determine the most appropriate eye specialist.

            Initial Condition: {initial_condition}
            
            User Answers:
            {answers_text}

            You MUST choose EXACTLY ONE from these 4 eye specialists. Your response must contain the exact text from this list:
            1. "Ophthalmologist" - General eye doctor for diagnosis, medical treatment, and complex eye conditions
            2. "Optometrist" - Primary eye care, vision tests, prescribing glasses/contacts, detecting eye diseases
            3. "Optician" - Fitting and dispensing eyewear, adjusting glasses and contact lenses
            4. "Ocular Surgeon" - Surgical procedures for serious eye conditions, cataracts, retinal surgery

            Guidelines for selection:
            - For blurry vision, eye strain, need for glasses/contacts → Optometrist
            - For serious eye diseases, infections, medical treatment → Ophthalmologist  
            - For surgical conditions, cataracts, retinal issues → Ocular Surgeon
            - For eyewear fitting, lens adjustments → Optician

            Return ONLY in this exact JSON format:
            {{
                "doctor_type": "[EXACT match from the 4 options above]",
                "reasoning": "Clear explanation for this choice based on symptoms and needs"
            }}
            
            CRITICAL: The doctor_type value must be exactly one of: Ophthalmologist, Optometrist, Optician, or Ocular Surgeon
            """
            
            response = llm.invoke(prompt)
            
            try:
                # Clean response content to handle markdown code blocks
                content = response.content.strip()
                if content.startswith('```json'):
                    content = content[7:]  # Remove ```json
                if content.endswith('```'):
                    content = content[:-3]  # Remove ```
                content = content.strip()
                
                result = json.loads(content)
                doctor_type = result.get("doctor_type", "").strip()
                
                # Normalize and validate doctor type with fuzzy matching
                normalized_type = self._normalize_doctor_type(doctor_type)
                
                if normalized_type not in config.ALLOWED_DOCTORS:
                    logger.warning(f"Invalid doctor type '{doctor_type}' normalized to '{normalized_type}', using fallback")
                    # Try to intelligently select based on keywords in condition/answers
                    normalized_type = self._intelligent_fallback(initial_condition, answers)
                
                result["doctor_type"] = normalized_type
                return result
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse doctor identification response: {e}")
                logger.error(f"Raw response: {response.content}")
                fallback_type = self._intelligent_fallback(initial_condition, answers)
                return {
                    "doctor_type": fallback_type,
                    "reasoning": "Selected based on symptom analysis due to parsing error"
                }
                
        except Exception as e:
            logger.error(f"Error identifying doctor type: {str(e)}")
            fallback_type = self._intelligent_fallback(initial_condition, answers)
            return {
                "doctor_type": fallback_type,
                "reasoning": "Selected based on symptom analysis due to system error"
            }
    
    def _normalize_doctor_type(self, doctor_type: str) -> str:
        """Normalize doctor type with fuzzy matching"""
        if not doctor_type:
            return "Ophthalmologist"
            
        # Clean the input
        cleaned = doctor_type.strip().lower()
        
        # Direct matches
        if "ophthalmologist" in cleaned:
            return "Ophthalmologist"
        elif "optometrist" in cleaned:
            return "Optometrist"
        elif "optician" in cleaned:
            return "Optician"
        elif "surgeon" in cleaned or "surgical" in cleaned:
            return "Ocular Surgeon"
        
        # Return original if no match found
        return doctor_type
    
    def _intelligent_fallback(self, condition: str, answers: List[Dict[str, Any]]) -> str:
        """Intelligently select doctor type based on keywords"""
        text_to_analyze = condition.lower()
        
        # Add answer text to analysis
        for answer in answers:
            answer_text = answer.get('selected_option') or answer.get('custom_answer', '')
            text_to_analyze += " " + str(answer_text).lower()
        
        # Surgery-related keywords
        surgery_keywords = ['surgery', 'surgical', 'operation', 'cataract', 'retinal', 'severe', 'tumor']
        if any(keyword in text_to_analyze for keyword in surgery_keywords):
            return "Ocular Surgeon"
        
        # Vision/glasses-related keywords
        vision_keywords = ['blurry', 'vision', 'glasses', 'contacts', 'prescription', 'reading', 'distance']
        if any(keyword in text_to_analyze for keyword in vision_keywords):
            return "Optometrist"
        
        # Eyewear fitting keywords
        fitting_keywords = ['fitting', 'adjustment', 'frame', 'lens']
        if any(keyword in text_to_analyze for keyword in fitting_keywords):
            return "Optician"
        
        # Default to Ophthalmologist for medical conditions
        return "Ophthalmologist"

class RAGQueryInput(BaseModel):
    condition_and_answers: str = Field(description="Combined condition and answers for context search")

class RAGQueryTool(BaseTool):
    name: str = "query_rag_knowledge"
    description: str = "Query the Qdrant vector store for relevant medical context"
    
    async def _arun(self, condition_and_answers: str) -> Dict[str, Any]:
        try:
            # Search for relevant documents
            documents = await qdrant_service.search_similar_documents(
                query=condition_and_answers,
                limit=5,
                score_threshold=0.3
            )
            
            context_texts = [doc.content for doc in documents]
            
            return {
                "retrieved_context": context_texts,
                "document_count": len(documents)
            }
            
        except Exception as e:
            logger.error(f"Error querying RAG knowledge: {str(e)}")
            return {
                "retrieved_context": [],
                "document_count": 0
            }
    
    def _run(self, condition_and_answers: str) -> Dict[str, Any]:
        # Synchronous version for compatibility
        try:
            import asyncio
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    # If loop is already running, create a new task
                    import concurrent.futures
                    with concurrent.futures.ThreadPoolExecutor() as executor:
                        future = executor.submit(asyncio.run, self._arun(condition_and_answers))
                        return future.result()
                else:
                    return loop.run_until_complete(self._arun(condition_and_answers))
            except RuntimeError:
                # No event loop running, create a new one
                return asyncio.run(self._arun(condition_and_answers))
        except Exception as e:
            logger.error(f"Error in RAG sync wrapper: {str(e)}")
            return {
                "retrieved_context": [],
                "document_count": 0
            }

class SummarizationInput(BaseModel):
    initial_condition: str = Field(description="Initial condition")
    answers: List[Dict[str, Any]] = Field(description="User answers")
    rag_context: List[str] = Field(description="Retrieved context from RAG")
    doctor_type: str = Field(description="Recommended doctor type")

class SummarizationTool(BaseTool):
    name: str = "generate_medical_summary"
    description: str = "Generate a concise medical summary for the doctor"
    
    def _run(
        self, 
        initial_condition: str, 
        answers: List[Dict[str, Any]], 
        rag_context: List[str], 
        doctor_type: str
    ) -> Dict[str, Any]:
        try:
            # Format answers
            formatted_answers = []
            for i, answer in enumerate(answers):
                answer_text = answer.get('selected_option') or answer.get('custom_answer', '')
                formatted_answers.append(f"Q{i+1}: {answer_text}")
            
            answers_text = "\n".join(formatted_answers)
            context_text = "\n\n".join(rag_context[:3])  # Limit context length
            
            prompt = f"""
            Generate a concise medical summary for a {doctor_type} based on the patient's information.

            IMPORTANT: Do NOT use asterisks (*), markdown formatting, or any special characters in your response. Use plain text only.

            Initial Condition: {initial_condition}
            
            Patient Responses:
            {answers_text}
            
            Relevant Medical Context:
            {context_text}
            
            Create a professional summary that includes:
            1. Chief complaint and symptoms
            2. Duration and severity
            3. Relevant patient history from responses
            4. Recommended next steps for the {doctor_type}
            
            Keep it concise but comprehensive, suitable for a medical professional.
            Return as plain text only, without any formatting, asterisks, or special characters.
            """
            
            response = llm.invoke(prompt)
            
            return {
                "summary": response.content
            }
            
        except Exception as e:
            logger.error(f"Error generating summary: {str(e)}")
            return {
                "summary": f"Patient presents with {initial_condition}. Requires evaluation by {doctor_type}."
            }

# Initialize tools
question_generation_tool = QuestionGenerationTool()
doctor_identification_tool = DoctorIdentificationTool()
rag_query_tool = RAGQueryTool()
summarization_tool = SummarizationTool()

# Export tools list
AGENT_TOOLS = [
    question_generation_tool,
    doctor_identification_tool,
    rag_query_tool,
    summarization_tool
]
