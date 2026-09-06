from itertools import chain

nested = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

flat = list(chain.from_iterable(nested))
print(f"Flat: {flat}")
