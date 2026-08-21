# HealthVerse Agent - Intelligent Health Assessment API

An intelligent health assessment system with session management, RAG-powered question generation, and multi-user support for eye-related conditions.

## Features

- **RAG-Powered Question Generation**: Uses Qdrant vector database to retrieve relevant medical context
- **Intelligent Doctor Recommendations**: Suggests appropriate specialists based on symptoms and medical history
- **Session-Based Assessments**: Supports multiple concurrent user sessions
- **Dynamic Follow-up Questions**: Generates context-aware questions based on conversation history
- **Medical History Integration**: Accepts and utilizes patient medical history for better recommendations
- **Multi-User Support**: Session isolation for concurrent users

## Tech Stack

- **FastAPI**: High-performance API framework
- **LangGraph**: Agent workflow orchestration
- **Groq**: OpenAI-compatible chat completions for reasoning
- **OpenRouter**: OpenAI-compatible embeddings API
- **Qdrant**: Vector database for RAG
- **Python 3.13+**: Core language

## Prerequisites

- Python 3.13 or higher
- Qdrant Cloud account or local Qdrant instance
- Groq API key
- OpenRouter API key

## Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd HealthVerse-agent_with_mcp
```

2. **Install dependencies:**
```bash
pip install -r requirements.txt
```

3. **Set up environment variables:**

Create a `.env` file in the root directory with the following:

```env
# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
API_RELOAD=false
API_LOG_LEVEL=info

# Groq chat model
GROQ_API_KEY=your_groq_api_key_here
GROQ_BASE_URL=https://api.groq.com/openai/v1
GROQ_MODEL=meta-llama/llama-4-scout-17b-16e-instruct

# OpenRouter embedding model
OPENROUTER_API_KEY=your_openrouter_api_key_here
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_EMBEDDING_MODEL=qwen/qwen3-embedding-8b
EMBEDDING_VECTOR_SIZE=4096

# Qdrant Configuration
QDRANT_CLUSTER_KEY=your_qdrant_api_key
QDRANT_CLUSTER_ID=your_cluster_id
QDRANT_ENDPOINT=your_qdrant_endpoint
QDRANT_COLLECTION_NAME=healthverse_cases

# Agent Configuration
CONFIDENCE_THRESHOLD=0.85
MAX_ITERATIONS=6
TOP_K_SEARCH=5
MCQS_PER_ITERATION=1
MCQ_OPTIONS_COUNT=4
```

## Running the Application

### Method 1: Using PowerShell Background Job (Recommended for Windows)

```powershell
Start-Job -ScriptBlock { 
    Set-Location 'E:\fyp\HealthVerse-agent_with_mcp'
    uvicorn app.main:app --host 0.0.0.0 --port 8000 
}

# Check job status
Get-Job

# View job output
Receive-Job -Id 1
```

### Method 2: Direct Uvicorn Command

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Method 3: Using Python Module

```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The server will start on `http://0.0.0.0:8000`

## API Endpoints

### Base URL
```
http://localhost:8000
```

### Interactive Documentation
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

### 1. Root Endpoint
**GET** `/`

Returns API welcome message and available features.

**Response:**
```json
{
  "message": "Welcome to the Health Assessment API",
  "version": "2.0.0",
  "features": [
    "Session-based assessments",
    "RAG-powered question generation",
    "Multi-user support",
    "Intelligent doctor recommendations"
  ],
  "docs": "/docs"
}
```

---

### 2. Health Check
**GET** `/health`

Check if the API is running.

**Response:**
```json
{
  "status": "healthy"
}
```

---

### 3. Start Assessment
**POST** `/health-assessment/start`

Start a new health assessment session.

**Request Body:**
```json
{
  "symptoms": "I have blurry vision and eye pain that started yesterday",
  "user_history": "History of diabetes and hypertension (optional)"
}
```

