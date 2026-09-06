import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s', stream=sys.stdout)
logger = logging.getLogger(__name__)

user = "Alice"
action = "login"
status = "success"

# Fixed: Using lazy % formatting
logger.info("User %s performed %s with status %s", user, action, status)
logger.info("Processing %s items for user %s", 42, user)
logger.debug("Debug info that should not appear: %s", "expensive_calc")

print("Logging complete")
