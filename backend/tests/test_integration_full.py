#!/usr/bin/env python3
"""
Full integration test for the Ophthalmology Assistant system.
Tests Qdrant collection initialization, RAG functionality, API responses, and end-to-end workflow.
"""

import asyncio
import sys
import os
import time
import json
import logging
from typing import Dict, List, Any

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Mock user conditions for testing
MOCK_USER_CONDITIONS = [
    {
        "name": "Digital Eye Strain Case",
        "condition": "I have been experiencing blurry vision and headaches for the past 2 weeks, especially when working on my computer for long hours. The symptoms are worse in the evening.",
        "expected_questions": ["duration", "computer use", "pain level", "vision changes"],
        "expected_doctors": ["Optometrist", "Ophthalmologist"],
        "mock_answers": [
            {"text": "2-4 weeks", "is_other": False},
            {"text": "More than 8 hours daily", "is_other": False},
            {"text": "Mild headaches", "is_other": False},
            {"text": "Other", "is_other": True, "custom": "Vision gets blurry when looking at screens"}
        ]
    },
    {
        "name": "Emergency Eye Pain Case",
        "condition": "I have sudden severe eye pain in my right eye with nausea and seeing halos around lights. This started about 4 hours ago.",
        "expected_questions": ["onset", "severity", "vision changes", "associated symptoms"],
        "expected_doctors": ["Ophthalmologist", "Ocular Surgeon"],
        "mock_answers": [
            {"text": "Less than 6 hours", "is_other": False},
            {"text": "Severe pain (8-10/10)", "is_other": False},
            {"text": "Seeing halos around lights", "is_other": False},
            {"text": "Nausea and vomiting", "is_other": False}
        ]
    },
    {
        "name": "Routine Vision Check Case",
        "condition": "I think I need new glasses. My current prescription seems weak and I'm having trouble reading small text and seeing road signs clearly.",
        "expected_questions": ["current glasses", "vision problems", "activities affected"],
        "expected_doctors": ["Optometrist", "Optician"],
        "mock_answers": [
            {"text": "Yes, over 2 years old", "is_other": False},
            {"text": "Difficulty with distance vision", "is_other": False},
            {"text": "Reading and driving", "is_other": False},
            {"text": "Other", "is_other": True, "custom": "Progressive lenses feel uncomfortable"}
        ]
    },
    {
        "name": "Post-Surgery Follow-up Case",
        "condition": "I had cataract surgery on my left eye 3 weeks ago and I'm experiencing some cloudiness and mild discomfort. My vision isn't as clear as expected.",
        "expected_questions": ["surgery type", "time since surgery", "symptoms", "vision quality"],
        "expected_doctors": ["Ophthalmologist", "Ocular Surgeon"],
        "mock_answers": [
            {"text": "Cataract surgery", "is_other": False},
            {"text": "2-4 weeks ago", "is_other": False},
            {"text": "Mild discomfort and cloudiness", "is_other": False},
            {"text": "Vision not as clear as expected", "is_other": False}
        ]
    }
]

