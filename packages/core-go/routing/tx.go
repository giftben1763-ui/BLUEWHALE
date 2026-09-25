package routing

// TxPaymentOp is a language-native representation of a Stellar payment
// operation as returned by Horizon's operations endpoint or constructed via
// txnbuild. It mirrors the fields used for deposit routing without importing
// the full stellar/go SDK, keeping this package dependency-free.
//
// Populate from a Horizon OperationResponse or a txnbuild.Payment like so:
//
//	op := TxPaymentOp{
//	    Destination:   horizonOp.To,
//	    SourceAccount: horizonOp.From, // or tx.SourceAccount
//	    MemoType:      horizonTx.MemoType,
//	    MemoValue:     horizonTx.Memo,
//	}
type TxPaymentOp struct {
	// Destination is the recipient address from the payment operation
	// (can be a G-address, M-address, or C-address).
	Destination string

	// SourceAccount is the transaction source account (optional).
	// When populated and is a C-address, routing state is cleared.
	SourceAccount string

	// MemoType is the memo type string: "none", "id", "text", "hash", or "return".
	// Leave empty or set to "none" when no memo is attached.
	MemoType string

	// MemoValue is the raw memo value string. Ignored when MemoType is "none".
	MemoValue string
}

// ExtractRoutingFromTx extracts deposit routing information from a Stellar
// payment operation. It normalises the memo type, delegates to [ExtractRouting],
// and returns the full [RoutingResult] — including any applicable warnings.
//
// Mapping from Horizon/txnbuild field names to [TxPaymentOp]:
//
//   - horizonOp.To        → Destination
//   - horizonOp.From      → SourceAccount (optional)
//   - horizonTx.MemoType  → MemoType  ("none" | "id" | "text" | "hash" | "return")
//   - horizonTx.Memo      → MemoValue
//
// The function never panics. Invalid or unrecognisable memo types are
// forwarded to [ExtractRouting], which emits a WarnUnsupportedMemoType
// warning and fails open.
func ExtractRoutingFromTx(op TxPaymentOp) RoutingResult {
	memoType := normalizeTxMemoType(op.MemoType)

	return ExtractRouting(RoutingInput{
		Destination:   op.Destination,
		SourceAccount: op.SourceAccount,
		MemoType:      memoType,
		MemoValue:     op.MemoValue,
	})
}

// normalizeTxMemoType maps the memo type strings used by Horizon / txnbuild
// to the canonical lowercase values expected by [ExtractRouting].
//
// Horizon returns upper-case names ("MemoID", "MemoText", "MemoHash",
// "MemoReturn"); txnbuild constants ("MEMO_ID", "MEMO_TEXT", …) are also
// handled. An empty string is treated as "none".
func normalizeTxMemoType(raw string) string {
	switch raw {
	case "", "none", "MemoNone", "MEMO_NONE":
		return "none"
	case "id", "MemoID", "MEMO_ID":
		return "id"
	case "text", "MemoText", "MEMO_TEXT":
		return "text"
	case "hash", "MemoHash", "MEMO_HASH":
		return "hash"
	case "return", "MemoReturn", "MEMO_RETURN":
		return "return"
	default:
		return raw
	}
}
