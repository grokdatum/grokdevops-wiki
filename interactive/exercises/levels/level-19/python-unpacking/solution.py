record = ("Alice", 30, "Engineer", "New York", "USA")

# Unpack the record
name, age, job, *_ = record

print(f"Name: {name}, Age: {age}, Job: {job}")
