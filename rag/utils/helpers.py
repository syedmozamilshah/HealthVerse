from typing import List, Dict, Any, Optional
from rag.qdrant.client import QdrantManager

async def query_for_condition(condition: str, answers: List[Dict[str, Any]], doctor_type: Optional[str] = None) -> List[Dict[str, Any]]:
    """Query the Qdrant vector store for documents related to a condition and answers"""
    # Create the query text
    query_text = f"Eye condition: {condition}. "
    if answers:
        query_text += "Patient answers: "
        for answer in answers:
            query_text += f"{answer.get('question', '')}: {answer.get('answer', '')}. "
    
    # Initialize the Qdrant manager
    qdrant_manager = QdrantManager(use_local=True, use_memory=True, force_cloud=True)
    
    # Search Qdrant
    results = await qdrant_manager.search(query_text)
    
    return results

async def query_for_doctor_type(doctor_type: str) -> List[Dict[str, Any]]:
    """Query the Qdrant vector store for documents related to a specific doctor type"""
    # Create the query text
    query_text = f"Information about {doctor_type} eye specialist"
    
    # Initialize the Qdrant manager
    qdrant_manager = QdrantManager(use_local=True, use_memory=True, force_cloud=True)
    
    # Create filters
    filters = {"doctor_type": doctor_type}
    
    # Search Qdrant
    results = await qdrant_manager.search(query_text, filters)
    
    return results

def format_qdrant_results(results: List[Dict[str, Any]]) -> str:
    """Format Qdrant results into a readable string"""
    if not results:
        return "No relevant information found."
    
    formatted_text = "Relevant medical information:\n"
    for i, result in enumerate(results):
        formatted_text += f"{i+1}. {result.get('content', '')}\n"
    
    return formatted_text