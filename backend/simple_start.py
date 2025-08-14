#!/usr/bin/env python3
"""
Simple Backend Launcher
========================

Direct launcher for the FastAPI backend without complex async startup.
"""

import os
import sys
from pathlib import Path

# Add backend to path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

def main():
    """Start the backend server directly"""
    print("🚀 Starting Ophthalmology Agent Backend...")
    
    try:
        # Import after path setup
        import uvicorn
        from src.api.main import app
        
        print("✅ Backend modules loaded successfully")
        print("🌐 Starting server on http://localhost:8000")
        print("📖 API Documentation: http://localhost:8000/docs")
        print("=" * 50)
        
        # Start the server
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8000,
            reload=False,
            log_level="info"
        )
        
    except KeyboardInterrupt:
        print("\n🛑 Server shutdown requested")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Server startup failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
