import os
import uuid
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, FieldCondition, Filter, MatchValue, VectorParams
from qdrant_client.models import PointStruct

load_dotenv()


class QdrantManager:
    _collection_status = {}
    _instance = None
    _client = None
    _initialized = False

    def __new__(cls, use_local=False, use_memory=False, force_cloud=True):
        if cls._instance is None:
            cls._instance = super(QdrantManager, cls).__new__(cls)
        return cls._instance

    def __init__(self, use_local=False, use_memory=False, force_cloud=True):
        if self._initialized:
            return

        self.qdrant_endpoint = os.getenv("QDRANT_ENDPOINT")
        self.qdrant_api_key = os.getenv("QDRANT_CLUSTER_KEY")
        self.qdrant_collection = os.getenv("QDRANT_COLLECTION_NAME", "healthverse_cases")
        self.openrouter_api_key = os.getenv("OPENROUTER_API_KEY")
        self.openrouter_base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        self.embedding_model = os.getenv("OPENROUTER_EMBEDDING_MODEL", "qwen/qwen3-embedding-8b")
        self.embedding_vector_size = int(os.getenv("EMBEDDING_VECTOR_SIZE", "4096"))
        self.top_k = int(os.getenv("TOP_K_SEARCH", "5"))
        self.use_local = use_local
        self.use_memory = use_memory
        self.force_cloud = force_cloud

        if self.openrouter_api_key:
            self.embedding_client = OpenAI(
                api_key=self.openrouter_api_key,
                base_url=self.openrouter_base_url,
            )
        else:
            self.embedding_client = None
            print("Warning: OPENROUTER_API_KEY not found in environment variables")

        self._initialize_client()
        self._ensure_collection_exists()
        self._initialized = True

    def _initialize_client(self):
        if self.force_cloud and self.qdrant_endpoint and self.qdrant_api_key:
            try:
                print(f"Attempting to connect to Qdrant cloud: {self.qdrant_endpoint}")
                self.client = QdrantClient(
                    url=self.qdrant_endpoint,
                    api_key=self.qdrant_api_key,
                )
                collections = self.client.get_collections()
                print(f"Successfully connected to Qdrant cloud: {self.qdrant_endpoint}")
                print(f"Found {len(collections.collections)} existing collections")
                return
            except Exception as e1:
                print(f"Cloud connection failed: {e1}")

                if ":6333" not in self.qdrant_endpoint:
                    try:
                        new_endpoint = self.qdrant_endpoint + ":6333"
                        print(f"Retrying with port 6333: {new_endpoint}")
                        self.client = QdrantClient(
                            url=new_endpoint,
                            api_key=self.qdrant_api_key,
                        )
                        collections = self.client.get_collections()
                        print(f"Successfully connected to Qdrant cloud: {new_endpoint}")
                        print(f"Found {len(collections.collections)} existing collections")
                        return
                    except Exception as e2:
                        print(f"Retry with port 6333 failed: {e2}")

                print(f"Endpoint: {self.qdrant_endpoint}")
                print(f"API Key configured: {'Yes' if self.qdrant_api_key else 'No'}")
                print("Falling back to local/in-memory Qdrant for development...")

        if self.use_local:
            try:
                print("Attempting to connect to local Qdrant...")
                self.client = QdrantClient(host="localhost", port=6333)
                self.client.get_collections()
                print("Connected to local Qdrant instance at localhost:6333")
                return
            except Exception as e:
                print(f"Local Qdrant connection failed: {e}")

        print("Using in-memory Qdrant for development/testing")
        self.client = QdrantClient(":memory:")
        self.use_memory = True
        print("In-memory Qdrant instance initialized")

    def _ensure_collection_exists(self):
        if not self.client:
            print("No Qdrant client available, cannot ensure collection exists")
            return False

        collection_key = f"{self.qdrant_endpoint or 'local'}:{self.qdrant_collection}"

        try:
            collections = self.client.get_collections()
            collection_names = [c.name for c in collections.collections]

            if self.qdrant_collection not in collection_names:
                print(f"Creating collection: {self.qdrant_collection}")
                self.client.create_collection(
                    collection_name=self.qdrant_collection,
                    vectors_config=VectorParams(
                        size=self.embedding_vector_size,
                        distance=Distance.COSINE,
                    ),
                )
                print(f"Collection '{self.qdrant_collection}' created successfully")
                self._collection_status[collection_key] = True
            else:
                print(f"Collection '{self.qdrant_collection}' already exists")
                self._warn_if_vector_size_mismatch()
                self._collection_status[collection_key] = True

            return True
        except Exception as e:
            print(f"Error ensuring collection exists: {e}")
            self._collection_status[collection_key] = False
            return False

    def _warn_if_vector_size_mismatch(self):
        try:
            collection_info = self.client.get_collection(self.qdrant_collection)
            vectors_config = collection_info.config.params.vectors
            existing_size = getattr(vectors_config, "size", None)
            if existing_size and existing_size != self.embedding_vector_size:
                print(
                    f"Warning: Qdrant collection vector size is {existing_size}, "
                    f"but {self.embedding_model} is configured for {self.embedding_vector_size}. "
                    "Switching embedding size to match the existing collection."
                )
                self.embedding_vector_size = existing_size
                if self.openrouter_api_key:
                    self.embedding_client = OpenAI(
                        api_key=self.openrouter_api_key,
                        base_url=self.openrouter_base_url,
                    )
        except Exception as e:
            print(f"Could not verify Qdrant vector size: {e}")

    def reset_collection_cache(self):
        collection_key = f"{self.qdrant_endpoint or 'local'}:{self.qdrant_collection}"
        if collection_key in self._collection_status:
            del self._collection_status[collection_key]

    def get_collection_info(self):
        if not self.client:
            return None

        try:
            collection_info = self.client.get_collection(self.qdrant_collection)
            vectors_count = 0

            if hasattr(collection_info, "vectors_count") and collection_info.vectors_count is not None:
                vectors_count = collection_info.vectors_count

            try:
                scroll_result = self.client.scroll(
                    collection_name=self.qdrant_collection,
                    limit=1,
                    with_vectors=False,
                )

                if isinstance(scroll_result, tuple):
                    points = scroll_result[0] if scroll_result else []
                    if points:
                        vectors_count = max(vectors_count, 1)
                elif hasattr(scroll_result, "points") and scroll_result.points:
                    vectors_count = max(vectors_count, len(scroll_result.points))
            except Exception as e:
                print(f"Could not get vector count via scroll: {e}")

            return {
                "name": self.qdrant_collection,
                "vectors_count": vectors_count,
                "status": collection_info.status,
                "config": collection_info.config,
            }
        except Exception as e:
            print(f"Error getting collection info: {e}")
            return None

    def verify_vectors_stored(self, expected_count: int = None) -> bool:
        if not self.client:
            return False

        try:
            scroll_result = self.client.scroll(
                collection_name=self.qdrant_collection,
                limit=10,
                with_vectors=True,
            )

            points = []
            if isinstance(scroll_result, tuple):
                points = scroll_result[0] if scroll_result[0] else []
            elif hasattr(scroll_result, "points"):
                points = scroll_result.points
            else:
                print(f"Unexpected scroll result type: {type(scroll_result)}")
                return False

            if points:
                print(f"Verified: Found {len(points)} sample vectors in collection")
                first_point = points[0]
                if hasattr(first_point, "vector") and first_point.vector:
                    vector_size = (
                        len(first_point.vector)
                        if isinstance(first_point.vector, list)
                        else len(first_point.vector.get("", []))
                    )
                    print(f"Verified: Vector embeddings are present (size: {vector_size})")
                    return True

                print("Error: Vectors found but no embeddings attached")
                return False

            print("Error: No vectors found in collection")
            return False
        except Exception as e:
            print(f"Error verifying vectors: {e}")
            return False

    def _get_embedding(self, text: str) -> List[float]:
        try:
            if not self.embedding_client:
                raise ValueError("OpenRouter API key not configured")

            if not hasattr(self, "_logged_model"):
                print(f"Using OpenRouter embedding model: {self.embedding_model}")
                self._logged_model = True

            response = self.embedding_client.embeddings.create(
                model=self.embedding_model,
                input=[text],
            )
            if not response.data or not response.data[0].embedding:
                raise ValueError("No embedding data received")
            return response.data[0].embedding
        except Exception as e:
            print(f"Error generating embedding with model {self.embedding_model}: {e}")
            return [0.0] * self.embedding_vector_size

    async def search(self, query: str, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        if not self.client:
            print("Qdrant client not available, cannot perform vector search")
            return []

        try:
            query_embedding = self._get_embedding(query)

            filter_obj = None
            if filters:
                filter_conditions = []
                for field, value in filters.items():
                    filter_conditions.append(FieldCondition(key=field, match=MatchValue(value=value)))
                filter_obj = Filter(must=filter_conditions)

            search_result = self.client.query_points(
                collection_name=self.qdrant_collection,
                query=query_embedding,
                limit=self.top_k,
                query_filter=filter_obj,
            ).points

            results = []
            for result in search_result:
                results.append(
                    {
                        "document_id": str(result.id),
                        "content": result.payload.get("content", ""),
                        "metadata": {
                            "condition": result.payload.get("condition", ""),
                            "doctor_type": result.payload.get("doctor_type", ""),
                            "urgency": result.payload.get("urgency", ""),
                            "symptoms": result.payload.get("symptoms", []),
                        },
                        "relevance_score": float(result.score),
                    }
                )

            return results
        except Exception as e:
            print(f"Error during Qdrant search: {e}")
            return []

    async def search_by_condition(self, condition: str, doctor_type: Optional[str] = None) -> List[Dict[str, Any]]:
        query = f"Eye condition: {condition}"
        filters = {"doctor_type": doctor_type} if doctor_type else None
        return await self.search(query, filters)

    def add_document(self, content: str, metadata: Dict[str, Any]) -> bool:
        if not self.client:
            print("Qdrant client not available, cannot add document")
            return False

        try:
            embedding = self._get_embedding(content)
            point = PointStruct(
                id=str(uuid.uuid4()),
                vector=embedding,
                payload={"content": content, **metadata},
            )

            self.client.upsert(
                collection_name=self.qdrant_collection,
                points=[point],
            )

            print("Successfully added document to Qdrant collection")
            return True
        except Exception as e:
            print(f"Error adding document to Qdrant: {e}")
            return False

    def add_medical_case(
        self,
        symptoms: List[str],
        disease: str,
        doctor_type: str,
        description: str,
        urgency: str = "medium",
    ) -> bool:
        symptoms_text = ", ".join(symptoms)
        content = f"Disease: {disease}. Symptoms: {symptoms_text}. {description}"

        metadata = {
            "disease": disease,
            "doctor_type": doctor_type,
            "symptoms": symptoms,
            "urgency": urgency,
            "original_description": description,
        }

        return self.add_document(content, metadata)
