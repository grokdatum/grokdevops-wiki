import functools


def timer(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        """Wrapper function"""
        result = func(*args, **kwargs)
        return result
    return wrapper

@timer
def calculate_sum(numbers):
    """Calculate the sum of a list of numbers."""
    return sum(numbers)

print(f"Function name: {calculate_sum.__name__}")
print(f"Docstring: {calculate_sum.__doc__}")
print(f"Result: {calculate_sum([1, 2, 3, 4, 5])}")
