import os
import asyncio
from typing import Dict, List, Any, Tuple, Annotated, TypedDict, cast

from langchain_openai import ChatOpenAI
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from dotenv import load_dotenv

from agents.utils.state import OphthalmologyState, create_initial_state

load_dotenv()

class OphthalmologyAgent:
    def __init__(self):
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.groq_base_url = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
        self.groq_model = os.getenv("GROQ_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")
        self.confidence_threshold = float(os.getenv("CONFIDENCE_THRESHOLD", "0.85"))
        self.max_questions = int(os.getenv("MAX_ITERATIONS", "5"))

        if not self.groq_api_key:
            raise ValueError("GROQ_API_KEY is not configured")
        
        self.llm = ChatOpenAI(
            model=self.groq_model,
            api_key=self.groq_api_key,
            base_url=self.groq_base_url,
            temperature=0.2,
        )
        
        self.mcp_client = None
        self.tools = None
        self.llm_with_tools = None
        
        self.graph = None
    
    async def initialize(self):

        try:
            from mcp_server.tools.ophthalmology_tools import (
                generate_followup_question,
                identify_doctor,
                query_qdrant,
                generate_doctor_summary
            )
            
            self.direct_tools = {
                'generate_question': generate_followup_question,
                'identify_doctor': identify_doctor,
                'query_qdrant': query_qdrant,
                'generate_summary': generate_doctor_summary
            }
            
            self.graph = self._create_graph(None)
        except Exception as e:
            print(f"Warning: Failed to initialize tools: {e}")
            print("The agent will continue with limited functionality.")
            self.direct_tools = {}
            self.graph = self._create_graph(None)
    
    def _create_graph(self, tool_node):
        builder = StateGraph(OphthalmologyState)
        
        builder.add_node("generate_question", self._generate_question)
        builder.add_node("process_answer", self._process_answer)
        builder.add_node("identify_doctor", self._identify_doctor)
        builder.add_node("query_qdrant", self._query_qdrant)
        builder.add_node("generate_summary", self._generate_summary)
        
        builder.add_edge("generate_question", "process_answer")
        
        builder.add_conditional_edges(
            "process_answer",
            self._should_ask_more_questions,
            {
                "ask_more": "generate_question",
                "identify_doctor": "identify_doctor"
            }
        )
        
        builder.add_edge("identify_doctor", "query_qdrant")
        builder.add_edge("query_qdrant", "generate_summary")
        builder.add_edge("generate_summary", END)
        
        builder.set_entry_point("generate_question")
        
        return builder.compile()
    
    async def _generate_question(self, state: OphthalmologyState) -> OphthalmologyState:
        condition = state["condition"]
        previous_answers = state.get("answers", [])
        
        rag_context = await self._get_rag_context(condition, previous_answers)
        
        if 'generate_question' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            user_answers = None
            if previous_answers:
                user_answers = [UserAnswer(**answer) for answer in previous_answers]
            
            question = self.direct_tools['generate_question'](condition, user_answers, rag_context)
            
            new_state = state.copy()
            new_state["current_question"] = {
                "question_text": question.question_text,
                "options": question.options
            }
            new_state["question_count"] = new_state.get("question_count", 0) + 1
            new_state["rag_context"] = rag_context  # 
            
            return new_state
        else:
            rag_context = await self._get_rag_context(condition, previous_answers)
            
            if not previous_answers:
                question = {
                    "question_text": "How long have you been experiencing this eye condition?",
                    "options": ["Less than 24 hours", "1-7 days", "1-4 weeks", "More than a month", "Other"]
                }
            else:
                question = {
                    "question_text": "Is your vision affected in one eye or both eyes?",
                    "options": ["Left eye only", "Right eye only", "Both eyes", "Vision is not affected", "Other"]
                }
            
            new_state = state.copy()
            new_state["current_question"] = question
            new_state["question_count"] = new_state.get("question_count", 0) + 1
            new_state["rag_context"] = rag_context  
            
            return new_state
    
    async def _get_rag_context(self, condition: str, answers: List[Dict[str, Any]]) -> str:
        try:
            if 'query_qdrant' in self.direct_tools:
                from mcp_server.tools.ophthalmology_tools import UserAnswer
                
                user_answers = [UserAnswer(**answer) for answer in answers]
                
                rag_results = self.direct_tools['query_qdrant'](condition, user_answers)
                
                if rag_results:
                    context_parts = []
                    for result in rag_results:
                        context_parts.append(f"Medical Knowledge: {result.content}")
                    return "\n".join(context_parts)
                else:
                    return "No specific medical context found."
            else:
                return "RAG system not available."
        except Exception as e:
            print(f"Error getting RAG context: {e}")
            return "Error retrieving medical context."
    
    async def _process_answer(self, state: OphthalmologyState) -> OphthalmologyState:
        if "current_answer" in state and state["current_answer"]:
            state["answers"] = state.get("answers", []) + [state["current_answer"]]
            state["current_answer"] = None
        
        return state
    
    def _should_ask_more_questions(self, state: OphthalmologyState) -> str:
        if state.get("question_count", 0) >= state.get("max_questions", self.max_questions):
            return "identify_doctor"
        
        if state.get("doctor_confidence", 0) >= state.get("confidence_threshold", self.confidence_threshold):
            return "identify_doctor"
        
        return "ask_more"
    
    async def _identify_doctor(self, state: OphthalmologyState) -> OphthalmologyState:
        condition = state["condition"]
        answers = state.get("answers", [])
        rag_context = state.get("rag_context", "")
        
        if 'identify_doctor' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            doctor_id = self.direct_tools['identify_doctor'](condition, user_answers, rag_context)
            
            new_state = state.copy()
            new_state["doctor_identification"] = {
                "doctor_type": doctor_id.doctor_type,
                "confidence": doctor_id.confidence,
                "reasoning": doctor_id.reasoning
            }
            
            return new_state
        else:
            rag_context = state.get("rag_context", "")
            combined_text = condition.lower() + " " + " ".join([a['answer'].lower() for a in answers])
            
            if rag_context:
                if "emergency" in rag_context.lower() or "immediate" in rag_context.lower():
                    doctor_type = "Ophthalmologist"
                    confidence = 0.90
                    reasoning = "Based on medical context, this condition requires immediate ophthalmological attention."
                elif "surgery" in rag_context.lower() or "surgical" in rag_context.lower():
                    doctor_type = "Ocular Surgeon"
                    confidence = 0.85
                    reasoning = "Medical context suggests surgical intervention may be needed."
                elif "optometrist" in rag_context.lower() and "routine" in rag_context.lower():
                    doctor_type = "Optometrist"
                    confidence = 0.80
                    reasoning = "Based on medical context, this appears to be a routine vision issue."
                else:
                    doctor_type = "Ophthalmologist"
                    confidence = 0.75
                    reasoning = "Medical context suggests specialized ophthalmological evaluation needed."
            else:
                if any(term in combined_text for term in ["surgery", "trauma", "severe pain"]):
                    doctor_type = "Ocular Surgeon"
                    confidence = 0.70
                    reasoning = "Symptoms suggest surgical intervention may be needed."
                elif any(term in combined_text for term in ["blurry", "vision", "glasses"]):
                    doctor_type = "Optometrist"
                    confidence = 0.75
                    reasoning = "Symptoms suggest vision correction issues."
                else:
                    doctor_type = "Ophthalmologist"
                    confidence = 0.65
                    reasoning = "General eye condition requiring medical evaluation."
            
            new_state = state.copy()
            new_state["doctor_identification"] = {
                "doctor_type": doctor_type,
                "confidence": confidence,
                "reasoning": reasoning
            }
            
            return new_state
    
    async def _query_qdrant(self, state: OphthalmologyState) -> OphthalmologyState:
        condition = state["condition"]
        answers = state.get("answers", [])
        doctor_id = state.get("doctor_identification", {})
        if 'query_qdrant' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            qdrant_results = self.direct_tools['query_qdrant'](condition, user_answers)
            
            new_state = state.copy()
            new_state["qdrant_results"] = [
                {
                    "document_id": result.document_id,
                    "content": result.content,
                    "relevance_score": result.relevance_score
                }
                for result in qdrant_results
            ]
            
            return new_state
        else:
            new_state = state.copy()
            new_state["qdrant_results"] = []
            new_state["error"] = "RAG system not available"
            
            return new_state
    
    def _should_generate_summary(self, state: OphthalmologyState) -> str:
        if "doctor_identification" in state and state["doctor_identification"]:
            return "generate_summary"
        
        return "end"
    
    async def _generate_summary(self, state: OphthalmologyState) -> OphthalmologyState:
        condition = state["condition"]
        answers = state.get("answers", [])
        doctor_id = state.get("doctor_identification", {})
        qdrant_results = state.get("qdrant_results", [])
        
        if 'generate_summary' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer, QdrantResult
            
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            qdrant_objects = [QdrantResult(**result) for result in qdrant_results]
            
            doctor_type = doctor_id.get("doctor_type", "Ophthalmologist")
            summary = self.direct_tools['generate_summary'](condition, user_answers, doctor_type, qdrant_objects)
            
            new_state = state.copy()
            new_state["doctor_summary"] = {
                "doctor_type": summary.doctor_type,
                "summary": summary.summary,
                "confidence": summary.confidence,
                "key_symptoms": summary.key_symptoms,
                "recommended_tests": summary.recommended_tests
            }
            
            return new_state
        else:
            doctor_type = doctor_id.get("doctor_type", "Ophthalmologist")
            rag_context = state.get("rag_context", "")
            
            summary_text = f"Patient presents with {condition}. "
            
            if answers:
                summary_text += "Patient responses: "
                for answer in answers:
                    summary_text += f"{answer['question']} - {answer['answer']}. "
            
            if rag_context:
                summary_text += f"\n\nRelevant medical context: {rag_context[:500]}..."
            
            key_symptoms = ["General eye discomfort"]
            if "pain" in condition.lower():
                key_symptoms.append("Eye pain")
            if "vision" in condition.lower() or "blurry" in condition.lower():
                key_symptoms.append("Vision changes")
            if "redness" in condition.lower():
                key_symptoms.append("Eye redness")
            
            new_state = state.copy()
            new_state["doctor_summary"] = {
                "doctor_type": doctor_type,
                "summary": summary_text,
                "confidence": 0.80,
                "key_symptoms": key_symptoms,
                "recommended_tests": ["Comprehensive eye exam"]
            }
            
            return new_state
    
    async def run(self, condition: str) -> Dict[str, Any]:
        try:
            initial_state = create_initial_state(condition)
            
            initial_state["max_questions"] = self.max_questions
            initial_state["confidence_threshold"] = self.confidence_threshold
            
            if not self.graph:
                await self.initialize()
            
            state_copy = dict(initial_state)
            
            result = await self.graph.ainvoke(state_copy)
            return result
        except Exception as e:
            print(f"Error running agent: {e}")
            import traceback
            traceback.print_exc()
            return {
                "error": str(e),
                "condition": condition,
                "answers": [],
                "doctor_identification": None,
                "doctor_summary": None
            }
