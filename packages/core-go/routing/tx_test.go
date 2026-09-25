package routing

import (
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
)

func TestExtractRoutingFromTx_GAddressNoMemo(t *testing.T) {
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testBaseG,
		MemoType:    "none",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              nil,
		RoutingSource:          "none",
		Warnings:               []address.Warning{},
	})
}

func TestExtractRoutingFromTx_HorizonMemoID(t *testing.T) {
	// Horizon returns "MemoID" as the memo type string.
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testBaseG,
		MemoType:    "MemoID",
		MemoValue:   "42",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              NewRoutingID("42"),
		RoutingSource:          "memo",
		Warnings:               []address.Warning{},
	})
}

func TestExtractRoutingFromTx_TxnbuildMemoText(t *testing.T) {
	// txnbuild uses "MEMO_TEXT" as the memo type constant.
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testBaseG,
		MemoType:    "MEMO_TEXT",
		MemoValue:   "99",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              NewRoutingID("99"),
		RoutingSource:          "memo",
		Warnings:               []address.Warning{},
	})
}

func TestExtractRoutingFromTx_MuxedDestination(t *testing.T) {
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testMuxed,
		MemoType:    "none",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              NewRoutingID("9007199254740993"),
		RoutingSource:          "muxed",
		Warnings:               []address.Warning{},
	})
}

func TestExtractRoutingFromTx_MuxedWithHorizonMemoID(t *testing.T) {
	// M-address takes precedence over a co-present MEMO_ID.
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testMuxed,
		MemoType:    "MemoID",
		MemoValue:   "7",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              NewRoutingID("9007199254740993"),
		RoutingSource:          "muxed",
		Warnings: []address.Warning{
			{
				Code:     address.WarnMemoPresentWithMuxed,
				Severity: "warn",
				Message:  "Routing ID found in both M-address and Memo. M-address ID takes precedence.",
			},
		},
	})
}

func TestExtractRoutingFromTx_ContractSourceClearsRouting(t *testing.T) {
	contractAddress, err := address.EncodeStrKey(address.VersionByteC, make([]byte, 32))
	if err != nil {
		t.Fatalf("failed to generate contract address: %v", err)
	}

	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination:   testBaseG,
		SourceAccount: contractAddress,
		MemoType:      "MEMO_ID",
		MemoValue:     "100",
	})

	assertRoutingResult(t, result, RoutingResult{
		RoutingSource: "none",
		Warnings: []address.Warning{
			{
				Code:     address.WarnContractSenderDetected,
				Severity: "info",
				Message:  "Contract source detected. Routing state cleared.",
			},
		},
	})
}

func TestExtractRoutingFromTx_EmptyMemoTypeDefaultsToNone(t *testing.T) {
	// An empty MemoType should be treated as "none".
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testBaseG,
		MemoType:    "",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              nil,
		RoutingSource:          "none",
		Warnings:               []address.Warning{},
	})
}

func TestExtractRoutingFromTx_HorizonMemoHash(t *testing.T) {
	result := ExtractRoutingFromTx(TxPaymentOp{
		Destination: testBaseG,
		MemoType:    "MemoHash",
		MemoValue:   "abc123",
	})

	assertRoutingResult(t, result, RoutingResult{
		DestinationBaseAccount: testBaseG,
		RoutingID:              nil,
		RoutingSource:          "none",
		Warnings: []address.Warning{
			{
				Code:     address.WarnUnsupportedMemoType,
				Severity: "warn",
				Message:  "Memo type hash is not supported for routing.",
				Context: &address.WarningContext{
					MemoType: "hash",
				},
			},
		},
	})
}

func TestExtractRoutingFromTx_NormalizeTxMemoType(t *testing.T) {
	cases := []struct {
		raw      string
		expected string
	}{
		{"", "none"},
		{"none", "none"},
		{"MemoNone", "none"},
		{"MEMO_NONE", "none"},
		{"id", "id"},
		{"MemoID", "id"},
		{"MEMO_ID", "id"},
		{"text", "text"},
		{"MemoText", "text"},
		{"MEMO_TEXT", "text"},
		{"hash", "hash"},
		{"MemoHash", "hash"},
		{"MEMO_HASH", "hash"},
		{"return", "return"},
		{"MemoReturn", "return"},
		{"MEMO_RETURN", "return"},
		{"unknown_custom", "unknown_custom"}, // pass through unknown values
	}

	for _, tc := range cases {
		t.Run(tc.raw, func(t *testing.T) {
			got := normalizeTxMemoType(tc.raw)
			if got != tc.expected {
				t.Errorf("normalizeTxMemoType(%q) = %q, want %q", tc.raw, got, tc.expected)
			}
		})
	}
}
