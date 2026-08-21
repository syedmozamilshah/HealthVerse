
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rag.data_loader import DataLoader

async def main():
    
    print("\nOptions:")
    print("1. Load data only if Qdrant is empty (recommended)")
    print("2. Force reload all data (overwrites existing)")
    
    choice = input("\nEnter your choice (1 or 2): ").strip()
    force_repopulate = choice == "2"
    
    if force_repopulate:
        print("WARNING: This will delete all existing data in Qdrant!")
        confirm = input("Are you sure? (yes/no): ").strip().lower()
        if confirm != "yes":
            print("Operation cancelled.")
            return
    
    loader = DataLoader()
    
    
    success = await loader.populate_qdrant(force_repopulate=force_repopulate)
    
    if success:
        print("\nData loading completed successfully!")
        
        test_queries = [
            "severe eye pain with halos around lights",
            "blurry vision and difficulty reading",
            "red itchy eyes with discharge"
        ]
        
        for query in test_queries:
            print(f"\n Testing query: '{query}'")
            await loader.test_search(query)
    else:
        print(f"\n Data loading failed!")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
