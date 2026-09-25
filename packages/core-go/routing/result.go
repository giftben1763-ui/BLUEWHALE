package routing

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
)

// ErrNoRoutingID is returned by RoutingID.Uint64 when the RoutingID is nil
// or holds no value.
var ErrNoRoutingID = errors.New("routing id: no value")

var (
	_ json.Marshaler   = RoutingID{}
	_ json.Unmarshaler = (*RoutingID)(nil)
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
//
// The zero value (and a nil *RoutingID) holds no ID. All accessors are
// nil-safe. JSON encoding uses a decimal string ("123") so values above
// 2^53 survive JavaScript consumers; decoding accepts a string or a number.
type RoutingID struct {
	raw string
}

// MarshalJSON encodes the ID as a JSON decimal string, or null when empty.
func (r RoutingID) MarshalJSON() ([]byte, error) {
	if r.raw == "" {
		return []byte("null"), nil
	}
	return json.Marshal(r.raw)
}

// UnmarshalJSON accepts a JSON number, a quoted decimal string, or null.
// Values are canonicalized (leading zeros removed) and must fit in uint64.
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

// String returns the decimal representation of the ID, or "" when r is nil
// or empty.
func (r *RoutingID) String() string {
	if r == nil {
		return ""
	}
	return r.raw
}

// Uint64 returns the ID as a uint64. It returns ErrNoRoutingID when r is nil
// or empty, and a *strconv.NumError when the value is not a valid uint64.
func (r *RoutingID) Uint64() (uint64, error) {
	if r.IsZero() {
		return 0, ErrNoRoutingID
	}
	return strconv.ParseUint(r.raw, 10, 64)
}

// IsZero reports whether r is nil or holds no ID. A RoutingID holding the
// value "0" is not zero: 0 is a valid routing ID.
func (r *RoutingID) IsZero() bool {
	return r == nil || r.raw == ""
}

func NewRoutingID(s string) *RoutingID {
	return &RoutingID{raw: s}
}
