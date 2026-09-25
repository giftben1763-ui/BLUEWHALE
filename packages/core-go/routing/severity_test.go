package routing

import (
	"reflect"
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
)

// The same table is asserted in core-ts (src/test/severity.test.ts) and
// core-dart (test/severity_test.dart) so that all three SDKs filter warnings
// identically: info = 0, warn = 1, error = 2.

const severityTestContract = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"

func warningCodes(warnings []address.Warning) []string {
	codes := make([]string, 0, len(warnings))
	for _, w := range warnings {
		codes = append(codes, string(w.Code))
	}
	return codes
}

func TestSeverityWeight(t *testing.T) {
	cases := map[string]int{
		SeverityInfo:  0,
		SeverityWarn:  1,
		SeverityError: 2,
		"fatal":       0,
		"":            0,
	}
	for severity, want := range cases {
		if got := SeverityWeight(severity); got != want {
			t.Errorf("SeverityWeight(%q) = %d, want %d", severity, got, want)
		}
	}
}

func TestFilterBySeverity(t *testing.T) {
	mixed := []address.Warning{
		{Code: address.WarnMemoIgnoredForMuxed, Severity: "info", Message: "info"},
		{Code: address.WarnNonCanonicalRoutingID, Severity: "warn", Message: "warn"},
		{Code: address.WarnInvalidDestination, Severity: "error", Message: "error"},
	}
	cases := []struct {
		min  string
		want []string
	}{
		{"info", []string{"MEMO_IGNORED_FOR_MUXED", "NON_CANONICAL_ROUTING_ID", "INVALID_DESTINATION"}},
		{"warn", []string{"NON_CANONICAL_ROUTING_ID", "INVALID_DESTINATION"}},
		{"error", []string{"INVALID_DESTINATION"}},
		{"bogus", []string{"MEMO_IGNORED_FOR_MUXED", "NON_CANONICAL_ROUTING_ID", "INVALID_DESTINATION"}},
	}
	for _, tc := range cases {
		t.Run(tc.min, func(t *testing.T) {
			if got := warningCodes(FilterBySeverity(mixed, tc.min)); !reflect.DeepEqual(got, tc.want) {
				t.Errorf("FilterBySeverity(%q) = %v, want %v", tc.min, got, tc.want)
			}
		})
	}
}

func TestExtractRouting_MinSeverityLevel(t *testing.T) {
	cases := []struct {
		name  string
		input RoutingInput
		want  map[string][]string
	}{
		{
			name:  "G + MEMO_TEXT '007' (warn)",
			input: RoutingInput{Destination: testBaseG, MemoType: "text", MemoValue: "007"},
			want: map[string][]string{
				"info":  {"NON_CANONICAL_ROUTING_ID"},
				"warn":  {"NON_CANONICAL_ROUTING_ID"},
				"error": {},
			},
		},
		{
			name:  "contract source (info)",
			input: RoutingInput{Destination: testBaseG, MemoType: "id", MemoValue: "1", SourceAccount: severityTestContract},
			want: map[string][]string{
				"info":  {"CONTRACT_SENDER_DETECTED"},
				"warn":  {},
				"error": {},
			},
		},
	}
	for _, tc := range cases {
		for _, min := range []string{"info", "warn", "error"} {
			t.Run(tc.name+"@"+min, func(t *testing.T) {
				input := tc.input
				input.MinSeverityLevel = min
				got := warningCodes(ExtractRouting(input).Warnings)
				if !reflect.DeepEqual(got, tc.want[min]) {
					t.Errorf("warnings = %v, want %v", got, tc.want[min])
				}
			})
		}
	}

	t.Run("defaults to info", func(t *testing.T) {
		got := warningCodes(ExtractRouting(cases[0].input).Warnings)
		if !reflect.DeepEqual(got, []string{"NON_CANONICAL_ROUTING_ID"}) {
			t.Errorf("warnings = %v", got)
		}
	})
}
