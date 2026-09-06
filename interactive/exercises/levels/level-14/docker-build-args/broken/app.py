with open('version.txt') as f:
    version = f.read().strip()
if version:
    print(f"App version: {version}")
else:
    print("ERROR: Version not set!")
