class SuppressErrors:
    def __init__(self, *exceptions) -> None:
        self.exceptions = exceptions

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type and issubclass(exc_type, self.exceptions):
            print(f"Suppressed: {exc_type.__name__}: {exc_val}")
            return True
        return False

with SuppressErrors(ValueError, TypeError):
    x = int("not_a_number")

print("Program continues after error")
