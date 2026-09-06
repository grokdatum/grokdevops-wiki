
class Inventory:
    def __init__(self, store_name) -> None:
        self.store_name = store_name
        self.items = {}  # Fix 1: instance variable

    def add_item(self, name, price, quantity) -> None:
        self.items[name] = {"price": price, "quantity": quantity}

    def get_total_value(self):
        total = 0
        for name, info in self.items.items():
            total += info["price"] * info["quantity"]
        return total

    def get_expensive_items(self, threshold):
        # Fix 2: correct comparison (>= for expensive)
        return [name for name, info in self.items.items() if info["price"] >= threshold]

    def apply_discount(self, pct) -> None:
        for name in self.items:
            # Fix 3: float division
            self.items[name]["price"] = self.items[name]["price"] * (100 - pct) / 100

def format_report(inventory):
    lines = []
    lines.append(f"Store: {inventory.store_name}")
    lines.append(f"Items: {len(inventory.items)}")

    for name, info in sorted(inventory.items.items()):
        lines.append(f"  {name}: ${info['price']:.2f} x {info['quantity']}")

    lines.append(f"Total value: ${inventory.get_total_value():.2f}")

    expensive = inventory.get_expensive_items(20)
    lines.append(f"Premium items: {sorted(expensive)}")

    return "\n".join(lines)

store = Inventory("TechMart")
store.add_item("Mouse", 25.00, 10)
store.add_item("Keyboard", 75.00, 5)
store.add_item("Cable", 5.00, 100)

store.apply_discount(10)

print(format_report(store))
