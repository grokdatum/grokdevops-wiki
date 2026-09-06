frontend = {"html", "css", "javascript", "react"}
backend = {"python", "javascript", "sql", "docker"}

# Find skills that appear in BOTH sets
common = frontend.union(backend)
print(f"Common skills: {sorted(common)}")
