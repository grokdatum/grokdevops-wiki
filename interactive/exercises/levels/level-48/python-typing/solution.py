from typing import Dict, List


def summarize_scores(scores: Dict[str, List[int]]) -> Dict[str, float]:
    """Return a dict mapping each name to their average score, rounded to 1 decimal."""
    result = {}
    for name, values in scores.items():
        result[name] = round(sum(values) / len(values), 1)
    return result

data = {
    "Alice": [90, 85, 92],
    "Bob": [78, 83, 80]
}

summary = summarize_scores(data)
for name in sorted(summary):
    print(f"{name}: {summary[name]}")
