package address

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

// fuzzSeedEdgeCases are hand-picked malformed and boundary inputs added to
// the fuzz corpus alongside the addresses from spec/vectors.json.
var fuzzSeedEdgeCases = []string{
	"",
	"G",
	"GA",
	"GAA",
	"M",
	"C",
	"====",
	"GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI=",
	" GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
	"gaycuyt553c5lhve2xpw5gmejt4bxgm7ahmjwlapzp53kjo7eiqadrsi",
	"GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSJ",
	"SBZVMB74Z76QZ3ZOY7UTDFYKMEGKW5XFJEB6PFKBF4UYSSWHG4EDH7PY",
	"MZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",
	"bob*example.com",
	"\x00\xff\xfe",
	"ǅſı",
	strings.Repeat("A", 1024),
}

// fuzzSeedsFromVectors returns every address-like input in spec/vectors.json.
func fuzzSeedsFromVectors(f *testing.F) []string {
	f.Helper()

	data, err := os.ReadFile("../../../spec/vectors.json")
	if err != nil {
		f.Fatalf("failed to read spec/vectors.json: %v", err)
	}

	var vectors struct {
		Cases []struct {
			Input map[string]any `json:"input"`
		} `json:"cases"`
	}
	if err := json.Unmarshal(data, &vectors); err != nil {
		f.Fatalf("failed to decode spec/vectors.json: %v", err)
	}

	var seeds []string
	for _, c := range vectors.Cases {
		for _, key := range []string{"address", "mAddress", "base_g", "destination"} {
			if s, ok := c.Input[key].(string); ok {
				seeds = append(seeds, s)
			}
		}
	}
	return seeds
}

func addFuzzSeeds(f *testing.F) {
	f.Helper()
	for _, s := range fuzzSeedsFromVectors(f) {
		f.Add(s)
	}
	for _, s := range fuzzSeedEdgeCases {
		f.Add(s)
	}
}

// FuzzParse verifies Parse never panics and that successful results are
// internally consistent.
func FuzzParse(f *testing.F) {
	addFuzzSeeds(f)

	f.Fuzz(func(t *testing.T, input string) {
		addr, err := Parse(input)
		if err != nil {
			if addr != nil {
				t.Fatalf("Parse(%q) returned both an address and error %v", input, err)
			}
			return
		}
		if addr == nil {
			t.Fatalf("Parse(%q) returned nil address and nil error", input)
		}

		switch addr.Kind {
		case KindG, KindM, KindC:
		default:
			t.Fatalf("Parse(%q) returned unknown kind %q", input, addr.Kind)
		}

		if addr.Raw != strings.ToUpper(input) {
			t.Fatalf("Parse(%q).Raw = %q, want uppercase input", input, addr.Raw)
		}

		nonCanonical := 0
		for _, w := range addr.Warnings {
			if w.Code == WarnNonCanonicalAddress {
				nonCanonical++
			}
		}
		wantNonCanonical := 0
		if addr.Raw != input {
			wantNonCanonical = 1
		}
		if nonCanonical != wantNonCanonical {
			t.Fatalf("Parse(%q) emitted %d NON_CANONICAL_ADDRESS warnings, want %d",
				input, nonCanonical, wantNonCanonical)
		}

		if addr.Kind == KindM {
			base, err := Parse(addr.BaseG)
			if err != nil || base.Kind != KindG {
				t.Fatalf("Parse(%q).BaseG = %q is not a valid G address: %v", input, addr.BaseG, err)
			}
		}
	})
}

// FuzzDetect verifies Detect never panics, only returns known kinds, and is
// case-insensitive.
func FuzzDetect(f *testing.F) {
	addFuzzSeeds(f)

	f.Fuzz(func(t *testing.T, input string) {
		kind, err := Detect(input)
		if err != nil {
			if kind != "" {
				t.Fatalf("Detect(%q) returned kind %q with error %v", input, kind, err)
			}
			return
		}

		switch kind {
		case KindG, KindM, KindC:
		default:
			t.Fatalf("Detect(%q) returned unknown kind %q", input, kind)
		}

		upperKind, upperErr := Detect(strings.ToUpper(input))
		if upperErr != nil || upperKind != kind {
			t.Fatalf("Detect(%q) = %q, but uppercase form gave %q, %v", input, kind, upperKind, upperErr)
		}
	})
}

