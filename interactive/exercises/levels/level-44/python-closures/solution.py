def make_multipliers():
    multipliers = []
    for i in range(1, 4):
        multipliers.append(lambda x, i=i: x * i)
    return multipliers

mult1, mult2, mult3 = make_multipliers()
print(f"2 x 1 = {mult1(2)}")
print(f"2 x 2 = {mult2(2)}")
print(f"2 x 3 = {mult3(2)}")
