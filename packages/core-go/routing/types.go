package routing

import "github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"

// RoutingInput represents incoming routing payload data.
type RoutingInput struct {
	SourceAddress string            `json:"sourceAddress"`
	TargetChains  []string          `json:"targetChains"`
	Metadata      map[string]string `json:"metadata,omitempty"`

	// Backward-compatible fields used by current extraction flow.
	Destination   string `json:"destination,omitempty"`
	MemoType      string `json:"memoType,omitempty"`
	MemoValue     string `json:"memoValue,omitempty"`
	SourceAccount string `json:"sourceAccount,omitempty"`

	// MinSeverityLevel drops warnings below this severity ("info", "warn" or
	// "error"). Empty means "info": all warnings are returned.
	MinSeverityLevel string `json:"minSeverityLevel,omitempty"`
}

// RoutingResult represents routing output data.
type RoutingResult struct {
	ResolvedAddresses map[string]string `json:"resolvedAddresses,omitempty"`
	Success           bool              `json:"success"`
	ErrorMessage      string            `json:"errorMessage,omitempty"`

	// Backward-compatible fields used by current extraction flow.
	DestinationBaseAccount string            `json:"destinationBaseAccount,omitempty"`
	RoutingID              *RoutingID        `json:"routingId,omitempty"`
	RoutingSource          string            `json:"routingSource,omitempty"`
	Warnings               []address.Warning `json:"warnings,omitempty"`
	DestinationError       *DestinationError `json:"destinationError,omitempty"`
}

// DestinationError is part of RoutingResult's wire schema. Both fields are
// omitempty for the same reason RoutingResult.ErrorMessage is: a consumer of
// the JSON should not have to distinguish "no message" from "empty message",
// and an error that only carries a code should not advertise a blank string.
type DestinationError struct {
	Code    address.ErrorCode `json:"code,omitempty"`
	Message string            `json:"message,omitempty"`
}
