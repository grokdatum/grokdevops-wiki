class PluginMeta(type):
    registry = {}

    def __new__(mcs, name, bases, namespace):
        cls = super().__new__(mcs, name, bases, namespace)
        mcs.registry[name] = cls
        return cls

class Plugin(metaclass=PluginMeta):
    def greet(self):
        return f"Hello from {type(self).__name__}"

class AuthPlugin(Plugin):
    pass

class CachePlugin(Plugin):
    pass

# Print registered plugins
for name in sorted(PluginMeta.registry):
    instance = PluginMeta.registry[name]()
    print(f"{name}: {instance.greet()}")

# Also try to instantiate from registry using wrong method
print(f"Total plugins: {len(PluginMeta.registry)}")
print(f"Base has greet: {hasattr(Plugin, 'greet')}")
print(f"Registry has Plugin: {'Plugin' in PluginMeta.registry}")
