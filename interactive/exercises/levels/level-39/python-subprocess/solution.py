import subprocess

result = subprocess.run(["echo", "Hello from subprocess"], text=True, capture_output=True)
output = result.stdout.strip()
print(f"Captured: {output}")
