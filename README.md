# Ophthalmology Assistant System

An autonomous ophthalmology assistant system built with LangGraph, Google Gemini, FastAPI, ReAct pattern, BindWithLLM, MCP server, and Qdrant vector store.

## Features

1. **User Interaction**
   - Users enter their initial eye-related condition
   - System generates follow-up questions with dynamic answer options
   - Support for custom user answers via "Other" option

2. **Doctor Identification**
   - Determines the most relevant eye specialist from:
     - Ophthalmologist
     - Optometrist
     - Optician
     - Ocular Surgeon

3. **RAG Integration**
   - Queries Qdrant vector store for relevant medical information
   - Enhances responses with retrieved context

4. **Final Output**
   - Recommended specialist
   - Concise medical summary for the doctor

## Tech Stack

### Backend
- **LangGraph**: Agent orchestration and workflow management
- **ReAct Pattern**: Reasoning + tool usage for autonomous decision making
- **BindWithLLM**: Autonomy + conditional tool calling
- **Google Gemini**: Question generation, reasoning, and summarization
- **Qdrant**: Vector store for medical context retrieval (RAG)
- **FastAPI**: High-performance backend API with automatic documentation
- **MCP Server**: Tool management and execution framework

### Frontend (Optional)
- **React**: Modern JavaScript library for building user interfaces
- **Axios**: HTTP client for API communication
- **Create React App**: Build toolchain and development setup

### Data & AI
- **Vector Embeddings**: Medical case similarity and retrieval
- **RAG (Retrieval-Augmented Generation)**: Context-aware medical responses
- **160 Medical Cases**: Comprehensive healthverse dataset

## Project Structure

```
├── app/                    # FastAPI application
│   ├── api/                # API endpoints
│   ├── core/               # Core application logic
│   └── main.py             # FastAPI entry point
├── agents/                 # LangGraph agents
│   ├── ophthalmology/      # Ophthalmology-specific agents
│   └── utils/              # Agent utilities
├── mcp_server/            # MCP server implementation
│   ├── tools/              # Tool definitions
│   └── server.py           # MCP server entry point
├── rag/                    # RAG implementation
│   ├── qdrant/             # Qdrant integration
│   └── utils/              # RAG utilities
├── frontend/              # React frontend (optional)
│   ├── src/                # React source code
│   ├── public/             # Static assets
│   └── package.json        # Node.js dependencies
├── tests/                  # Test suites
│   ├── test_api_endpoints.py
│   ├── test_mcp_server.py
│   ├── test_ophthalmology_agent.py
│   └── test_rag_integration.py
├── data/                   # Medical data
│   └── healthverse_cases.json  # 160 medical cases
├── .env                    # Environment variables (create from template)
├── .env.template           # Environment variables template
├── .gitignore              # Git ignore file
├── main.py                 # End-to-end demo script
├── api_demo.py             # API demonstration script
├── run_tests.py            # Test execution script
├── system_validation.py    # System health check
└── README.md               # Project documentation
```

## Prerequisites

- Python 3.10 or higher
- Node.js 16+ (for frontend)
- pip (Python package manager)
- npm (Node.js package manager)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd mcp
```

### 2. Setup Environment Variables
```bash
# Copy the template file
cp .env.template .env

# Edit .env file with your actual credentials
# Required: GEMINI_API_KEY, QDRANT credentials
```

**Important**: You need to obtain:
- **Gemini API Key**: Get from [Google AI Studio](https://makersuite.google.com/app/apikey)
- **Qdrant Credentials**: Sign up at [Qdrant Cloud](https://cloud.qdrant.io/) or run locally

### 3. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 4. Install Frontend Dependencies (Optional)
```bash
cd frontend
npm install
cd ..
```

### 5. Initialize Vector Store
The system will automatically populate the Qdrant vector store with medical data on first run.

## Running the System

### Quick Start (Recommended)
Run the complete system with one command:
```bash
python main.py
```
This will:
- Start the MCP server
- Start the FastAPI backend
- Initialize the RAG system
- Run a sample workflow
- Display results

### Manual Setup (Development)

#### Terminal 1: Start MCP Server
```bash
python mcp_server/server.py
```
Keep this running - it provides tools for the AI agent.

#### Terminal 2: Start Backend API
```bash
python app/main.py
```
The API will be available at http://localhost:8000

#### Terminal 3: Start Frontend (Optional)
```bash
cd frontend
npm start
```
The frontend will be available at http://localhost:3000

### Testing the API

#### Option 1: API Demo Script
```bash
python api_demo.py
```
Interactive demo showing:
- Condition submission
- Follow-up questions
- Doctor recommendations
- Medical summaries

#### Option 2: Frontend Integration Test
```bash
python test_frontend_integration.py
```
Tests frontend-backend communication.

#### Option 3: Manual API Testing
Use curl, Postman, or any HTTP client:
```bash
curl -X POST "http://localhost:8000/submit_condition" \
     -H "Content-Type: application/json" \
     -d '{"condition": "I have blurry vision and eye pain"}'
```

## Testing

### Run All Tests
```bash
python run_tests.py
```

### Run Specific Test Suites
```bash
# Test the AI agent
python -m unittest tests/test_ophthalmology_agent.py -v

# Test API endpoints
python -m unittest tests/test_api_endpoints.py -v

# Test MCP server tools
python -m unittest tests/test_mcp_server.py -v

# Test RAG integration
python -m unittest tests/test_rag_integration.py -v
```

### System Validation
```bash
# Comprehensive system health check
python system_validation.py
```

### Frontend Tests
```bash
cd frontend
npm test
```

## Architecture Overview

### Component Interaction
```
User Input → FastAPI → LangGraph Agent → Gemini LLM + MCP Tools + Qdrant RAG → Response
```

### Key Components
1. **FastAPI Backend**: REST API endpoints
2. **LangGraph Agent**: AI workflow orchestration
3. **MCP Server**: Tool management and execution
4. **Qdrant RAG**: Medical knowledge retrieval
5. **React Frontend**: User interface (optional)

## Troubleshooting

### Common Issues

1. **Environment Variables Missing**
   ```bash
   # Check if .env file exists and has required values
   cat .env | grep -E "GEMINI_API_KEY|QDRANT"
   ```

2. **Qdrant Connection Failed**
   - Verify Qdrant credentials in `.env`
   - Check if Qdrant service is running
   - System will fallback to mock data if Qdrant unavailable

3. **Port Already in Use**
   ```bash
   # Find process using port 8000
   netstat -ano | findstr :8000
   # Kill the process or change API_PORT in .env
   ```

4. **Frontend Connection Issues**
   - Ensure backend is running on port 8000
   - Check CORS configuration in FastAPI

### Development Tips

- Use separate terminals for different components
- Check logs for detailed error messages
- The system gracefully degrades when external services are unavailable
- RAG system auto-populates on first run

## API Documentation

Once the backend is running, visit:
- **Interactive Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Contributing

1. Follow the existing code structure
2. Add tests for new features
3. Update documentation for changes
4. Ensure all tests pass before submitting