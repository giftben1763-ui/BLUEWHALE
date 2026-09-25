package routing

import (
	"encoding/json"
	"fmt"
	"strconv"
)

type MemoType string

const (
	MemoTypeNone   MemoType = "none"
	MemoTypeID     MemoType = "id"
	MemoTypeText   MemoType = "text"
	MemoTypeHash   MemoType = "hash"
	MemoTypeReturn MemoType = "return"
)

// RoutingID is a wrapper around a numeric string representing a 64-bit unsigned integer.
type RoutingID struct {
	raw string
}

func (r *RoutingID) UnmarshalJSON(data []byte) error {
	if r == nil {
		return fmt.Errorf("routing id: UnmarshalJSON on nil receiver")
	}

	if string(data) == "null" {
		r.raw = ""
		return nil
	}

	var id string
	if len(data) > 0 && data[0] == '"' {
		if err := json.Unmarshal(data, &id); err != nil {
			return fmt.Errorf("routing id: invalid quoted value: %w", err)
		}
	} else {
		id = string(data)
	}

	parsed, err := strconv.ParseUint(id, 10, 64)
	if err != nil {
		return fmt.Errorf("routing id: invalid uint64 value %q: %w", id, err)
	}

	r.raw = strconv.FormatUint(parsed, 10)
	return nil
}

// MarshalJSON serializes the routing ID as a JSON quoted decimal string
// (e.g. "18446744073709551615") rather than a bare integer literal.
//
// This is intentional: JavaScript clients and Flutter Web both represent
// numbers as IEEE-754 doubles, which can only hold integers exactly up to
// 2^53-1 (Number.MAX_SAFE_INTEGER = 9007199254740991).  Stellar M-address
// IDs may be up to 2^64-1, so emitting a bare integer would silently
// corrupt any ID above that boundary when parsed by a JS or Dart-Web
// client.  A quoted string forces the receiver to use BigInt / BigInt
// parsing and keeps the full uint64 precision intact.
func (r RoutingID) MarshalJSON() ([]byte, error) {
	if r.raw == "" {
		return []byte("null"), nil
	}
	return json.Marshal(r.raw)
}

func (r *RoutingID) String() string {
	if r == nil {
		return ""
	}
	return r.raw
}

func (r *RoutingID) Uint64() (uint64, error) {
	if r == nil {
		return 0, strconv.ErrSyntax
	}
	return strconv.ParseUint(r.raw, 10, 64)
}

func NewRoutingID(s string) *RoutingID {
	return &RoutingID{raw: s}
}
