import os

port = os.environ.get('APP_PORT', 'NOT SET')
name = os.environ.get('APP_NAME', 'NOT SET')
print(f"App {name} running on port {port}")
