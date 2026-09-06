counter = 0

def increment() -> None:
    global counter
    counter += 1

increment()
increment()
increment()
print(f"Counter: {counter}")
