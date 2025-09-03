import json
import asyncio
import uuid
from typing import List, Dict, Any
from pathlib import Path
from qdrant_client.models import PointStruct
from rag.qdrant.client import QdrantManager

class DataLoader:
    """Load and process medical data for the RAG system"""
    
    def __init__(self, data_file_path: str = "data/healthverse_cases.json"):
        self.data_file_path = Path(data_file_path)
        self.qdrant_manager = None
    
    async def initialize(self):
        """Initialize the Qdrant manager"""
        # Try cloud instance first, fallback to in-memory for development
        self.qdrant_manager = QdrantManager(use_local=True, use_memory=True, force_cloud=True)
        print("✅ Qdrant manager initialized")
    
    def load_medical_data(self) -> List[Dict[str, Any]]:
        """Load medical cases from JSON file"""
        try:
            with open(self.data_file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            print(f"✅ Loaded {len(data)} medical cases from {self.data_file_path}")
            return data
        except FileNotFoundError:
            print(f"❌ Data file not found: {self.data_file_path}")
            return []
        except json.JSONDecodeError as e:
            print(f"❌ Error parsing JSON file: {e}")
            return []
    
    def process_case(self, case: Dict[str, Any]) -> Dict[str, Any]:
        """Process a single medical case for embedding"""
        # Create comprehensive text for embedding
        symptoms_text = ", ".join(case.get("symptoms", []))
        disease = case.get("disease", "Unknown")
        doctor = case.get("doctor", "Ophthalmologist")
        description = case.get("description", "")
        
        # Create searchable content
        content = f"Disease: {disease}. Symptoms: {symptoms_text}. {description}"
        
        # Determine urgency based on symptoms and disease
        urgency = self._determine_urgency(case)
        
        return {
            "content": content,
            "disease": disease,
            "doctor_type": doctor,
            "symptoms": case.get("symptoms", []),
            "urgency": urgency,
            "original_description": description
        }
    
    def _determine_urgency(self, case: Dict[str, Any]) -> str:
        """Determine urgency level based on symptoms"""
        symptoms = [s.lower() for s in case.get("symptoms", [])]
        disease = case.get("disease", "").lower()
        
        # High urgency indicators
        high_urgency_symptoms = [
            "severe pain", "sudden vision loss", "eye trauma", "chemical burn",
            "foreign object", "severe headache", "nausea", "vomiting",
            "halos around lights", "eye pressure", "flashing lights"
        ]
        
        # Emergency conditions
        emergency_diseases = ["glaucoma", "retinal detachment", "acute iritis"]
        
        if any(symptom in " ".join(symptoms) for symptom in high_urgency_symptoms):
            return "high"
        elif disease in emergency_diseases:
            return "high"
        elif any(symptom in symptoms for symptom in ["pain", "redness", "discharge"]):
            return "medium"
        else:
            return "low"
    
    async def populate_qdrant(self, force_repopulate=False):
        """Load data and populate Qdrant vector store"""
        if not self.qdrant_manager:
            await self.initialize()
        
        # Check if collection already has data
        if not force_repopulate:
            collection_info = self.qdrant_manager.get_collection_info()
            if collection_info and collection_info.get("vectors_count", 0) > 0:
                print(f"ℹ️  Collection '{self.qdrant_manager.qdrant_collection}' already contains {collection_info['vectors_count']} vectors")
                print("ℹ️  Use force_repopulate=True to overwrite existing data")
                return True
        
        # Load medical data
        medical_cases = self.load_medical_data()
        if not medical_cases:
            print("❌ No medical data to load")
            return False
        
        print(f"📊 Processing {len(medical_cases)} medical cases...")
        
        # Clear existing data if force repopulating
        if force_repopulate:
            try:
                # Check if collection exists before trying to delete
                collections = self.qdrant_manager.client.get_collections()
                collection_names = [c.name for c in collections.collections]
                
                if self.qdrant_manager.qdrant_collection in collection_names:
                    # Delete existing collection
                    self.qdrant_manager.client.delete_collection(self.qdrant_manager.qdrant_collection)
                    print("🗑️  Cleared existing collection data")
                    # Reset the collection cache
                    self.qdrant_manager.reset_collection_cache()
                
                # Recreate collection
                recreated = self.qdrant_manager._ensure_collection_exists()
                if not recreated:
                    print("❌ Failed to recreate collection")
                    return False
                    
            except Exception as e:
                print(f"⚠️  Warning: Could not clear existing data: {e}")
        
        # Process cases and create points
        points = []
        processed_count = 0
        
        for case in medical_cases:
            try:
                processed_case = self.process_case(case)
                
                # Generate embedding
                embedding = self.qdrant_manager._get_embedding(processed_case["content"])
                
                # Create point
                point = PointStruct(
                    id=str(uuid.uuid4()),
                    vector=embedding,
                    payload=processed_case
                )
                points.append(point)
                processed_count += 1
                
                # Progress indicator
                if processed_count % 50 == 0:
                    print(f"  Processed {processed_count}/{len(medical_cases)} cases...")
                    
            except Exception as e:
                print(f"⚠️  Error processing case: {e}")
                continue
        
        print(f"✅ Successfully processed {len(points)} cases")
        
        # Upload to Qdrant in batches
        batch_size = 100
        total_uploaded = 0
        
        try:
            # Verify collection exists before uploading
            collections = self.qdrant_manager.client.get_collections()
            collection_names = [c.name for c in collections.collections]
            if self.qdrant_manager.qdrant_collection not in collection_names:
                print(f"❌ Collection {self.qdrant_manager.qdrant_collection} not found during upload!")
                print(f"Available collections: {collection_names}")
                return False
            
            print(f"✅ Confirmed collection {self.qdrant_manager.qdrant_collection} exists for upload")
            
            for i in range(0, len(points), batch_size):
                batch = points[i:i + batch_size]
                
                self.qdrant_manager.client.upsert(
                    collection_name=self.qdrant_manager.qdrant_collection,
                    points=batch
                )
                total_uploaded += len(batch)
                print(f"  Uploaded batch: {total_uploaded}/{len(points)} points")
            
            print(f"🎉 Successfully uploaded {total_uploaded} medical cases to Qdrant!")
            
            # Verify the upload with multiple methods
            print("\n🔍 Verifying vector storage...")
            
            # Method 1: Check collection info
            collection_info = self.qdrant_manager.get_collection_info()
            if collection_info:
                print(f"ℹ️  Collection info reports: {collection_info['vectors_count']} vectors")
            
            # Method 2: Verify vectors are actually stored
            vectors_verified = self.qdrant_manager.verify_vectors_stored(total_uploaded)
            
            # Method 3: Test a simple search
            test_results = await self.qdrant_manager.search("eye pain test query")
            print(f"ℹ️  Test search returned: {len(test_results)} results")
            
            if vectors_verified and len(test_results) > 0:
                print("✅ Vector storage verification successful!")
            else:
                print("⚠️  Vector storage verification failed - vectors may not be properly stored")
            
            return True
            
        except Exception as e:
            print(f"❌ Error uploading to Qdrant: {e}")
            return False
    
    async def test_search(self, query: str = "severe eye pain with halos"):
        """Test the search functionality"""
        if not self.qdrant_manager:
            await self.initialize()
        
        print(f"\n🔍 Testing search with query: '{query}'")
        results = await self.qdrant_manager.search(query)
        
        if results:
            print(f"✅ Found {len(results)} relevant cases:")
            for i, result in enumerate(results[:3], 1):
                metadata = result.get('metadata', {})
                print(f"\n  {i}. Disease: {metadata.get('disease', 'Unknown')}")
                print(f"     Doctor: {metadata.get('doctor_type', 'Unknown')}")
                print(f"     Urgency: {metadata.get('urgency', 'Unknown')}")
                symptoms = metadata.get('symptoms', [])
                if symptoms:
                    print(f"     Symptoms: {', '.join(symptoms[:3])}...")
                print(f"     Relevance: {result.get('relevance_score', 0):.3f}")
                print(f"     Content: {result.get('content', '')[:100]}...")
        else:
            print("❌ No results found")

async def main():
    """Main function to load data and test"""
    print("=" * 70)
    print("📚 HEALTHVERSE MEDICAL DATA LOADER")
    print("=" * 70)
    
    loader = DataLoader()
    
    # Load and populate data
    success = await loader.populate_qdrant()
    
    if success:
        # Test different queries
        test_queries = [
            "severe eye pain with halos around lights",
            "blurry vision and difficulty reading",
            "red itchy eyes with discharge",
            "flashing lights and floaters",
            "gradual vision loss"
        ]
        
        for query in test_queries:
            await loader.test_search(query)
    
    print("\n" + "=" * 70)
    print("✅ DATA LOADING COMPLETE")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(main())