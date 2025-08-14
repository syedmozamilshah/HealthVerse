#!/usr/bin/env python3
"""
Comprehensive Backend Startup Script
====================================

This script provides detailed startup logging and initialization tracking
for the Ophthalmology Agent Backend API.

Features:
- Step-by-step startup logging
- Configuration validation
- Service health checks
- Error handling and troubleshooting
- Performance monitoring
"""

import os
import sys
import time
import asyncio
import logging
from datetime import datetime
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

# Enhanced logging configuration
def setup_logging():
    """Setup comprehensive logging for startup"""
    log_dir = backend_dir / "logs"
    log_dir.mkdir(exist_ok=True)
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        '%(asctime)s | %(name)-20s | %(levelname)-8s | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    simple_formatter = logging.Formatter(
        '%(asctime)s | %(levelname)-8s | %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # Setup root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(simple_formatter)
    console_handler.setLevel(logging.INFO)
    root_logger.addHandler(console_handler)
    
    # File handler
    log_file = log_dir / f"startup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(detailed_formatter)
    file_handler.setLevel(logging.DEBUG)
    root_logger.addHandler(file_handler)
    
    return logging.getLogger("startup")

def print_banner():
    """Print startup banner"""
    banner = """
╔══════════════════════════════════════════════════════════════════╗
║                    OPHTHALMOLOGY AGENT BACKEND                      ║
║                         Starting Up...                              ║
╚══════════════════════════════════════════════════════════════════╝
"""
    print(banner)

def check_python_version():
    """Check Python version compatibility"""
    logger = logging.getLogger("startup.python")
    
    python_version = sys.version_info
    logger.info(f"Python version: {python_version.major}.{python_version.minor}.{python_version.micro}")
    
    if python_version < (3, 8):
        logger.error("❌ Python 3.8+ required")
        sys.exit(1)
    
    logger.info("✅ Python version compatible")

def check_environment():
    """Check environment setup"""
    logger = logging.getLogger("startup.environment")
    
    logger.info("🔍 Checking environment setup...")
    
    # Check .env file
    env_file = backend_dir / ".env"
    if env_file.exists():
        logger.info("✅ .env file found")
    else:
        logger.warning("⚠️  .env file not found - using environment variables")
    
    # Check required directories
    required_dirs = ["src", "logs", "tests", "scripts"]
    for dir_name in required_dirs:
        dir_path = backend_dir / dir_name
        if dir_path.exists():
            logger.info(f"✅ Directory found: {dir_name}/")
        else:
            logger.error(f"❌ Missing directory: {dir_name}/")
            sys.exit(1)

def validate_configuration():
    """Validate configuration settings"""
    logger = logging.getLogger("startup.config")
    
    logger.info("🔧 Validating configuration...")
    
    try:
        from src.core.config import config
        
        # Test configuration validation
        config.validate()
        logger.info("✅ Configuration validation passed")
        
        # Log key settings (without sensitive data)
        logger.info(f"  - Host: {config.HOST}")
        logger.info(f"  - Port: {config.PORT}")
        logger.info(f"  - Debug: {config.DEBUG}")
        logger.info(f"  - Allowed Origins: {len(config.ALLOWED_ORIGINS)} origin(s)")
        logger.info(f"  - Allowed Doctors: {len(config.ALLOWED_DOCTORS)} type(s)")
        logger.info(f"  - Qdrant Collection: {config.QDRANT_COLLECTION_NAME}")
        
        # Check API keys (without revealing them)
        if config.GEMINI_API_KEY:
            logger.info(f"  - Gemini API Key: ****{config.GEMINI_API_KEY[-4:]}")
        else:
            logger.error("❌ Gemini API Key not configured")
            
        if config.QDRANT_CLUSTER_KEY:
            logger.info(f"  - Qdrant Cluster Key: ****{config.QDRANT_CLUSTER_KEY[-4:]}")
        else:
            logger.error("❌ Qdrant Cluster Key not configured")
            
        return config
        
    except Exception as e:
        logger.error(f"❌ Configuration validation failed: {str(e)}")
        sys.exit(1)

def check_dependencies():
    """Check required dependencies"""
    logger = logging.getLogger("startup.dependencies")
    
    logger.info("📦 Checking dependencies...")
    
    required_packages = [
        ("fastapi", "fastapi"),
        ("uvicorn", "uvicorn"),
        ("langchain", "langchain"),
        ("langchain_google_genai", "langchain_google_genai"),
        ("qdrant_client", "qdrant_client"),
        ("google.generativeai", "google-generativeai"),
        ("pydantic", "pydantic"),
        ("dotenv", "python-dotenv")
    ]
    
    missing_packages = []
    
    for import_name, package_name in required_packages:
        try:
            __import__(import_name)
            logger.info(f"[OK] {package_name}")
        except ImportError:
            logger.error(f"[MISSING] {package_name}")
            missing_packages.append(package_name)
    
    if missing_packages:
        logger.error("❌ Missing dependencies. Install with:")
        logger.error(f"   pip install {' '.join(missing_packages)}")
        sys.exit(1)
    
    logger.info("✅ All dependencies satisfied")

