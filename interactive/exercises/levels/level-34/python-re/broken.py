import re

text = "The cat sat on the mat"
pattern = "\bcat\b"

match = re.search(pattern, text)
if match:
    print(f"Found: '{match.group()}' at position {match.start()}")
else:
    print("No match found")
