package routing

import "github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"

// Warning severities, ordered from least to most severe.
const (
	SeverityInfo  = "info"
	SeverityWarn  = "warn"
	SeverityError = "error"
)

// SeverityWeight returns the numeric weight of a warning severity. The ordering
// is normative and shared verbatim with core-ts (SEVERITY_ORDER) and core-dart
// (severityWeight): info = 0, warn = 1, error = 2. Unknown severities weigh the
// same as info so that an unrecognized value never hides warnings.
func SeverityWeight(severity string) int {
	switch severity {
	case SeverityWarn:
		return 1
	case SeverityError:
		return 2
	default:
		return 0
	}
}

// FilterBySeverity keeps only warnings whose severity weight is >= the weight
// of minSeverity, preserving their original order. An empty or "info"
// threshold returns warnings unchanged.
func FilterBySeverity(warnings []address.Warning, minSeverity string) []address.Warning {
	threshold := SeverityWeight(minSeverity)
	if threshold == 0 {
		return warnings
	}
	filtered := make([]address.Warning, 0, len(warnings))
	for _, w := range warnings {
		if SeverityWeight(w.Severity) >= threshold {
			filtered = append(filtered, w)
		}
	}
	return filtered
}
