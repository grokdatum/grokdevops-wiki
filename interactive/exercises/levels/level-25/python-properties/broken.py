class Thermostat:
    def __init__(self, temp) -> None:
        self._temp = temp

    @property
    def temperature(self):
        return self._temp

t = Thermostat(20)
print(f"Initial: {t.temperature}C")
t.temperature = 25
print(f"Updated: {t.temperature}C")
