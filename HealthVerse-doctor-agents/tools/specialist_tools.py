"""
tools/specialist_tools.py

LangChain tools available to specialist agents.
These are lightweight functions — no external DB in this version.
The tools give the LLM structured reasoning scaffolding.
"""
import re
from langchain_core.tools import tool

# ─────────────────────────────────────────────
# RED FLAG DETECTION
# ─────────────────────────────────────────────

OPHTHALMIC_RED_FLAGS = [
    (r"sudden.*(loss|change|blur|deteriorat).*(vision|sight|sight)", "Sudden vision change — potential emergency"),
    (r"sudden.*painless.*loss.*vision",                               "Sudden painless vision loss — vascular emergency"),
    (r"(curtain|shadow|veil).*(vision|eye)",                          "Curtain over vision — possible retinal detachment"),
    (r"flash(es)?.*float(ers?)?|float(ers?)?.*flash(es?)?",           "Flashes and floaters — retinal tear/detachment risk"),
    (r"severe.*eye.*pain|eye.*pain.*severe",                          "Severe eye pain — urgent evaluation needed"),
    (r"chemical.*(burn|injury|splash).*(eye|vision)",                 "Chemical eye injury — EMERGENCY"),
    (r"(trauma|injury|hit|struck|penetrat).*(eye|orbit)",             "Ocular trauma — urgent evaluation"),
    (r"iop.*(high|elevated|raised|\d{2,3})|pressure.*(eye|iop)",      "Elevated IOP mentioned — glaucoma concern"),
    (r"iop.*[2-9]\d|iop.*[1-9]\d\d",                                  "Significantly elevated IOP — urgent"),
    (r"(acute|sudden).*(angle.*clos|glaucom)",                        "Acute angle closure — EMERGENCY"),
    (r"(endophthalm|severe.*infect|abscess).*(eye|orbit)",            "Severe ocular infection — urgent"),
    (r"diplop",                                                        "Diplopia — neurological or muscle concern"),
    (r"(visual field|peripheral vision).*(loss|defect|cut)",          "Visual field defect — optic nerve/retinal concern"),
    (r"(eyelid|lid).*(swell|droop).*(sudden|acute)",                  "Acute eyelid change — may indicate orbital pathology"),
    (r"(post.?op|after.*surgery|following.*operat).*(pain|red|loss)", "Post-operative complication"),
    (r"hyphaema|blood.*(front|anterior|chamber).*(eye)",              "Hyphaema — ocular trauma"),
]

@tool
def detect_red_flags(text: str) -> dict:
    """
    Scan clinical text for ophthalmic red flags requiring urgent attention.
    Returns a list of detected red flags with their descriptions.
    Use this when a patient message mentions symptoms that could be emergencies.
    """
    found = []
    text_lower = text.lower()
    for pattern, description in OPHTHALMIC_RED_FLAGS:
        if re.search(pattern, text_lower):
            found.append(description)
    return {
        "red_flags": found,
        "urgent": len(found) > 0,
        "count": len(found),
    }


# ─────────────────────────────────────────────
# MESSAGE INTENT CLASSIFICATION
# ─────────────────────────────────────────────

INTENT_PATTERNS = {
    "symptom_report":       [r"patient has|patient report|complain|present|symptoms?|pain|vision|red|blur|discharge|itch|swell"],
    "examination_question": [r"examin|look for|slit lamp|fundus|iop|visual acuity|cover test|what should i (check|test|do)"],
    "diagnosis_question":   [r"what (could|is|are|might)|differ|diagnos|cause|why|possib|suspect"],
    "treatment_question":   [r"treat|manag|prescri|medication|drug|dose|surgery|refer|how (do|should|to)"],
    "follow_up":            [r"now|also|started|only|update|since|after|and also|additionally|furthermore"],
    "general_knowledge":    [r"what is|how does|explain|tell me about|what are the|definition"],
    "out_of_domain":        [r"weather|sport|cook|politic|movie|music|travel|food|joke"],
}

@tool
def classify_message_intent(text: str) -> dict:
    """
    Classify the intent of a doctor's message to guide specialist response style.
    Returns the primary intent category and confidence.
    Use this to determine whether to focus on diagnosis, treatment, examination, etc.
    """
    text_lower = text.lower()
    scores: dict[str, int] = {}
    for intent, patterns in INTENT_PATTERNS.items():
        score = sum(1 for p in patterns if re.search(p, text_lower))
        if score > 0:
            scores[intent] = score

    if not scores:
        primary = "general_knowledge"
    else:
        primary = max(scores, key=lambda k: scores[k])

    return {
        "primary_intent": primary,
        "is_out_of_domain": primary == "out_of_domain",
        "is_follow_up": primary == "follow_up" or bool(re.search(r"started|only|also|now|since|after", text_lower)),
        "all_intents": scores,
    }
