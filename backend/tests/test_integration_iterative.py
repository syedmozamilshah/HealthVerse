#!/usr/bin/env python3
"""
Comprehensive Integration Test for Iterative Questioning System
==============================================================

This test verifies the complete integration between frontend and backend,
focusing specifically on the smart iterative questioning workflow.
"""

import asyncio
import requests
import json
import time
from datetime import datetime

# Test configuration
API_BASE_URL = "http://localhost:8000"
FRONTEND_URL = "http://localhost:3000"

class TestIntegrationIterative:
    """Test suite for iterative questioning integration"""
    
    def test_api_health_check(self, api_client):
        """Test that the API is running and healthy"""
        response = api_client.get(f"{API_BASE_URL}/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert "services" in data
        
    def test_cors_headers(self, api_client):
        """Test CORS configuration"""
        # Test preflight request
        headers = {
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Content-Type"
        }
        response = api_client.options(f"{API_BASE_URL}/api/iterative/start", headers=headers)
        
        # Should allow the origin
        assert response.headers.get("Access-Control-Allow-Origin") == "http://localhost:3000"
        
        
    def test_iterative_workflow_integration(self, api_client):
        """Test the new iterative questioning workflow"""
        # Step 1: Start iterative session
        session_request = {
            "condition": "I have sudden onset of flashing lights and floaters in my right eye"
        }
        
        response = api_client.post(
            f"{API_BASE_URL}/api/iterative/start",
            json=session_request,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 200
        session_data = response.json()
        
        assert "session_id" in session_data
        assert "first_question" in session_data
        assert "confidence_score" in session_data
        
        session_id = session_data["session_id"]
        current_question = session_data["first_question"]
        confidence = session_data["confidence_score"]
        
        # Validate initial confidence structure
        assert "overall_confidence" in confidence
        assert "doctor_confidence" in confidence
        assert "reasoning" in confidence
        assert 0 <= confidence["overall_confidence"] <= 1
        
        print(f"✅ Started iterative session: {session_id}")
        print(f"   Initial confidence: {confidence['overall_confidence']:.2f}")
        
        # Step 2: Iterative questioning loop
        question_count = 0
        max_questions = 8  # Safety limit
        
        while current_question and question_count < max_questions:
            question_count += 1
            print(f"   Question {question_count}: {current_question['question']}")
            
            # Validate question structure
            assert "question" in current_question
            assert "options" in current_question
            assert len(current_question["options"]) >= 3
            
            # Select first non-other option
            selected_answer = None
            for option in current_question["options"]:
                if not option.get("is_other", False):
                    selected_answer = option["text"]
                    break
            
            assert selected_answer is not None, "No non-other option found"
            
            # Submit answer
            answer_request = {
                "session_id": session_id,
                "answer": selected_answer
            }
            
            response = api_client.post(
                f"{API_BASE_URL}/api/iterative/next",
                json=answer_request,
                headers={"Content-Type": "application/json"}
            )
            
            assert response.status_code == 200
            next_data = response.json()
            
            assert "is_complete" in next_data
            assert "confidence_score" in next_data
            assert "conversation_history" in next_data
            
            # Update confidence
            confidence = next_data["confidence_score"]
            print(f"   Updated confidence: {confidence['overall_confidence']:.2f}")
            
            if next_data["is_complete"]:
                # Session completed
                assert "doctor_recommendation" in next_data
                assert "summary_for_doctor" in next_data
                
                doctor = next_data["doctor_recommendation"]
                assert "doctor_type" in doctor
                assert "reasoning" in doctor
                assert doctor["doctor_type"] in ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
                
                print(f"✅ Iterative session completed after {question_count} questions")
                print(f"   Final recommendation: {doctor['doctor_type']}")
                print(f"   Final confidence: {confidence['overall_confidence']:.2f}")
                break
            else:
                # Continue with next question
                current_question = next_data.get("question")
                if not current_question:
                    raise RuntimeError("Session not complete but no next question provided")
        
        else:
            raise RuntimeError(f"Session did not complete within {max_questions} questions")
            
        # Step 3: Verify conversation history
        assert len(next_data["conversation_history"]) == question_count
        for i, entry in enumerate(next_data["conversation_history"]):
            assert "question" in entry
            assert "answer" in entry
            assert "timestamp" in entry
            print(f"   History {i+1}: Q: {entry['question'][:50]}... A: {entry['answer']}")
        
    def test_session_status_endpoint(self, api_client):
        """Test session status retrieval"""
        # Start a session first
        session_request = {
            "condition": "Test condition for session status"
        }
        
        response = api_client.post(
            f"{API_BASE_URL}/api/iterative/start",
            json=session_request,
            headers={"Content-Type": "application/json"}
        )
        
        session_data = response.json()
        session_id = session_data["session_id"]
        
        # Get session status
        response = api_client.get(f"{API_BASE_URL}/api/iterative/session/{session_id}")
        assert response.status_code == 200
        
        status_data = response.json()
        assert "session_id" in status_data
        assert "initial_condition" in status_data
        assert "conversation_history" in status_data
        assert "confidence_score" in status_data
        assert "is_complete" in status_data
        
        print(f"✅ Session status endpoint working for session: {session_id}")
        
    def test_invalid_session_handling(self, api_client):
        """Test handling of invalid session IDs"""
        # Test with non-existent session ID
        invalid_session_id = "invalid-session-id-12345"
        
        response = api_client.post(
            f"{API_BASE_URL}/api/iterative/next",
            json={
                "session_id": invalid_session_id,
                "answer": "test answer"
            },
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 404
        error_data = response.json()
        assert "detail" in error_data
        
        print("✅ Invalid session handling working correctly")
        
    def test_error_handling_and_validation(self, api_client):
        """Test various error conditions and input validation"""
        # Test empty condition for iterative start
        response = api_client.post(
            f"{API_BASE_URL}/api/iterative/start",
            json={"condition": ""},
            headers={"Content-Type": "application/json"}
        )
        # Should either work with empty string or return 422
        assert response.status_code in [200, 422]
        
        # Test malformed JSON
        response = api_client.post(
            f"{API_BASE_URL}/api/iterative/start",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422
        
        print("✅ Error handling and validation working correctly")
        
    def test_allowed_doctors_endpoint(self, api_client):
        """Test the allowed doctors information endpoint"""
        response = api_client.get(f"{API_BASE_URL}/api/allowed-doctors")
        assert response.status_code == 200
        
        data = response.json()
        assert "allowed_doctors" in data
        assert "descriptions" in data
        
        allowed_doctors = data["allowed_doctors"]
        assert "Ophthalmologist" in allowed_doctors
        assert "Optometrist" in allowed_doctors
        assert "Optician" in allowed_doctors
        assert "Ocular Surgeon" in allowed_doctors
        
        print("✅ Allowed doctors endpoint working correctly")

def run_integration_tests():
    """Run all integration tests"""
    print("🧪 Starting Comprehensive Integration Tests")
    print("=" * 60)
    
    # Check if backend is running
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        if response.status_code != 200:
            print("❌ Backend not responding. Please start the backend first.")
            return False
    except requests.exceptions.RequestException:
        print("❌ Backend not accessible. Please start the backend first.")
        return False
    
    # Run tests
    test_instance = TestIntegrationIterative()
    api_client = requests.Session()
    
    test_methods = [
        ("Health Check", test_instance.test_api_health_check),
        ("CORS Configuration", test_instance.test_cors_headers),
        ("Iterative Workflow", test_instance.test_iterative_workflow_integration),
        ("Session Status", test_instance.test_session_status_endpoint),
        ("Invalid Session Handling", test_instance.test_invalid_session_handling),
        ("Error Handling", test_instance.test_error_handling_and_validation),
        ("Allowed Doctors", test_instance.test_allowed_doctors_endpoint),
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_method in test_methods:
        try:
            print(f"\n🔍 Running: {test_name}")
            test_method(api_client)
            print(f"✅ {test_name}: PASSED")
            passed += 1
        except Exception as e:
            print(f"❌ {test_name}: FAILED - {str(e)}")
            failed += 1
    
    print("\n" + "=" * 60)
    print(f"🏁 Integration Tests Complete")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Success Rate: {(passed / (passed + failed)) * 100:.1f}%")
    
    if failed == 0:
        print("🎉 All integration tests passed! System is ready for use.")
        return True
    else:
        print("⚠️  Some tests failed. Please check the backend configuration and try again.")
        return False

if __name__ == "__main__":
    success = run_integration_tests()
    exit(0 if success else 1)
