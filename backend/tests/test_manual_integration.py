#!/usr/bin/env python3
"""
Manual Frontend-Backend Integration Verification
================================================

This script provides a comprehensive verification of the frontend-backend
integration by testing the complete workflow manually through HTTP requests
and providing manual testing guidance.
"""

import requests
import json
import time
from datetime import datetime

# Configuration
FRONTEND_URL = "http://localhost:3000"
BACKEND_URL = "http://localhost:8000"

class ManualIntegrationVerifier:
    """Verify frontend-backend integration manually"""
    
    def __init__(self):
        self.session = requests.Session()
    
    def check_services(self):
        """Check that both services are running"""
        print("🔍 Checking service availability...")
        
        # Check backend
        try:
            response = self.session.get(f"{BACKEND_URL}/health", timeout=5)
            if response.status_code == 200:
                print("✅ Backend service is running")
                backend_health = response.json()
                print(f"   Backend status: {backend_health.get('status', 'unknown')}")
            else:
                print(f"❌ Backend returned status {response.status_code}")
                return False
        except requests.RequestException as e:
            print(f"❌ Backend not accessible: {str(e)}")
            return False
        
        # Check frontend
        try:
            response = self.session.get(FRONTEND_URL, timeout=5)
            if response.status_code == 200:
                print("✅ Frontend service is running")
                print(f"   Frontend accessible at: {FRONTEND_URL}")
            else:
                print(f"❌ Frontend returned status {response.status_code}")
                return False
        except requests.RequestException as e:
            print(f"❌ Frontend not accessible: {str(e)}")
            return False
        
        return True
    
    def test_complete_workflow_api(self):
        """Test the complete iterative workflow via API calls"""
        print("\n🔍 Testing complete iterative workflow via API...")
        
        try:
            # Step 1: Start session
            print("   Step 1: Starting iterative session...")
            session_request = {
                "condition": "I have been experiencing sudden flashing lights and floaters in my right eye since yesterday"
            }
            
            response = self.session.post(
                f"{BACKEND_URL}/api/iterative/start",
                json=session_request,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code != 200:
                print(f"❌ Failed to start session: {response.status_code}")
                return False
            
            session_data = response.json()
            session_id = session_data["session_id"]
            confidence = session_data["confidence_score"]
            
            print(f"✅ Session started: {session_id}")
            print(f"   Initial confidence: {confidence['overall_confidence']:.2f}")
            print(f"   First question: {session_data['first_question']['question'][:80]}...")
            
            # Step 2: Answer questions iteratively
            current_question = session_data["first_question"]
            question_count = 0
            max_questions = 6
            
            while current_question and question_count < max_questions:
                question_count += 1
                print(f"\n   Step {question_count + 1}: Answering question {question_count}...")
                
                # Select first non-other option
                selected_answer = None
                for option in current_question["options"]:
                    if not option.get("is_other", False):
                        selected_answer = option["text"]
                        break
                
                if not selected_answer:
                    print("❌ No suitable answer option found")
                    return False
                
                print(f"   Selected answer: {selected_answer}")
                
                # Submit answer
                answer_request = {
                    "session_id": session_id,
                    "answer": selected_answer
                }
                
                response = self.session.post(
                    f"{BACKEND_URL}/api/iterative/next",
                    json=answer_request,
                    headers={"Content-Type": "application/json"}
                )
                
                if response.status_code != 200:
                    print(f"❌ Failed to submit answer: {response.status_code}")
                    return False
                
                next_data = response.json()
                confidence = next_data["confidence_score"]
                print(f"   Updated confidence: {confidence['overall_confidence']:.2f}")
                
                if next_data["is_complete"]:
                    print("✅ Session completed!")
                    doctor = next_data["doctor_recommendation"]
                    print(f"   Final recommendation: {doctor['doctor_type']}")
                    print(f"   Reasoning: {doctor['reasoning'][:100]}...")
                    print(f"   Final confidence: {confidence['overall_confidence']:.2f}")
                    return True
                else:
                    current_question = next_data.get("question")
                    if not current_question:
                        print("❌ Session not complete but no next question provided")
                        return False
            
            print("❌ Session did not complete within maximum questions")
            return False
            
        except Exception as e:
            print(f"❌ Workflow test failed: {str(e)}")
            return False
    
    def test_cors_functionality(self):
        """Test CORS configuration for frontend-backend communication"""
        print("\n🔍 Testing CORS configuration...")
        
        try:
            # Test preflight request
            headers = {
                "Origin": FRONTEND_URL,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type"
            }
            
            response = self.session.options(
                f"{BACKEND_URL}/api/iterative/start",
                headers=headers
            )
            
            cors_origin = response.headers.get("Access-Control-Allow-Origin")
            if cors_origin == FRONTEND_URL or cors_origin == "*":
                print("✅ CORS properly configured")
                print(f"   Allowed origin: {cors_origin}")
                return True
            else:
                print(f"❌ CORS misconfigured. Allowed origin: {cors_origin}")
                return False
                
        except Exception as e:
            print(f"❌ CORS test failed: {str(e)}")
            return False
    
    def generate_manual_test_instructions(self):
        """Generate instructions for manual frontend testing"""
        print("\n📝 Manual Frontend Testing Instructions")
        print("=" * 50)
        
        instructions = [
            {
                "step": 1,
                "action": "Open browser and navigate to frontend",
                "url": FRONTEND_URL,
                "expected": "Should see 'Smart Ophthalmology Assistant' heading and condition input form"
            },
            {
                "step": 2,
                "action": "Enter a test condition",
                "example": "I have sudden flashing lights and floaters in my right eye",
                "expected": "Text area should accept input without issues"
            },
            {
                "step": 3,
                "action": "Click 'Start Smart Consultation'",
                "expected": "Should transition to iterative questioning interface with confidence panel"
            },
            {
                "step": 4,
                "action": "Answer the first question",
                "expected": "Should show radio button options with 'Other' option available"
            },
            {
                "step": 5,
                "action": "Submit answer",
                "expected": "Should update confidence score and show next question or results"
            },
            {
                "step": 6,
                "action": "Continue answering questions",
                "expected": "Should build conversation history and update confidence progressively"
            },
            {
                "step": 7,
                "action": "Complete session",
                "expected": "Should show final doctor recommendation with reasoning and medical summary"
            },
            {
                "step": 8,
                "action": "Start new consultation",
                "expected": "Should reset form and return to initial condition input"
            }
        ]
        
        for instruction in instructions:
            print(f"\n{instruction['step']}. {instruction['action']}")
            if 'url' in instruction:
                print(f"   URL: {instruction['url']}")
            if 'example' in instruction:
                print(f"   Example: {instruction['example']}")
            print(f"   Expected: {instruction['expected']}")
        
        print("\n" + "=" * 50)
        print("⚠️  Things to verify manually:")
        print("• Confidence score updates correctly (0-100%)")
        print("• Conversation history displays properly")
        print("• Leading doctor recommendation updates")
        print("• Error handling for empty inputs")
        print("• Responsive design on different screen sizes")
        print("• Print functionality works")
        print("• 'Other' option allows custom text input")
        
    def run_verification(self):
        """Run complete verification suite"""
        print("🧪 Manual Frontend-Backend Integration Verification")
        print("=" * 60)
        
        tests = [
            ("Service Availability", self.check_services),
            ("CORS Configuration", self.test_cors_functionality),
            ("Complete Workflow API", self.test_complete_workflow_api),
        ]
        
        passed = 0
        failed = 0
        
        for test_name, test_method in tests:
            print(f"\n🔍 Running: {test_name}")
            try:
                if test_method():
                    print(f"✅ {test_name}: PASSED")
                    passed += 1
                else:
                    print(f"❌ {test_name}: FAILED")
                    failed += 1
            except Exception as e:
                print(f"❌ {test_name}: FAILED - {str(e)}")
                failed += 1
        
        # Generate manual testing instructions
        self.generate_manual_test_instructions()
        
        print("\n" + "=" * 60)
        print(f"🏁 Automated Tests Complete")
        print(f"✅ Passed: {passed}")
        print(f"❌ Failed: {failed}")
        
        if failed == 0:
            print("\n🎉 All automated tests passed!")
            print("🔗 Backend API is properly integrated and CORS is configured")
            print("📝 Please follow the manual testing instructions above")
            print("   to verify the complete frontend user experience")
            return True
        else:
            print("\n⚠️  Some automated tests failed.")
            print("   Please fix backend issues before testing frontend")
            return False

def main():
    """Main verification execution"""
    verifier = ManualIntegrationVerifier()
    success = verifier.run_verification()
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
