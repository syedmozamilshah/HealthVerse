#!/usr/bin/env python3
"""
Comprehensive System Validation Test
Tests RAG retrieval, MCP server, doctor recommendations, and question generation
"""

import asyncio
import sys
import os
from typing import List, Dict, Any

# Add project root to path
sys.path.insert(0, os.path.abspath('.'))

# Test imports
try:
    from rag.qdrant.client import QdrantManager
    from rag.data_loader import DataLoader
    from mcp_server.tools.ophthalmology_tools import (
        query_qdrant, generate_followup_question, identify_doctor, 
        generate_doctor_summary, UserAnswer, QdrantResult
    )
    from agents.ophthalmology.agent import OphthalmologyAgent
    print("✅ All imports successful")
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

class SystemValidator:
    def __init__(self):
        self.qdrant_manager = None
        self.test_results = {}
        
    async def setup(self):
        """Initialize and populate Qdrant with real data"""
        print("\n" + "="*70)
        print("🔧 SYSTEM SETUP")
        print("="*70)
        
        try:
            # Initialize Qdrant and populate with real data
            loader = DataLoader()
            success = await loader.populate_qdrant()
            
            if success:
                # Keep reference to the populated instance
                self.qdrant_manager = loader.qdrant_manager
                print("✅ Qdrant populated with real medical data")
                return True
            else:
                print("❌ Failed to populate Qdrant")
                return False
                
        except Exception as e:
            print(f"❌ Setup error: {e}")
            return False
    
    async def test_rag_retrieval(self):
        """Test 1: RAG document retrieval functionality"""
        print("\n" + "="*70)
        print("📄 TEST 1: RAG DOCUMENT RETRIEVAL")
        print("="*70)
        
        test_queries = [
            {
                "query": "severe eye pain with halos around lights",
                "expected_keywords": ["glaucoma", "pain", "halos", "emergency"],
                "description": "Emergency glaucoma symptoms"
            },
            {
                "query": "blurry vision difficulty reading",
                "expected_keywords": ["vision", "blurry", "reading", "refractive"],
                "description": "Vision correction needs"
            },
            {
                "query": "red itchy eyes with discharge",
                "expected_keywords": ["infection", "red", "discharge", "inflammation"],
                "description": "Eye infection symptoms"
            },
            {
                "query": "gradual vision loss peripheral",
                "expected_keywords": ["vision loss", "peripheral", "gradual"],
                "description": "Progressive vision issues"
            }
        ]
        
        retrieval_results = []
        
        for test_case in test_queries:
            print(f"\n🔍 Testing: {test_case['description']}")
            print(f"Query: '{test_case['query']}'")
            
            try:
                # Search using the populated Qdrant instance
                results = await self.qdrant_manager.search(test_case['query'])
                
                print(f"Retrieved: {len(results)} documents")
                
                if results:
                    # Show top result
                    top_result = results[0]
                    content = top_result.get('content', '')
                    score = top_result.get('relevance_score', 0)
                    
                    print(f"Top result relevance: {score:.3f}")
                    print(f"Content: {content[:150]}...")
                    
                    # Check for expected keywords
                    content_lower = content.lower()
                    found_keywords = [kw for kw in test_case['expected_keywords'] 
                                    if kw.lower() in content_lower]
                    
                    print(f"Expected keywords found: {found_keywords}")
                    
                    retrieval_results.append({
                        'query': test_case['query'],
                        'results_count': len(results),
                        'top_score': score,
                        'keywords_found': len(found_keywords),
                        'keywords_expected': len(test_case['expected_keywords']),
                        'success': len(results) > 0 and score > 0.1
                    })
                else:
                    print("❌ No results returned")
                    retrieval_results.append({
                        'query': test_case['query'],
                        'results_count': 0,
                        'success': False
                    })
                    
            except Exception as e:
                print(f"❌ Error during search: {e}")
                retrieval_results.append({
                    'query': test_case['query'],
                    'error': str(e),
                    'success': False
                })
        
        # Summarize RAG retrieval results
        successful_retrievals = sum(1 for r in retrieval_results if r.get('success', False))
        total_tests = len(retrieval_results)
        
        print(f"\n📊 RAG Retrieval Summary: {successful_retrievals}/{total_tests} successful")
        self.test_results['rag_retrieval'] = {
            'success_rate': successful_retrievals / total_tests,
            'details': retrieval_results
        }
        
        return successful_retrievals > 0
    
    def test_mcp_server_tools(self):
        """Test 2: MCP server tools functionality"""
        print("\n" + "="*70)
        print("🔧 TEST 2: MCP SERVER TOOLS")
        print("="*70)
        
        tool_results = []
        
        # Test conditions and answers
        test_cases = [
            {
                "condition": "severe eye pain with halos and nausea",
                "answers": [
                    UserAnswer(question="Pain severity?", answer="10/10 excruciating", is_custom=False),
                    UserAnswer(question="Onset?", answer="Sudden, 2 hours ago", is_custom=False)
                ],
                "expected_doctor": "Ophthalmologist",
                "description": "Emergency glaucoma case"
            },
            {
                "condition": "blurry vision when reading",
                "answers": [
                    UserAnswer(question="Age?", answer="45 years old", is_custom=False),
                    UserAnswer(question="Distance vision?", answer="Distance is fine", is_custom=False)
                ],
                "expected_doctor": "Optometrist",
                "description": "Presbyopia case"
            }
        ]
        
        for test_case in test_cases:
            print(f"\n🧪 Testing: {test_case['description']}")
            print(f"Condition: {test_case['condition']}")
            
            try:
                # Test 1: RAG Query
                print("Testing query_qdrant...")
                rag_results = query_qdrant(test_case['condition'], test_case['answers'])
                print(f"✅ RAG query returned {len(rag_results)} results")
                
                # Test 2: Question Generation
                print("Testing generate_followup_question...")
                rag_context = "\n".join([r.content for r in rag_results]) if rag_results else ""
                question = generate_followup_question(test_case['condition'], test_case['answers'], rag_context)
                print(f"✅ Generated question: {question.question_text}")
                print(f"✅ Options count: {len(question.options)}")
                
                # Test 3: Doctor Identification
                print("Testing identify_doctor...")
                doctor_id = identify_doctor(test_case['condition'], test_case['answers'], rag_context)
                print(f"✅ Identified doctor: {doctor_id.doctor_type}")
                print(f"✅ Confidence: {doctor_id.confidence:.2f}")
                print(f"✅ Reasoning: {doctor_id.reasoning}")
                
                # Test 4: Summary Generation
                print("Testing generate_doctor_summary...")
                summary = generate_doctor_summary(test_case['condition'], test_case['answers'], 
                                                doctor_id.doctor_type, rag_results)
                print(f"✅ Generated summary: {summary.summary[:100]}...")
                
                tool_results.append({
                    'condition': test_case['condition'],
                    'rag_results_count': len(rag_results),
                    'question_generated': bool(question.question_text),
                    'doctor_identified': doctor_id.doctor_type,
                    'expected_doctor': test_case['expected_doctor'],
                    'confidence': doctor_id.confidence,
                    'summary_generated': bool(summary.summary),
                    'success': True
                })
                
            except Exception as e:
                print(f"❌ Tool test error: {e}")
                tool_results.append({
                    'condition': test_case['condition'],
                    'error': str(e),
                    'success': False
                })
        
        successful_tools = sum(1 for r in tool_results if r.get('success', False))
        total_tests = len(tool_results)
        
        print(f"\n📊 MCP Tools Summary: {successful_tools}/{total_tests} successful")
        self.test_results['mcp_tools'] = {
            'success_rate': successful_tools / total_tests,
            'details': tool_results
        }
        
        return successful_tools > 0
    
    def test_doctor_recommendations(self):
        """Test 3: Doctor recommendation accuracy"""
        print("\n" + "="*70)
        print("👨‍⚕️ TEST 3: DOCTOR RECOMMENDATION ACCURACY")
        print("="*70)
        
        recommendation_tests = [
            {
                "condition": "sudden severe eye pain with halos around lights and nausea",
                "answers": [UserAnswer(question="Pain severity?", answer="10/10", is_custom=False)],
                "rag_context": "Emergency acute angle-closure glaucoma. High urgency. Immediate ophthalmological intervention required.",
                "expected_doctors": ["Ophthalmologist"],
                "min_confidence": 0.85,
                "description": "Emergency glaucoma"
            },
            {
                "condition": "difficulty reading small text, need to squint",
                "answers": [UserAnswer(question="Age?", answer="Over 40", is_custom=False)],
                "rag_context": "Routine presbyopia. Low urgency. Optometrist can handle vision correction.",
                "expected_doctors": ["Optometrist"],
                "min_confidence": 0.70,
                "description": "Presbyopia"
            },
            {
                "condition": "eye trauma from accident, possible foreign object",
                "answers": [UserAnswer(question="Trauma type?", answer="Metal fragment", is_custom=False)],
                "rag_context": "Eye trauma requiring surgical evaluation. Ocular surgeon consultation needed.",
                "expected_doctors": ["Ocular Surgeon", "Ophthalmologist"],
                "min_confidence": 0.75,
                "description": "Eye trauma"
            },
            {
                "condition": "need new glasses prescription",
                "answers": [UserAnswer(question="Current prescription?", answer="2 years old", is_custom=False)],
                "rag_context": "Routine vision correction. Basic refraction needed. Optician can handle.",
                "expected_doctors": ["Optician", "Optometrist"],
                "min_confidence": 0.60,
                "description": "Routine glasses"
            }
        ]
        
        recommendation_results = []
        
        for test_case in recommendation_tests:
            print(f"\n🎯 Testing: {test_case['description']}")
            print(f"Condition: {test_case['condition']}")
            
            try:
                doctor_id = identify_doctor(test_case['condition'], test_case['answers'], test_case['rag_context'])
                
                is_correct_doctor = doctor_id.doctor_type in test_case['expected_doctors']
                meets_confidence = doctor_id.confidence >= test_case['min_confidence']
                
                print(f"Recommended: {doctor_id.doctor_type}")
                print(f"Expected: {', '.join(test_case['expected_doctors'])}")
                print(f"Confidence: {doctor_id.confidence:.2f} (min: {test_case['min_confidence']})")
                print(f"Correct doctor: {'✅' if is_correct_doctor else '❌'}")
                print(f"Meets confidence: {'✅' if meets_confidence else '❌'}")
                
                recommendation_results.append({
                    'description': test_case['description'],
                    'recommended_doctor': doctor_id.doctor_type,
                    'expected_doctors': test_case['expected_doctors'],
                    'confidence': doctor_id.confidence,
                    'min_confidence': test_case['min_confidence'],
                    'correct_doctor': is_correct_doctor,
                    'meets_confidence': meets_confidence,
                    'success': is_correct_doctor and meets_confidence
                })
                
            except Exception as e:
                print(f"❌ Recommendation error: {e}")
                recommendation_results.append({
                    'description': test_case['description'],
                    'error': str(e),
                    'success': False
                })
        
        successful_recommendations = sum(1 for r in recommendation_results if r.get('success', False))
        total_tests = len(recommendation_results)
        
        print(f"\n📊 Doctor Recommendation Summary: {successful_recommendations}/{total_tests} accurate")
        self.test_results['doctor_recommendations'] = {
            'success_rate': successful_recommendations / total_tests,
            'details': recommendation_results
        }
        
        return successful_recommendations > 0
    
    def test_question_generation(self):
        """Test 4: Question generation relevance"""
        print("\n" + "="*70)
        print("❓ TEST 4: QUESTION GENERATION RELEVANCE")
        print("="*70)
        
        question_tests = [
            {
                "condition": "severe eye pain",
                "previous_answers": [],
                "rag_context": "Emergency glaucoma symptoms. Need to assess pain severity and associated symptoms.",
                "expected_themes": ["pain", "severity", "duration", "associated symptoms"],
                "description": "Initial emergency question"
            },
            {
                "condition": "blurry vision",
                "previous_answers": [
                    UserAnswer(question="Duration?", answer="1 week", is_custom=False)
                ],
                "rag_context": "Vision issues. Need to determine if one or both eyes affected.",
                "expected_themes": ["eyes affected", "one eye", "both eyes", "vision"],
                "description": "Follow-up vision question"
            },
            {
                "condition": "eye discomfort",
                "previous_answers": [
                    UserAnswer(question="Duration?", answer="2 days", is_custom=False),
                    UserAnswer(question="Eyes affected?", answer="Both eyes", is_custom=False)
                ],
                "rag_context": "General eye discomfort. Consider light sensitivity, discharge, or other symptoms.",
                "expected_themes": ["light", "sensitivity", "discharge", "symptoms"],
                "description": "Further diagnostic question"
            }
        ]
        
        question_results = []
        
        for test_case in question_tests:
            print(f"\n💭 Testing: {test_case['description']}")
            print(f"Condition: {test_case['condition']}")
            print(f"Previous answers: {len(test_case['previous_answers'])}")
            
            try:
                question = generate_followup_question(
                    test_case['condition'], 
                    test_case['previous_answers'], 
                    test_case['rag_context']
                )
                
                print(f"Generated question: {question.question_text}")
                print(f"Options: {question.options}")
                
                # Check relevance
                question_lower = question.question_text.lower()
                options_text = " ".join(question.options).lower()
                combined_text = question_lower + " " + options_text
                
                relevant_themes = [theme for theme in test_case['expected_themes'] 
                                 if theme.lower() in combined_text]
                
                has_options = len(question.options) >= 3
                has_other_option = any("other" in opt.lower() for opt in question.options)
                is_relevant = len(relevant_themes) > 0
                
                print(f"Expected themes: {test_case['expected_themes']}")
                print(f"Found themes: {relevant_themes}")
                print(f"Has sufficient options: {'✅' if has_options else '❌'}")
                print(f"Has 'Other' option: {'✅' if has_other_option else '❌'}")
                print(f"Thematically relevant: {'✅' if is_relevant else '❌'}")
                
                question_results.append({
                    'description': test_case['description'],
                    'question_text': question.question_text,
                    'options_count': len(question.options),
                    'has_other_option': has_other_option,
                    'relevant_themes': relevant_themes,
                    'expected_themes': test_case['expected_themes'],
                    'is_relevant': is_relevant,
                    'success': has_options and has_other_option and is_relevant
                })
                
            except Exception as e:
                print(f"❌ Question generation error: {e}")
                question_results.append({
                    'description': test_case['description'],
                    'error': str(e),
                    'success': False
                })
        
        successful_questions = sum(1 for r in question_results if r.get('success', False))
        total_tests = len(question_results)
        
        print(f"\n📊 Question Generation Summary: {successful_questions}/{total_tests} relevant")
        self.test_results['question_generation'] = {
            'success_rate': successful_questions / total_tests,
            'details': question_results
        }
        
        return successful_questions > 0
    
    async def test_end_to_end_integration(self):
        """Test 5: End-to-end system integration"""
        print("\n" + "="*70)
        print("🔄 TEST 5: END-TO-END INTEGRATION")
        print("="*70)
        
        try:
            # Initialize agent
            agent = OphthalmologyAgent()
            await agent.initialize()
            
            test_conditions = [
                "I have severe eye pain with halos around lights and feel nauseous",
                "I'm having trouble reading small text and need to squint",
                "My eyes are red and itchy with some discharge"
            ]
            
            integration_results = []
            
            for condition in test_conditions:
                print(f"\n🔄 Testing condition: {condition}")
                
                try:
                    # Run full agent workflow
                    result = await agent.run(condition)
                    
                    # Check result structure
                    has_doctor_id = 'doctor_identification' in result
                    has_summary = 'doctor_summary' in result
                    has_rag_context = 'rag_context' in result
                    
                    print(f"Has doctor identification: {'✅' if has_doctor_id else '❌'}")
                    print(f"Has summary: {'✅' if has_summary else '❌'}")
                    print(f"Has RAG context: {'✅' if has_rag_context else '❌'}")
                    
                    if has_doctor_id:
                        doctor_type = result['doctor_identification'].get('doctor_type', 'Unknown')
                        confidence = result['doctor_identification'].get('confidence', 0)
                        print(f"Recommended doctor: {doctor_type} (confidence: {confidence:.2f})")
                    
                    integration_results.append({
                        'condition': condition,
                        'has_doctor_id': has_doctor_id,
                        'has_summary': has_summary,
                        'has_rag_context': has_rag_context,
                        'success': has_doctor_id and has_summary
                    })
                    
                except Exception as e:
                    print(f"❌ Integration error for condition: {e}")
                    integration_results.append({
                        'condition': condition,
                        'error': str(e),
                        'success': False
                    })
            
            successful_integrations = sum(1 for r in integration_results if r.get('success', False))
            total_tests = len(integration_results)
            
            print(f"\n📊 Integration Summary: {successful_integrations}/{total_tests} successful")
            self.test_results['integration'] = {
                'success_rate': successful_integrations / total_tests,
                'details': integration_results
            }
            
            return successful_integrations > 0
            
        except Exception as e:
            print(f"❌ Integration test setup error: {e}")
            return False
    
    def generate_final_report(self):
        """Generate comprehensive test report"""
        print("\n" + "="*70)
        print("📋 FINAL SYSTEM VALIDATION REPORT")
        print("="*70)
        
        overall_success = True
        
        for test_name, results in self.test_results.items():
            success_rate = results.get('success_rate', 0)
            status = "✅ PASS" if success_rate >= 0.5 else "❌ FAIL"
            print(f"{test_name.upper().replace('_', ' ')}: {status} ({success_rate:.1%})")
            
            if success_rate < 0.5:
                overall_success = False
        
        print("\n" + "="*70)
        if overall_success:
            print("🎉 SYSTEM VALIDATION: OVERALL SUCCESS")
            print("The RAG-enabled ophthalmology system is functioning correctly!")
        else:
            print("⚠️  SYSTEM VALIDATION: NEEDS ATTENTION")
            print("Some components require optimization.")
        print("="*70)
        
        return overall_success

async def main():
    """Main validation function"""
    print("🏥 OPHTHALMOLOGY ASSISTANT SYSTEM VALIDATION")
    print("Testing RAG retrieval, MCP tools, doctor recommendations, and question generation")
    
    validator = SystemValidator()
    
    # Setup
    setup_success = await validator.setup()
    if not setup_success:
        print("❌ Setup failed. Cannot proceed with tests.")
        return False
    
    # Run all tests
    test_1 = await validator.test_rag_retrieval()
    test_2 = validator.test_mcp_server_tools()
    test_3 = validator.test_doctor_recommendations()
    test_4 = validator.test_question_generation()
    test_5 = await validator.test_end_to_end_integration()
    
    # Generate report
    overall_success = validator.generate_final_report()
    
    return overall_success

if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n❌ Validation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Validation failed with error: {e}")
        sys.exit(1)