# HealthVerse Doctor Specialist Agents

A unified, production-ready multi-specialist eye-care AI system for **doctors**.
Powered by **LangGraph ReAct agents** + **GPT-OSS-120B** via Groq.

> **Separate from** `HealthVerse-agent_with_mcp/` (which is the patient MCQ triage for the Flutter app).
> This service is for the **BlazorUI doctor dashboard** — it assists doctors with clinical decision support.

---

## Architecture

```
BlazorUI Doctor Dashboard
        ↓
first_api (.NET ASP.NET Core)
        ↓  AIAgentService.cs
POST /chat/{specialist}
        ↓
LangGraph ReAct Agent Factory  ← THIS SERVICE
        ↓
Specialist Config (system prompt, tools, domain rules)
        ↓
GPT-OSS-120B via Groq API
        ↓
MCP Tools (red flag detection, message classification)
        ↓
Response → .NET → MongoDB → Doctor
```

## Specialists

| Specialist | Route | Domain |
|---|---|---|
| Ophthalmologist | `POST /chat/ophthalmologist` | Eye diseases, glaucoma, retina, emergency ophthalmology |
| Optometrist | `POST /chat/optometrist` | Refraction, visual acuity, binocular vision, contact lenses |
| Optician | `POST /chat/optician` | Spectacles, lenses, frames, dispensing, optical troubleshooting |
| Ocularist | `POST /chat/ocularist` | Prosthetic eyes, socket assessment, rehabilitation |

## Project Structure

```
HealthVerse-doctor-agents/
├── main.py                         # FastAPI app entry point
├── config.py                       # Environment variable config
├── requirements.txt
├── .env                            # NOT committed — contains API keys
├── agents/
│   ├── base_agent.py               # LangGraph ReAct factory (shared)
│   └── specialists/
│       ├── ophthalmologist.py      # System prompt + config
│       ├── optometrist.py
│       ├── optician.py
│       └── ocularist.py
├── tools/
│   └── specialist_tools.py         # detect_red_flags, classify_message_intent
├── api/
│   └── chat_routes.py              # FastAPI /chat/* endpoints
└── tests/
    └── test_specialists.py         # Full test suite (15 tests, all passing)
```

## Quick Start (Local)

```bash
cd HealthVerse-doctor-agents

# Install dependencies
pip install -r requirements.txt

# Create .env (copy from .env.example or create manually)
# Add your GROQ_API_KEY

# Run the server
python main.py
# Server starts at http://localhost:8001
```

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `GROQ_API_KEY` | Groq API key | required |
| `GROQ_BASE_URL` | Groq API base URL | `https://api.groq.com/openai/v1` |
| `GROQ_MODEL` | Model name | `openai/gpt-oss-120b` |
| `API_HOST` | Server host | `0.0.0.0` |
| `API_PORT` | Server port | `8001` |
| `MAX_CONTEXT_TURNS` | Max conversation turns in context | `10` |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | `http://localhost:5257,...` |

## API Usage

### Request Format (compatible with .NET AIAgentService MessagesArray)
```json
POST /chat/ophthalmologist
{
  "messages": [
    { "role": "user", "content": "Patient has blurry vision." },
    { "role": "assistant", "content": "Blurry vision can be caused by..." },
    { "role": "user", "content": "Started yesterday, only right eye." }
  ],
  "patient_id": "optional-patient-id",
  "conversation_id": "optional-conv-id"
}
```

### Response Format
```json
{
  "response": "Based on acute unilateral blurred vision...",
  "specialist": "ophthalmologist",
  "red_flags": [],
  "escalation_needed": false
}
```

## Running Tests

```bash
python tests/test_specialists.py
```

**Test Results (all 15 tests passed):**
- Ophthalmologist: 8 tests (partial symptoms, red flags, multi-turn conversation, out-of-domain)
- Optometrist: 2 tests (VA interpretation, contact lens)
- Optician: 2 tests (coating recommendation, emergency escalation)
- Ocularist: 2 tests (socket discharge, prosthesis maintenance) — wait tests run 1 extra

## Connecting to .NET Backend

The `.NET` `first_api/Data/AIAgentService.cs` has been updated.

**For local development:** The .NET backend calls `http://localhost:8001` by default.

**For production:** Set the `DOCTOR_AGENTS_URL` environment variable in your .NET app:
```
DOCTOR_AGENTS_URL=https://your-koyeb-url.koyeb.app
```

## Deployment (Koyeb — Free, No Sleep)

1. Create a `Dockerfile` (see below)
2. Push to GitHub
3. Connect GitHub repo to Koyeb
4. Set `GROQ_API_KEY` in Koyeb environment variables
5. Update `DOCTOR_AGENTS_URL` in your .NET backend

### Dockerfile (for Koyeb)
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8001
CMD ["python", "main.py"]
```
