#!/usr/bin/env python3
"""
Script to populate Qdrant vector store with sample ophthalmology knowledge for testing.
"""

import asyncio
import sys
import os
import requests

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

API_BASE_URL = "http://localhost:8000"

# Sample ophthalmology knowledge documents
SAMPLE_DOCUMENTS = [
    {
        "content": "Blurry vision can be caused by refractive errors such as myopia (nearsightedness), hyperopia (farsightedness), or astigmatism. These conditions are commonly treated by optometrists who can prescribe corrective lenses or contact lenses.",
        "metadata": {"category": "refractive_errors", "specialist": "optometrist"}
    },
    {
        "content": "Sudden onset of severe eye pain with redness, nausea, and vision loss may indicate acute angle-closure glaucoma, which is a medical emergency requiring immediate attention from an ophthalmologist or emergency care.",
        "metadata": {"category": "glaucoma", "specialist": "ophthalmologist", "urgency": "emergency"}
    },
    {
        "content": "Cataracts are clouding of the natural lens of the eye that commonly occur with aging. Cataract surgery performed by ocular surgeons involves removing the cloudy lens and replacing it with an artificial intraocular lens.",
        "metadata": {"category": "cataracts", "specialist": "ocular_surgeon"}
    },
    {
        "content": "Computer vision syndrome or digital eye strain causes symptoms like dry eyes, blurred vision, and headaches from prolonged screen use. An optometrist can recommend specialized computer glasses or vision therapy exercises.",
        "metadata": {"category": "digital_eye_strain", "specialist": "optometrist"}
    },
    {
        "content": "Diabetic retinopathy is a complication of diabetes that affects the blood vessels in the retina. Regular eye examinations by an ophthalmologist are crucial for early detection and treatment to prevent vision loss.",
        "metadata": {"category": "diabetic_retinopathy", "specialist": "ophthalmologist"}
    },
    {
        "content": "Proper fitting of eyeglasses and contact lenses is essential for optimal vision correction. Opticians are trained to measure facial features, adjust frames, and ensure proper lens positioning for maximum comfort and effectiveness.",
        "metadata": {"category": "optical_fitting", "specialist": "optician"}
    },
    {
        "content": "Conjunctivitis (pink eye) can be caused by bacteria, viruses, or allergies. Bacterial conjunctivitis may require antibiotic treatment prescribed by an ophthalmologist or optometrist, while viral conjunctivitis usually resolves on its own.",
        "metadata": {"category": "conjunctivitis", "specialist": "ophthalmologist"}
    },
    {
        "content": "Retinal detachment is a serious condition where the retina separates from the underlying tissue. It requires emergency surgical intervention by a specialized ocular surgeon to prevent permanent vision loss.",
        "metadata": {"category": "retinal_detachment", "specialist": "ocular_surgeon", "urgency": "emergency"}
    },
    {
        "content": "Dry eye syndrome can cause discomfort, burning sensation, and vision fluctuations. Treatment options include artificial tears, prescription eye drops, and lifestyle modifications that can be recommended by an optometrist or ophthalmologist.",
        "metadata": {"category": "dry_eye", "specialist": "optometrist"}
    },
    {
        "content": "Age-related macular degeneration (AMD) affects central vision and is a leading cause of vision loss in older adults. Regular monitoring by an ophthalmologist is important for early detection and treatment options.",
        "metadata": {"category": "macular_degeneration", "specialist": "ophthalmologist"}
    },
    {
        "content": "Contact lens complications can include infections, corneal ulcers, and protein deposits. Proper lens care, regular replacement, and follow-up appointments with an optometrist are essential for safe contact lens wear.",
        "metadata": {"category": "contact_lens_care", "specialist": "optometrist"}
    },
    {
        "content": "Strabismus (crossed eyes) is a condition where the eyes do not align properly. Treatment may involve vision therapy, prisms in glasses fitted by an optician, or corrective surgery performed by an ocular surgeon.",
        "metadata": {"category": "strabismus", "specialist": "ocular_surgeon"}
    }
]

async def setup_test_data():
    """Upload sample documents to the knowledge base"""
    print("📚 Setting up test data in Qdrant vector store...")
    print("=" * 50)
    
    success_count = 0
    total_count = len(SAMPLE_DOCUMENTS)
    
    for i, doc in enumerate(SAMPLE_DOCUMENTS, 1):
        try:
            response = requests.post(
                f"{API_BASE_URL}/api/add-knowledge",
                json={
                    "content": doc["content"],
                    "metadata": doc["metadata"]
                },
                timeout=30
            )
            
            if response.status_code == 200:
                print(f"✅ Document {i}/{total_count}: {doc['metadata']['category']}")
                success_count += 1
            else:
                print(f"❌ Document {i}/{total_count} failed: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Document {i}/{total_count} failed: {str(e)}")
    
    print("\n" + "=" * 50)
    print(f"📊 Results: {success_count}/{total_count} documents uploaded successfully")
    
    if success_count == total_count:
        print("🎉 All test data uploaded successfully!")
        print("\nThe knowledge base is now ready for testing.")
    else:
        print("⚠️  Some documents failed to upload. Check the errors above.")
    
    return success_count == total_count

def check_server_running():
    """Check if the backend server is running"""
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

if __name__ == "__main__":
    # Check if server is running first
    if not check_server_running():
        print("❌ Backend server is not running!")
        print("\nTo start the server:")
        print("1. cd backend")
        print("2. python main.py")
        print("\nThen run this script again.")
        sys.exit(1)
    
    # Set up test data
    success = asyncio.run(setup_test_data())
    sys.exit(0 if success else 1)
