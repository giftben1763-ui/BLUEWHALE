// Command go_adapter is the core-go side of the differential address harness
// (scripts/differential-fuzz.js). It reads newline-delimited JSON strings from
// stdin, runs address.Detect and address.Parse on each, and writes one JSON
// outcome per line to stdout in the shared adapter format.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"os"
	"strconv"

	"github.com/REDISHFISH/BLUEWHALE/packages/core-go/address"
)

type parseOutcome struct {
	OK      bool    `json:"ok"`
	Kind    *string `json:"kind"`
	Address *string `json:"address"`
	BaseG   *string `json:"baseG"`
	MuxedID *string `json:"muxedId"`
	Error   *string `json:"error"`
}

type outcome struct {
	Detect *string      `json:"detect"`
	Parse  parseOutcome `json:"parse"`
}

func strPtr(s string) *string { return &s }

func run(input string) (out outcome) {
	defer func() {
		if r := recover(); r != nil {
			out = outcome{Parse: parseOutcome{Error: strPtr("PANIC")}}
		}
	}()

	if kind, err := address.Detect(input); err == nil && kind != "" {
		out.Detect = strPtr(string(kind))
	}

	parsed, err := address.Parse(input)
	if err != nil {
		code := "UNKNOWN"
		var routingErr address.RoutingError
		if errors.As(err, &routingErr) {
			code = string(routingErr.Code)
		}
		out.Parse.Error = strPtr(code)
		return out
	}

	out.Parse.OK = true
	out.Parse.Kind = strPtr(string(parsed.Kind))
	out.Parse.Address = strPtr(parsed.Raw)
	if parsed.Kind == address.KindM {
		out.Parse.BaseG = strPtr(parsed.BaseG)
		out.Parse.MuxedID = strPtr(strconv.FormatUint(parsed.MuxedID, 10))
	}
	return out
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()
	encoder := json.NewEncoder(writer)

	for scanner.Scan() {
		var input string
		if err := json.Unmarshal(scanner.Bytes(), &input); err != nil {
			os.Stderr.WriteString("go_adapter: invalid input line: " + err.Error() + "\n")
			os.Exit(2)
		}
		if err := encoder.Encode(run(input)); err != nil {
			os.Stderr.WriteString("go_adapter: " + err.Error() + "\n")
			os.Exit(2)
		}
	}
	if err := scanner.Err(); err != nil {
		os.Stderr.WriteString("go_adapter: " + err.Error() + "\n")
		os.Exit(2)
	}
}
