class Base:
    def __init__(self) -> None:
        super().__init__()
        self.base_attr = "base"

class Left(Base):
    def __init__(self) -> None:
        super().__init__()
        self.left_attr = "left"

class Right(Base):
    def __init__(self) -> None:
        super().__init__()
        self.right_attr = "right"

class Child(Left, Right):
    def __init__(self) -> None:
        super().__init__()
        self.child_attr = "child"

    def show(self):
        return f"{self.base_attr}, {self.left_attr}, {self.right_attr}, {self.child_attr}"

c = Child()
print(c.show())
