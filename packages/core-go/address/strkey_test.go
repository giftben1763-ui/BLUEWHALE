package address

import (
	"bytes"
	"testing"

	"github.com/stellar/go/strkey"
)

func TestDecodeStrKey(t *testing.T) {
	tests := []struct {
		name        string
		address     string
		expectedVB  byte
		expectError bool
	}{
		{
			name:       "Valid G address",
			address:    "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
			expectedVB: VersionByteG,
		},
		{
			name:       "Valid M address",
			address:    "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672",
			expectedVB: VersionByteM,
		},
		{
			name:        "Invalid checksum",
			address:     "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSJ", // Last char changed
			expectError: true,
		},
		{
			name:        "Invalid base32",
			address:     "GZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",
			expectError: true,
		},
		{
			name:        "Unknown version byte",
			address:     "SAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI", // S is seed
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vb, payload, err := DecodeStrKey(tt.address)

			if tt.expectError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}

			if vb != tt.expectedVB {
				t.Errorf("expected version byte %d, got %d", tt.expectedVB, vb)
			}

			// Check payload length
			if tt.address[0] == 'G' || tt.address[0] == 'C' {
				if len(payload) != 32 {
					t.Errorf("expected payload length 32, got %d", len(payload))
				}
			} else if tt.address[0] == 'M' {
				if len(payload) != 40 {
					t.Errorf("expected payload length 40, got %d", len(payload))
				}
			}
		})
	}
}

func TestDetect(t *testing.T) {
	tests := []struct {
		name    string
		address string
		kind    AddressKind
		wantErr bool
	}{
		{
			name:    "Valid G address",
			address: "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI",
			kind:    KindG,
		},
		{
			name:    "Valid M address",
			address: "MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672",
			kind:    KindM,
		},
		{
			name: "Valid C address",
		},
		{
			name:    "Invalid address",
			address: "INVALID",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr := tt.address
			// For C-address test, generate a valid C address dynamically.
			if tt.name == "Valid C address" {
				payload := make([]byte, 32)
				var err error
				addr, err = EncodeStrKey(VersionByteC, payload)
				if err != nil {
					t.Fatalf("failed to generate C address: %v", err)
				}
				tt.kind = KindC
			}

			kind, err := Detect(addr)
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error, got none")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if kind != tt.kind {
				t.Errorf("expected kind %v, got %v", tt.kind, kind)
			}
		})
	}
}

// TestStrKeyMatchesStellarGo cross-checks the in-house strkey codec against
// github.com/stellar/go/strkey, the reference implementation. See
// docs/WHY_STRKEY_DEP.md for why address/ does not call it directly.
func TestStrKeyMatchesStellarGo(t *testing.T) {
	kinds := []struct {
		name       string
		ours       byte
		reference  strkey.VersionByte
		payloadLen int
	}{
		{name: "G", ours: VersionByteG, reference: strkey.VersionByteAccountID, payloadLen: 32},
		{name: "M", ours: VersionByteM, reference: strkey.VersionByteMuxedAccount, payloadLen: 40},
		{name: "C", ours: VersionByteC, reference: strkey.VersionByteContract, payloadLen: 32},
	}

	for _, k := range kinds {
		for seed := 0; seed < 64; seed++ {
			payload := make([]byte, k.payloadLen)
			for i := range payload {
				payload[i] = byte(seed*31 + i*7)
			}

			want, err := strkey.Encode(k.reference, payload)
			if err != nil {
				t.Fatalf("%s: strkey.Encode: %v", k.name, err)
			}
			got, err := EncodeStrKey(k.ours, payload)
			if err != nil {
				t.Fatalf("%s: EncodeStrKey: %v", k.name, err)
			}
			if got != want {
				t.Fatalf("%s seed %d: EncodeStrKey = %s, stellar/go = %s", k.name, seed, got, want)
			}

			vb, decoded, err := DecodeStrKey(want)
			if err != nil {
				t.Fatalf("%s seed %d: DecodeStrKey(%s): %v", k.name, seed, want, err)
			}
			refDecoded, err := strkey.Decode(k.reference, want)
			if err != nil {
				t.Fatalf("%s seed %d: strkey.Decode: %v", k.name, seed, err)
			}
			if vb != k.ours || !bytes.Equal(decoded, refDecoded) {
				t.Fatalf("%s seed %d: DecodeStrKey payload differs from stellar/go", k.name, seed)
			}
		}
	}
}