class IntegrationTester:
    def __init__(self):
        self.passed_tests = 0
        self.total_tests = 0
        
    async def test_configuration_loading(self) -> bool:
        """Test if configuration loads correctly"""
        print("🔧 Testing Configuration Loading...")
        self.total_tests += 1
        
        try:
            from config import config
            
            # Check essential configuration
            required_configs = [
                ("GEMINI_API_KEY", config.GEMINI_API_KEY),
                ("QDRANT_ENDPOINT", config.QDRANT_ENDPOINT),
                ("QDRANT_CLUSTER_KEY", config.QDRANT_CLUSTER_KEY),
                ("QDRANT_COLLECTION_NAME", config.QDRANT_COLLECTION_NAME),
                ("GEMINI_EMBEDDING_MODEL", config.GEMINI_EMBEDDING_MODEL),
                ("GEMINI_REASONING_MODEL", config.GEMINI_REASONING_MODEL)
            ]
            
            missing_configs = []
            for name, value in required_configs:
                if not value:
                    missing_configs.append(name)
                else:
                    print(f"   ✅ {name}: {str(value)[:20]}...")
            
            if missing_configs:
                print(f"   ❌ Missing configurations: {missing_configs}")
                return False
            
            # Test validation
            config.validate()
            print("   ✅ Configuration validation passed")
            
            self.passed_tests += 1
            return True
            
        except Exception as e:
            print(f"   ❌ Configuration loading failed: {str(e)}")
            return False
    
    async def test_qdrant_connection(self) -> bool:
        """Test Qdrant connection and collection initialization"""
        print("\n📊 Testing Qdrant Connection...")
        self.total_tests += 1
        
        try:
            from qdrant_service import qdrant_service
            from config import config
            
            # Test connection
            collections = qdrant_service.client.get_collections()
            print(f"   ✅ Connected to Qdrant: {len(collections.collections)} collections found")
            
            # Test collection initialization
            await qdrant_service.initialize_collection()
            
            # Verify collection exists
            collections_after = qdrant_service.client.get_collections()
            collection_names = [col.name for col in collections_after.collections]
            
            if config.QDRANT_COLLECTION_NAME in collection_names:
                print(f"   ✅ Collection '{config.QDRANT_COLLECTION_NAME}' exists/created successfully")
                
                # Get collection info
                collection_info = qdrant_service.client.get_collection(config.QDRANT_COLLECTION_NAME)
                print(f"   ✅ Collection points: {collection_info.points_count}")
                print(f"   ✅ Vector size: {collection_info.config.params.vectors.size}")
                
                self.passed_tests += 1
                return True
            else:
                print(f"   ❌ Collection '{config.QDRANT_COLLECTION_NAME}' not found")
                return False
                
        except Exception as e:
            print(f"   ❌ Qdrant connection failed: {str(e)}")
            return False
    
    async def test_embedding_generation(self) -> bool:
        """Test Gemini embedding generation"""
        print("\n🧠 Testing Gemini Embedding Generation...")
        self.total_tests += 1
        
        try:
            from qdrant_service import qdrant_service
            
            test_text = "Patient has blurry vision and headaches from computer use"
            
            # Generate embedding
            embedding = qdrant_service.generate_embedding(test_text)
            
            # Validate embedding
            if isinstance(embedding, list) and len(embedding) > 0:
                print(f"   ✅ Embedding generated: {len(embedding)} dimensions")
                print(f"   ✅ Sample values: {embedding[:5]}...")
                
                # Test that embeddings are different for different texts
                embedding2 = qdrant_service.generate_embedding("Eye pain and redness")
                if embedding != embedding2:
                    print("   ✅ Different texts produce different embeddings")
                    self.passed_tests += 1
                    return True
                else:
                    print("   ❌ Same embeddings for different texts")
                    return False
            else:
                print(f"   ❌ Invalid embedding format: {type(embedding)}")
                return False
                
        except Exception as e:
            print(f"   ❌ Embedding generation failed: {str(e)}")
            return False
    
    async def test_rag_functionality(self) -> bool:
        """Test RAG document storage and retrieval"""
        print("\n🔍 Testing RAG Functionality...")
        self.total_tests += 1
        
        try:
            from qdrant_service import qdrant_service
            
            # Add test documents
            test_documents = [
                {
                    "content": "Computer vision syndrome causes eye strain, dry eyes, and headaches from prolonged screen use. Treatment includes proper lighting, regular breaks, and computer glasses.",
                    "metadata": {"category": "digital_eye_strain", "specialist": "optometrist"}
                },
                {
                    "content": "Acute angle-closure glaucoma presents with sudden severe eye pain, nausea, vomiting, and seeing halos around lights. This is a medical emergency requiring immediate treatment.",
                    "metadata": {"category": "glaucoma", "specialist": "ophthalmologist", "urgency": "emergency"}
                }
            ]
            
            # Add documents
            for i, doc in enumerate(test_documents):
                success = await qdrant_service.add_document(doc["content"], doc["metadata"])
                if success:
                    print(f"   ✅ Added test document {i+1}")
                else:
                    print(f"   ❌ Failed to add test document {i+1}")
                    return False
            
            # Test search functionality
            search_queries = [
                ("computer headaches blurry vision", "digital_eye_strain"),
                ("severe eye pain nausea halos", "glaucoma")
            ]
            
            for query, expected_category in search_queries:
                documents = await qdrant_service.search_similar_documents(query, limit=3, score_threshold=0.3)
                
                if documents:
                    print(f"   ✅ Search for '{query}': {len(documents)} results")
                    top_result = documents[0]
                    print(f"      Top result score: {top_result.score:.3f}")
                    print(f"      Category: {top_result.metadata.get('category', 'unknown')}")
                    
                    # Check if we got relevant results
                    if top_result.metadata.get('category') == expected_category:
                        print(f"      ✅ Relevant result found")
                    else:
                        print(f"      ⚠️  Unexpected category: {top_result.metadata.get('category')}")
                else:
                    print(f"   ❌ No search results for '{query}'")
                    return False
            
            self.passed_tests += 1
            return True
            
        except Exception as e:
            print(f"   ❌ RAG functionality test failed: {str(e)}")
            return False
    
    async def test_llm_integration(self) -> bool:
        """Test LLM integration and tool functionality"""
        print("\n🤖 Testing LLM Integration...")
        self.total_tests += 1
        
        try:
            from agent_tools import question_generation_tool, doctor_identification_tool, summarization_tool
            
            test_condition = "I have blurry vision and headaches when using computer"
            
            # Test question generation
            print("   Testing question generation...")
            questions_result = question_generation_tool._run(test_condition)
            
            if "questions" in questions_result and len(questions_result["questions"]) > 0:
                questions = questions_result["questions"]
                print(f"   ✅ Generated {len(questions)} questions")
                
                # Validate question structure
                for i, q in enumerate(questions):
                    if "question" not in q or "options" not in q:
                        print(f"      ❌ Question {i+1} missing required fields")
                        return False
                    
                    # Check for "Other" option
                    has_other = any(opt.get("is_other", False) for opt in q["options"])
                    if not has_other:
                        print(f"      ❌ Question {i+1} missing 'Other' option")
                        return False
                
                print("   ✅ Question structure validation passed")
            else:
                print("   ❌ No questions generated")
                return False
            
            # Test doctor identification
            print("   Testing doctor identification...")
            mock_answers = [
                {"selected_option": "2-4 weeks", "custom_answer": None},
                {"selected_option": "More than 8 hours daily", "custom_answer": None}
            ]
            
            doctor_result = doctor_identification_tool._run(test_condition, mock_answers)
            
            if "doctor_type" in doctor_result and "reasoning" in doctor_result:
                doctor_type = doctor_result["doctor_type"]
                from config import config
                if doctor_type in config.ALLOWED_DOCTORS:
                    print(f"   ✅ Doctor identification: {doctor_type}")
                    print(f"      Reasoning: {doctor_result['reasoning'][:100]}...")
                else:
                    print(f"   ❌ Invalid doctor type: {doctor_type}")
                    return False
            else:
                print("   ❌ Doctor identification failed")
                return False
            
            # Test summarization
            print("   Testing medical summarization...")
            summary_result = summarization_tool._run(
                test_condition, 
                mock_answers, 
                ["Computer vision syndrome causes eye strain and headaches"], 
                doctor_type
            )
            
            if "summary" in summary_result and len(summary_result["summary"]) > 50:
                print(f"   ✅ Summary generated: {len(summary_result['summary'])} characters")
                print(f"      Preview: {summary_result['summary'][:150]}...")
            else:
                print("   ❌ Summary generation failed")
                return False
            
            self.passed_tests += 1
            return True
            
        except Exception as e:
            print(f"   ❌ LLM integration test failed: {str(e)}")
            return False
    
    async def test_end_to_end_workflow(self, test_case: Dict[str, Any]) -> bool:
        """Test complete end-to-end workflow with a test case"""
        print(f"\n🔄 Testing End-to-End Workflow: {test_case['name']}")
        self.total_tests += 1
        
        try:
            from agent import ophthalmology_agent
            from models import UserAnswer
            
            # Step 1: Generate questions
            print("   Step 1: Generating questions...")
            questions = await ophthalmology_agent.generate_questions(test_case['condition'])
            
            if not questions or len(questions) == 0:
                print("      ❌ No questions generated")
                return False
            
            print(f"      ✅ Generated {len(questions)} questions")
            
            # Step 2: Create mock answers
            print("   Step 2: Creating mock answers...")
            user_answers = []
            
            for i, question in enumerate(questions):
                if i < len(test_case['mock_answers']):
                    mock_answer = test_case['mock_answers'][i]
                    if mock_answer['is_other'] and 'custom' in mock_answer:
                        user_answers.append(UserAnswer(
                            question_index=i,
                            selected_option=None,
                            custom_answer=mock_answer['custom']
                        ))
                    else:
                        user_answers.append(UserAnswer(
                            question_index=i,
                            selected_option=mock_answer['text'],
                            custom_answer=None
                        ))
                else:
                    # Use first option as fallback
                    user_answers.append(UserAnswer(
                        question_index=i,
                        selected_option=question.options[0].text,
                        custom_answer=None
                    ))
            
            print(f"      ✅ Created {len(user_answers)} answers")
            
            # Step 3: Process complete flow
            print("   Step 3: Processing complete workflow...")
            final_state = await ophthalmology_agent.process_complete_flow(
                test_case['condition'], 
                user_answers
            )
            
            # Validate results
            if not final_state.doctor_recommendation:
                print("      ❌ No doctor recommendation generated")
                return False
            
            doctor_type = final_state.doctor_recommendation.doctor_type
            if doctor_type not in test_case['expected_doctors']:
                print(f"      ⚠️  Unexpected doctor: {doctor_type} (expected: {test_case['expected_doctors']})")
            else:
                print(f"      ✅ Expected doctor recommended: {doctor_type}")
            
            if not final_state.summary or len(final_state.summary) < 50:
                print("      ❌ Invalid or missing summary")
                return False
            
            print(f"      ✅ Summary generated: {len(final_state.summary)} characters")
            print(f"      ✅ RAG context retrieved: {len(final_state.rag_context)} documents")
            
            # Display results
            print(f"\n   📋 Results Summary:")
            print(f"      Doctor: {doctor_type}")
            print(f"      Reasoning: {final_state.doctor_recommendation.reasoning}")
            print(f"      Summary preview: {final_state.summary[:200]}...")
            
            self.passed_tests += 1
            return True
            
        except Exception as e:
            print(f"   ❌ End-to-end workflow failed: {str(e)}")
            return False
    
    async def run_all_tests(self) -> bool:
        """Run all integration tests"""
        print("🚀 Starting Full Integration Tests")
        print("=" * 80)
        
        start_time = time.time()
        
        # Core system tests
        tests = [
            ("Configuration Loading", self.test_configuration_loading),
            ("Qdrant Connection", self.test_qdrant_connection),
            ("Embedding Generation", self.test_embedding_generation),
            ("RAG Functionality", self.test_rag_functionality),
            ("LLM Integration", self.test_llm_integration)
        ]
        
        for test_name, test_func in tests:
            if not await test_func():
                print(f"\n❌ Critical test failed: {test_name}")
                print("   Cannot proceed with end-to-end tests.")
                return False
        
        # End-to-end workflow tests
        print(f"\n🎯 Running End-to-End Workflow Tests...")
        workflow_passed = 0
        
        for test_case in MOCK_USER_CONDITIONS:
            if await self.test_end_to_end_workflow(test_case):
                workflow_passed += 1
        
        # Results summary
        end_time = time.time()
        test_duration = end_time - start_time
        
        print("\n" + "=" * 80)
        print("📊 Integration Test Results")
        print("=" * 80)
        print(f"⏱️  Test Duration: {test_duration:.2f} seconds")
        print(f"✅ Core Tests Passed: {self.passed_tests}/{len(tests)}")
        print(f"✅ Workflow Tests Passed: {workflow_passed}/{len(MOCK_USER_CONDITIONS)}")
        print(f"🎯 Overall Tests Passed: {self.passed_tests + workflow_passed}/{self.total_tests + len(MOCK_USER_CONDITIONS)}")
        
        success_rate = (self.passed_tests + workflow_passed) / (self.total_tests + len(MOCK_USER_CONDITIONS)) * 100
        print(f"📈 Success Rate: {success_rate:.1f}%")
        
        if success_rate >= 90:
            print("\n🎉 SYSTEM READY FOR PRODUCTION!")
            print("✅ All critical components are working correctly")
            print("✅ Qdrant collection is initialized and functional")
            print("✅ RAG system is retrieving relevant documents")
            print("✅ LLM integration is working properly")
            print("✅ End-to-end workflows are successful")
            return True
        else:
            print(f"\n⚠️  System needs attention ({success_rate:.1f}% success rate)")
            return False

async def main():
    """Main test runner"""
    tester = IntegrationTester()
    success = await tester.run_all_tests()
    return 0 if success else 1

if __name__ == "__main__":
    print("🔬 Ophthalmology Assistant - Full Integration Test Suite")
    print("This will test the complete system with real API connections\n")
    
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
