import asyncio
import os
import sys
import unittest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.main import app
from app.api.endpoints import router as ophthalmology_router


class TestAPIEndpoints(unittest.TestCase):
    """Test cases for the FastAPI endpoints"""

    def setUp(self):
        """Set up test fixtures"""
        self.client = TestClient(app)

    def test_root_endpoint(self):
        """Test the root endpoint"""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Welcome to the Ophthalmology Assistant API", "docs": "/docs"})

    def test_health_check(self):
        """Test the health check endpoint"""
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "healthy"})

    @patch('app.api.endpoints.get_ophthalmology_agent')
    def test_condition_endpoint(self, mock_get_agent):
        """Test the condition endpoint"""
        # Mock the agent instance
        mock_agent = MagicMock()
        mock_future = asyncio.Future()
        mock_future.set_result(mock_agent)
        mock_get_agent.return_value = mock_future
        
        # Mock the _process_condition method
        mock_agent._process_condition = MagicMock()
        mock_agent._process_condition.return_value = asyncio.Future()
        mock_agent._process_condition.return_value.set_result({
            "question_text": "How long have you been experiencing this eye condition?",
            "options": ["Less than 24 hours", "1-7 days", "1-4 weeks", "More than a month", "Other"]
        })
        
        # Make the request
        response = self.client.post(
            "/ophthalmology/condition",
            json={"condition": "I have blurry vision"}
        )
        
        # Assertions
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("question_text", data)
        self.assertIn("options", data)
        self.assertEqual(len(data["options"]), 5)
        self.assertIn("Other", data["options"])

    @patch('app.api.endpoints.get_ophthalmology_agent')
    def test_answer_endpoint(self, mock_get_agent):
        """Test the answer endpoint"""
        # Mock the agent instance
        mock_agent = MagicMock()
        mock_future = asyncio.Future()
        mock_future.set_result(mock_agent)
        mock_get_agent.return_value = mock_future
        
        # Mock the _process_answer method
        mock_agent._process_answer = MagicMock()
        mock_agent._process_answer.return_value = asyncio.Future()
        mock_agent._process_answer.return_value.set_result({
            "next_step": "question",
            "question": {
                "question_text": "Is your vision affected in one eye or both eyes?",
                "options": ["One eye", "Both eyes", "Not sure", "Other"]
            }
        })
        
        # Make the request
        response = self.client.post(
            "/ophthalmology/answer",
            json={
                "question": "How long have you been experiencing this eye condition?",
                "answer": "1-7 days",
                "is_custom": False
            }
        )
        
        # Assertions
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("next_step", data)
        self.assertEqual(data["next_step"], "question")
        self.assertIn("question", data)
        self.assertIn("question_text", data["question"])
        self.assertIn("options", data["question"])

    @patch('app.api.endpoints.get_ophthalmology_agent')
    def test_identify_doctor_endpoint(self, mock_get_agent):
        """Test the identify-doctor endpoint"""
        # Mock the agent instance
        mock_agent = MagicMock()
        mock_future = asyncio.Future()
        mock_future.set_result(mock_agent)
        mock_get_agent.return_value = mock_future
        
        # Mock the _identify_doctor method
        mock_agent._identify_doctor = MagicMock()
        mock_agent._identify_doctor.return_value = asyncio.Future()
        mock_agent._identify_doctor.return_value.set_result({
            "doctor_type": "Retina Specialist",
            "confidence": 0.92,
            "reasoning": "The symptoms of blurry vision, floaters, and flashes are consistent with retinal issues."
        })
        
        # Make the request
        response = self.client.post(
            "/ophthalmology/identify-doctor?condition=I have blurry vision and eye pain",
            json=[
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
        )
        
        # Assertions
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("doctor_type", data)
        self.assertIn("confidence", data)
        self.assertIn("reasoning", data)
        self.assertEqual(data["doctor_type"], "Optometrist")

    @patch('app.api.endpoints.get_ophthalmology_agent')
    def test_summary_endpoint(self, mock_get_agent):
        """Test the summary endpoint"""
        # Mock the agent instance
        mock_agent = MagicMock()
        mock_future = asyncio.Future()
        mock_future.set_result(mock_agent)
        mock_get_agent.return_value = mock_future
        
        # Mock the _query_qdrant and _generate_summary methods
        mock_agent._query_qdrant = MagicMock()
        mock_agent._query_qdrant.return_value = asyncio.Future()
        mock_agent._query_qdrant.return_value.set_result({
            "results": [
                "Blurry vision can be caused by refractive errors, cataracts, or other eye conditions.",
                "Eye pain with blurry vision may indicate inflammation or increased eye pressure."
            ]
        })
        
        mock_agent._generate_summary = MagicMock()
        mock_agent._generate_summary.return_value = asyncio.Future()
        mock_agent._generate_summary.return_value.set_result({
            "doctor_type": "Ophthalmologist",
            "summary": "Patient reports blurry vision and eye pain in both eyes for 1-7 days.",
            "key_symptoms": ["Blurry vision", "Eye pain", "Bilateral symptoms"],
            "recommended_tests": ["Visual acuity test", "Intraocular pressure measurement"]
        })
        
        # Make the request
        response = self.client.post(
            "/ophthalmology/summary?condition=I have blurry vision and eye pain&doctor_type=Ophthalmologist",
            json=[
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
        )
        
        # Assertions
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("doctor_type", data)
        self.assertIn("summary", data)
        self.assertIn("key_symptoms", data)
        self.assertIn("recommended_tests", data)
        self.assertEqual(data["doctor_type"], "Ophthalmologist")

    @patch('app.api.endpoints.get_ophthalmology_agent')
    def test_complete_endpoint(self, mock_get_agent):
        """Test the complete endpoint"""
        # Mock the agent instance
        mock_agent = MagicMock()
        mock_future = asyncio.Future()
        mock_future.set_result(mock_agent)
        mock_get_agent.return_value = mock_future
        
        # Mock the run method
        mock_agent.run = MagicMock()
        mock_agent.run.return_value = asyncio.Future()
        mock_agent.run.return_value.set_result({
            "doctor_identification": {
                "doctor_type": "Ophthalmologist",
                "confidence": 0.85,
                "reasoning": "Based on the symptoms of blurry vision and eye pain, an ophthalmologist is recommended."
            },
            "doctor_summary": {
                "doctor_type": "Ophthalmologist",
                "summary": "Patient reports blurry vision and eye pain in both eyes for 1-7 days.",
                "key_symptoms": ["Blurry vision", "Eye pain", "Bilateral symptoms"],
                "recommended_tests": ["Visual acuity test", "Intraocular pressure measurement"]
            }
        })
        
        # Make the request
        response = self.client.post(
            "/ophthalmology/complete?condition=I have blurry vision and eye pain",
            json=[
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
        )
        
        # Assertions
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("doctor_identification", data)
        self.assertIn("doctor_summary", data)
        self.assertEqual(data["doctor_identification"]["doctor_type"], "Optometrist")
        self.assertEqual(data["doctor_summary"]["doctor_type"], "Optometrist")


if __name__ == '__main__':
    unittest.main()