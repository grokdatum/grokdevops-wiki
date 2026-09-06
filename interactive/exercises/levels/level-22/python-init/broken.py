class Person:
    def __init__(self, name, age) -> None:
        self.name = name
        self.age = age

class Employee(Person):
    def __init__(self, name, age, company) -> None:
        self.company = company

    def info(self):
        return f"{self.name}, age {self.age}, works at {self.company}"

emp = Employee("Alice", 30, "TechCorp")
print(emp.info())
