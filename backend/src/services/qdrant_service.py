from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams
from typing import List, Dict, Any
import logging
import google.generativeai as genai
from src.core.config import config
from src.models.models import RAGDocument

logger = logging.getLogger(__name__)

class QdrantService:
    def __init__(self):
        # For local development, don't use API key if not provided
        if config.QDRANT_CLUSTER_KEY:
            self.client = QdrantClient(
                url=config.QDRANT_ENDPOINT,
                api_key=config.QDRANT_CLUSTER_KEY,
                check_compatibility=False  # Skip version check
            )
        else:
            # Local Qdrant instance without API key
            self.client = QdrantClient(
                url=config.QDRANT_ENDPOINT,
                check_compatibility=False  # Skip version check
            )
            
        self.collection_name = config.QDRANT_COLLECTION_NAME
        self.embedding_model_name = config.GEMINI_EMBEDDING_MODEL
        
        # Configure Gemini
        genai.configure(api_key=config.GEMINI_API_KEY)
        self.embedding_dimension = 768  # Gemini embedding dimension
        
    async def initialize_collection(self):
        """Initialize collection if it doesn't exist"""
        try:
            # Check if Qdrant is available
            try:
                collections = self.client.get_collections()
                collection_names = [col.name for col in collections.collections]
                
                if self.collection_name not in collection_names:
                    self.client.create_collection(
                        collection_name=self.collection_name,
                        vectors_config=VectorParams(
                            size=self.embedding_dimension,
                            distance=Distance.COSINE
                        )
                    )
                    logger.info(f"Created collection: {self.collection_name}")
                else:
                    logger.info(f"Collection already exists: {self.collection_name}")
            except Exception as e:
                # For development purposes, create a mock collection
                logger.warning(f"Qdrant connection failed: {str(e)}")
                logger.warning("Running in development mode without Qdrant. Some features will be limited.")
                # Continue without Qdrant for development purposes
                
        except Exception as e:
            logger.error(f"Error initializing collection: {str(e)}")
            raise
    
    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for given text using Gemini"""
        try:
            result = genai.embed_content(
                model=self.embedding_model_name,
                content=text
            )
            return result['embedding']
        except Exception as e:
            logger.error(f"Error generating embedding: {str(e)}")
            raise
    
    async def search_similar_documents(
        self, 
        query: str, 
        limit: int = 5,
        score_threshold: float = 0.3
    ) -> List[RAGDocument]:
        """Search for similar documents in the vector store"""
        try:
            query_embedding = self.generate_embedding(query)
            
            search_result = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=limit,
                score_threshold=score_threshold
            )
            
            documents = []
            for point in search_result:
                doc = RAGDocument(
                    content=point.payload.get("content", ""),
                    score=point.score,
                    metadata=point.payload.get("metadata", {})
                )
                documents.append(doc)
            
            logger.info(f"Found {len(documents)} similar documents for query: {query[:50]}...")
            return documents
            
        except Exception as e:
            logger.error(f"Error searching documents: {str(e)}")
            return []
    
    async def add_document(
        self, 
        content: str, 
        metadata: Dict[str, Any] = None
    ) -> bool:
        """Add a document to the vector store"""
        try:
            embedding = self.generate_embedding(content)
            
            point = {
                "id": hash(content) % (10**10),  # Simple ID generation
                "vector": embedding,
                "payload": {
                    "content": content,
                    "metadata": metadata or {}
                }
            }
            
            self.client.upsert(
                collection_name=self.collection_name,
                points=[point]
            )
            
            logger.info(f"Added document to collection: {content[:50]}...")
            return True
            
        except Exception as e:
            logger.error(f"Error adding document: {str(e)}")
            return False

# Global instance
qdrant_service = QdrantService()
