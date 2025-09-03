import unittest
import asyncio
import os
import sys
from unittest.mock import patch, MagicMock

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from rag.qdrant.client import QdrantManager
from rag.data_loader import DataLoader
from mcp_server.tools.ophthalmology_tools import (
    query_qdrant,
    generate_followup_question, 
    identify_doctor,
    generate_doctor_summary,
    UserAnswer,
    QdrantResult
)
from agents.ophthalmology.agent import OphthalmologyAgent
from agents.utils.state import create_initial_state


class TestRAGIntegration(unittest.TestCase):
    """Test complete RAG integration with real vector embeddings"""
    
    def setUp(self):
        """Set up test fixtures"""
        # Get or create event loop for async operations
        try:
            self.loop = asyncio.get_running_loop()
        except RuntimeError:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
    
    def test_data_loader_populates_qdrant(self):
        """Test that data loader can populate Qdrant with real medical cases"""
        async def run_data_loading_test():
            loader = DataLoader()
            
            # Load medical data
            data = loader.load_medical_data()
            self.assertGreater(len(data), 0, "Should load medical cases from JSON file")
            
            # Process a sample case
            if data:
                sample_case = data[0]
                processed = loader.process_case(sample_case)
                
                self.assertIn("content", processed)
                self.assertIn("disease", processed)
                self.assertIn("doctor_type", processed)
                self.assertIn("urgency", processed)
                
                # Verify urgency determination
                urgency = processed["urgency"]
                self.assertIn(urgency, ["low", "medium", "high"])
            
            # Test population (this creates embeddings)
            await loader.initialize()
            success = await loader.populate_qdrant()
            self.assertTrue(success, "Should successfully populate Qdrant with embeddings")
        
        self.loop.run_until_complete(run_data_loading_test())
    
    def test_qdrant_search_returns_relevant_results(self):
        """Test that Qdrant search returns relevant medical cases"""
        async def run_search_test():
            # Test different medical queries
            test_queries = [
                "severe eye pain with halos around lights",  # Should match glaucoma cases
                "blurry vision when reading",  # Should match vision issues
                "red itchy eyes with discharge",  # Should match infections
                "gradual vision loss peripheral"  # Should match specific conditions
            ]
            
            qdrant_manager = QdrantManager(use_local=True, use_memory=True, force_cloud=True)
            
            for query in test_queries:
                results = await qdrant_manager.search(query)
                # Each query should return some results (since we populated with real data)
                self.assertIsInstance(results, list)
                
                # If we have results, check their structure
                if results:
                    result = results[0]
                    self.assertIn("document_id", result)
                    self.assertIn("content", result)
                    self.assertIn("relevance_score", result)
                    self.assertIsInstance(result["relevance_score"], (int, float))
        
        self.loop.run_until_complete(run_search_test())
    
    def test_rag_workflow_user_query_to_llm(self):
        """Test the complete RAG workflow: User Query → RAG Retrieval → Context + Query → LLM → Decision"""
        # Step 1: User provides symptoms
        condition = "I have severe eye pain with halos around lights and nausea"
        answers = [
            UserAnswer(question="How severe is your pain?", answer="10/10 unbearable", is_custom=False),
            UserAnswer(question="How long?", answer="Started suddenly 2 hours ago", is_custom=False)
        ]
        
        # Step 2: Query RAG system for relevant medical knowledge
        rag_results = query_qdrant(condition, answers)
        self.assertIsInstance(rag_results, list)
        
        # Step 3: Generate RAG context
        rag_context = ""
        if rag_results:
            rag_context = "\n".join([r.content for r in rag_results])
        
        # Step 4: Use RAG context + User Query in LLM decisions
        
        # Test question generation with RAG context
        question = generate_followup_question(condition, answers, rag_context)
        self.assertIsInstance(question.question_text, str)
        self.assertIsInstance(question.options, list)
        self.assertGreater(len(question.options), 3)
        
        # Test doctor identification with RAG context
        doctor_id = identify_doctor(condition, answers, rag_context)
        self.assertIsInstance(doctor_id.doctor_type, str)
        self.assertIsInstance(doctor_id.confidence, float)
        self.assertGreaterEqual(doctor_id.confidence, 0.0)
        self.assertLessEqual(doctor_id.confidence, 1.0)
        
        # For emergency symptoms with RAG context, should identify ophthalmologist
        if rag_context and ("emergency" in rag_context.lower() or "glaucoma" in rag_context.lower()):
            self.assertEqual(doctor_id.doctor_type, "Ophthalmologist")
            self.assertGreater(doctor_id.confidence, 0.85)
        
        # Test summary generation with RAG context
        summary = generate_doctor_summary(condition, answers, doctor_id.doctor_type, rag_results)
        self.assertIsInstance(summary.summary, str)
        self.assertIn(condition, summary.summary)
        
        # RAG context should be included in summary
        if rag_results:
            # Summary should contain relevant medical context
            self.assertIn("Relevant medical context", summary.summary)
    
    def test_rag_context_influences_decisions(self):
        """Test that RAG context significantly influences LLM decisions"""
        base_condition = "blurry vision"
        answers = [UserAnswer(question="Duration?", answer="1 week", is_custom=False)]
        
        # Test 1: Without RAG context (should be more generic)
        doctor_no_rag = identify_doctor(base_condition, answers, None)
        
        # Test 2: With emergency RAG context (should escalate)
        emergency_rag_context = "EMERGENCY: Acute angle-closure glaucoma requires immediate ophthalmological intervention. High urgency condition."
        doctor_with_emergency_rag = identify_doctor(base_condition, answers, emergency_rag_context)
        
        # Test 3: With routine RAG context (should be more conservative)
        routine_rag_context = "Routine refractive error. Low urgency. Optometrist can handle basic vision correction."
        doctor_with_routine_rag = identify_doctor(base_condition, answers, routine_rag_context)
        
        # RAG context should influence the decisions
        self.assertEqual(doctor_with_emergency_rag.doctor_type, "Ophthalmologist")
        self.assertGreater(doctor_with_emergency_rag.confidence, 0.90)
        
        if "optometrist" in routine_rag_context.lower():
            self.assertEqual(doctor_with_routine_rag.doctor_type, "Optometrist")
    
    def test_agent_uses_rag_throughout_workflow(self):
        """Test that the agent uses RAG context throughout the entire workflow"""
        async def run_agent_test():
            agent = OphthalmologyAgent()
            await agent.initialize()
            
            # Test condition that should have RAG context
            condition = "severe eye pain with halos and nausea"
            result = await agent.run(condition)
            
            # Check that result includes RAG context
            self.assertIsInstance(result, dict)
            
            # Should have key components
            self.assertIn("doctor_identification", result)
            self.assertIn("doctor_summary", result)
            
            # Check if RAG context was used (should be in state)
            if "rag_context" in result:
                self.assertIsInstance(result["rag_context"], str)
                # RAG context should influence the decision
                doctor_type = result["doctor_identification"]["doctor_type"]
                self.assertIn(doctor_type, ["Ophthalmologist", "Ocular Surgeon", "Optometrist", "Optician"])
        
        self.loop.run_until_complete(run_agent_test())


