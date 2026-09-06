import json

data = {
    "name": "Alice",
    "scores": {85, 92, 78},
    "active": True
}

result = json.dumps(data, sort_keys=True)
print(result)
