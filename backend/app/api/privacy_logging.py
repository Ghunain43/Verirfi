"""Keep uvicorn's access log from recording what the privacy design avoids collecting.

- the client address is replaced by "-"
- /lookup/ and /report lines are dropped (the 4-hex prefix is in the lookup path)
Hosting platforms (Render, Railway, ...) keep their own request logs outside our control.
"""
import logging

_DROP_PATHS = ("/lookup/", "/report")


class AccessLogPrivacy(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        args = record.args
        if isinstance(args, tuple) and len(args) >= 3:
            if any(p in str(args[2]) for p in _DROP_PATHS):
                return False
            record.args = ("-",) + args[1:]
        return True


def install() -> None:
    logger = logging.getLogger("uvicorn.access")
    if not any(isinstance(f, AccessLogPrivacy) for f in logger.filters):
        logger.addFilter(AccessLogPrivacy())
