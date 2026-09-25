package routing

import (
	"encoding/json"
	"errors"
	"strconv"
	"testing"
)

func TestRoutingIDNilSafety(t *testing.T) {
	var r *RoutingID

	if got := r.String(); got != "" {
		t.Errorf("nil String() = %q, want empty", got)
	}
	if !r.IsZero() {
		t.Error("nil IsZero() = false, want true")
	}
	if _, err := r.Uint64(); !errors.Is(err, ErrNoRoutingID) {
		t.Errorf("nil Uint64() error = %v, want ErrNoRoutingID", err)
	}

	var empty RoutingID
	if !empty.IsZero() {
		t.Error("zero-value IsZero() = false, want true")
	}
	if _, err := empty.Uint64(); !errors.Is(err, ErrNoRoutingID) {
		t.Errorf("zero-value Uint64() error = %v, want ErrNoRoutingID", err)
	}
}

func TestRoutingIDUint64(t *testing.T) {
	tests := []struct {
		name    string
		raw     string
		want    uint64
		wantErr bool
	}{
		{name: "zero", raw: "0", want: 0},
		{name: "one", raw: "1", want: 1},
		{name: "2^53", raw: "9007199254740992", want: 1 << 53},
		{name: "2^53+1", raw: "9007199254740993", want: 1<<53 + 1},
		{name: "max uint64", raw: "18446744073709551615", want: ^uint64(0)},
		{name: "overflow", raw: "18446744073709551616", wantErr: true},
		{name: "negative", raw: "-1", wantErr: true},
		{name: "non-numeric", raw: "abc", wantErr: true},
		{name: "whitespace", raw: " 1", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRoutingID(tt.raw)
			if r.IsZero() {
				t.Fatalf("IsZero() = true for %q", tt.raw)
			}
			if r.String() != tt.raw {
				t.Errorf("String() = %q, want %q", r.String(), tt.raw)
			}

			got, err := r.Uint64()
			if tt.wantErr {
				var numErr *strconv.NumError
				if !errors.As(err, &numErr) {
					t.Fatalf("Uint64() error = %v, want *strconv.NumError", err)
				}
				return
			}
			if err != nil {
				t.Fatalf("Uint64() unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("Uint64() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestRoutingIDMarshalJSON(t *testing.T) {
	tests := []struct {
		name string
		id   *RoutingID
		want string
	}{
		{name: "max uint64 as string", id: NewRoutingID("18446744073709551615"), want: `"18446744073709551615"`},
		{name: "zero is a value", id: NewRoutingID("0"), want: `"0"`},
		{name: "empty is null", id: &RoutingID{}, want: `null`},
		{name: "nil pointer is null", id: nil, want: `null`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := json.Marshal(tt.id)
			if err != nil {
				t.Fatalf("json.Marshal error: %v", err)
			}
			if string(got) != tt.want {
				t.Errorf("json.Marshal = %s, want %s", got, tt.want)
			}
		})
	}

	// Value (non-pointer) fields use the same encoding.
	body, err := json.Marshal(struct {
		ID RoutingID `json:"id"`
	}{ID: *NewRoutingID("42")})
	if err != nil {
		t.Fatalf("json.Marshal error: %v", err)
	}
	if string(body) != `{"id":"42"}` {
		t.Errorf("json.Marshal struct = %s, want {\"id\":\"42\"}", body)
	}
}

func TestRoutingIDJSONRoundTrip(t *testing.T) {
	for _, raw := range []string{"0", "7", "9007199254740993", "18446744073709551615"} {
		data, err := json.Marshal(NewRoutingID(raw))
		if err != nil {
			t.Fatalf("Marshal(%s): %v", raw, err)
		}
		var got RoutingID
		if err := json.Unmarshal(data, &got); err != nil {
			t.Fatalf("Unmarshal(%s): %v", data, err)
		}
		if got.String() != raw {
			t.Errorf("round trip %s -> %s -> %s", raw, data, got.String())
		}
	}
}

func TestRoutingIDUnmarshalJSONEdgeCases(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "null clears", input: `null`, want: ""},
		{name: "leading zeros canonicalized", input: `"007"`, want: "7"},
		{name: "number zero", input: `0`, want: "0"},
		{name: "overflow", input: `18446744073709551616`, wantErr: true},
		{name: "negative", input: `-1`, wantErr: true},
		{name: "float", input: `1.5`, wantErr: true},
		{name: "exponent", input: `1e3`, wantErr: true},
		{name: "empty string", input: `""`, wantErr: true},
		{name: "bool", input: `true`, wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRoutingID("99")
			err := json.Unmarshal([]byte(tt.input), r)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("Unmarshal(%s) = %q, want error", tt.input, r.String())
				}
				return
			}
			if err != nil {
				t.Fatalf("Unmarshal(%s) unexpected error: %v", tt.input, err)
			}
			if r.String() != tt.want {
				t.Errorf("Unmarshal(%s) = %q, want %q", tt.input, r.String(), tt.want)
			}
		})
	}
}

func TestRoutingResultJSONEncodesRoutingIDAsString(t *testing.T) {
	result := ExtractRouting(RoutingInput{
		Destination: benchMAddr,
		MemoType:    "none",
	})

	data, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("json.Marshal error: %v", err)
	}

	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal error: %v", err)
	}
	if decoded["routingId"] != "9007199254740993" {
		t.Errorf("routingId = %#v, want \"9007199254740993\"", decoded["routingId"])
	}
}
