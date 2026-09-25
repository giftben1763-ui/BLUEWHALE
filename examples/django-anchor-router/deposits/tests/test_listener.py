"""
Unit tests for deposits.listener – exponential-backoff retry behaviour.

Run with:
    python -m pytest examples/django-anchor-router/deposits/tests/test_listener.py -v
"""

from __future__ import annotations

import importlib
import sys
import unittest
from unittest.mock import MagicMock, call, patch

import requests

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_http_error(status_code: int) -> requests.HTTPError:
    """Build a requests.HTTPError with the given HTTP status code."""
    response = MagicMock(spec=requests.Response)
    response.status_code = status_code
    err = requests.HTTPError(response=response)
    return err


# ---------------------------------------------------------------------------
# Ensure Django settings are configured before importing the module under test
# ---------------------------------------------------------------------------

import django
from django.conf import settings

if not settings.configured:
    settings.configure(
        INSTALLED_APPS=[
            "django.contrib.contenttypes",
            "django.contrib.auth",
            "deposits",
        ],
        DATABASES={
            "default": {
                "ENGINE": "django.db.backends.sqlite3",
                "NAME": ":memory:",
            }
        },
    )
    django.setup()

from deposits import listener  # noqa: E402 – must follow settings.configure()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestRetryPredicate(unittest.TestCase):
    """_is_retryable should only return True for HTTP 429 and 504."""

    def test_429_is_retryable(self) -> None:
        err = _make_http_error(429)
        self.assertTrue(listener._is_retryable(err))

    def test_504_is_retryable(self) -> None:
        err = _make_http_error(504)
        self.assertTrue(listener._is_retryable(err))

    def test_500_is_not_retryable(self) -> None:
        err = _make_http_error(500)
        self.assertFalse(listener._is_retryable(err))

    def test_404_is_not_retryable(self) -> None:
        err = _make_http_error(404)
        self.assertFalse(listener._is_retryable(err))

    def test_generic_exception_is_not_retryable(self) -> None:
        self.assertFalse(listener._is_retryable(ValueError("boom")))


class TestFetchPaymentsRetry(unittest.TestCase):
    """
    _fetch_payments should retry transparently on 429 and eventually
    succeed when a later attempt returns 200.
    """

    def _ok_response(self) -> MagicMock:
        resp = MagicMock(spec=requests.Response)
        resp.status_code = 200
        resp.json.return_value = {"_embedded": {"records": []}}
        resp.raise_for_status.return_value = None
        return resp

    def _error_response(self, status_code: int) -> MagicMock:
        resp = MagicMock(spec=requests.Response)
        resp.status_code = status_code
        resp.raise_for_status.side_effect = _make_http_error(status_code)
        return resp

    # ------------------------------------------------------------------ #

    @patch("deposits.listener.requests.get")
    def test_succeeds_on_first_attempt(self, mock_get: MagicMock) -> None:
        """No retry when Horizon responds 200 immediately."""
        mock_get.return_value = self._ok_response()

        # Re-wrap with a fast wait so the test doesn't sleep
        with _fast_retry():
            result = listener._fetch_payments(cursor="now")

        self.assertEqual(mock_get.call_count, 1)
        self.assertIn("_embedded", result)

    @patch("deposits.listener.requests.get")
    def test_retries_on_429_then_succeeds(self, mock_get: MagicMock) -> None:
        """
        Simulates two consecutive 429 responses followed by a successful 200.
        _fetch_payments should retry twice and eventually return the 200 payload.
        """
        mock_get.side_effect = [
            self._error_response(429),  # attempt 1 → 429
            self._error_response(429),  # attempt 2 → 429
            self._ok_response(),        # attempt 3 → 200 ✓
        ]

        with _fast_retry():
            result = listener._fetch_payments(cursor="now")

        self.assertEqual(mock_get.call_count, 3)
        self.assertIn("_embedded", result)

    @patch("deposits.listener.requests.get")
    def test_retries_on_504_then_succeeds(self, mock_get: MagicMock) -> None:
        """Same as above but with 504 Gateway Timeout."""
        mock_get.side_effect = [
            self._error_response(504),  # attempt 1 → 504
            self._ok_response(),        # attempt 2 → 200 ✓
        ]

        with _fast_retry():
            result = listener._fetch_payments(cursor="now")

        self.assertEqual(mock_get.call_count, 2)
        self.assertIn("_embedded", result)

    @patch("deposits.listener.requests.get")
    def test_raises_after_max_attempts(self, mock_get: MagicMock) -> None:
        """
        When every attempt returns 429, the retry mechanism should exhaust
        all attempts and re-raise the last HTTPError.
        """
        mock_get.return_value = self._error_response(429)

        with _fast_retry():
            with self.assertRaises(requests.HTTPError) as ctx:
                listener._fetch_payments(cursor="now")

        # MAX_RETRY_ATTEMPTS calls in total
        self.assertEqual(mock_get.call_count, listener.MAX_RETRY_ATTEMPTS)
        self.assertEqual(ctx.exception.response.status_code, 429)

    @patch("deposits.listener.requests.get")
    def test_non_retryable_error_raises_immediately(
        self, mock_get: MagicMock
    ) -> None:
        """A 404 should NOT be retried – it must propagate on the first attempt."""
        mock_get.return_value = self._error_response(404)

        with _fast_retry():
            with self.assertRaises(requests.HTTPError):
                listener._fetch_payments(cursor="now")

        self.assertEqual(mock_get.call_count, 1)


# ---------------------------------------------------------------------------
# Context manager to patch tenacity wait so tests don't actually sleep
# ---------------------------------------------------------------------------

import contextlib
from tenacity import wait_none


@contextlib.contextmanager
def _fast_retry():
    """
    Temporarily replace the exponential-wait policy on _fetch_payments with
    wait_none() so unit tests complete without sleeping.
    """
    original = listener._fetch_payments.retry.wait
    listener._fetch_payments.retry.wait = wait_none()
    try:
        yield
    finally:
        listener._fetch_payments.retry.wait = original


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    unittest.main()
