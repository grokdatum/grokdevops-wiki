import asyncio


async def fetch_data(name, delay):
    await asyncio.sleep(delay)
    return f"Data from {name}"

async def main() -> None:
    result1 = await fetch_data("API-1", 0.1)
    result2 = await fetch_data("API-2", 0.1)
    print(f"Result 1: {result1}")
    print(f"Result 2: {result2}")

asyncio.run(main())
