import asyncio
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from agents.ophthalmology.agent import OphthalmologyAgent
from agents.utils.state import OphthalmologyState, create_initial_state


class TestOphthalmologyAgent(unittest.TestCase):
    """Test cases for the OphthalmologyAgent class"""

    def setUp(self):
        """Set up test fixtures"""
        self.agent = OphthalmologyAgent()
        # Get or create event loop for async operations
        try:
            self.loop = asyncio.get_running_loop()
        except RuntimeError:
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
        # Initialize the agent to set up direct_tools
        self.loop.run_until_complete(self.agent.initialize())

    @patch('agents.ophthalmology.agent.OphthalmologyAgent.initialize')
    def test_initialization(self, mock_initialize):
        """Test agent initialization"""
        mock_initialize.return_value = asyncio.Future()
        mock_initialize.return_value.set_result(None)
        
        self.loop.run_until_complete(self.agent.initialize())
        mock_initialize.assert_called_once()

    def test_generate_question(self):
        """Test question generation"""
        # Create a test state
        state = create_initial_state("I have blurry vision")
        
        # Run the test
        result = self.loop.run_until_complete(self.agent._generate_question(state))
        
        # Assertions
        self.assertIn("current_question", result)
        self.assertIn("question_text", result["current_question"])
        self.assertIn("options", result["current_question"])
        self.assertTrue(len(result["current_question"]["options"]) >= 4)

    def test_process_answer(self):
        """Test answer processing"""
        # Create a test state with current_answer
        state = create_initial_state("I have blurry vision")
        state["current_answer"] = {
            "question": "How long have you been experiencing this eye condition?",
            "answer": "1-7 days",
            "is_custom": False
        }
        
        # Run the test
        result = self.loop.run_until_complete(self.agent._process_answer(state))
        
        # Assertions
        self.assertIn("answers", result)
        self.assertEqual(len(result["answers"]), 1)

    def test_identify_doctor(self):
        """Test doctor identification"""
        # Create a test state
        state = create_initial_state("I have blurry vision and eye pain")
        state["answers"] = [
            {
                "question": "How long have you been experiencing this eye condition?",
                "answer": "1-7 days",
                "is_custom": False
            },
            {
                "question": "Is your vision affected in one eye or both eyes?",
                "answer": "Both eyes",
                "is_custom": False
            }
        ]
        
        # Run the test
        result = self.loop.run_until_complete(self.agent._identify_doctor(state))
        
        # Assertions
        self.assertIn("doctor_identification", result)
        self.assertIn("doctor_type", result["doctor_identification"])
        self.assertIn("confidence", result["doctor_identification"])
        self.assertIn("reasoning", result["doctor_identification"])

    def test_query_qdrant(self):
        """Test Qdrant querying"""
        # Create a test state
        state = create_initial_state("I have blurry vision and eye pain")
        state["doctor_identification"] = {
            "doctor_type": "Ophthalmologist",
            "confidence": 0.85,
            "reasoning": "Based on the symptoms of blurry vision and eye pain, an ophthalmologist is recommended."
        }
        
        # Run the test
        result = self.loop.run_until_complete(self.agent._query_qdrant(state))
        
        # Assertions
        self.assertIn("qdrant_results", result)
        self.assertTrue(len(result["qdrant_results"]) >= 1)

    def test_generate_summary(self):
        """Test summary generation"""
        # Create a test state
        state = create_initial_state("I have blurry vision and eye pain")
        state["answers"] = [
            {
                "question": "How long have you been experiencing this eye condition?",
                "answer": "1-7 days",
                "is_custom": False
            },
            {
                "question": "Is your vision affected in one eye or both eyes?",
                "answer": "Both eyes",
                "is_custom": False
            }
        ]
        state["doctor_identification"] = {
            "doctor_type": "Ophthalmologist",
            "confidence": 0.85,
            "reasoning": "Based on the symptoms of blurry vision and eye pain, an ophthalmologist is recommended."
        }
        state["qdrant_results"] = [
            {
                "document_id": "doc1",
                "content": "Blurry vision can be caused by refractive errors, cataracts, or other eye conditions.",
                "relevance_score": 0.85
            },
            {
                "document_id": "doc2",
                "content": "Eye pain with blurry vision may indicate inflammation or increased eye pressure.",
                "relevance_score": 0.80
            }
        ]
        
        # Run the test
        result = self.loop.run_until_complete(self.agent._generate_summary(state))
        
        # Assertions
        self.assertIn("doctor_summary", result)
        self.assertIn("doctor_type", result["doctor_summary"])
        self.assertIn("summary", result["doctor_summary"])
        self.assertIn("key_symptoms", result["doctor_summary"])
        self.assertIn("recommended_tests", result["doctor_summary"])

    def test_run(self):
        """Test the complete agent run"""
        # Run the test
        result = self.loop.run_until_complete(self.agent.run("I have blurry vision and eye pain"))
        
        # Assertions
        self.assertIn("doctor_identification", result)
        self.assertIn("doctor_summary", result)
        self.assertIsNotNone(result["doctor_identification"])
        self.assertIsNotNone(result["doctor_summary"])


if __name__ == '__main__':
    unittest.main()