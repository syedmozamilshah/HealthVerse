import json
import os
from typing import List, Optional

from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from mcp.server import FastMCP

from tools.ophthalmology_tools import (
    DoctorIdentification,
    DoctorSummary,
    InputValidationResult,
    LLMGeneratedQuestion,
    QdrantResult,
    Question,
    UserAnswer,
    generate_doctor_summary,
    generate_followup_question,
    identify_doctor,
    query_qdrant,
)

load_dotenv()

groq_api_key = os.getenv("GROQ_API_KEY")
groq_base_url = os.getenv("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
groq_model = os.getenv("GROQ_MODEL", "meta-llama/llama-4-scout-17b-16e-instruct")

if not groq_api_key:
    raise ValueError("GROQ_API_KEY is not configured")

llm = ChatOpenAI(
    model=groq_model,
    api_key=groq_api_key,
    base_url=groq_base_url,
    temperature=0.2,
)

mcp = FastMCP("OphthalmologyAssistant")


@mcp.tool()
def validate_input(user_input: str) -> dict:
    """
    Validate user input using LLM. Checks if input is a valid eye/vision symptom description,
    detects language (english, urdu, roman_urdu), and returns an error message if invalid.
    """
    try:
        prompt = f'''You are a smart and friendly input validator for a medical eye/vision symptom assessment system.

User Input: "{user_input}"

TASK: Analyze if this is a VALID medical symptom description about eyes/vision, and detect the language.

INVALID INPUTS (is_valid = false):
- Greetings: "hello", "hi", "kaise ho", "salam", "how are you", "assalam o alaikum", etc.
- Offensive/inappropriate content: slang, insults, vulgar words, offensive phrases
- Random gibberish: "asdfgh", "xyz123", "hi skdfhdskfj 234", meaningless text, random characters
- Non-medical questions: "what time is it", "who are you", general chat, jokes
- Empty or very short non-descriptive text (less than 3 meaningful words)
- General statements without eye/vision symptoms

VALID INPUTS (is_valid = true):
- Eye symptoms: pain, redness, itching, burning, watering, dryness, swelling
- Vision problems: blurry vision, double vision, floaters, flashes, difficulty seeing
- Roman Urdu symptoms: "aankh mein dard", "nazar kamzor", "aankh laal", "kharish", "dhundla dikhai dena"
- Urdu symptoms: medical eye symptoms written in Urdu script

LANGUAGE DETECTION (detect from the user's input):
- "english" = English words only
- "roman_urdu" = Urdu/Hindi written in English letters
- "urdu" = Urdu script

ERROR MESSAGES:
- Generate a helpful, friendly error message in the SAME LANGUAGE as the user's input
- For greetings: Acknowledge politely, then ask them to describe their eye symptoms
- For gibberish: Kindly ask them to describe their eye/vision problem clearly
- For non-medical: Explain this is for eye health assessment and ask for symptoms

Respond with ONLY valid JSON (no markdown, no explanation):
{{"is_valid": true/false, "detected_language": "english/urdu/roman_urdu", "error_message": "helpful message if invalid, empty string if valid"}}'''

        response = llm.invoke([HumanMessage(content=prompt)])
        response_text = response.content.strip()

        if "```json" in response_text:
            response_text = response_text.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```", 1)[1].strip()

        if not response_text.startswith("{"):
            start = response_text.find("{")
            end = response_text.rfind("}") + 1
            if start != -1 and end > start:
                response_text = response_text[start:end]

        result = json.loads(response_text)
        return InputValidationResult(**result).dict()
    except Exception as e:
        print(f"Error in LLM validation: {e}")
        return InputValidationResult(
            is_valid=True,
            detected_language="english",
            error_message="",
        ).dict()


@mcp.tool()
def generate_llm_question(
    symptoms: str,
    previous_answers: Optional[List[dict]] = None,
    detected_language: str = "english",
    rag_context: str = "",
) -> dict:
    """
    Generate a question using the configured Groq model in the detected language.
    """
    try:
        conversation = ""
        if previous_answers:
            for answer in previous_answers:
                conversation += f"Q: {answer.get('question', '')} A: {answer.get('answer', '')}. "

        language_instructions = {
            "english": "Generate the question and all options in ENGLISH.",
            "urdu": "Generate the question and all options in URDU (using Urdu script).",
            "roman_urdu": "Generate the question and all options in ROMAN URDU (Urdu written in English letters).",
        }
        lang_instruction = language_instructions.get(detected_language, language_instructions["english"])
        other_text = {
            "english": "Other",
            "urdu": "دیگر",
            "roman_urdu": "Dusra/Other",
        }.get(detected_language, "Other")

        prompt = f'''You are a medical assistant helping to assess eye conditions. Generate ONE focused question to better understand the patient's condition.

IMPORTANT LANGUAGE INSTRUCTION: {lang_instruction}
The patient's input language is: {detected_language}

Patient's symptoms: {symptoms}

{f"Conversation so far: {conversation}" if conversation else ""}
{f"Medical context: {rag_context}" if rag_context else ""}

Generate a single, clear question with 4-5 specific answer options. The question should:
1. Be easy to understand for a layperson
2. Help narrow down the diagnosis based on the symptoms
3. Be clinically relevant to the medical context
4. ALWAYS include "{other_text}" as the last option
5. Generate contextually relevant options based on the specific symptoms

Format your response as JSON:
{{
    "question_text": "Your question here in {detected_language}",
    "options": ["Option 1 in {detected_language}", "Option 2 in {detected_language}", "Option 3 in {detected_language}", "Option 4 in {detected_language}", "{other_text}"]
}}'''

        response = llm.invoke([HumanMessage(content=prompt)])
        response_text = response.content.strip()

        if "```json" in response_text:
            response_text = response_text.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```", 1)[1].strip()

        if not response_text.startswith("{"):
            start = response_text.find("{")
            end = response_text.rfind("}") + 1
            if start != -1 and end > start:
                response_text = response_text[start:end]

        result = json.loads(response_text)
        result["detected_language"] = detected_language
        return LLMGeneratedQuestion(**result).dict()
    except Exception as e:
        print(f"Error generating LLM question: {e}")
        return LLMGeneratedQuestion(
            question_text="How long have you been experiencing these symptoms?",
            options=["Less than 24 hours", "1-7 days", "1-4 weeks", "More than a month", "Other"],
            detected_language="english",
        ).dict()


@mcp.tool()
def generate_question(condition: str, previous_answers: Optional[List[dict]] = None) -> dict:
    user_answers = None
    if previous_answers:
        user_answers = [UserAnswer(**answer) for answer in previous_answers]

    question = generate_followup_question(condition, user_answers)
    return question.dict()


@mcp.tool()
def identify_eye_doctor(condition: str, answers: List[dict]) -> dict:
    user_answers = [UserAnswer(**answer) for answer in answers]
    doctor_id = identify_doctor(condition, user_answers)
    return doctor_id.dict()


@mcp.tool()
def search_medical_knowledge(condition: str, answers: List[dict]) -> List[dict]:
    user_answers = [UserAnswer(**answer) for answer in answers]
    results = query_qdrant(condition, user_answers)
    return [result.dict() for result in results]


@mcp.tool()
def create_doctor_summary(
    condition: str,
    answers: List[dict],
    doctor_type: str,
    qdrant_results: List[dict],
) -> dict:
    user_answers = [UserAnswer(**answer) for answer in answers]
    qdrant_docs = [QdrantResult(**result) for result in qdrant_results]
    summary = generate_doctor_summary(condition, user_answers, doctor_type, qdrant_docs)
    return summary.dict()


@mcp.tool()
def generate_english_clinical_summary(
    initial_symptoms: str,
    questions_and_answers: List[dict],
    detected_language: str = "english",
    medical_history: Optional[str] = None,
) -> dict:
    """
    Generate a comprehensive clinical summary in English for medical documentation.
    """
    try:
        conversation_parts = []
        for i, qa in enumerate(questions_and_answers):
            conversation_parts.append(f"Q{i + 1}: {qa.get('question', '')}")
            conversation_parts.append(f"A{i + 1}: {qa.get('answer', '')}")

        conversation_text = "\n".join(conversation_parts)

        prompt = f'''You are a medical documentation assistant. Generate a comprehensive CLINICAL SUMMARY in ENGLISH for medical records.

PATIENT ASSESSMENT DATA:
- Initial Symptoms (may be in any language): {initial_symptoms}
- Patient Medical History: {medical_history or "Not provided"}
- Assessment Language Used: {detected_language}

QUESTIONS AND ANSWERS FROM ASSESSMENT:
{conversation_text}

TASK: Create a professional medical summary in ENGLISH that includes:
1. Chief Complaint
2. History of Present Illness
3. Associated Symptoms
4. Relevant Medical History
5. Clinical Assessment
6. Recommended Specialist
7. Urgency Level
8. Recommended Next Steps

Format your response as JSON:
{{
    "chief_complaint": "Patient's main complaint in English",
    "history_of_present_illness": "Detailed history based on Q&A",
    "associated_symptoms": ["symptom1", "symptom2"],
    "medical_history": "Relevant history or 'None provided'",
    "clinical_assessment": "Brief clinical impression",
    "recommended_specialist": "Ophthalmologist/Optometrist/Ocular Surgeon/Optician",
    "confidence_score": 0.85,
    "urgency_level": "Low/Medium/High/Emergency",
    "reasoning": "Why this specialist is recommended",
    "recommended_actions": ["action1", "action2"],
    "full_summary": "A complete narrative summary paragraph in professional medical English documenting everything"
}}'''

        response = llm.invoke([HumanMessage(content=prompt)])
        response_text = response.content.strip()

        if "```json" in response_text:
            response_text = response_text.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```", 1)[1].strip()

        if not response_text.startswith("{"):
            start = response_text.find("{")
            end = response_text.rfind("}") + 1
            if start != -1 and end > start:
                response_text = response_text[start:end]

        result = json.loads(response_text)
        return {"success": True, "summary": result}
    except Exception as e:
        print(f"Error generating English clinical summary: {e}")
        return {
            "success": False,
            "summary": {
                "chief_complaint": initial_symptoms,
                "full_summary": f"Patient presented with: {initial_symptoms}. Professional eye examination recommended.",
                "recommended_specialist": "Ophthalmologist",
                "urgency_level": "Medium",
            },
            "error": str(e),
        }


if __name__ == "__main__":
    mcp.run()
