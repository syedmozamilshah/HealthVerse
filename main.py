import asyncio
import os
import subprocess
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def start_mcp_server():
    """Start the MCP server in a separate process"""
    print("Starting MCP server...")
    mcp_process = subprocess.Popen(
        ["python", "mcp_server/server.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    # Wait a moment for the server to start
    time.sleep(2)
    return mcp_process

async def start_fastapi_server():
    """Start the FastAPI server in a separate process"""
    print("Starting FastAPI server...")
    api_process = subprocess.Popen(
        ["python", "app/main.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    # Wait a moment for the server to start
    time.sleep(2)
    return api_process

async def run_demo():
    """Run a demonstration of the ophthalmology assistant system"""
    from agents.ophthalmology.agent import OphthalmologyAgent
    
    print("Initializing Ophthalmology Assistant...")
    agent = OphthalmologyAgent()
    try:
        await agent.initialize()
        
        # Example condition
        condition = "I have blurry vision and eye pain that started yesterday"
        print(f"\nUser condition: {condition}")
        
        # Run the agent
        print("\nProcessing...")
        result = await agent.run(condition)
        
        return result
    except Exception as e:
        print(f"Error running demo: {e}")
        import traceback
        traceback.print_exc()
        return {"error": str(e)}
    
    # Display the result
    print("\n===== RESULT =====")
    if "error" in result and result["error"]:
        print(f"Error: {result['error']}")
    else:
        doctor_id = result.get("doctor_identification", {})
        doctor_summary = result.get("doctor_summary", {})
        
        print(f"Recommended Doctor: {doctor_id.get('doctor_type', 'Unknown')}")
        print(f"Confidence: {doctor_id.get('confidence', 0.0):.2f}")
        print(f"Reasoning: {doctor_id.get('reasoning', 'N/A')}")
        
        print("\nDoctor Summary:")
        print(doctor_summary.get("summary", "No summary available."))
        
        print("\nKey Symptoms:")
        for symptom in doctor_summary.get("key_symptoms", []):
            print(f"- {symptom}")
        
        if doctor_summary.get("recommended_tests"):
            print("\nRecommended Tests:")
            for test in doctor_summary.get("recommended_tests", []):
                print(f"- {test}")

async def main():
    """Main function to run the system"""
    mcp_process = None
    api_process = None
    
    try:
        # Start the MCP server
        mcp_process = await start_mcp_server()
        
        # Start the FastAPI server
        api_process = await start_fastapi_server()
        
        # Run the demo
        result = await run_demo()
        print("\nDemo result:", result)
        
        # Keep the servers running
        print("\nServers are running. Press Ctrl+C to stop.")
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down...")
    except Exception as e:
        print(f"\nError in main: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Terminate the servers
        if mcp_process:
            print("Stopping MCP server...")
            mcp_process.terminate()
        if api_process:
            print("Stopping FastAPI server...")
            api_process.terminate()

if __name__ == "__main__":
    asyncio.run(main())