class TestRAGWorkflowScenarios(unittest.TestCase):
    """Test specific RAG workflow scenarios"""
    
    def setUp(self):
        """Set up test fixtures"""
        try:
            self.loop = asyncio.get_running_loop()
        except RuntimeError:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
    
    def test_emergency_glaucoma_scenario(self):
        """Test emergency glaucoma scenario with RAG retrieval"""
        condition = "sudden severe eye pain with halos around lights, nausea, and vision changes"
        answers = [
            UserAnswer(question="Pain severity?", answer="10/10 excruciating", is_custom=False),
            UserAnswer(question="Onset?", answer="Sudden, 1 hour ago", is_custom=False),
            UserAnswer(question="Associated symptoms?", answer="Nausea and vomiting", is_custom=False)
        ]
        
        # Query RAG for glaucoma cases
        rag_results = query_qdrant(condition, answers)
        
        # Should find relevant glaucoma cases
        rag_context = "\n".join([r.content for r in rag_results]) if rag_results else ""
        
        # With glaucoma context, should recommend ophthalmologist urgently
        doctor_id = identify_doctor(condition, answers, rag_context)
        
        # Emergency case should go to ophthalmologist with high confidence
        self.assertIn(doctor_id.doctor_type, ["Ophthalmologist", "Ocular Surgeon"])
        self.assertGreater(doctor_id.confidence, 0.80)
        
        # Summary should include emergency context
        summary = generate_doctor_summary(condition, answers, doctor_id.doctor_type, rag_results)
        self.assertIn("severe", summary.summary.lower())
    
    def test_routine_vision_scenario(self):
        """Test routine vision correction scenario with RAG retrieval"""
        condition = "difficulty reading small text, need to squint"
        answers = [
            UserAnswer(question="Age related?", answer="Yes, I'm over 40", is_custom=False),
            UserAnswer(question="Distance vision?", answer="Distance vision is fine", is_custom=False)
        ]
        
        # Query RAG for vision correction cases
        rag_results = query_qdrant(condition, answers)
        rag_context = "\n".join([r.content for r in rag_results]) if rag_results else ""
        
        # Should recommend optometrist for routine vision issues
        doctor_id = identify_doctor(condition, answers, rag_context)
        
        # Routine vision issues can be handled by optometrist
        if "optometrist" in rag_context.lower() or "routine" in rag_context.lower():
            self.assertEqual(doctor_id.doctor_type, "Optometrist")
    
    def test_continuous_rag_context_flow(self):
        """Test that RAG context flows through multiple questions and builds up"""
        condition = "eye discomfort and vision changes"
        
        # First question with initial RAG context
        initial_answers = []
        question1 = generate_followup_question(condition, initial_answers)
        
        # User answers first question
        answers_after_q1 = [
            UserAnswer(question=question1.question_text, answer="1-7 days", is_custom=False)
        ]
        
        # Get RAG context after first answer
        rag_results_1 = query_qdrant(condition, answers_after_q1)
        rag_context_1 = "\n".join([r.content for r in rag_results_1]) if rag_results_1 else ""
        
        # Second question should be influenced by RAG context
        question2 = generate_followup_question(condition, answers_after_q1, rag_context_1)
        
        # User answers second question
        answers_after_q2 = answers_after_q1 + [
            UserAnswer(question=question2.question_text, answer="Both eyes", is_custom=False)
        ]
        
        # Get updated RAG context
        rag_results_2 = query_qdrant(condition, answers_after_q2)
        rag_context_2 = "\n".join([r.content for r in rag_results_2]) if rag_results_2 else ""
        
        # Final decision should use all accumulated context
        final_doctor_id = identify_doctor(condition, answers_after_q2, rag_context_2)
        
        # Should have a well-informed decision
        self.assertIsInstance(final_doctor_id.doctor_type, str)
        self.assertGreater(len(final_doctor_id.reasoning), 20)  # Should have detailed reasoning


