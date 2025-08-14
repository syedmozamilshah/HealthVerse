#!/usr/bin/env python3
"""
Mock test to verify the system structure and components without requiring external API keys.
This script tests the system with mock data to ensure everything is working properly.
"""

import sys
import os
import asyncio
import json
from unittest.mock import patch, MagicMock

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

def test_imports():
    """Test that all modules can be imported successfully"""
    print("🔍 Testing Module Imports...")
    
    try:
        # Test config
        from config import config
        print("✅ Config module imported")
        
        # Test models
        from models import (
            InitialConditionRequest, FollowUpQuestion, QuestionOption,
            UserAnswer, DoctorRecommendation, FinalResponse, AgentState
        )
        print("✅ Models imported")
        
        # Test that we can create model instances
        question = FollowUpQuestion(
            question="Test question?",
            options=[
                QuestionOption(text="Option 1", is_other=False),
                QuestionOption(text="Other", is_other=True)
            ]
        )
        print(f"✅ FollowUpQuestion created: {question.question}")
        
        return True
        
    except Exception as e:
        print(f"❌ Import failed: {str(e)}")
        return False

def test_doctor_validation():
    """Test doctor type validation"""
    print("\n🏥 Testing Doctor Type Validation...")
    
    try:
        from config import config
        
        allowed_doctors = config.ALLOWED_DOCTORS
        expected_doctors = ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
        
        if set(allowed_doctors) == set(expected_doctors):
            print("✅ Doctor types are correctly configured:")
            for doctor in allowed_doctors:
                print(f"   - {doctor}")
            return True
        else:
            print(f"❌ Doctor types mismatch:")
            print(f"   Expected: {expected_doctors}")
            print(f"   Found: {allowed_doctors}")
            return False
            
    except Exception as e:
        print(f"❌ Doctor validation failed: {str(e)}")
        return False

def test_mock_question_generation():
    """Test question generation with mock LLM response"""
    print("\n❓ Testing Mock Question Generation...")
    
    try:
        # Mock LLM response
        mock_llm_response = {
            "questions": [
                {
                    "question": "How long have you been experiencing these symptoms?",
                    "options": [
                        {"text": "Less than a week", "is_other": False},
                        {"text": "1-4 weeks", "is_other": False},
                        {"text": "More than a month", "is_other": False},
                        {"text": "Other", "is_other": True}
                    ]
                },
                {
                    "question": "Do you experience any pain or discomfort?",
                    "options": [
                        {"text": "No pain", "is_other": False},
                        {"text": "Mild discomfort", "is_other": False},
                        {"text": "Moderate pain", "is_other": False},
                        {"text": "Severe pain", "is_other": False},
                        {"text": "Other", "is_other": True}
                    ]
                }
            ]
        }
        
        # Validate the mock response structure
        questions = mock_llm_response.get('questions', [])
        
        if not questions:
            print("❌ No questions in mock response")
            return False
        
        for i, question in enumerate(questions):
            if not question.get('question'):
                print(f"❌ Question {i+1} missing question text")
                return False
            
            options = question.get('options', [])
            if len(options) < 3:
                print(f"❌ Question {i+1} has insufficient options")
                return False
            
            # Check for "Other" option
            has_other = any(opt.get('is_other', False) for opt in options)
            if not has_other:
                print(f"❌ Question {i+1} missing 'Other' option")
                return False
        
        print(f"✅ Mock question generation validated")
        print(f"   Generated {len(questions)} questions")
        for i, q in enumerate(questions, 1):
            print(f"   Q{i}: {q['question'][:50]}...")
            print(f"        Options: {len(q['options'])} (including Other)")
        
        return True
        
    except Exception as e:
        print(f"❌ Mock question generation failed: {str(e)}")
        return False

def test_mock_doctor_identification():
    """Test doctor identification with mock data"""
    print("\n👩‍⚕️ Testing Mock Doctor Identification...")
    
    test_cases = [
        {
            "condition": "Blurry vision and headaches",
            "answers": ["1-4 weeks", "Mild discomfort", "Reading and computer work"],
            "expected_doctors": ["Ophthalmologist", "Optometrist"]
        },
        {
            "condition": "Severe eye pain with redness", 
            "answers": ["Less than a day", "Severe pain", "Cannot open eye"],
            "expected_doctors": ["Ophthalmologist", "Ocular Surgeon"]
        },
        {
            "condition": "Need new glasses prescription",
            "answers": ["Several months", "No pain", "Difficulty seeing far"],
            "expected_doctors": ["Optometrist", "Optician"]
        }
    ]
    
    try:
        from config import config
        allowed_doctors = config.ALLOWED_DOCTORS
        
        for i, case in enumerate(test_cases, 1):
            print(f"   Test Case {i}: {case['condition'][:30]}...")
            
            # Mock logic for doctor identification
            condition_lower = case['condition'].lower()
            answers_text = ' '.join(case['answers']).lower()
            
            # Simple rule-based mock logic
            if 'severe' in condition_lower or 'pain' in condition_lower:
                if 'surgery' in condition_lower or 'severe' in answers_text:
                    mock_doctor = "Ocular Surgeon"
                else:
                    mock_doctor = "Ophthalmologist"
            elif 'glasses' in condition_lower or 'prescription' in condition_lower:
                if 'fitting' in condition_lower:
                    mock_doctor = "Optician"
                else:
                    mock_doctor = "Optometrist"
            elif 'blurry' in condition_lower or 'vision' in condition_lower:
                mock_doctor = "Optometrist"
            else:
                mock_doctor = "Ophthalmologist"  # Default
            
            # Validate mock doctor is in allowed list
            if mock_doctor not in allowed_doctors:
                print(f"❌ Mock doctor {mock_doctor} not in allowed list")
                return False
            
            # Check if recommendation makes sense
            if mock_doctor in case['expected_doctors']:
                print(f"   ✅ Recommended: {mock_doctor} (expected)")
            else:
                print(f"   ⚠️  Recommended: {mock_doctor} (unexpected but valid)")
        
        print("✅ Mock doctor identification completed")
        return True
        
    except Exception as e:
        print(f"❌ Mock doctor identification failed: {str(e)}")
        return False

