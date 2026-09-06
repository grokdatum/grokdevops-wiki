class Validated:
    def __init__(self, name, min_val=0) -> None:
        self.name = name
        self.min_val = min_val
        self.storage_name = f"_{name}"

    def __set_name__(self, owner, name) -> None:
        self.name = name
        self.storage_name = f"_{name}"

    def __get__(self, obj, objtype=None):
        if obj is None:
            return self
        return getattr(obj, self.storage_name, 0)

    def __set__(self, obj, value) -> None:
        if value < self.min_val:
            raise ValueError(f"{self.name} must be >= {self.min_val}")
        setattr(obj, self.storage_name, value)

class Product:
    price = Validated("price", min_val=0)
    quantity = Validated("quantity", min_val=1)

    def __init__(self, name, price, quantity) -> None:
        self.name = name
        self.price = price
        self.quantity = quantity

    def total(self):
        return self.price * self.quantity

p = Product("Widget", 25, 4)
print(f"Product: {p.name}")
print(f"Total: {p.total()}")
