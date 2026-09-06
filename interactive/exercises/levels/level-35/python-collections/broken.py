from collections import Counter

words = ["python", "java", "python", "go", "java", "python", "rust", "go", "java", "python"]

counter = Counter(words)
top_3 = counter.most_common[3]

for word, count in top_3:
    print(f"{word}: {count}")
