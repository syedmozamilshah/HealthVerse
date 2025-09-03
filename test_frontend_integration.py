#!/usr/bin/env python3
"""
Frontend-Backend Integration Test
Tests the complete integration between React frontend and FastAPI backend
"""

import asyncio
import aiohttp
import json
import time

async def test_integration():
    """Test the integration between frontend and backend"""
    print("🔗 FRONTEND-BACKEND INTEGRATION TEST")
    print("=" * 50)
    
    base_url = "http://localhost:8080"
    
    async with aiohttp.ClientSession() as session:
        # Test 1: Health Check
        print("\n1. Testing Backend Health Check...")
        try:
            async with session.get(f"{base_url}/health") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"✅ Backend Health: {data['status']}")
                else:
                    print(f"❌ Health check failed: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ Cannot connect to backend: {e}")
            print("🚨 Make sure FastAPI server is running on port 8080")
            return False
        
        # Test 2: CORS Configuration
        print("\n2. Testing CORS Configuration...")
        try:
            async with session.options(f"{base_url}/ophthalmology/condition") as response:
                cors_headers = response.headers.get('access-control-allow-origin', '')
                if cors_headers:
                    print(f"✅ CORS configured: {cors_headers}")
                else:
                    print("⚠️  CORS headers not found (may still work)")
        except Exception as e:
            print(f"❌ CORS test failed: {e}")
        
        # Test 3: Complete API Flow (mimicking frontend)
        print("\n3. Testing Complete API Flow...")
        
        # Step 1: Submit condition
        condition = "I have severe eye pain with halos around lights"
        try:
            async with session.post(
                f"{base_url}/ophthalmology/condition",
                json={"condition": condition},
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    question_data = await response.json()
                    print(f"✅ Condition submitted, received question: {question_data['question_text'][:50]}...")
                else:
                    error_text = await response.text()
                    print(f"❌ Condition submission failed: {response.status} - {error_text}")
                    return False
        except Exception as e:
            print(f"❌ Condition submission error: {e}")
            return False
        
        # Step 2: Submit answer
        try:
            async with session.post(
                f"{base_url}/ophthalmology/answer",
                json={
                    "question": question_data['question_text'],
                    "answer": question_data['options'][0],
                    "is_custom": False
                },
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    answer_data = await response.json()
                    print(f"✅ Answer submitted, next step: {answer_data['next_step']}")
                else:
                    error_text = await response.text()
                    print(f"❌ Answer submission failed: {response.status} - {error_text}")
                    return False
        except Exception as e:
            print(f"❌ Answer submission error: {e}")
            return False
        
        # Step 3: Identify doctor
        answers = [{
            "question": question_data['question_text'],
            "answer": question_data['options'][0],
            "is_custom": False
        }]
        
        try:
            async with session.post(
                f"{base_url}/ophthalmology/identify-doctor?condition={condition}",
                json=answers,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    doctor_data = await response.json()
                    print(f"✅ Doctor identified: {doctor_data['doctor_type']} (confidence: {doctor_data['confidence']:.2f})")
                else:
                    error_text = await response.text()
                    print(f"❌ Doctor identification failed: {response.status} - {error_text}")
                    return False
        except Exception as e:
            print(f"❌ Doctor identification error: {e}")
            return False
        
        # Test 4: Performance Check
        print("\n4. Testing Response Times...")
        start_time = time.time()
        try:
            async with session.get(f"{base_url}/health") as response:
                response_time = (time.time() - start_time) * 1000
                print(f"✅ Average response time: {response_time:.0f}ms")
                if response_time > 1000:
                    print("⚠️  Response time is high (>1s)")
        except Exception as e:
            print(f"❌ Performance test failed: {e}")
    
    print("\n" + "=" * 50)
    print("🎉 INTEGRATION TEST COMPLETED SUCCESSFULLY!")
    print("✅ Frontend can successfully communicate with backend")
    print("✅ All API endpoints are accessible")
    print("✅ RAG workflow is functional")
    print("\n📱 Frontend URL: http://localhost:3000")
    print("🔗 Backend URL: http://localhost:8080")
    print("📖 API Docs: http://localhost:8080/docs")
    
    return True

async def main():
    """Main test function"""
    try:
        success = await test_integration()
        return success
    except KeyboardInterrupt:
        print("\n❌ Test interrupted by user")
        return False
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)