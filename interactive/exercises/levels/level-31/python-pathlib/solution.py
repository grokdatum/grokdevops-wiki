from pathlib import Path

base = Path("/home/user")
config_file = base / "config" / "settings.json"
print(f"Config path: {config_file}")