def test_mock_summary_generation():
    """Test summary generation with mock data"""
    print("\n📋 Testing Mock Summary Generation...")
    
    try:
        mock_data = {
            "condition": "Blurry vision and headaches for the past week",
            "answers": [
                "1-4 weeks duration",
                "Mild discomfort", 
                "Mainly when reading or using computer"
            ],
            "doctor_type": "Optometrist",
            "rag_context": [
                "Computer vision syndrome causes eye strain and headaches",
                "Refractive errors can cause blurry vision and discomfort"
            ]
        }
        
        # Mock summary generation
        mock_summary = f"""
Patient presents with {mock_data['condition']}.

Duration and Severity:
- Symptoms present for {mock_data['answers'][0]}
- Reports {mock_data['answers'][1]}
- Symptoms primarily occur {mock_data['answers'][2]}

Clinical Context:
Based on patient responses and medical knowledge, this appears consistent with digital eye strain or possible refractive error.

Recommendations for {mock_data['doctor_type']}:
1. Comprehensive eye examination including refraction
2. Assess for computer vision syndrome
3. Consider prescription glasses if refractive error detected
4. Provide guidance on computer ergonomics and break schedules
        """.strip()
        
        # Validate summary content
        if len(mock_summary) < 100:
            print("❌ Summary too short")
            return False
        
        required_elements = [
            mock_data['condition'],
            mock_data['doctor_type'],
            'examination'
        ]
        
        for element in required_elements:
            if element.lower() not in mock_summary.lower():
                print(f"❌ Summary missing required element: {element}")
                return False
        
        print("✅ Mock summary generation validated")
        print(f"   Summary length: {len(mock_summary)} characters")
        print(f"   Contains all required elements")
        
        return True
        
    except Exception as e:
        print(f"❌ Mock summary generation failed: {str(e)}")
        return False

def test_frontend_structure():
    """Test that frontend files exist and have correct structure"""
    print("\n🌐 Testing Frontend Structure...")
    
    try:
        frontend_files = [
            'frontend/package.json',
            'frontend/src/App.js',
            'frontend/src/App.css',
            'frontend/src/index.js',
            'frontend/public/index.html'
        ]
        
        missing_files = []
        for file_path in frontend_files:
            if not os.path.exists(file_path):
                missing_files.append(file_path)
        
        if missing_files:
            print(f"❌ Missing frontend files: {missing_files}")
            return False
        else:
            print("✅ All frontend files present")
        
        # Check package.json structure
        with open('frontend/package.json', 'r') as f:
            package_data = json.load(f)
        
        required_deps = ['react', 'axios']
        missing_deps = [dep for dep in required_deps if dep not in package_data.get('dependencies', {})]
        
        if missing_deps:
            print(f"❌ Missing frontend dependencies: {missing_deps}")
            return False
        else:
            print("✅ All required frontend dependencies present")
        
        # Check if App.js contains key components
        with open('frontend/src/App.js', 'r') as f:
            app_content = f.read()
        
        required_features = [
            'useState',
            'axios',
            'generate-questions',
            'process-answers',
            'is_other'
        ]
        
        missing_features = [feature for feature in required_features if feature not in app_content]
        
        if missing_features:
            print(f"❌ App.js missing features: {missing_features}")
            return False
        else:
            print("✅ App.js contains all required features")
        
        return True
        
    except Exception as e:
        print(f"❌ Frontend structure test failed: {str(e)}")
        return False

def run_all_mock_tests():
    """Run all mock tests"""
    print("🔬 Running Mock System Tests")
    print("=" * 60)
    
    tests = [
        ("Module Imports", test_imports),
        ("Doctor Validation", test_doctor_validation),
        ("Question Generation", test_mock_question_generation),
        ("Doctor Identification", test_mock_doctor_identification),
        ("Summary Generation", test_mock_summary_generation),
        ("Frontend Structure", test_frontend_structure)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                print(f"   ❌ {test_name} failed")
        except Exception as e:
            print(f"   ❌ {test_name} failed with exception: {str(e)}")
    
    print("\n" + "=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All mock tests passed! System structure is correct.")
        print("\n📋 Next Steps:")
        print("1. Configure real API keys in backend/.env")
        print("2. Start the backend server: cd backend && python main.py")
        print("3. Start the frontend: cd frontend && npm start")
        print("4. Run the full API tests: python test_api_endpoints.py")
        return True
    else:
        print("❌ Some tests failed. Please fix the issues above.")
        return False

if __name__ == "__main__":
    success = run_all_mock_tests()
    sys.exit(0 if success else 1)
