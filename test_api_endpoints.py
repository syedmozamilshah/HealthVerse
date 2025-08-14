#!/usr/bin/env python3
"""
Comprehensive test script for the Ophthalmology Assistant API.
Tests all endpoints with mock data and verifies responses.
"""

import asyncio
import json
import sys
import os
import time
import httpx
from typing import Dict, List, Any

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

# Test configurations
API_BASE_URL = "http://localhost:8000"
TEST_TIMEOUT = 30  # seconds

# Mock test data
MOCK_TEST_CASES = [
    {
        "name": "Blurry Vision Case",
        "initial_condition": "I have been experiencing blurry vision and headaches for the past week, especially when reading or using the computer.",
        "expected_doctor_types": ["Ophthalmologist", "Optometrist"]
    },
    {
        "name": "Eye Pain Case", 
        "initial_condition": "I have severe eye pain with redness and discharge that started yesterday.",
        "expected_doctor_types": ["Ophthalmologist", "Ocular Surgeon"]
    },
    {
        "name": "Vision Correction Case",
        "initial_condition": "I need new glasses because my current prescription doesn't seem right anymore.",
        "expected_doctor_types": ["Optometrist", "Optician"]
    },
    {
        "name": "Post-Surgery Case",
        "initial_condition": "I had cataract surgery last month and I'm experiencing some vision issues and discomfort.",
        "expected_doctor_types": ["Ophthalmologist", "Ocular Surgeon"]
    }
]

