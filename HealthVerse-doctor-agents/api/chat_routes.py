"""
api/chat_routes.py

FastAPI routes for the 4 specialist doctor AI agents.
Compatible with the .NET AIAgentService MessagesArray request format.
"""
import logging
import time
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from agents.base_agent import run_specialist_agent
from agents.specialists.ophthalmologist import SPECIALIST_CONFIG as OPHTHALMOLOGIST
from agents.specialists.optometrist import SPECIALIST_CONFIG as OPTOMETRIST
from agents.specialists.optician import SPECIALIST_CONFIG as OPTICIAN
from agents.specialists.ocularist import SPECIALIST_CONFIG as OCULARIST

logger = logging.getLogger(__name__)
router = APIRouter()

SPECIALIST_REGISTRY = {
    "ophthalmologist": OPHTHALMOLOGIST,
    "optometrist":     OPTOMETRIST,
    "optician":        OPTICIAN,
    "ocularist":       OCULARIST,
}


# ── Request / Response Models ─────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str     # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    # Optional fields for future compatibility
    patient_id: str | None = None
    conversation_id: str | None = None

class ChatResponse(BaseModel):
    response: str
    specialist: str
    red_flags: list[str] = []
    escalation_needed: bool = False


# ── Generic specialist handler ─────────────────────────────────────────────────

async def handle_specialist_chat(specialist_name: str, request: ChatRequest) -> ChatResponse:
    config = SPECIALIST_REGISTRY.get(specialist_name)
    if not config:
        raise HTTPException(status_code=404, detail=f"Specialist '{specialist_name}' not found")

    if not request.messages:
        raise HTTPException(status_code=400, detail="messages array cannot be empty")

    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    start = time.monotonic()
    try:
        result = await run_specialist_agent(config, messages)
        duration = time.monotonic() - start
        logger.info(
            f"[{specialist_name}] conv={request.conversation_id} patient={request.patient_id} "
            f"msgs={len(messages)} duration={duration:.2f}s red_flags={len(result['red_flags'])}"
        )
        return ChatResponse(**result)

    except Exception as e:
        duration = time.monotonic() - start
        logger.error(f"[{specialist_name}] ERROR after {duration:.2f}s: {e}", exc_info=True)
        # Never expose raw exceptions to the frontend
        raise HTTPException(
            status_code=500,
            detail="The AI specialist encountered an error. Please try again."
        )


# ── 4 Specialist Endpoints ────────────────────────────────────────────────────

@router.post("/chat/ophthalmologist", response_model=ChatResponse)
async def ophthalmologist_chat(request: ChatRequest):
    """Ophthalmologist specialist — eye diseases, surgery, emergency ophthalmology."""
    return await handle_specialist_chat("ophthalmologist", request)

@router.post("/chat/optometrist", response_model=ChatResponse)
async def optometrist_chat(request: ChatRequest):
    """Optometrist specialist — refraction, visual acuity, binocular vision, contact lenses."""
    return await handle_specialist_chat("optometrist", request)

@router.post("/chat/optician", response_model=ChatResponse)
async def optician_chat(request: ChatRequest):
    """Optician specialist — lens dispensing, frame fitting, optical troubleshooting."""
    return await handle_specialist_chat("optician", request)

@router.post("/chat/ocularist", response_model=ChatResponse)
async def ocularist_chat(request: ChatRequest):
    """Ocularist specialist — prosthetic eyes, socket care, cosmetic rehabilitation."""
    return await handle_specialist_chat("ocularist", request)


# ── Generic endpoint (for future extensibility) ───────────────────────────────

@router.post("/chat/{specialist}", response_model=ChatResponse)
async def specialist_chat(specialist: str, request: ChatRequest):
    """Generic endpoint — route to any registered specialist by name."""
    return await handle_specialist_chat(specialist.lower(), request)
