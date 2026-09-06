import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s', stream=sys.stdout)
logger = logging.getLogger(__name__)

user = "Alice"
action = "login"
status = "success"

# Bug: Using f-string instead of lazy % formatting
logger.info(f"User {user} performed {action} with status {status}")
logger.info("Processing %s items for user %s", 42, user)
logger.debug(f"Debug info that should not appear: {1/0}")

print("Logging complete")
