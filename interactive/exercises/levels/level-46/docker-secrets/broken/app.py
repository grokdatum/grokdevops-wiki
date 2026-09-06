import os
db_pass = os.environ.get('DATABASE_PASSWORD')
api_key = os.environ.get('API_KEY')
print(f"Connected with credentials (length: {len(db_pass)}, {len(api_key)})")
