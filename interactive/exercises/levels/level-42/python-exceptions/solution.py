def safe_divide(a, b):
    try:
        return str(a / b)
    except (ZeroDivisionError, TypeError):
        return "Error: invalid operation"

results = []
results.append(safe_divide(10, 2))
results.append(safe_divide(10, 0))
results.append(safe_divide("10", 2))

for r in results:
    print(r)
