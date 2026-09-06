def validate_age(age):
    assert(age >= 0, "Age cannot be negative")
    return f"Valid age: {age}"

# This should raise AssertionError but doesn't!
try:
    result = validate_age(-5)
    print(f"Bug! Got: {result}")
except AssertionError as e:
    print(f"Caught: {e}")
