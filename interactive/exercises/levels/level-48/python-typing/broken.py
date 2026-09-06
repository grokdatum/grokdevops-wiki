from typing import Dict, List


def summarize_scores(scores: Dict[str, List[int]]) -> Dict[str, float]:
    """Return a dict mapping each name to their average score, rounded to 1 decimal."""
    result = {}
    for name, values in scores.items():
        # Bug: using integer division instead of float division with rounding
        result[name] = sum(values) // len(values)
    return result

data = {
    "Alice": [90, 85, 92],
    "Bob": [78, 83, 80]
}

summary = summarize_scores(data)
for name in sorted(summary):
    print(f"{name}: {summary[name]}")