**Response:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "question": {
    "id": "q1",
    "text": "How would you rate your eye pain on a scale of 1-10?",
    "options": [
      { "id": "1", "text": "1-3 (Mild)" },
      { "id": "2", "text": "4-6 (Moderate)" },
      { "id": "3", "text": "7-10 (Severe)" },
      { "id": "4", "text": "No pain" },
      { "id": "5", "text": "Other" }
    ]
  },
  "initial_guess": "Ophthalmologist",
  "is_completed": false,
  "questions_answered": 0,
  "total_questions": 1
}
```

---

### 4. Submit Answer
**POST** `/health-assessment/answer`

Submit an answer to the current question and get the next question.

**Request Body:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "question_id": "q1",
  "option_id": "3",
  "custom_text": "Additional details (optional, for 'Other' option)"
}
```

**Response:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "question": {
    "id": "q2",
    "text": "Do you experience sensitivity to light?",
    "options": [
      { "id": "1", "text": "Yes, severe" },
      { "id": "2", "text": "Yes, moderate" },
      { "id": "3", "text": "Yes, mild" },
      { "id": "4", "text": "No sensitivity" },
      { "id": "5", "text": "Other" }
    ]
  },
  "initial_guess": "Ophthalmologist",
  "is_completed": false,
  "questions_answered": 1,
  "total_questions": 2
}
```

---

### 5. Get Session Status
**GET** `/health-assessment/session/{session_id}`

Get the current status of a session.

**Example:**
```
GET /health-assessment/session/1615aa61-b95e-46d4-a967-9c300abb7814
```

**Response:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "question": {
    "id": "q2",
    "text": "Do you experience sensitivity to light?",
    "options": [...]
  },
  "initial_guess": "Ophthalmologist",
  "is_completed": false,
  "questions_answered": 1,
  "total_questions": 2
}
```

---

### 6. Get Conversation History
**GET** `/health-assessment/session/{session_id}/history`

Retrieve the complete conversation history for a session.

**Example:**
```
GET /health-assessment/session/1615aa61-b95e-46d4-a967-9c300abb7814/history
```

**Response:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "conversation_history": [
    {
      "question_id": "q1",
      "question_text": "How would you rate your eye pain on a scale of 1-10?",
      "question_options": [...],
      "answer_option_id": "3",
      "answer_text": "7-10 (Severe)",
      "custom_answer": null,
      "order": 1
    },
    {
      "question_id": "q2",
      "question_text": "Do you experience sensitivity to light?",
      "question_options": [...],
      "answer_option_id": "2",
      "answer_text": "Yes, moderate",
      "custom_answer": null,
      "order": 2
    }
  ],
  "updated": false
}
```

---

### 7. Update Medical History
**POST** `/health-assessment/history`

Update the medical history for an existing session.

**Request Body:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "medical_history": "History of diabetes and hypertension"
}
```

**Response:**
```json
{
  "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
  "conversation_history": [...],
  "updated": true
}
```

---

## Usage Examples

### PowerShell

```powershell
# Start a new assessment
$body = @{ 
    symptoms = "I have blurry vision and eye pain" 
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8000/health-assessment/start" `
    -Method Post -Body $body -ContentType "application/json"

$sessionId = $response.session_id

