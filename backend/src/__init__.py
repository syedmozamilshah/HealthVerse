# Ophthalmology Agent Backend Package
import os
import sys

# Add the parent directory (backend) to the Python path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)