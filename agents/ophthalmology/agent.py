import os
import asyncio
from typing import Dict, List, Any, Tuple, Annotated, TypedDict, cast

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from dotenv import load_dotenv

# Import our state management
from agents.utils.state import OphthalmologyState, create_initial_state

# Load environment variables
load_dotenv()

class OphthalmologyAgent:
    """LangGraph agent for ophthalmology assistant using ReAct pattern"""
    
    def __init__(self):
        # Load configuration from environment variables
        self.gemini_api_key = os.getenv("GEMINI_API_KEY")
        self.gemini_model = os.getenv("GEMINI_REASONING_MODEL", "gemini-2.0-flash")
        self.confidence_threshold = float(os.getenv("CONFIDENCE_THRESHOLD", "0.85"))
        self.max_questions = int(os.getenv("MAX_ITERATIONS", "5"))
        
        # Initialize the LLM
        self.llm = ChatGoogleGenerativeAI(
            model=self.gemini_model,
            google_api_key=self.gemini_api_key,
            temperature=0.2,
            convert_system_message_to_human=True
        )
        
        # Initialize the MCP client
        self.mcp_client = None
        self.tools = None
        self.llm_with_tools = None
        
        # Initialize the graph
        self.graph = None
    
    async def initialize(self):
        """Initialize the MCP client and tools"""
        try:
            # Initialize the MCP client for stdio transport (local MCP server)
            # Note: The MCP server is running as a stdio server, not HTTP
            # For testing, we'll use direct tool imports instead
            from mcp_server.tools.ophthalmology_tools import (
                generate_followup_question,
                identify_doctor,
                query_qdrant,
                generate_doctor_summary
            )
            
            # Store direct tool references
            self.direct_tools = {
                'generate_question': generate_followup_question,
                'identify_doctor': identify_doctor,
                'query_qdrant': query_qdrant,
                'generate_summary': generate_doctor_summary
            }
            
            # Create the tool node
            self.graph = self._create_graph(None)
        except Exception as e:
            print(f"Warning: Failed to initialize tools: {e}")
            print("The agent will continue with limited functionality.")
            # Set up minimal functionality without tools
            self.direct_tools = {}
            self.graph = self._create_graph(None)
    
    def _create_graph(self, tool_node):
        """Create the LangGraph for the ophthalmology assistant"""
        # Create the graph builder
        builder = StateGraph(OphthalmologyState)
        
        # Add the nodes
        builder.add_node("generate_question", self._generate_question)
        builder.add_node("process_answer", self._process_answer)
        builder.add_node("identify_doctor", self._identify_doctor)
        builder.add_node("query_qdrant", self._query_qdrant)
        builder.add_node("generate_summary", self._generate_summary)
        
        # Direct connections without tool nodes to avoid state conflicts
        builder.add_edge("generate_question", "process_answer")
        
        # Add conditional edges
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
        
        # Set the entry point
        builder.set_entry_point("generate_question")
        
        # Compile the graph
        return builder.compile()
    
    async def _generate_question(self, state: OphthalmologyState) -> OphthalmologyState:
        """Generate a follow-up question based on the current state with RAG context"""
        # Get the condition and previous answers
        condition = state["condition"]
        previous_answers = state.get("answers", [])
        
        # First, get RAG context for this condition
        rag_context = await self._get_rag_context(condition, previous_answers)
        
        # Use direct tool if available
        if 'generate_question' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            # Convert previous answers to UserAnswer objects
            user_answers = None
            if previous_answers:
                user_answers = [UserAnswer(**answer) for answer in previous_answers]
            
            # Generate the question using the tool with RAG context
            question = self.direct_tools['generate_question'](condition, user_answers, rag_context)
            
            # Update the state with the new question
            new_state = state.copy()
            new_state["current_question"] = {
                "question_text": question.question_text,
                "options": question.options
            }
            new_state["question_count"] = new_state.get("question_count", 0) + 1
            new_state["rag_context"] = rag_context  # Store RAG context for later use
            
            return new_state
        else:
            # Without tools, generate basic questions that still require RAG context
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
            
            # Update the state
            new_state = state.copy()
            new_state["current_question"] = question
            new_state["question_count"] = new_state.get("question_count", 0) + 1
            new_state["rag_context"] = rag_context  # Always include RAG context
            
            return new_state
    
    async def _get_rag_context(self, condition: str, answers: List[Dict[str, Any]]) -> str:
        """Get relevant context from RAG system"""
        try:
            if 'query_qdrant' in self.direct_tools:
                from mcp_server.tools.ophthalmology_tools import UserAnswer
                
                # Convert answers to UserAnswer objects
                user_answers = [UserAnswer(**answer) for answer in answers]
                
                # Query RAG system
                rag_results = self.direct_tools['query_qdrant'](condition, user_answers)
                
                # Combine RAG results into context string
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
        """Process the user's answer to the current question"""
        # Add the answer to the list of answers
        if "current_answer" in state and state["current_answer"]:
            state["answers"] = state.get("answers", []) + [state["current_answer"]]
            state["current_answer"] = None
        
        return state
    
    def _should_ask_more_questions(self, state: OphthalmologyState) -> str:
        """Determine if we should ask more questions or identify the doctor"""
        # Check if we've reached the maximum number of questions
        if state.get("question_count", 0) >= state.get("max_questions", self.max_questions):
            return "identify_doctor"
        
        # Check if we have enough confidence to identify the doctor
        if state.get("doctor_confidence", 0) >= state.get("confidence_threshold", self.confidence_threshold):
            return "identify_doctor"
        
        # Otherwise, ask more questions
        return "ask_more"
    
    async def _identify_doctor(self, state: OphthalmologyState) -> OphthalmologyState:
        """Identify the most appropriate doctor based on the condition, answers, and RAG context"""
        # Get the condition and answers
        condition = state["condition"]
        answers = state.get("answers", [])
        rag_context = state.get("rag_context", "")
        
        # Use direct tool if available
        if 'identify_doctor' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            # Convert answers to UserAnswer objects
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            # Identify the doctor using the tool with RAG context
            doctor_id = self.direct_tools['identify_doctor'](condition, user_answers, rag_context)
            
            # Update the state with the doctor identification
            new_state = state.copy()
            new_state["doctor_identification"] = {
                "doctor_type": doctor_id.doctor_type,
                "confidence": doctor_id.confidence,
                "reasoning": doctor_id.reasoning
            }
            
            return new_state
        else:
            # Without tools, still try to use RAG context for reasoning
            rag_context = state.get("rag_context", "")
            combined_text = condition.lower() + " " + " ".join([a['answer'].lower() for a in answers])
            
            # Use RAG context if available for better decisions
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
                # Last resort - basic rule-based approach
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
            
            # Update the state
            new_state = state.copy()
            new_state["doctor_identification"] = {
                "doctor_type": doctor_type,
                "confidence": confidence,
                "reasoning": reasoning
            }
            
            return new_state
    
    async def _query_qdrant(self, state: OphthalmologyState) -> OphthalmologyState:
        """Query the Qdrant vector store for relevant medical information"""
        # Get the condition, answers, and doctor identification
        condition = state["condition"]
        answers = state.get("answers", [])
        doctor_id = state.get("doctor_identification", {})
        
        # Use direct tool if available
        if 'query_qdrant' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer
            
            # Convert answers to UserAnswer objects
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            # Query Qdrant using the tool
            qdrant_results = self.direct_tools['query_qdrant'](condition, user_answers)
            
            # Update the state with the Qdrant results
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
            # Return empty state if tools not available
            new_state = state.copy()
            new_state["qdrant_results"] = []
            new_state["error"] = "RAG system not available"
            
            return new_state
    
    def _should_generate_summary(self, state: OphthalmologyState) -> str:
        """Determine if we should generate the summary or end the conversation"""
        # Check if we have the necessary information to generate a summary
        if "doctor_identification" in state and state["doctor_identification"]:
            return "generate_summary"
        
        # Otherwise, end the conversation
        return "end"
    
    async def _generate_summary(self, state: OphthalmologyState) -> OphthalmologyState:
        """Generate a comprehensive summary for the doctor"""
        # Get the necessary information
        condition = state["condition"]
        answers = state.get("answers", [])
        doctor_id = state.get("doctor_identification", {})
        qdrant_results = state.get("qdrant_results", [])
        
        # Use direct tool if available
        if 'generate_summary' in self.direct_tools:
            from mcp_server.tools.ophthalmology_tools import UserAnswer, QdrantResult
            
            # Convert answers to UserAnswer objects
            user_answers = [UserAnswer(**answer) for answer in answers]
            
            # Convert qdrant_results to QdrantResult objects
            qdrant_objects = [QdrantResult(**result) for result in qdrant_results]
            
            # Generate the summary using the tool
            doctor_type = doctor_id.get("doctor_type", "Ophthalmologist")
            summary = self.direct_tools['generate_summary'](condition, user_answers, doctor_type, qdrant_objects)
            
            # Update the state with the doctor summary
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
            # Generate summary using RAG context when available
            doctor_type = doctor_id.get("doctor_type", "Ophthalmologist")
            rag_context = state.get("rag_context", "")
            
            summary_text = f"Patient presents with {condition}. "
            
            if answers:
                summary_text += "Patient responses: "
                for answer in answers:
                    summary_text += f"{answer['question']} - {answer['answer']}. "
            
            # Include RAG context in summary
            if rag_context:
                summary_text += f"\n\nRelevant medical context: {rag_context[:500]}..."
            
            key_symptoms = ["General eye discomfort"]
            if "pain" in condition.lower():
                key_symptoms.append("Eye pain")
            if "vision" in condition.lower() or "blurry" in condition.lower():
                key_symptoms.append("Vision changes")
            if "redness" in condition.lower():
                key_symptoms.append("Eye redness")
            
            # Update the state
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
        """Run the ophthalmology assistant agent"""
        try:
            # Create the initial state
            initial_state = create_initial_state(condition)
            
            # Set the configuration from environment variables
            initial_state["max_questions"] = self.max_questions
            initial_state["confidence_threshold"] = self.confidence_threshold
            
            # Make sure the graph is initialized
            if not self.graph:
                await self.initialize()
            
            # Create a copy of the initial state to avoid concurrent updates
            state_copy = dict(initial_state)
            
            # Run the graph with the copied state
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