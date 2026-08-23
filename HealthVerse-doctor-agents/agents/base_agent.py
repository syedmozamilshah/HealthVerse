"""
agents/base_agent.py

Shared LangGraph ReAct agent factory.
All 4 specialists share this same graph structure — only the config differs.
"""
import logging
from typing import Any
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from config import GROQ_API_KEY, GROQ_BASE_URL, GROQ_MODEL, MAX_CONTEXT_TURNS

logger = logging.getLogger(__name__)

# ── LLM (shared across all agents, initialized once) ──────────────────────────
_llm: ChatOpenAI | None = None

def get_llm() -> ChatOpenAI:
    global _llm
    if _llm is None:
        _llm = ChatOpenAI(
            model=GROQ_MODEL,
            api_key=GROQ_API_KEY,
            base_url=GROQ_BASE_URL,
            temperature=0.2,
            max_tokens=1024,
        )
        logger.info(f"LLM initialized: {GROQ_MODEL} @ {GROQ_BASE_URL}")
    return _llm


# ── Agent cache (one compiled graph per specialist) ────────────────────────────
_agent_cache: dict[str, Any] = {}

def get_specialist_agent(config: dict) -> Any:
    """
    Returns a cached compiled LangGraph ReAct agent for the given specialist config.
    Creates it on first call, reuses on subsequent calls.
    """
    specialist_name = config["name"]
    if specialist_name not in _agent_cache:
        llm = get_llm()
        agent = create_react_agent(
            model=llm,
            tools=config["tools"],
            prompt=config["system_prompt"],
        )
        _agent_cache[specialist_name] = agent
        logger.info(f"Agent compiled for specialist: {specialist_name}")
    return _agent_cache[specialist_name]


# ── Message preparation ────────────────────────────────────────────────────────
def prepare_messages(raw_messages: list[dict]) -> list[dict]:
    """
    Take the full conversation history from the .NET backend and trim to
    MAX_CONTEXT_TURNS recent turns (user+assistant pairs) to stay within
    the context window budget.

    Input format (from .NET MessagesArray):
        [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}, ...]

    Also supports the N8nWebhook format by normalizing it.
    """
    if not raw_messages:
        return []

    # Trim to last MAX_CONTEXT_TURNS * 2 messages (each turn = 1 user + 1 assistant)
    max_msgs = MAX_CONTEXT_TURNS * 2
    if len(raw_messages) > max_msgs:
        raw_messages = raw_messages[-max_msgs:]

    return raw_messages


# ── Main agent runner ──────────────────────────────────────────────────────────
async def run_specialist_agent(
    config: dict,
    messages: list[dict],
) -> dict:
    """
    Run the specialist LangGraph ReAct agent with the given conversation messages.

    Args:
        config: Specialist config dict from agents/specialists/*.py
        messages: List of {role, content} dicts representing the full conversation

    Returns:
        {
            "response": str,
            "specialist": str,
            "red_flags": list[str],
            "escalation_needed": bool,
        }
    """
    specialist_name = config["name"]
    agent = get_specialist_agent(config)
    prepared = prepare_messages(messages)

    logger.info(f"[{specialist_name}] Running with {len(prepared)} messages")

    try:
        result = await agent.ainvoke({"messages": prepared})

        # Extract the last AI message as the response
        ai_messages = [m for m in result["messages"] if hasattr(m, "content") and getattr(m, "type", None) == "ai"]
        if ai_messages:
            response_text = ai_messages[-1].content
        else:
            # Fallback: get the last message content
            last = result["messages"][-1]
            response_text = last.content if hasattr(last, "content") else str(last)

        # Check if any tool calls returned red flags
        red_flags: list[str] = []
        escalation_needed = False
        for msg in result["messages"]:
            if hasattr(msg, "content") and isinstance(msg.content, str):
                if "red_flags" in msg.content.lower() or "urgent" in msg.content.lower():
                    # Simple heuristic — the actual flags come from tool results
                    pass

        # Extract red flags from tool results in message history
        for msg in result["messages"]:
            if hasattr(msg, "type") and msg.type == "tool":
                try:
                    import json
                    tool_content = json.loads(msg.content) if isinstance(msg.content, str) else msg.content
                    if isinstance(tool_content, dict) and "red_flags" in tool_content:
                        red_flags.extend(tool_content["red_flags"])
                        if tool_content.get("urgent"):
                            escalation_needed = True
                except Exception:
                    pass

        logger.info(f"[{specialist_name}] Response generated. Red flags: {len(red_flags)}")

        return {
            "response": response_text,
            "specialist": specialist_name,
            "red_flags": red_flags,
            "escalation_needed": escalation_needed,
        }

    except Exception as e:
        logger.error(f"[{specialist_name}] Agent error: {e}", exc_info=True)
        raise
