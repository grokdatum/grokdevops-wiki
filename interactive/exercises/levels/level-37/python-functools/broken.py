from functools import lru_cache


@lru_cache(maxsize=128)
def sum_items(items):
    return sum(items)

numbers = [1, 2, 3, 4, 5]
result = sum_items(numbers)
print(f"Sum: {result}")
