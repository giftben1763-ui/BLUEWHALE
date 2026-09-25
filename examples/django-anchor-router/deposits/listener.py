"""
Horizon Deposit Listener with Exponential-Backoff Retry
========================================================
Polls the Stellar Horizon API for incoming payments to a target account.
Wraps every Horizon call with tenacity-powered retry logic so that transient
HTTP 429 (Too Many Requests) and 504 (Gateway Timeout) errors trigger an
exponential back-off rather than crashing the process or silently dropping
transactions.

Usage (management command or standalone):
    python manage.py run_deposit_listener
    # or directly:
    python -c "from deposits.listener import run; run()"
"""

from __future__ import annotations

import logging
import os
from typing import Any

import requests
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger(__name__)

# ── Configuration ────────────────────────────────────────────────────────────

HORIZON_URL: str = os.environ.get(
    "HORIZON_URL", "https://horizon-testnet.stellar.org"
)
TARGET_ACCOUNT: str = os.environ.get(
    "HORIZON_TARGET_ACCOUNT",
    "GA7QYNF7SOWQ3GLR2B6RS22TBGZAOR6KLYH4PA5ZAM73A3H4K2HZZSQU",
)

# Retry policy: back off on 429 or 504, up to 5 attempts.
MAX_RETRY_ATTEMPTS: int = 5
WAIT_MULTIPLIER: float = 1.0   # seconds – base multiplier for exponential wait
WAIT_MIN: float = 2.0          # seconds – minimum wait before first retry
WAIT_MAX: float = 60.0         # seconds – cap on wait time


# ── Retry predicate ──────────────────────────────────────────────────────────

def _is_retryable(exc: BaseException) -> bool:
    """Return True for HTTP 429 and 504 responses; False for all other errors."""
    if isinstance(exc, requests.HTTPError):
        status = exc.response.status_code if exc.response is not None else None
        return status in (429, 504)
    return False


# ── Horizon client helpers ────────────────────────────────────────────────────

@retry(
    retry=retry_if_exception(_is_retryable),
    wait=wait_exponential(multiplier=WAIT_MULTIPLIER, min=WAIT_MIN, max=WAIT_MAX),
    stop=stop_after_attempt(MAX_RETRY_ATTEMPTS),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def _fetch_payments(cursor: str = "now") -> dict[str, Any]:
    """
    Fetch a page of payment operations from Horizon.

    Retries automatically on HTTP 429 and 504 with exponential back-off.
    The ``before_sleep`` hook logs a warning that includes the retry attempt
    count, the exception, and the time until the next attempt, e.g.:

        WARNING deposits.listener:listener.py Retrying _fetch_payments in 4.0s
        (attempt 2); last exception: 429 Client Error: Too Many Requests

    Args:
        cursor: Horizon paging cursor.  ``"now"`` starts from the live ledger.

    Returns:
        Parsed JSON response from Horizon as a Python dict.

    Raises:
        requests.HTTPError: Re-raised after all retry attempts are exhausted.
    """
    url = (
        f"{HORIZON_URL}/accounts/{TARGET_ACCOUNT}/payments"
        f"?cursor={cursor}&order=asc&limit=100&join=transactions"
    )
    logger.debug("GET %s", url)
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return response.json()


def _process_payment(record: dict[str, Any]) -> None:
    """
    Handle a single Horizon payment record.

    Extend this function with your own routing, database write, or
    downstream notification logic.
    """
    tx_hash = record.get("transaction_hash", "<unknown>")
    amount = record.get("amount", "0")
    asset = record.get("asset_code", "XLM")
    from_addr = record.get("from", "<unknown>")

    logger.info(
        "Received payment",
        extra={
            "tx_hash": tx_hash,
            "amount": amount,
            "asset": asset,
            "from": from_addr,
        },
    )


# ── Main loop ─────────────────────────────────────────────────────────────────

def run(cursor: str = "now") -> None:
    """
    Poll Horizon for payments in a tight loop, persisting the cursor across
    pages so no transaction is processed twice.

    This function is intentionally simple – production deployments should
    wrap it in a Django management command or Celery beat task and store
    the cursor in the database.
    """
    logger.info(
        "Starting Horizon deposit listener",
        extra={"account": TARGET_ACCOUNT, "cursor": cursor},
    )

    while True:
        try:
            page = _fetch_payments(cursor=cursor)
        except requests.HTTPError as exc:
            # All retries exhausted – log and exit so the supervisor can
            # restart the process (or raise to bubble up the error).
            logger.error(
                "Horizon request failed after %d attempts: %s",
                MAX_RETRY_ATTEMPTS,
                exc,
            )
            raise

        records = page.get("_embedded", {}).get("records", [])
        if not records:
            logger.debug("No new payments; sleeping before next poll.")
            import time
            time.sleep(5)
            continue

        for record in records:
            _process_payment(record)
            cursor = record.get("paging_token", cursor)
