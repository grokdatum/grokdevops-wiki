def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

list1 = add_item("apple")
list2 = add_item("banana")
list3 = add_item("cherry")

print(f"List 1: {list1}")
print(f"List 2: {list2}")
print(f"List 3: {list3}")
