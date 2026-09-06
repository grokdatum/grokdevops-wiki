import urllib.request

# Bug: using localhost instead of service name
try:
    response = urllib.request.urlopen("http://localhost:6379")
    print("Connected to Redis!")
except Exception as e:
    print(f"Connection failed: {e}")