func TestParse_NonCanonicalAddressWarning(t *testing.T) {
	const upperG = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"
	const upperM = "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG"

	tests := []struct {
		name     string
		input    string
		wantWarn bool
	}{
		{name: "uppercase G has no warning", input: upperG},
		{name: "lowercase G warns", input: strings.ToLower(upperG), wantWarn: true},
		{name: "mixed-case G warns", input: "g" + upperG[1:], wantWarn: true},
		{name: "uppercase M has no warning", input: upperM},
		{name: "lowercase M warns", input: strings.ToLower(upperM), wantWarn: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, err := Parse(tt.input)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if !tt.wantWarn {
				if len(addr.Warnings) != 0 {
					t.Fatalf("Warnings = %+v, want none", addr.Warnings)
				}
				return
			}

			want := Warning{
				Code:     WarnNonCanonicalAddress,
				Severity: "warn",
				Message:  "lowercase address was normalized to uppercase",
				Normalization: &Normalization{
					Original:   tt.input,
					Normalized: strings.ToUpper(tt.input),
				},
			}
			if len(addr.Warnings) != 1 {
				t.Fatalf("Warnings = %+v, want exactly one", addr.Warnings)
			}
			got := addr.Warnings[0]
			if got.Code != want.Code || got.Severity != want.Severity || got.Message != want.Message ||
				got.Normalization == nil || *got.Normalization != *want.Normalization {
				t.Fatalf("Warning = %+v, want %+v", got, want)
			}
			if _, err := json.Marshal(got); err != nil {
				t.Fatalf("warning does not serialize: %v", err)
			}
		})
	}
}

func TestParseMuxedAddress(t *testing.T) {
	const baseG = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI"

	tests := []struct {
		name       string
		mAddress   string
		wantBaseG  string
		wantMuxed  uint64
		shouldFail bool
	}{
		{
			name:      "decode id=0 boundary case",
			mAddress:  "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672",
			wantBaseG: baseG,
			wantMuxed: 0,
		},
		{
			name:      "decode id=1 small positive case",
			mAddress:  "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAHOO2",
			wantBaseG: baseG,
			wantMuxed: 1,
		},
		{
			name:      "decode id=2^53 precision boundary",
			mAddress:  "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAAFZG",
			wantBaseG: baseG,
			wantMuxed: 9007199254740992,
		},
		{
			name:      "decode id=2^53+1 interop canary",
			mAddress:  "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG",
			wantBaseG: baseG,
			wantMuxed: 9007199254740993,
		},
		{
			name:      "decode id=2^64-1 max uint64",
			mAddress:  "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQAD7777777777774OFW",
			wantBaseG: baseG,
			wantMuxed: 18446744073709551615,
		},
		{
			name:       "invalid M-address should return error",
			mAddress:   "MZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",
			shouldFail: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, err := Parse(tt.mAddress)

			if tt.shouldFail {
				if err == nil {
					t.Fatalf("expected error, got none")
				}
				return
			}

			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if addr.Kind != KindM {
				t.Fatalf("expected KindM, got %v", addr.Kind)
			}

			if addr.Raw != tt.mAddress {
				t.Errorf("Raw = %s, want %s", addr.Raw, tt.mAddress)
			}

			if addr.BaseG != tt.wantBaseG {
				t.Errorf("BaseG = %s, want %s", addr.BaseG, tt.wantBaseG)
			}

			if addr.MuxedID != tt.wantMuxed {
				t.Errorf("MuxedID = %d, want %d", addr.MuxedID, tt.wantMuxed)
			}
		})
	}
}
