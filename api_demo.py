import asyncio
import aiohttp
import json

async def api_demo():
    """Demonstrate the API endpoints for the ophthalmology assistant"""
    base_url = "http://localhost:8080/ophthalmology"
    
    async with aiohttp.ClientSession() as session:
        # Step 1: Submit the initial condition
        print("Step 1: Submitting initial condition...")
        condition = "I have blurry vision and eye pain that started yesterday"
        
        try:
            async with session.post(
                f"{base_url}/condition",
                json={"condition": condition},
                timeout=aiohttp.ClientTimeout(total=30)  # 30 second timeout
            ) as response:
                if response.status == 200:
                    question_data = await response.json()
                    print(f"Question: {question_data['question_text']}")
                    print("Options:")
                    for i, option in enumerate(question_data['options']):
                        print(f"  {i+1}. {option}")
                    
                    # Simulate user selecting an option
                    selected_option = question_data['options'][1]  # Select the second option
                    print(f"\nUser selects: {selected_option}")
                else:
                    error = await response.text()
                    print(f"Error: {response.status} - {error}")
                    return
        except aiohttp.ClientError as e:
            print(f"Connection error during condition submission: {e}")
            return
        
        # Step 2: Submit the answer and get the next question
        print("\nStep 2: Submitting answer and getting next question...")
        
        try:
            async with session.post(
                f"{base_url}/answer",
                json={
                    "question": question_data['question_text'],
                    "answer": selected_option,
                    "is_custom": False
                },
                timeout=aiohttp.ClientTimeout(total=30)  # 30 second timeout
            ) as response:
                if response.status == 200:
                    next_step_data = await response.json()
                    
                    if next_step_data['next_step'] == 'question':
                        question_data = next_step_data['question']
                        print(f"Next question: {question_data['question_text']}")
                        print("Options:")
                        for i, option in enumerate(question_data['options']):
                            print(f"  {i+1}. {option}")
                        
                        # Simulate user selecting an option
                        selected_option = question_data['options'][2]  # Select the third option
                        print(f"\nUser selects: {selected_option}")
                    elif next_step_data['next_step'] == 'identify_doctor':
                        print("Moving to doctor identification...")
                    else:
                        print("Ready to identify doctor")
                else:
                    error = await response.text()
                    print(f"Error: {response.status} - {error}")
                    return
        except aiohttp.ClientError as e:
            print(f"Connection error during answer submission: {e}")
            return
        
        # Step 3: Identify the doctor
        print("\nStep 3: Identifying the most appropriate doctor...")
        
        # In a real implementation, we would have collected all answers
        # For this demo, we'll use the two answers we've simulated
        answers = [
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
        
        try:
            async with session.post(
                f"{base_url}/identify-doctor?condition={condition}",
                json=answers,
                timeout=aiohttp.ClientTimeout(total=30)  # 30 second timeout
            ) as response:
                if response.status == 200:
                    doctor_data = await response.json()
                    print(f"Identified doctor: {doctor_data['doctor_type']}")
                    print(f"Confidence: {doctor_data['confidence']:.2f}")
                    print(f"Reasoning: {doctor_data['reasoning']}")
                else:
                    error = await response.text()
                    print(f"Error: {response.status} - {error}")
                    return
        except aiohttp.ClientError as e:
            print(f"Connection error during doctor identification: {e}")
            return
        
        # Step 4: Generate the doctor summary
        print("\nStep 4: Generating doctor summary...")
        
        try:
            async with session.post(
                f"{base_url}/summary?condition={condition}&doctor_type={doctor_data['doctor_type']}",
                json=answers,
                timeout=aiohttp.ClientTimeout(total=30)  # 30 second timeout
            ) as response:
                if response.status == 200:
                    summary_data = await response.json()
                    print(f"Doctor: {summary_data['doctor_type']}")
                    print("\nSummary:")
                    print(summary_data['summary'])
                    
                    print("\nKey Symptoms:")
                    for symptom in summary_data['key_symptoms']:
                        print(f"- {symptom}")
                    
                    if summary_data['recommended_tests']:
                        print("\nRecommended Tests:")
                        for test in summary_data['recommended_tests']:
                            print(f"- {test}")
                else:
                    error = await response.text()
                    print(f"Error: {response.status} - {error}")
                    return
        except aiohttp.ClientError as e:
            print(f"Connection error during summary generation: {e}")
            return
        
        # Step 5: Complete flow (alternative approach)
        print("\nStep 5: Running complete flow...")
        
        try:
            async with session.post(
                f"{base_url}/complete?condition={condition}",
                json=answers,
                timeout=aiohttp.ClientTimeout(total=30)  # 30 second timeout
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    print("Complete flow result:")
                    print(json.dumps(result, indent=2))
                else:
                    error = await response.text()
                    print(f"Error: {response.status} - {error}")
                    return
        except aiohttp.ClientError as e:
            print(f"Connection error during complete flow: {e}")
            return

if __name__ == "__main__":
    asyncio.run(api_demo())