class APITester:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=TEST_TIMEOUT)
        
    async def test_health_check(self) -> bool:
        """Test if the API server is running"""
        try:
            response = await self.client.get(f"{self.base_url}/health")
            if response.status_code == 200:
                data = response.json()
                print("✅ API Health Check:")
                print(f"   Status: {data.get('status')}")
                print(f"   Version: {data.get('version')}")
                return True
            else:
                print(f"❌ Health check failed with status: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Health check failed: {str(e)}")
            return False
    
    async def test_allowed_doctors_endpoint(self) -> bool:
        """Test the allowed doctors endpoint"""
        try:
            response = await self.client.get(f"{self.base_url}/api/allowed-doctors")
            if response.status_code == 200:
                data = response.json()
                allowed_doctors = data.get('allowed_doctors', [])
                expected_doctors = ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
                
                if set(allowed_doctors) == set(expected_doctors):
                    print("✅ Allowed Doctors Endpoint:")
                    for doctor in allowed_doctors:
                        print(f"   - {doctor}")
                    return True
                else:
                    print(f"❌ Doctor types mismatch. Expected: {expected_doctors}, Got: {allowed_doctors}")
                    return False
            else:
                print(f"❌ Allowed doctors endpoint failed with status: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Allowed doctors test failed: {str(e)}")
            return False
    
    async def test_question_generation(self, condition: str) -> Dict[str, Any]:
        """Test question generation endpoint"""
        try:
            payload = {"condition": condition}
            response = await self.client.post(
                f"{self.base_url}/api/generate-questions",
                json=payload
            )
            
            if response.status_code == 200:
                data = response.json()
                questions = data.get('questions', [])
                
                # Validate response structure
                if not questions:
                    print(f"❌ No questions generated for condition: {condition[:50]}...")
                    return None
                
                # Check if questions have proper structure
                for i, question in enumerate(questions):
                    if not question.get('question'):
                        print(f"❌ Question {i+1} missing question text")
                        return None
                    
                    options = question.get('options', [])
                    if len(options) < 3:  # Should have at least 3 options including "Other"
                        print(f"❌ Question {i+1} has insufficient options")
                        return None
                    
                    # Check for "Other" option
                    has_other = any(opt.get('is_other', False) for opt in options)
                    if not has_other:
                        print(f"❌ Question {i+1} missing 'Other' option")
                        return None
                
                print(f"✅ Generated {len(questions)} questions for: {condition[:50]}...")
                return data
            
            else:
                print(f"❌ Question generation failed with status: {response.status_code}")
                if response.status_code == 500:
                    error_detail = response.json().get('detail', 'Unknown error')
                    print(f"   Error: {error_detail}")
                return None
                
        except Exception as e:
            print(f"❌ Question generation test failed: {str(e)}")
            return None
    
    async def test_answer_processing(self, condition: str, questions_data: Dict[str, Any]) -> Dict[str, Any]:
        """Test answer processing endpoint with mock answers"""
        try:
            questions = questions_data.get('questions', [])
            
            # Generate mock answers
            mock_answers = []
            for i, question in enumerate(questions):
                options = question.get('options', [])
                
                # For testing, select the first non-Other option, or provide custom answer for Other
                non_other_options = [opt for opt in options if not opt.get('is_other', False)]
                other_options = [opt for opt in options if opt.get('is_other', False)]
                
                if non_other_options and i % 2 == 0:  # Use predefined options for even indices
                    selected_option = non_other_options[0]['text']
                    mock_answers.append({
                        "question_index": i,
                        "selected_option": selected_option,
                        "custom_answer": None
                    })
                elif other_options:  # Use custom answer for odd indices
                    mock_answers.append({
                        "question_index": i,
                        "selected_option": None,
                        "custom_answer": f"Custom answer for question {i+1}: This is a detailed custom response."
                    })
                else:  # Fallback
                    mock_answers.append({
                        "question_index": i,
                        "selected_option": options[0]['text'] if options else "No answer",
                        "custom_answer": None
                    })
            
            # Submit answers
            payload = {
                "initial_condition": condition,
                "answers": mock_answers
            }
            
            response = await self.client.post(
                f"{self.base_url}/api/process-answers",
                json=payload
            )
            
            if response.status_code == 200:
                data = response.json()
                
                # Validate response structure
                doctor = data.get('doctor')
                summary = data.get('summary_for_doctor')
                
                if not doctor or not summary:
                    print(f"❌ Incomplete response: missing doctor or summary")
                    return None
                
                doctor_type = doctor.get('doctor_type')
                reasoning = doctor.get('reasoning')
                
                if not doctor_type or not reasoning:
                    print(f"❌ Incomplete doctor recommendation")
                    return None
                
                # Check if doctor type is valid
                allowed_doctors = ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
                if doctor_type not in allowed_doctors:
                    print(f"❌ Invalid doctor type: {doctor_type}")
                    return None
                
                print(f"✅ Processed answers successfully:")
                print(f"   Doctor: {doctor_type}")
                print(f"   Reasoning: {reasoning[:100]}...")
                print(f"   Summary length: {len(summary)} characters")
                
                return data
            
            else:
                print(f"❌ Answer processing failed with status: {response.status_code}")
                if response.status_code == 500:
                    error_detail = response.json().get('detail', 'Unknown error')
                    print(f"   Error: {error_detail}")
                return None
                
        except Exception as e:
            print(f"❌ Answer processing test failed: {str(e)}")
            return None
    
    async def test_full_workflow(self, test_case: Dict[str, Any]) -> bool:
        """Test the complete workflow for a test case"""
        print(f"\n🔬 Testing: {test_case['name']}")
        print(f"Condition: {test_case['initial_condition'][:100]}...")
        
        # Step 1: Generate questions
        questions_data = await self.test_question_generation(test_case['initial_condition'])
        if not questions_data:
            return False
        
        # Step 2: Process answers
        result_data = await self.test_answer_processing(test_case['initial_condition'], questions_data)
        if not result_data:
            return False
        
        # Step 3: Validate doctor recommendation
        recommended_doctor = result_data['doctor']['doctor_type']
        expected_doctors = test_case['expected_doctor_types']
        
        if recommended_doctor in expected_doctors:
            print(f"✅ Doctor recommendation validated: {recommended_doctor}")
        else:
            print(f"⚠️  Unexpected doctor recommendation: {recommended_doctor}")
            print(f"   Expected one of: {expected_doctors}")
        
        return True
    
    async def run_all_tests(self) -> bool:
        """Run all API tests"""
        print("🚀 Starting Comprehensive API Tests")
        print("=" * 60)
        
        # Test 1: Health Check
        if not await self.test_health_check():
            print("\n❌ API server is not responding. Please start the backend server first.")
            return False
        
        # Test 2: Allowed Doctors Endpoint
        if not await self.test_allowed_doctors_endpoint():
            return False
        
        # Test 3: Full Workflow Tests
        all_passed = True
        for test_case in MOCK_TEST_CASES:
            success = await self.test_full_workflow(test_case)
            if not success:
                all_passed = False
        
        # Summary
        print("\n" + "=" * 60)
        if all_passed:
            print("🎉 All API tests passed successfully!")
            print("\n📋 Test Summary:")
            print(f"✅ Health check: Passed")
            print(f"✅ Allowed doctors endpoint: Passed") 
            print(f"✅ Full workflow tests: {len(MOCK_TEST_CASES)} cases passed")
            
            print("\n🔧 System is ready for production use!")
        else:
            print("❌ Some tests failed. Please check the errors above.")
        
        return all_passed
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()

async def main():
    """Main test runner"""
    print("🔍 Ophthalmology Assistant API Test Suite")
    print("This script will test all API endpoints with mock data\n")
    
    # Check if server is likely running
    tester = APITester(API_BASE_URL)
    
    try:
        success = await tester.run_all_tests()
        return 0 if success else 1
    finally:
        await tester.close()

def check_server_running():
    """Check if the backend server is running"""
    import requests
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

if __name__ == "__main__":
    # Check if server is running first
    if not check_server_running():
        print("❌ Backend server is not running!")
        print("\nTo start the server:")
        print("1. cd backend")
        print("2. python main.py")
        print("\nThen run this test script again.")
        sys.exit(1)
    
    # Run async tests
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
