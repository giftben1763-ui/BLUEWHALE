package listener

import (
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/routing"
	"github.com/stellar/go/protocols/horizon"
	"github.com/stellar/go/protocols/horizon/operations"
)

const (
	testBaseG = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
	testMuxed = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG"
)

func newPayment(to, memoType, memo string) operations.Payment {
	p := operations.Payment{To: to}
	p.Transaction = &horizon.Transaction{MemoType: memoType, Memo: memo}
	return p
}

func TestExtractRouting_FromHorizonPayment(t *testing.T) {
	tests := []struct {
		name          string
		payment       operations.Payment
		wantBase      string
		wantRoutingID string
		wantSource    string
		wantSeverity  Severity
	}{
		{
			name:          "g_address_with_memo_id",
			payment:       newPayment(testBaseG, "id", "100"),
			wantBase:      testBaseG,
			wantRoutingID: "100",
			wantSource:    "memo",
			wantSeverity:  SeverityInfo,
		},
		{
			name:          "muxed_address_without_memo",
			payment:       newPayment(testMuxed, "none", ""),
			wantBase:      testBaseG,
			wantRoutingID: "9007199254740993",
			wantSource:    "muxed",
			wantSeverity:  SeverityInfo,
		},
		{
			name:         "g_address_without_memo_is_unroutable",
			payment:      newPayment(testBaseG, "none", ""),
			wantBase:     testBaseG,
			wantSource:   "none",
			wantSeverity: SeverityError,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractRouting(tt.payment)

			if got.DestinationBaseAccount != tt.wantBase {
				t.Errorf("DestinationBaseAccount = %q, want %q", got.DestinationBaseAccount, tt.wantBase)
			}
			if got.RoutingSource != tt.wantSource {
				t.Errorf("RoutingSource = %q, want %q", got.RoutingSource, tt.wantSource)
			}
			gotID := ""
			if got.RoutingID != nil {
				gotID = got.RoutingID.String()
			}
			if gotID != tt.wantRoutingID {
				t.Errorf("RoutingID = %q, want %q", gotID, tt.wantRoutingID)
			}
			if sev := MapResultToSeverity(got); sev != tt.wantSeverity {
				t.Errorf("MapResultToSeverity = %q, want %q", sev, tt.wantSeverity)
			}
		})
	}
}

func TestMapResultToSeverity(t *testing.T) {
	tests := []struct {
		name   string
		result routing.RoutingResult
		want   Severity
	}{
		{
			name:   "destination_error_is_error",
			result: routing.RoutingResult{DestinationError: &routing.DestinationError{}, RoutingSource: "memo"},
			want:   SeverityError,
		},
		{
			name:   "unroutable_is_error",
			result: routing.RoutingResult{RoutingSource: "none"},
			want:   SeverityError,
		},
		{
			name:   "clean_routing_is_info",
			result: routing.RoutingResult{RoutingSource: "memo"},
			want:   SeverityInfo,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := MapResultToSeverity(tt.result); got != tt.want {
				t.Errorf("MapResultToSeverity = %q, want %q", got, tt.want)
			}
		})
	}
}