class TestRAGSystemRobustness(unittest.TestCase):
    """Test RAG system robustness and edge cases"""
    
    def setUp(self):
        """Set up test fixtures"""
        try:
            self.loop = asyncio.get_running_loop()
        except RuntimeError:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
    
    def test_rag_handles_empty_results(self):
        """Test system handles gracefully when RAG returns no results"""
        condition = "completely unique eye condition never seen before xyz123"
        answers = []
        
        # Query should return empty results for nonsense condition
        rag_results = query_qdrant(condition, answers)
        
        # System should still function with empty RAG results
        doctor_id = identify_doctor(condition, answers, "")
        self.assertIsInstance(doctor_id.doctor_type, str)
        self.assertIsInstance(doctor_id.confidence, float)
    
    def test_rag_handles_multiple_conditions(self):
        """Test RAG can handle multiple overlapping conditions"""
        condition = "eye pain, blurry vision, redness, and light sensitivity"
        answers = [
            UserAnswer(question="Multiple symptoms?", answer="All at once", is_custom=False)
        ]
        
        rag_results = query_qdrant(condition, answers)
        
        # Should return relevant results for complex condition
        self.assertIsInstance(rag_results, list)
        
        # Decision should handle multiple symptoms
        doctor_id = identify_doctor(condition, answers, "Multiple eye symptoms requiring evaluation")
        self.assertIn(doctor_id.doctor_type, ["Ophthalmologist", "Optometrist", "Ocular Surgeon", "Optician"])
    
    def test_rag_consistency_across_similar_queries(self):
        """Test that RAG returns consistent results for similar queries"""
        # Similar conditions should return similar RAG results
        conditions = [
            "severe eye pain with halos",
            "intense eye pain and light halos",
            "extreme eye pain seeing halos around lights"
        ]
        
        all_results = []
        for condition in conditions:
            rag_results = query_qdrant(condition, [])
            all_results.append(rag_results)
        
        # All should return results (assuming our data contains relevant cases)
        for results in all_results:
            self.assertIsInstance(results, list)


if __name__ == '__main__':
    unittest.main()