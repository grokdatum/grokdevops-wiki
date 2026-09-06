from datetime import datetime

dt = datetime(2025, 3, 15, 14, 30, 0)

# Format: "2025-03-15 02:30 PM"
formatted = dt.strftime("%Y-%m-%d %H:%M %p")
print(f"Date: {formatted}")
