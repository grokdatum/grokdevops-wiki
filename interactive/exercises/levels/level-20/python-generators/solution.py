def squares(n):
    for i in range(1, n + 1):
        yield i ** 2

nums = list(squares(5))

total = sum(nums)
count = len(nums)
average = total / count if count > 0 else 0

print(f"Sum: {total}")
print(f"Average: {average}")
