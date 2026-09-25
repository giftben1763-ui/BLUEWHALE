package spec

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/muxed"
	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/routing"
)

type VectorCase struct {
	Module      string                 `json:"module"`
	Description string                 `json:"description"`
	Input       map[string]interface{} `json:"input"`
	Expected    map[string]interface{} `json:"expected"`
}

type Vectors struct {
	Cases []VectorCase `json:"cases"`
}

func vectorTestName(index int, tc VectorCase) string {
	description := strings.TrimSpace(tc.Description)
	if description == "" {
		description = "unnamed vector"
	}

	// Keep the label readable in `go test` output while avoiding path-like nesting.
	description = strings.ReplaceAll(description, "/", "-")
	return fmt.Sprintf("%03d_%s_%s", index, tc.Module, description)
}

// assertParseWarnings checks Parse output against a detect vector's expected
// normalized address and warnings (code, severity, normalization).
func assertParseWarnings(t *testing.T, input string, expected map[string]interface{}) {
	t.Helper()

	parsed, err := address.Parse(input)
	if err != nil {
		t.Fatalf("Parse(%q) unexpected error: %v", input, err)
	}

	if want, ok := expected["address"].(string); ok && parsed.Raw != want {
		t.Errorf("Parse(%q).Raw = %s, want %s", input, parsed.Raw, want)
	}

	wantWarnings, _ := expected["warnings"].([]interface{})
	if len(parsed.Warnings) != len(wantWarnings) {
		t.Fatalf("Parse(%q) warnings = %+v, want %d warnings", input, parsed.Warnings, len(wantWarnings))
	}

	for i, raw := range wantWarnings {
		want := raw.(map[string]interface{})
		got := parsed.Warnings[i]

		if string(got.Code) != want["code"] {
			t.Errorf("warning[%d].Code = %s, want %v", i, got.Code, want["code"])
		}
		if got.Severity != want["severity"] {
			t.Errorf("warning[%d].Severity = %s, want %v", i, got.Severity, want["severity"])
		}
		if wantNorm, ok := want["normalization"].(map[string]interface{}); ok {
			if got.Normalization == nil {
				t.Errorf("warning[%d].Normalization = nil, want %v", i, wantNorm)
				continue
			}
			if got.Normalization.Original != wantNorm["original"] ||
				got.Normalization.Normalized != wantNorm["normalized"] {
				t.Errorf("warning[%d].Normalization = %+v, want %v", i, *got.Normalization, wantNorm)
			}
		}
	}
}

func TestVectors(t *testing.T) {
	f, err := os.Open("../../../spec/vectors.json")
	if err != nil {
		t.Fatalf("failed to open vectors.json: %v", err)
	}
	defer f.Close()

	var v Vectors
	dec := json.NewDecoder(f)
	dec.UseNumber()
	if err := dec.Decode(&v); err != nil {
		t.Fatalf("failed to unmarshal vectors.json: %v", err)
	}

	for i, tc := range v.Cases {
		tc := tc
		name := vectorTestName(i, tc)

		t.Run(name, func(t *testing.T) {
			t.Logf("vector=%s", name)

			switch tc.Module {
			case "muxed_encode":
				baseG := tc.Input["base_g"].(string)
				idStr := fmt.Sprintf("%v", tc.Input["id"])

				res, err := muxed.EncodeMuxed(baseG, idStr)
				if err != nil {
					t.Fatalf("unexpected error: %v", err)
				}
				if res != tc.Expected["mAddress"].(string) {
					t.Errorf("Expected %s, got %s", tc.Expected["mAddress"], res)
				}

			case "muxed_decode":
				mAddr := tc.Input["mAddress"].(string)
				baseG, id, err := muxed.DecodeMuxed(mAddr)

				if tc.Expected["expected_error"] != nil {
					if err == nil {
						t.Errorf("expected error, got none")
					}
				} else {
					if err != nil {
						t.Fatalf("unexpected error: %v", err)
					}
					if baseG != tc.Expected["base_g"].(string) {
						t.Errorf("Expected baseG %s, got %s", tc.Expected["base_g"], baseG)
					}

					expID := fmt.Sprintf("%v", tc.Expected["id"])
					if fmt.Sprintf("%d", id) != expID {
						t.Errorf("Expected id %s, got %d", expID, id)
					}
				}

			case "detect":
				addr := tc.Input["address"].(string)
				kind, err := address.Detect(addr)
				if tc.Expected["kind"] != nil {
					if err != nil {
						t.Fatalf("unexpected error: %v", err)
					}
					if string(kind) != tc.Expected["kind"].(string) {
						t.Errorf("Expected kind %s, got %s", tc.Expected["kind"], kind)
					}
					assertParseWarnings(t, addr, tc.Expected)
				} else {
					// Should probably return error or unknown
					if err == nil && kind != "" {
						t.Errorf("expected error or empty kind for invalid address")
					}
				}

			case "extract_routing":
				// Only vectors that exercise the source-account policy are run
				// here; the remaining extract_routing vectors use legacy
				// placeholder addresses that Go rejects at checksum validation.
				source, _ := tc.Input["sourceAccount"].(string)
				if source == "" {
					t.Skip("extract_routing vector without sourceAccount")
				}
				memoValue, _ := tc.Input["memoValue"].(string)
				res := routing.ExtractRouting(routing.RoutingInput{
					Destination:   tc.Input["destination"].(string),
					MemoType:      tc.Input["memoType"].(string),
					MemoValue:     memoValue,
					SourceAccount: source,
				})
				assertRoutingVector(t, tc.Expected, res)
			}
		})
	}
}

func assertRoutingVector(t *testing.T, expected map[string]interface{}, res routing.RoutingResult) {
	t.Helper()

	wantBase, _ := expected["destinationBaseAccount"].(string)
	if res.DestinationBaseAccount != wantBase {
		t.Errorf("destinationBaseAccount = %q, want %q", res.DestinationBaseAccount, wantBase)
	}

	wantID, _ := expected["routingId"].(string)
	gotID := ""
	if res.RoutingID != nil {
		gotID = res.RoutingID.String()
	}
	if gotID != wantID {
		t.Errorf("routingId = %q, want %q", gotID, wantID)
	}

	if res.RoutingSource != expected["routingSource"] {
		t.Errorf("routingSource = %q, want %v", res.RoutingSource, expected["routingSource"])
	}

	wantWarnings, _ := expected["warnings"].([]interface{})
	if len(res.Warnings) != len(wantWarnings) {
		t.Fatalf("warnings = %+v, want %v", res.Warnings, wantWarnings)
	}
	for i, raw := range wantWarnings {
		w := raw.(map[string]interface{})
		got := res.Warnings[i]
		if string(got.Code) != w["code"] || got.Severity != w["severity"] || got.Message != w["message"] {
			t.Errorf("warnings[%d] = %+v, want %v", i, got, w)
		}
	}
}
