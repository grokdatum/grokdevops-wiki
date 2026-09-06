def greet(name):
    if name:
            message = f"Hello, {name}!"
    print(message)
    else:
        message = "Hello, stranger!"
        print(message)

greet("Alice")
