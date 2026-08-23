import pymongo
from bson import json_util
import json

uri = "mongodb+srv://syedmozamilsherazi_db_user:bqogjxsop7AL7i3r@syedmozamilshah.hagzum9.mongodb.net/healthverse?appName=SyedMozamilShah"
client = pymongo.MongoClient(uri)
db = client['healthverse']
doctors = db['doctor']

doc = doctors.find_one({"email": "syedmozamilsherazi@gmail.com"})
if doc:
    print(json.dumps(doc, default=json_util.default, indent=2))
else:
    print("Not found")
