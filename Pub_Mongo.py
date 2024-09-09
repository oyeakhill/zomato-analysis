import requests
from pymongo import MongoClient
from datetime import datetime

# Define the ngrok API endpoint
ngrok_api_url = "http://localhost:4040/api/tunnels"

# MongoDB connection string (replace with your actual connection string)
mongo_connection_string = "mongodb+srv://chandirasegaransegar:jwQ7Rc2x3EBkNkvl@password.hgj3l.mongodb.net/Password?retryWrites=true&w=majority"

# Database and collection names
database_name = "PublicURL"
collection_name = "ngrok"

# Get the instance ID
instance_id_url = "http://169.254.169.254/latest/meta-data/instance-id"
instance_id = requests.get(instance_id_url).text

# Connect to MongoDB
client = MongoClient(mongo_connection_string)
db = client[database_name]
collection = db[collection_name]

# Perform a GET request to the ngrok API
try:
    response = requests.get(ngrok_api_url)
    response.raise_for_status()
    tunnels = response.json().get("tunnels", [])

    # Extract the public URL (assuming the first tunnel is HTTP)
    if tunnels:
        public_url = tunnels[0].get("public_url")
        print(f"ngrok Public URL: {public_url}")

        # Check if the instance ID already exists in MongoDB
        existing_document = collection.find_one({"instanceId": instance_id})

        if existing_document:
            # If instance ID exists, update the public URL
            collection.update_one(
                {"_id": existing_document["_id"]},
                {"$set": {
                    "publicUrl": public_url,
                    "updatedAt": datetime.utcnow().isoformat() + "Z"
                }}
            )
            print("Data updated in MongoDB.")
        else:
            # If instance ID does not exist, insert a new document
            insert_data = {
                "instanceId": instance_id,
                "publicUrl": public_url,
                "createdAt": datetime.utcnow().isoformat() + "Z"
            }
            collection.insert_one(insert_data)
            print("Data inserted into MongoDB.")
    else:
        print("No tunnels found.")
except requests.exceptions.RequestException as e:
    print(f"Error: {e}")
finally:
    # Close the MongoDB connection
    client.close()
