import subprocess

result = subprocess.run(["echo", "Hello from subprocess"], text=True)
output = result.stdout.strip()
print(f"Captured: {output}")
