class Student:
    grades = []

    def __init__(self, name) -> None:
        self.name = name

    def add_grade(self, grade) -> None:
        self.grades.append(grade)

alice = Student("Alice")
bob = Student("Bob")

alice.add_grade(90)
bob.add_grade(75)

print(f"Alice: {alice.grades}")
print(f"Bob: {bob.grades}")
