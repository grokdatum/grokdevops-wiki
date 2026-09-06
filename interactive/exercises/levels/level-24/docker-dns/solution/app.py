import urllib.request

# Fixed: using service name for DNS resolution
try:
    response = urllib.request.urlopen("http://redis:6379")
    print("Connected to Redis!")
except Exception as e:
    print(f"Connection failed: {e}")
