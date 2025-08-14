from typing import Dict, List, Any, Optional
from langgraph.graph import StateGraph, END
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.schema import HumanMessage, AIMessage
import logging
import asyncio

from src.core.config import config
from src.models.models import AgentState, FollowUpQuestion, QuestionOption, DoctorRecommendation, UserAnswer
from src.tools.agent_tools import AGENT_TOOLS, question_generation_tool, doctor_identification_tool, rag_query_tool, summarization_tool

logger = logging.getLogger(__name__)

# Try to import BindWithLLM with fallback
try:
    from langchain.agents import BindWithLLM
    BIND_WITH_LLM_AVAILABLE = True
except ImportError:
    BIND_WITH_LLM_AVAILABLE = False
    logger.warning("BindWithLLM not available, falling back to direct tool usage")

class OphthalmologyAgent:
    def __init__(self):
        self.llm = ChatGoogleGenerativeAI(
            model=config.GEMINI_REASONING_MODEL,
            google_api_key=config.GEMINI_API_KEY,
            temperature=0.3
        )
        
        # Direct access to tools for autonomous decision making
        self.tools = AGENT_TOOLS
        
        # Try to initialize BindWithLLM if available
        self.llm_with_tools = None
        if BIND_WITH_LLM_AVAILABLE:
            try:
                self.llm_with_tools = BindWithLLM(llm=self.llm, tools=self.tools)
                logger.info("BindWithLLM initialized successfully")
            except Exception as e:
                logger.warning(f"Failed to initialize BindWithLLM: {e}")
                self.llm_with_tools = None
        
        self.graph = self._create_graph()
    
    def _create_graph(self) -> StateGraph:
        """Create the LangGraph state graph for agent orchestration"""
        
        # Define the state graph
        workflow = StateGraph(AgentState)
        
        # Add nodes for different steps
        workflow.add_node("generate_questions", self._generate_questions_node)
        workflow.add_node("process_answers", self._process_answers_node)
        workflow.add_node("query_rag", self._query_rag_node)
        workflow.add_node("identify_doctor", self._identify_doctor_node)
        workflow.add_node("generate_summary", self._generate_summary_node)
        
        # Define the flow
        workflow.set_entry_point("generate_questions")
        
        workflow.add_edge("generate_questions", "process_answers")
        workflow.add_edge("process_answers", "query_rag")
        workflow.add_edge("query_rag", "identify_doctor")
        workflow.add_edge("identify_doctor", "generate_summary")
        workflow.add_edge("generate_summary", END)
        
        return workflow.compile()
    
    async def _generate_questions_node(self, state: AgentState) -> AgentState:
        """Generate follow-up questions based on initial condition"""
        try:
            logger.info(f"Generating questions for condition: {state.initial_condition}")
            
            # Use the question generation tool
            result = question_generation_tool._run(state.initial_condition)
            
            # Convert to FollowUpQuestion objects
            questions = []
            for q_data in result.get("questions", []):
                options = [
                    QuestionOption(text=opt["text"], is_other=opt["is_other"])
                    for opt in q_data.get("options", [])
                ]
                question = FollowUpQuestion(
                    question=q_data["question"],
                    options=options
                )
                questions.append(question)
            
            state.questions = questions
            state.current_step = "questions_generated"
            
            logger.info(f"Generated {len(questions)} questions")
            return state
            
        except Exception as e:
            logger.error(f"Error in generate_questions_node: {str(e)}")
            # Provide fallback questions (4 questions)
            state.questions = [
                FollowUpQuestion(
                    question="How long have you been experiencing these symptoms?",
                    options=[
                        QuestionOption(text="Less than a week", is_other=False),
                        QuestionOption(text="1-4 weeks", is_other=False),
                        QuestionOption(text="More than a month", is_other=False),
                        QuestionOption(text="Other", is_other=True)
                    ]
                ),
                FollowUpQuestion(
                    question="How would you describe the severity of your symptoms?",
                    options=[
                        QuestionOption(text="Mild - doesn't interfere with daily activities", is_other=False),
                        QuestionOption(text="Moderate - sometimes affects daily activities", is_other=False),
                        QuestionOption(text="Severe - significantly impacts daily life", is_other=False),
                        QuestionOption(text="Other", is_other=True)
                    ]
                ),
                FollowUpQuestion(
                    question="Are you experiencing any pain or discomfort?",
                    options=[
                        QuestionOption(text="No pain", is_other=False),
                        QuestionOption(text="Mild discomfort", is_other=False),
                        QuestionOption(text="Significant pain", is_other=False),
                        QuestionOption(text="Other", is_other=True)
                    ]
                ),
                FollowUpQuestion(
                    question="Have you had any previous eye problems or treatments?",
                    options=[
                        QuestionOption(text="No previous eye problems", is_other=False),
                        QuestionOption(text="Minor issues (glasses, contacts)", is_other=False),
                        QuestionOption(text="Previous eye surgery or treatment", is_other=False),
                        QuestionOption(text="Other", is_other=True)
                    ]
                )
            ]
            state.current_step = "questions_generated"
            return state
    
    async def _process_answers_node(self, state: AgentState) -> AgentState:
        """Process user answers (this is handled externally in the API)"""
        # This node is primarily for state tracking
        state.current_step = "answers_processed"
        logger.info(f"Processing {len(state.answers)} user answers")
        return state
    
    async def _query_rag_node(self, state: AgentState) -> AgentState:
        """Query RAG knowledge base for relevant context"""
        try:
            logger.info("Querying RAG knowledge base")
            
            # Combine condition and answers for context search
            condition_and_answers = f"Initial condition: {state.initial_condition}\n"
            for i, answer in enumerate(state.answers):
                answer_text = answer.selected_option or answer.custom_answer or ""
                condition_and_answers += f"Answer {i+1}: {answer_text}\n"
            
            # Use the RAG query tool
            result = rag_query_tool._run(condition_and_answers)
            
            state.rag_context = result.get("retrieved_context", [])
            state.current_step = "rag_queried"
            
            logger.info(f"Retrieved {len(state.rag_context)} context documents")
            return state
            
        except Exception as e:
            logger.error(f"Error in query_rag_node: {str(e)}")
            state.rag_context = []
            state.current_step = "rag_queried"
            return state
    
    async def _identify_doctor_node(self, state: AgentState) -> AgentState:
        """Identify the most appropriate doctor type"""
        try:
            logger.info("Identifying appropriate doctor type")
            
            # Convert answers to dict format for the tool
            answers_dict = []
            for answer in state.answers:
                answers_dict.append({
                    "selected_option": answer.selected_option,
                    "custom_answer": answer.custom_answer
                })
            
            # Use the doctor identification tool
            result = doctor_identification_tool._run(state.initial_condition, answers_dict)
            
            state.doctor_recommendation = DoctorRecommendation(
                doctor_type=result.get("doctor_type", "Ophthalmologist"),
                reasoning=result.get("reasoning", "General eye specialist for comprehensive evaluation")
            )
            state.current_step = "doctor_identified"
            
            logger.info(f"Recommended doctor: {state.doctor_recommendation.doctor_type}")
            return state
            
        except Exception as e:
            logger.error(f"Error in identify_doctor_node: {str(e)}")
            state.doctor_recommendation = DoctorRecommendation(
                doctor_type="Ophthalmologist",
                reasoning="General eye specialist for comprehensive evaluation"
            )
            state.current_step = "doctor_identified"
            return state
    
    async def _generate_summary_node(self, state: AgentState) -> AgentState:
        """Generate medical summary for the doctor"""
        try:
            logger.info("Generating medical summary")
            
            # Convert answers to dict format for the tool
            answers_dict = []
            for answer in state.answers:
                answers_dict.append({
                    "selected_option": answer.selected_option,
                    "custom_answer": answer.custom_answer
                })
            
            # Use the summarization tool
            result = summarization_tool._run(
                initial_condition=state.initial_condition,
                answers=answers_dict,
                rag_context=state.rag_context,
                doctor_type=state.doctor_recommendation.doctor_type if state.doctor_recommendation else "Ophthalmologist"
            )
            
            state.summary = result.get("summary", "")
            state.current_step = "summary_generated"
            
            logger.info("Medical summary generated successfully")
            return state
            
        except Exception as e:
            logger.error(f"Error in generate_summary_node: {str(e)}")
            state.summary = f"Patient presents with {state.initial_condition}. Requires evaluation by eye specialist."
            state.current_step = "summary_generated"
            return state
    
    async def generate_questions(self, initial_condition: str) -> List[FollowUpQuestion]:
        """Generate follow-up questions for initial condition"""
        try:
            initial_state = AgentState(
                initial_condition=initial_condition,
                current_step="start"
            )
            
            # Run only the question generation part
            result_state = await self._generate_questions_node(initial_state)
            return result_state.questions
            
        except Exception as e:
            logger.error(f"Error generating questions: {str(e)}")
            raise
    
    async def process_complete_flow(
        self, 
        initial_condition: str, 
        answers: List[UserAnswer]
    ) -> AgentState:
        """Process the complete flow from answers to final recommendation"""
        try:
            initial_state = AgentState(
                initial_condition=initial_condition,
                answers=answers,
                current_step="start"
            )
            
            # Skip question generation since we already have answers
            state = initial_state
            state.current_step = "answers_processed"
            
            # Run through the remaining nodes
            state = await self._query_rag_node(state)
            state = await self._identify_doctor_node(state)
            state = await self._generate_summary_node(state)
            
            return state
            
        except Exception as e:
            logger.error(f"Error processing complete flow: {str(e)}")
            raise

# Global agent instance
ophthalmology_agent = OphthalmologyAgent()
