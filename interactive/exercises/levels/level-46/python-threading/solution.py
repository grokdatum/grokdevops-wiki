import threading
import time

counter = {"value": 0}
lock = threading.Lock()

def increment(n) -> None:
    for _ in range(n):
        with lock:
            val = counter["value"]
            time.sleep(0)  # Force context switch
            counter["value"] = val + 1

threads = []
for _ in range(4):
    t = threading.Thread(target=increment, args=(100,))
    threads.append(t)
    t.start()

for t in threads:
    t.join()

expected = 400
actual = counter["value"]
print(f"Expected: {expected}")
print(f"Actual: {actual}")
print(f"Safe: {actual == expected}")
