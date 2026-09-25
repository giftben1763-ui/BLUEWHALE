"""Deposit routing for SEP-24 / SEP-31 anchor deposits.

Mirrors the Bluewhale routing rules (see spec/vectors.json) using only the
standard library:

* M-address  -> base G-account + muxed ID (any external memo is ignored)
* G-address  -> routing ID taken from MEMO_ID or numeric MEMO_TEXT
* C-address  -> rejected; contracts are not valid deposit destinations
"""
import base64
import binascii
import re

VERSION_ACCOUNT_ID = 6 << 3  # 'G'
VERSION_MUXED_ACCOUNT = 12 << 3  # 'M'
VERSION_CONTRACT = 2 << 3  # 'C'

MAX_UINT64 = 2**64 - 1
_DIGITS = re.compile(r"^[0-9]+$")


class StrKeyError(ValueError):
    pass


def _crc16_xmodem(data: bytes) -> int:
    return binascii.crc_hqx(data, 0)


def _decode(strkey: str) -> tuple[int, bytes]:
    padding = "=" * (-len(strkey) % 8)
    try:
        raw = base64.b32decode(strkey + padding)
    except (binascii.Error, ValueError) as exc:
        raise StrKeyError("invalid encoded string") from exc
    if len(raw) < 3:
        raise StrKeyError("invalid encoded string")
    # Reject non-canonical encodings (e.g. non-zero trailing bits).
    if base64.b32encode(raw).decode().rstrip("=") != strkey:
        raise StrKeyError("unused bits in base32 encoding must be zero")
    version, payload, checksum = raw[0], raw[1:-2], raw[-2:]
    if _crc16_xmodem(raw[:-2]).to_bytes(2, "little") != checksum:
        raise StrKeyError("invalid checksum")
    return version, payload


def _encode(version: int, payload: bytes) -> str:
    body = bytes([version]) + payload
    checksum = _crc16_xmodem(body).to_bytes(2, "little")
    return base64.b32encode(body + checksum).decode().rstrip("=")


def _warning(code: str, severity: str, message: str) -> dict:
    return {"code": code, "severity": severity, "message": message}


def _unroutable(warnings: list[dict], base: str | None = None) -> dict:
    return {
        "destination_base_account": base,
        "routing_id": None,
        "routing_source": "none",
        "warnings": warnings,
    }


def _parse_routing_id(value: str, warnings: list[dict]) -> str | None:
    if not _DIGITS.match(value) or int(value) > MAX_UINT64:
        return None
    canonical = str(int(value))
    if canonical != value:
        warnings.append(
            _warning(
                "NON_CANONICAL_ROUTING_ID",
                "warn",
                "routing ID had leading zeros and was normalized",
            )
        )
    return canonical


def extract_routing(destination: str, memo_type: str = "none", memo_value: str = "") -> dict:
    """Return the account to credit and the routing ID for an incoming deposit.

    Routing IDs are always returned as strings to avoid 64-bit precision loss.
    """
    destination = (destination or "").strip()
    memo_type = (memo_type or "none").strip().lower()
    memo_value = (memo_value or "").strip()
    warnings: list[dict] = []

    if destination != destination.upper():
        destination = destination.upper()
        warnings.append(
            _warning("NON_CANONICAL_ADDRESS", "warn", "lowercase address was normalized to uppercase")
        )

    try:
        version, payload = _decode(destination)
    except StrKeyError as exc:
        return _unroutable(warnings + [_warning("INVALID_DESTINATION", "error", str(exc))])

    if version == VERSION_CONTRACT:
        return _unroutable(
            warnings + [_warning("INVALID_DESTINATION", "error", "C address is not a valid destination")]
        )

    if version == VERSION_MUXED_ACCOUNT and len(payload) == 40:
        base = _encode(VERSION_ACCOUNT_ID, payload[:32])
        muxed_id = int.from_bytes(payload[32:], "big")
        if memo_type != "none":
            warnings.append(
                _warning(
                    "MEMO_IGNORED_FOR_MUXED",
                    "warn",
                    "M-address already encodes a routing ID; external memo ignored",
                )
            )
        return {
            "destination_base_account": base,
            "routing_id": str(muxed_id),
            "routing_source": "muxed",
            "warnings": warnings,
        }

    if version != VERSION_ACCOUNT_ID or len(payload) != 32:
        return _unroutable(
            warnings + [_warning("INVALID_DESTINATION", "error", "unsupported address type")]
        )

    if memo_type in ("id", "text") and memo_value:
        routing_id = _parse_routing_id(memo_value, warnings)
        if routing_id is not None:
            return {
                "destination_base_account": destination,
                "routing_id": routing_id,
                "routing_source": "memo",
                "warnings": warnings,
            }
        warnings.append(
            _warning("UNROUTABLE_MEMO", "warn", "memo does not contain a numeric routing ID")
        )
    elif memo_type in ("hash", "return"):
        warnings.append(
            _warning("UNROUTABLE_MEMO", "warn", "hash/return memos cannot carry a routing ID")
        )

    return _unroutable(warnings, base=destination)
