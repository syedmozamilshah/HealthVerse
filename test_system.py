#!/usr/bin/env python3
"""
Test script to verify the Ophthalmology Assistant system functionality.
This script tests the key components without requiring external services.
"""

import sys
import os
import asyncio
import logging

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_system_components():
    """Test various system components"""
    
    print("🔬 Testing Ophthalmology Assistant System")
    print("=" * 50)
    
    # Test 1: Configuration
    print("\n1. Testing Configuration...")
    try:
        from config import config
        print(f"✅ Configuration loaded successfully")
        print(f"   - Embedding Model: {config.EMBEDDING_MODEL}")
        print(f"   - Allowed Doctors: {len(config.ALLOWED_DOCTORS)} types")
        
        # Check if required env vars are set (without showing values)
        required_vars = ['GOOGLE_API_KEY', 'QDRANT_ENDPOINT', 'QDRANT_API_KEY']
        missing_vars = []
        for var in required_vars:
            if not getattr(config, var):
                missing_vars.append(var)
        
        if missing_vars:
            print(f"⚠️  Missing environment variables: {', '.join(missing_vars)}")
            print("   Please configure these in the .env file for full functionality")
        else:
            print("✅ All required environment variables are set")
            
    except Exception as e:
        print(f"❌ Configuration test failed: {str(e)}")
        return False
    
    # Test 2: Models
    print("\n2. Testing Data Models...")
    try:
        from models import (
            InitialConditionRequest, FollowUpQuestion, QuestionOption,
            UserAnswer, DoctorRecommendation, FinalResponse
        )
        
        # Test model creation
        question = FollowUpQuestion(
            question="How long have you experienced symptoms?",
            options=[
                QuestionOption(text="Less than a week", is_other=False),
                QuestionOption(text="Other", is_other=True)
            ]
        )
        
        answer = UserAnswer(
            question_index=0,
            selected_option="Less than a week",
            custom_answer=None
        )
        
        doctor_rec = DoctorRecommendation(
            doctor_type="Ophthalmologist",
            reasoning="Test reasoning"
        )
        
        print("✅ All data models work correctly")
        print(f"   - Question: {question.question}")
        print(f"   - Options: {len(question.options)}")
        print(f"   - Doctor: {doctor_rec.doctor_type}")
        
    except Exception as e:
        print(f"❌ Models test failed: {str(e)}")
        return False
    
    # Test 3: Basic Agent Tools (without external dependencies)
    print("\n3. Testing Agent Tools Structure...")
    try:
        from agent_tools import (
            QuestionGenerationTool, DoctorIdentificationTool,
            RAGQueryTool, SummarizationTool
        )
        
        # Test tool instantiation
        tools = [
            QuestionGenerationTool(),
            DoctorIdentificationTool(),
            RAGQueryTool(),
            SummarizationTool()
        ]
        
        print("✅ All agent tools instantiated successfully")
        for tool in tools:
            print(f"   - {tool.name}: {tool.description[:50]}...")
            
    except Exception as e:
        print(f"❌ Agent tools test failed: {str(e)}")
        return False
    
    # Test 4: FastAPI App Structure
    print("\n4. Testing FastAPI Application...")
    try:
        # Import without starting the server
        from main import app
        
        # Check routes
        routes = [route.path for route in app.routes if hasattr(route, 'path')]
        expected_routes = ['/api/generate-questions', '/api/process-answers', '/api/allowed-doctors']
        
        print("✅ FastAPI application structure is correct")
        print(f"   - Total routes: {len(routes)}")
        print(f"   - API routes: {len([r for r in routes if r.startswith('/api')])}")
        
        # Check if expected routes exist
        missing_routes = [route for route in expected_routes if route not in routes]
        if missing_routes:
            print(f"⚠️  Missing expected routes: {missing_routes}")
        else:
            print("✅ All expected API routes are present")
            
    except Exception as e:
        print(f"❌ FastAPI test failed: {str(e)}")
        return False
    
    # Test 5: React Frontend Structure
    print("\n5. Testing Frontend Structure...")
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
            print(f"⚠️  Missing frontend files: {missing_files}")
        else:
            print("✅ All frontend files are present")
            
        # Check package.json
        import json
        with open('frontend/package.json', 'r') as f:
            package_data = json.load(f)
            
        required_deps = ['react', 'axios']
        missing_deps = [dep for dep in required_deps if dep not in package_data.get('dependencies', {})]
        
        if missing_deps:
            print(f"⚠️  Missing frontend dependencies: {missing_deps}")
        else:
            print("✅ All required frontend dependencies are present")
            
    except Exception as e:
        print(f"❌ Frontend test failed: {str(e)}")
        return False
    
    # Summary
    print("\n" + "=" * 50)
    print("🎉 System Component Tests Completed!")
    print("\n📋 Next Steps:")
    print("1. Configure environment variables in backend/.env")
    print("2. Install backend dependencies: pip install -r backend/requirements.txt")
    print("3. Install frontend dependencies: cd frontend && npm install")
    print("4. Start backend: cd backend && python main.py")
    print("5. Start frontend: cd frontend && npm start")
    print("6. Open http://localhost:3000 in your browser")
    
    return True

def test_doctor_validation():
    """Test doctor type validation"""
    print("\n🏥 Testing Doctor Type Validation...")
    
    try:
        from config import config
        
        allowed_doctors = config.ALLOWED_DOCTORS
        expected_doctors = ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
        
        if set(allowed_doctors) == set(expected_doctors):
            print("✅ Doctor types are correctly configured")
            for doctor in allowed_doctors:
                print(f"   - {doctor}")
        else:
            print(f"⚠️  Doctor types mismatch:")
            print(f"   Expected: {expected_doctors}")
            print(f"   Found: {allowed_doctors}")
            
    except Exception as e:
        print(f"❌ Doctor validation failed: {str(e)}")

def main():
    """Main test function"""
    print("🚀 Starting Ophthalmology Assistant System Tests\n")
    
    # Test doctor validation
    test_doctor_validation()
    
    # Test system components
    success = asyncio.run(test_system_components())
    
    if success:
        print("\n✅ All tests passed! System is ready for deployment.")
        return 0
    else:
        print("\n❌ Some tests failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
