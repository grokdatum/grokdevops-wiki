from collections import defaultdict

words = ["apple", "banana", "apple", "cherry", "banana", "apple"]

word_count = defaultdict(int)
for word in words:
    word_count[word] += 1

for word in sorted(word_count):
    print(f"{word}: {word_count[word]}")
