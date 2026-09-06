import argparse

parser = argparse.ArgumentParser(description="Greeter")
parser.add_argument("--name", required=True, help="Name to greet")
parser.add_argument("--times", default=1, help="Number of times")

# Simulate command line: --name World --times 3
args = parser.parse_args(["--name", "World", "--times", "3"])

greetings = []
for i in range(args.times):
    greetings.append(f"Hello, {args.name}!")

print("\n".join(greetings))
