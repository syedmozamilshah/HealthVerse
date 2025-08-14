#!/usr/bin/env python3
"""
Simple Backend Runner
====================

This is a simple wrapper to run the comprehensive startup script.
"""

import subprocess
import sys
from pathlib import Path

def main():
    """Run the comprehensive startup script"""
    backend_dir = Path(__file__).parent
    startup_script = backend_dir / "scripts" / "start_backend.py"
    
    if not startup_script.exists():
        print("❌ Startup script not found!")
        sys.exit(1)
    
    # Run the startup script
    try:
        subprocess.run([sys.executable, str(startup_script)], check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Backend startup failed with exit code {e.returncode}")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\n🛑 Backend shutdown requested")
        sys.exit(0)

if __name__ == "__main__":
    main()
