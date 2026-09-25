#!/usr/bin/env python3
"""
python-compliance-logger
Reads a CSV of Stellar addresses, classifies each one, writes an annotated
output CSV, then prints a formatted summary to stderr.

Input CSV columns : address, memo_type (optional), memo_value (optional)
Output CSV columns: address, memo_type, memo_value, address_type, risk_label, notes

Pass --json to also print a machine-readable JSON compliance log to stdout.
"""
import csv
import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))
from reporter import build_report, print_summary


def classify(address: str, memo_type: str, memo_value: str) -> dict:
    address = address.strip()
    memo_type = memo_type.strip().upper()
    memo_value = memo_value.strip()

    if address.startswith("C"):
        return {
            "address_type": "C",
            "risk_label": "INVALID_DESTINATION",
            "notes": "Contract addresses cannot receive memo-based deposits.",
        }

    if address.startswith("M"):
        addr_type = "M"
        if memo_type and memo_value:
            return {
                "address_type": addr_type,
                "risk_label": "WARN_REDUNDANT_MEMO",
                "notes": "M-address already encodes a routing ID; external memo ignored.",
            }
        return {"address_type": addr_type, "risk_label": "OK", "notes": ""}

    if address.startswith("G"):
        addr_type = "G"
        if memo_type == "ID" and memo_value:
            return {"address_type": addr_type, "risk_label": "OK", "notes": ""}
        if memo_type == "TEXT" and memo_value.isdigit():
            return {
                "address_type": addr_type,
                "risk_label": "WARN_MEMO_TYPE_MISMATCH",
                "notes": "Numeric MEMO_TEXT should be MEMO_ID.",
            }
        if memo_type in ("TEXT", "HASH", "RETURN") and memo_value:
            return {
                "address_type": addr_type,
                "risk_label": "NON_ROUTABLE_MEMO",
                "notes": "Cannot extract a numeric routing ID from this memo.",
            }
        return {
            "address_type": addr_type,
            "risk_label": "MISSING_MEMO",
            "notes": "G-address deposit has no routing memo.",
        }

    return {"address_type": "UNKNOWN", "risk_label": "UNKNOWN", "notes": "Unrecognised address prefix."}


def process(input_path: str, output_path: str) -> list[dict]:
    rows: list[dict] = []
    with open(input_path, newline="") as f_in, open(output_path, "w", newline="") as f_out:
        reader = csv.DictReader(f_in)
        fieldnames = ["address", "memo_type", "memo_value", "address_type", "risk_label", "notes"]
        writer = csv.DictWriter(f_out, fieldnames=fieldnames)
        writer.writeheader()

        for record in reader:
            address = record.get("address", "")
            memo_type = record.get("memo_type", "")
            memo_value = record.get("memo_value", "")
            result = classify(address, memo_type, memo_value)
            row = {
                "address": address,
                "memo_type": memo_type,
                "memo_value": memo_value,
                **result,
            }
            writer.writerow(row)
            rows.append(row)

    return rows


def main() -> None:
    args = sys.argv[1:]
    emit_json = "--json" in args
    paths = [a for a in args if a != "--json"]
    if len(paths) != 2:
        print(f"Usage: {sys.argv[0]} [--json] <input.csv> <output.csv>", file=sys.stderr)
        sys.exit(1)

    input_path, output_path = paths
    rows = process(input_path, output_path)
    print(f"Wrote {len(rows)} rows to {output_path}", file=sys.stderr)
    print_summary(rows)
    if emit_json:
        print(json.dumps(build_report(rows), indent=2))


if __name__ == "__main__":
    main()
