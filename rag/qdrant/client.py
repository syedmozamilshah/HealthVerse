import os
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv
from qdrant_client import QdrantClient
from qdrant_client.http.models import Filter, FieldCondition, MatchValue, Distance, VectorParams
from qdrant_client.models import PointStruct
import google.generativeai as genai
import uuid

# Load environment variables
load_dotenv()

class QdrantManager:
    """Manager for Qdrant vector store operations"""
    
    # Class-level cache to track collection status
    _collection_status = {}
    
    def __init__(self, use_local=False, use_memory=False, force_cloud=True):
        # Load configuration from environment variables
        self.qdrant_endpoint = os.getenv("QDRANT_ENDPOINT")
        self.qdrant_api_key = os.getenv("QDRANT_CLUSTER_KEY")
        self.qdrant_collection = os.getenv("QDRANT_COLLECTION_NAME", "healthverse_cases")
        self.gemini_api_key = os.getenv("GEMINI_API_KEY")
        self.embedding_model = os.getenv("GEMINI_EMBEDDING_MODEL", "models/text-embedding-004")
        self.top_k = int(os.getenv("TOP_K_SEARCH", "5"))
        self.use_local = use_local
        self.use_memory = use_memory
        self.force_cloud = force_cloud
        
        # Initialize Gemini for embeddings
        if self.gemini_api_key:
            genai.configure(api_key=self.gemini_api_key)
        else:
            print("⚠️  Warning: GEMINI_API_KEY not found in environment variables")
        
        # Initialize Qdrant client with priority: cloud > local > memory
        self._initialize_client()
        
        # Setup collection only once per collection name
        self._ensure_collection_exists()
    
    def _initialize_client(self):
        """Initialize Qdrant client with fallback strategy"""
        if self.force_cloud and self.qdrant_endpoint and self.qdrant_api_key:
            # Try cloud instance first (production setup)
            try:
                print(f"🔌 Attempting to connect to Qdrant cloud: {self.qdrant_endpoint}")
                
                # Try different client configurations for cloud
                self.client = QdrantClient(
                    url=self.qdrant_endpoint,
                    api_key=self.qdrant_api_key,
                    timeout=60,
                    https=True,
                    port=6333,  # Try standard port
                    prefer_grpc=False  # Use REST API instead of gRPC
                )
                
                # Test connection with a simple operation
                collections = self.client.get_collections()
                print(f"✅ Successfully connected to Qdrant cloud: {self.qdrant_endpoint}")
                print(f"ℹ️  Found {len(collections.collections)} existing collections")
                return
            except Exception as e1:
                # Try alternative connection method
                try:
                    print(f"⚠️  First cloud connection attempt failed: {e1}")
                    print(f"🔄 Trying alternative cloud connection method...")
                    
                    self.client = QdrantClient(
                        url=self.qdrant_endpoint,
                        api_key=self.qdrant_api_key,
                        timeout=30,
                        port=443,  # HTTPS port
                        prefer_grpc=True  # Try gRPC
                    )
                    
                    collections = self.client.get_collections()
                    print(f"✅ Successfully connected to Qdrant cloud (alternative method): {self.qdrant_endpoint}")
                    print(f"ℹ️  Found {len(collections.collections)} existing collections")
                    return
                except Exception as e2:
                    print(f"⚠️  Cloud Qdrant connection failed (all methods): {e2}")
                    print(f"⚠️  Endpoint: {self.qdrant_endpoint}")
                    print(f"⚠️  API Key configured: {'Yes' if self.qdrant_api_key else 'No'}")
                    print(f"⚠️  Falling back to local/in-memory Qdrant for development...")
        
        if self.use_local:
            # Try local Qdrant instance
            try:
                print("🔌 Attempting to connect to local Qdrant...")
                self.client = QdrantClient(host="localhost", port=6333)
                # Test connection
                self.client.get_collections()
                print("✅ Connected to local Qdrant instance at localhost:6333")
                return
            except Exception as e:
                print(f"⚠️  Local Qdrant connection failed: {e}")
        
        # Always fallback to in-memory for development
        print("🔌 Using in-memory Qdrant for development/testing")
        self.client = QdrantClient(":memory:")
        self.use_memory = True
        print("✅ In-memory Qdrant instance initialized")
    
    def _ensure_collection_exists(self):
        """Ensure the Qdrant collection exists, but only create it once"""
        if not self.client:
            print("❌ No Qdrant client available, cannot ensure collection exists")
            return False
        
        # Check if we've already verified this collection exists
        collection_key = f"{self.qdrant_endpoint or 'local'}:{self.qdrant_collection}"
        
        # Always check actual collection status, don't rely on cache for recreation
        try:
            # Check if collection exists
            collections = self.client.get_collections()
            collection_names = [c.name for c in collections.collections]
            
            if self.qdrant_collection not in collection_names:
                print(f"📦 Creating collection: {self.qdrant_collection}")
                # Create collection with proper vector configuration
                self.client.create_collection(
                    collection_name=self.qdrant_collection,
                    vectors_config=VectorParams(
                        size=768,  # Gemini text-embedding-004 dimension
                        distance=Distance.COSINE
                    )
                )
                print(f"✅ Collection '{self.qdrant_collection}' created successfully")
                self._collection_status[collection_key] = True
            else:
                print(f"✅ Collection '{self.qdrant_collection}' already exists")
                self._collection_status[collection_key] = True
            
            return True
                
        except Exception as e:
            print(f"❌ Error ensuring collection exists: {e}")
            self._collection_status[collection_key] = False
            return False
    
    def reset_collection_cache(self):
        """Reset the collection status cache - useful after deleting collections"""
        collection_key = f"{self.qdrant_endpoint or 'local'}:{self.qdrant_collection}"
        if collection_key in self._collection_status:
            del self._collection_status[collection_key]
    
    def get_collection_info(self):
        """Get information about the collection including count of vectors"""
        if not self.client:
            return None
        
        try:
            collection_info = self.client.get_collection(self.qdrant_collection)
            
            # Try to get accurate vector count using multiple methods
            vectors_count = 0
            
            # Method 1: Use collection info if available
            if hasattr(collection_info, 'vectors_count') and collection_info.vectors_count is not None:
                vectors_count = collection_info.vectors_count
            
            # Method 2: Use scroll to count vectors (more reliable)
            try:
                scroll_result = self.client.scroll(
                    collection_name=self.qdrant_collection,
                    limit=1,
                    with_vectors=False
                )
                
                # Handle both tuple and object results
                if isinstance(scroll_result, tuple):
                    points = scroll_result[0] if scroll_result else []
                    if points:  # If we get any points, there are vectors
                        # For in-memory, we need to scroll through all to get count
                        # But for now, just confirm vectors exist
                        vectors_count = max(vectors_count, 1)  # At least 1
                elif hasattr(scroll_result, 'points') and scroll_result.points:
                    vectors_count = max(vectors_count, len(scroll_result.points))
                    
            except Exception as e:
                print(f"⚠️  Could not get vector count via scroll: {e}")
            
            return {
                "name": self.qdrant_collection,
                "vectors_count": vectors_count,
                "status": collection_info.status,
                "config": collection_info.config
            }
        except Exception as e:
            print(f"❌ Error getting collection info: {e}")
            return None
    
    def verify_vectors_stored(self, expected_count: int = None) -> bool:
        """Verify that vectors are actually stored in the collection"""
        if not self.client:
            return False
        
        try:
            # Use scroll to check if vectors exist
            scroll_result = self.client.scroll(
                collection_name=self.qdrant_collection,
                limit=10,  # Get a few samples
                with_vectors=True
            )
            
            # Handle both tuple and object results
            points = []
            if isinstance(scroll_result, tuple):
                points = scroll_result[0] if scroll_result[0] else []
            elif hasattr(scroll_result, 'points'):
                points = scroll_result.points
            else:
                print(f"⚠️  Unexpected scroll result type: {type(scroll_result)}")
                return False
            
            if points:
                print(f"✅ Verified: Found {len(points)} sample vectors in collection")
                # Check if vectors have embeddings
                first_point = points[0]
                if hasattr(first_point, 'vector') and first_point.vector:
                    vector_size = len(first_point.vector) if isinstance(first_point.vector, list) else len(first_point.vector.get('', []))
                    print(f"✅ Verified: Vector embeddings are present (size: {vector_size})")
                    return True
                else:
                    print("❌ Error: Vectors found but no embeddings attached")
                    return False
            else:
                print("❌ Error: No vectors found in collection")
                return False
                
        except Exception as e:
            print(f"❌ Error verifying vectors: {e}")
            return False
    
    # ... existing code ...
    
    def _get_embedding(self, text: str) -> List[float]:
        """Get embedding for text using Gemini"""
        try:
            if not self.gemini_api_key:
                raise ValueError("Gemini API key not configured")
            
            # Log embedding model being used (only first time)
            if not hasattr(self, '_logged_model'):
                print(f"🤖 Using Gemini embedding model: {self.embedding_model}")
                self._logged_model = True
            
            result = genai.embed_content(
                model=self.embedding_model,
                content=text,
                task_type="retrieval_document"
            )
            return result['embedding']
        except Exception as e:
            print(f"❌ Error generating embedding with model {self.embedding_model}: {e}")
            # Return a dummy embedding if Gemini fails
            return [0.0] * 768
    
    async def search(self, query: str, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Search the Qdrant vector store for relevant documents"""
        if not self.client:
            print("Qdrant client not available, cannot perform vector search")
            return []
        
        try:
            # Get embedding for the query
            query_embedding = self._get_embedding(query)
            
            # Create filter if provided
            filter_obj = None
            if filters:
                filter_conditions = []
                for field, value in filters.items():
                    filter_conditions.append(FieldCondition(key=field, match=MatchValue(value=value)))
                filter_obj = Filter(must=filter_conditions)
            
            # Search Qdrant
            search_result = self.client.search(
                collection_name=self.qdrant_collection,
                query_vector=query_embedding,
                limit=self.top_k,
                query_filter=filter_obj
            )
            
            # Format results
            results = []
            for result in search_result:
                results.append({
                    "document_id": str(result.id),
                    "content": result.payload.get("content", ""),
                    "metadata": {
                        "condition": result.payload.get("condition", ""),
                        "doctor_type": result.payload.get("doctor_type", ""),
                        "urgency": result.payload.get("urgency", ""),
                        "symptoms": result.payload.get("symptoms", [])
                    },
                    "relevance_score": float(result.score)
                })
            
            return results
            
        except Exception as e:
            print(f"Error during Qdrant search: {e}")
            return []
    
    async def search_by_condition(self, condition: str, doctor_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """Search for documents related to an eye condition and optionally filtered by doctor type"""
        # Create the query
        query = f"Eye condition: {condition}"
        
        # Create filters if doctor_type is provided
        filters = None
        if doctor_type:
            filters = {"doctor_type": doctor_type}
        
        # Search (will use mock data if Qdrant is not available)
        return await self.search(query, filters)