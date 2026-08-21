import asyncio
import os
import subprocess
import time
from dotenv import load_dotenv
from app.main import app

load_dotenv()

async def start_mcp_server():
    mcp_process = subprocess.Popen(
        ["python", "mcp_server/server.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    time.sleep(2)
    return mcp_process

async def start_fastapi_server():
    api_process = subprocess.Popen(
        ["python", "app/main.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    time.sleep(2)
    return api_process

async def run_demo():
    from agents.ophthalmology.agent import OphthalmologyAgent
    
    agent = OphthalmologyAgent()
    try:
        await agent.initialize()
        
        condition = "I have blurry vision and eye pain that started yesterday"
        print(f"\nUser condition: {condition}")
        
        result = await agent.run(condition)
        
        return result
    except Exception as e:
        print(f"Error running demo: {e}")
        import traceback
        traceback.print_exc()
        return {"error": str(e)}
    


async def main():
    mcp_process = None
    api_process = None
    
    try:
        mcp_process = await start_mcp_server()
        
        api_process = await start_fastapi_server()
        
        result = await run_demo()
        print("\nDemo result:", result)
        print("server running")
        
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down")
    except Exception as e:
        print(f"\nError in main: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if mcp_process:
            print("Stopping MCP server")
            mcp_process.terminate()
        if api_process:
            print("Stopping FastAPI server")
            api_process.terminate()

if __name__ == "__main__":
    asyncio.run(main())
