"""End-to-end tests: run main.py as a subprocess and check its outputs."""
import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "main.py"
FIXTURE = ROOT / "tests" / "fixtures" / "deposits.csv"

EXPECTED_LABELS = [
    "OK",
    "OK",
    "INVALID_DESTINATION",
    "WARN_MEMO_TYPE_MISMATCH",
    "MISSING_MEMO",
    "WARN_REDUNDANT_MEMO",
]


class ComplianceLoggerRunTests(unittest.TestCase):
    def run_main(self, *args):
        return subprocess.run(
            [sys.executable, str(MAIN), *args],
            capture_output=True,
            text=True,
            timeout=30,
        )

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.output = Path(self.tmp.name) / "out.csv"

    def tearDown(self):
        self.tmp.cleanup()

    def test_exits_cleanly_and_writes_annotated_csv(self):
        proc = self.run_main(str(FIXTURE), str(self.output))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertIn("COMPLIANCE SUMMARY", proc.stderr)
        self.assertIn(f"Wrote {len(EXPECTED_LABELS)} rows", proc.stderr)

        with self.output.open(newline="") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(
            list(rows[0].keys()),
            ["address", "memo_type", "memo_value", "address_type", "risk_label", "notes"],
        )
        self.assertEqual([r["risk_label"] for r in rows], EXPECTED_LABELS)

    def test_json_log_matches_expected_structure(self):
        proc = self.run_main("--json", str(FIXTURE), str(self.output))
        self.assertEqual(proc.returncode, 0, proc.stderr)

        report = json.loads(proc.stdout)
        self.assertEqual(
            set(report), {"event", "total", "by_address_type", "by_risk_label", "quarantined"}
        )
        self.assertEqual(report["event"], "compliance_summary")
        self.assertEqual(report["total"], 6)
        self.assertEqual(report["by_address_type"], {"C": 1, "G": 3, "M": 2})
        self.assertEqual(
            report["by_risk_label"],
            {
                "INVALID_DESTINATION": 1,
                "MISSING_MEMO": 1,
                "OK": 2,
                "WARN_MEMO_TYPE_MISMATCH": 1,
                "WARN_REDUNDANT_MEMO": 1,
            },
        )
        self.assertEqual(sum(report["by_risk_label"].values()), report["total"])

        quarantined = report["quarantined"]
        self.assertEqual([q["risk_label"] for q in quarantined], ["INVALID_DESTINATION", "MISSING_MEMO"])
        for entry in quarantined:
            self.assertEqual(set(entry), {"address", "address_type", "risk_label", "notes"})
            self.assertTrue(entry["notes"])

    def test_usage_error_exits_non_zero(self):
        proc = self.run_main(str(FIXTURE))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Usage:", proc.stderr)


if __name__ == "__main__":
    unittest.main()
