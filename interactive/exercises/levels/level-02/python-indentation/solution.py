def greet(name) -> None:
    if name:
        message = f"Hello, {name}!"
        print(message)
    else:
        message = "Hello, stranger!"
        print(message)

greet("Alice")
