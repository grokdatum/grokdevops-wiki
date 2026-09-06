class Dog:
    def __init__(self, name, breed) -> None:
        self.name = name
        self.breed = breed

    def describe(self):
        return f"{self.name} is a {self.breed}"

dog = Dog("Rex", "German Shepherd")
print(dog.describe())