async def initialize_services(config):
    """Initialize all services"""
    logger = logging.getLogger("startup.services")
    
    logger.info("🚀 Initializing services...")
    
    # Initialize Qdrant service
    logger.info("  📊 Initializing Qdrant service...")
    try:
        from src.services.qdrant_service import qdrant_service
        await qdrant_service.initialize_collection()
        logger.info("  ✅ Qdrant service initialized")
    except Exception as e:
        logger.error(f"  ❌ Qdrant initialization failed: {str(e)}")
        logger.warning("  ⚠️  Continuing without Qdrant (RAG features disabled)")
    
    # Initialize agent
    logger.info("  🤖 Initializing agent...")
    try:
        from src.core.agent import ophthalmology_agent
        logger.info(f"  ✅ Agent initialized with {len(ophthalmology_agent.tools)} tools")
        
        # Check BindWithLLM status
        if hasattr(ophthalmology_agent, 'llm_with_tools') and ophthalmology_agent.llm_with_tools:
            logger.info("  ✅ BindWithLLM integration enabled")
        else:
            logger.info("  ⚠️  Using direct tool access (BindWithLLM not available)")
            
    except Exception as e:
        logger.error(f"  ❌ Agent initialization failed: {str(e)}")
        sys.exit(1)
    
    # Test LLM connection
    logger.info("  🧠 Testing LLM connection...")
    try:
        from src.tools.agent_tools import llm
        test_response = llm.invoke("Hello, this is a connection test.")
        logger.info("  ✅ LLM connection successful")
    except Exception as e:
        logger.error(f"  ❌ LLM connection failed: {str(e)}")
        sys.exit(1)

def run_startup_tests():
    """Run quick startup validation tests"""
    logger = logging.getLogger("startup.tests")
    
    logger.info("🧪 Running startup validation tests...")
    
    try:
        # Test basic imports
        from src.models.models import FollowUpQuestion, QuestionOption
        from src.core.config import config
        
        # Test basic model creation
        test_option = QuestionOption(text="Test", is_other=False)
        test_question = FollowUpQuestion(
            question="Test question?",
            options=[test_option]
        )
        
        logger.info("✅ Model validation passed")
        
        # Test configuration access
        allowed_doctors = config.ALLOWED_DOCTORS
        logger.info(f"✅ Configuration access passed ({len(allowed_doctors)} doctor types)")
        
    except Exception as e:
        logger.error(f"❌ Startup tests failed: {str(e)}")
        sys.exit(1)

def start_server(config):
    """Start the FastAPI server"""
    logger = logging.getLogger("startup.server")
    
    logger.info("🌐 Starting FastAPI server...")
    
    try:
        import uvicorn
        
        # Server configuration
        server_config = {
            "app": "src.api.main:app",
            "host": config.HOST,
            "port": config.PORT,
            "reload": config.DEBUG,
            "log_level": "info" if not config.DEBUG else "debug",
            "access_log": True
        }
        
        logger.info(f"  🔗 Server URL: http://{config.HOST}:{config.PORT}")
        logger.info(f"  📖 API Docs: http://{config.HOST}:{config.PORT}/docs")
        logger.info(f"  🔄 Reload: {config.DEBUG}")
        
        print("\n" + "="*70)
        print("🎉 BACKEND STARTUP COMPLETE!")
        print(f"🌐 Server running at: http://{config.HOST}:{config.PORT}")
        print(f"📖 API Documentation: http://{config.HOST}:{config.PORT}/docs")
        print("="*70 + "\n")
        
        # Start the server
        uvicorn.run(**server_config)
        
    except KeyboardInterrupt:
        logger.info("🛑 Server shutdown requested")
    except Exception as e:
        logger.error(f"❌ Server startup failed: {str(e)}")
        sys.exit(1)

async def main():
    """Main startup sequence"""
    start_time = time.time()
    
    # Setup logging first
    logger = setup_logging()
    
    try:
        print_banner()
        logger.info("🚀 Starting Ophthalmology Agent Backend...")
        
        # Step-by-step initialization
        check_python_version()
        check_environment()
        config = validate_configuration()
        check_dependencies()
        await initialize_services(config)
        run_startup_tests()
        
        startup_time = time.time() - start_time
        logger.info(f"✅ Startup completed in {startup_time:.2f} seconds")
        
        # Start the server
        start_server(config)
        
    except KeyboardInterrupt:
        logger.info("🛑 Startup interrupted by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"❌ Startup failed: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    # Run the async main function
    asyncio.run(main())
