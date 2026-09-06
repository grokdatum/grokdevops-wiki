class User:
    __slots__ = ('name', 'age')

    def __init__(self, name, age, email) -> None:
        self.name = name
        self.age = age
        self.email = email

    def info(self):
        return f"{self.name} ({self.age}) - {self.email}"

u = User("Alice", 30, "alice@example.com")
print(u.info())