# Submit an answer
$answerBody = @{ 
    session_id = $sessionId
    question_id = "q1"
    option_id = "3"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/health-assessment/answer" `
    -Method Post -Body $answerBody -ContentType "application/json"

# Get conversation history
Invoke-RestMethod -Uri "http://localhost:8000/health-assessment/session/$sessionId/history" `
    -Method Get
```

### cURL

```bash
# Start a new assessment
curl -X POST "http://localhost:8000/health-assessment/start" \
  -H "Content-Type: application/json" \
  -d '{"symptoms": "I have blurry vision and eye pain"}'

# Submit an answer
curl -X POST "http://localhost:8000/health-assessment/answer" \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "1615aa61-b95e-46d4-a967-9c300abb7814",
    "question_id": "q1",
    "option_id": "3"
  }'

# Get session status
curl -X GET "http://localhost:8000/health-assessment/session/1615aa61-b95e-46d4-a967-9c300abb7814"
```

### Python

```python
import requests

# Start assessment
response = requests.post(
    "http://localhost:8000/health-assessment/start",
    json={
        "symptoms": "I have blurry vision and eye pain",
        "user_history": "History of diabetes"
    }
)
session_data = response.json()
session_id = session_data["session_id"]

# Submit answer
answer_response = requests.post(
    "http://localhost:8000/health-assessment/answer",
    json={
        "session_id": session_id,
        "question_id": session_data["question"]["id"],
        "option_id": "3"
    }
)

# Get history
history = requests.get(
    f"http://localhost:8000/health-assessment/session/{session_id}/history"
)
print(history.json())
```

## Project Structure

```
HealthVerse-agent_with_mcp/
├── agents/
│   ├── ophthalmology/
│   │   ├── agent.py              # LangGraph agent implementation
│   │   └── __init__.py
│   └── utils/
│       ├── state.py              # Agent state management
│       └── __init__.py
├── app/
│   ├── api/
│   │   ├── endpoints.py          # API route handlers
│   │   └── __init__.py
│   ├── core/
│   │   ├── config.py             # Configuration settings
│   │   ├── session_manager.py   # Session management
│   │   └── __init__.py
│   ├── services/
│   │   ├── question_service.py  # Question generation logic
│   │   └── __init__.py
│   ├── main.py                   # FastAPI application
│   └── __init__.py
├── data/
│   └── healthverse_cases.json    # Medical case data
├── mcp_server/
│   ├── tools/
│   │   ├── ophthalmology_tools.py # MCP tools
│   │   └── __init__.py
│   └── server.py                 # MCP server (optional)
├── rag/
│   ├── qdrant/
│   │   ├── client.py             # Qdrant client wrapper
│   │   └── __init__.py
│   ├── utils/
│   │   └── helpers.py
│   └── data_loader.py            # Data loading utilities
├── .env                          # Environment variables
├── requirements.txt              # Python dependencies
├── load_data.py                  # Load data into Qdrant
├── main.py                       # Alternative entry point
└── README.md                     # This file
```

## Doctor Types

The system can recommend the following eye care specialists:

1. **Ophthalmologist**: For serious eye diseases, retinal issues, glaucoma, surgical conditions
2. **Optometrist**: For vision problems, glasses, contacts, routine eye exams
3. **Ocular Surgeon**: For surgical conditions, cataracts, corneal issues
4. **Optician**: For glasses fitting, basic vision aids

## Session Management

- Sessions expire after inactivity (configurable)
- Automatic cleanup of expired sessions
- Each session is isolated and supports concurrent users
- Maximum questions per session: 6 (configurable via `MAX_ITERATIONS`)

## Error Handling

The API returns appropriate HTTP status codes:

- `200 OK`: Successful request
- `400 Bad Request`: Invalid request data
- `404 Not Found`: Session not found or expired
- `500 Internal Server Error`: Server-side error

## Troubleshooting

### Server Won't Start

If the server keeps shutting down, try:

```powershell
# Use PowerShell background job
Start-Job -ScriptBlock { 
    Set-Location 'path\to\HealthVerse-agent_with_mcp'
    uvicorn app.main:app --host 0.0.0.0 --port 8000 
}
```

### Port Already in Use

Check if port 8000 is already in use:

```powershell
netstat -ano | Select-String "8000"
```

Kill the process or use a different port:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

### Qdrant Connection Issues

Verify your Qdrant credentials in `.env`:
- Check `QDRANT_ENDPOINT`
- Verify `QDRANT_CLUSTER_KEY`
- Ensure `QDRANT_COLLECTION_NAME` exists

### Load Initial Data

To load medical cases into Qdrant:

```bash
python load_data.py
```

## Development

### Running with Auto-Reload

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Running Tests

```bash
pytest
```

## License

[Add your license here]

## Contributors

[Add contributors here]

## Support

For issues and questions, please [create an issue](link-to-issues) in the repository.
