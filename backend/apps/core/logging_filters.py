import logging


class ExcludeHealthCheckAccessFilter(logging.Filter):
    """Drop noisy access logs for health endpoints to reduce log/IO overhead."""

    def filter(self, record: logging.LogRecord) -> bool:
        message = record.getMessage()
        return '"GET /health' not in message and '"HEAD /health' not in message