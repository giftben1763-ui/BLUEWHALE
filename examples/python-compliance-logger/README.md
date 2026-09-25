# python-compliance-logger

A Python CLI tool that reads a CSV of Stellar deposit addresses, classifies
each one by address type (G / M / C) and risk label, writes an annotated
output CSV, and prints a formatted summary table to `stderr`.

Implements [issue #256](https://github.com/REDISHFISH/BLUEWHALE/issues/256).

## Requirements

Python 3.10+. No third-party dependencies.

## Usage

```bash
python3 main.py [--json] <input.csv> <output.csv>
```

With `--json`, a machine-readable compliance log is also printed to `stdout`:

```json
{
  "event": "compliance_summary",
  "total": 4,
  "by_address_type": {"C": 1, "G": 2, "M": 1},
  "by_risk_label": {"INVALID_DESTINATION": 1, "OK": 2, "WARN_MEMO_TYPE_MISMATCH": 1},
  "quarantined": [
    {"address": "CA...", "address_type": "C", "risk_label": "INVALID_DESTINATION", "notes": "..."}
  ]
}
```

`quarantined` lists deposits that cannot be credited (`INVALID_DESTINATION`,
`MISSING_MEMO`, `NON_ROUTABLE_MEMO`, `UNKNOWN`).

### Input CSV

| Column | Required | Description |
|---|---|---|
| `address` | yes | Stellar address (G-, M-, or C-address) |
| `memo_type` | no | `ID`, `TEXT`, `HASH`, or `RETURN` |
| `memo_value` | no | The memo value |

Example `deposits.csv`:

```csv
address,memo_type,memo_value
GA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBVQQNHNMGDPZAQ6BXQFN33,ID,12345
MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAAAAAAAAABQD,,
CA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBQQ,,
GA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBVQQNHNMGDPZAQ6BXQFN33,TEXT,99
```

### Output CSV

The output file contains all original columns plus:

| Column | Description |
|---|---|
| `address_type` | `G`, `M`, or `C` |
| `risk_label` | Classification result (see table below) |
| `notes` | Human-readable explanation |

### Risk Labels

| Label | Meaning |
|---|---|
| `OK` | Routable, no issues |
| `WARN_REDUNDANT_MEMO` | M-address with an external memo (memo is ignored) |
| `WARN_MEMO_TYPE_MISMATCH` | Numeric `MEMO_TEXT` that should have been `MEMO_ID` |
| `NON_ROUTABLE_MEMO` | Memo present but cannot yield a numeric routing ID |
| `MISSING_MEMO` | G-address with no memo — deposit cannot be routed |
| `INVALID_DESTINATION` | C-address — cannot receive deposits |

### Terminal Summary

After writing the CSV, the tool prints a summary to `stderr`:

```
+--------------------------------------------------+
|                COMPLIANCE SUMMARY                |
+--------------------------------------------------+
| Total transactions:          4                    |
+--------------------------------------------------+
| ADDRESS TYPE                 COUNT                |
+--------------------------------------------------+
| C                            1                    |
| G                            2                    |
| M                            1                    |
+--------------------------------------------------+
| RISK LABEL                   COUNT                |
+--------------------------------------------------+
| INVALID_DESTINATION          1                    |
| OK                           2                    |
| WARN_MEMO_TYPE_MISMATCH      1                    |
+--------------------------------------------------+
```

## Tests

```bash
./run_tests.sh
```

Runs `main.py` end-to-end against `tests/fixtures/deposits.csv`, checking that
it exits cleanly, writes the annotated CSV, and emits the expected JSON log
structure. These tests run in CI via `.github/workflows/ci-examples.yml`.

## Project Structure

```
python-compliance-logger/
├── main.py          # Entry point
├── run_tests.sh     # Test runner
├── src/
│   └── reporter.py  # print_summary(rows) terminal report, build_report(rows) JSON log
└── tests/
    ├── fixtures/deposits.csv
    └── test_main.py
```
