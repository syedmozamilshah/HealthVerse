import asyncio
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from mcp_server.tools.ophthalmology_tools import (
    generate_followup_question,
    identify_doctor,
    query_qdrant,
    generate_doctor_summary,
    UserAnswer,
    QdrantResult
)


class TestMCPServer(unittest.TestCase):
    """Test cases for the MCP server tools"""

    def test_generate_followup_question(self):
        """Test the generate_followup_question function"""
        # Test with initial condition
        result = generate_followup_question("I have blurry vision")
        
        self.assertIsInstance(result.question_text, str)
        self.assertIsInstance(result.options, list)
        self.assertTrue(len(result.options) >= 3)
        
        # Test with existing conversation
        previous_answers = [
            UserAnswer(question="How long have you been experiencing this eye condition?", answer="1-7 days", is_custom=False)
        ]
        result = generate_followup_question("I have blurry vision", previous_answers)
        
        self.assertIsInstance(result.question_text, str)
        self.assertIsInstance(result.options, list)
        self.assertTrue(len(result.options) >= 3)

    def test_identify_doctor(self):
        """Test the identify_doctor function"""
        user_answers = [
            UserAnswer(question="How long have you been experiencing this eye condition?", answer="1-7 days", is_custom=False),
            UserAnswer(question="Is your vision affected in one eye or both eyes?", answer="Both eyes", is_custom=False)
        ]
        result = identify_doctor("I have blurry vision and eye pain", user_answers)
        
        self.assertIsInstance(result.doctor_type, str)
        self.assertIsInstance(result.confidence, float)
        self.assertIsInstance(result.reasoning, str)
        self.assertGreaterEqual(result.confidence, 0.0)
        self.assertLessEqual(result.confidence, 1.0)

    def test_query_qdrant(self):
        """Test the query_qdrant function"""
        user_answers = [
            UserAnswer(question="How long have you been experiencing this eye condition?", answer="1-7 days", is_custom=False)
        ]
        result = query_qdrant("I have blurry vision and eye pain", user_answers)
        
        self.assertIsInstance(result, list)
        self.assertTrue(len(result) > 0)
        for item in result:
            self.assertIsInstance(item, QdrantResult)

    def test_generate_doctor_summary(self):
        """Test the generate_doctor_summary function"""
        user_answers = [
            UserAnswer(question="How long have you been experiencing this eye condition?", answer="1-7 days", is_custom=False),
            UserAnswer(question="Is your vision affected in one eye or both eyes?", answer="Both eyes", is_custom=False)
        ]
        qdrant_results = [
            QdrantResult(document_id="doc1", content="Blurry vision can be caused by refractive errors, cataracts, or other eye conditions.", relevance_score=0.85),
            QdrantResult(document_id="doc2", content="Eye pain with blurry vision may indicate inflammation or increased eye pressure.", relevance_score=0.80)
        ]
        
        result = generate_doctor_summary(
            "I have blurry vision and eye pain",
            user_answers,
            "Ophthalmologist",
            qdrant_results
        )
        
        self.assertIsInstance(result.doctor_type, str)
        self.assertIsInstance(result.summary, str)
        self.assertIsInstance(result.key_symptoms, list)
        self.assertIsInstance(result.recommended_tests, list)
        self.assertEqual(result.doctor_type, "Ophthalmologist")
        self.assertTrue(len(result.key_symptoms) > 0)
        self.assertTrue(len(result.recommended_tests) > 0)


if __name__ == '__main__':
    unittest.main()