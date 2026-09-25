# Horizon Payment Listener (Go)

A production-grade reference implementation demonstrating deposit routing correctness using the `@redishfish/bluewhale-core`. This daemon monitors a Stellar Horizon testnet account, extracts routing information from incoming payments, and handles compliance warnings with structured severity tiers.

## What this demonstrates
This example shows how a backend exchange or payment service can reliably reconcile deposits. It specifically highlights the kit's ability to:
- Resolve **M-addresses** to their base G-address and routing ID.
- Reconcile **Memo IDs** and **Numeric Memo Text** when G-addresses are used.
- Detect and flag **compliance edge cases** (like contract-senders or non-canonical IDs) using a structured warning system.

## Prerequisites
- Go 1.22+
- Docker & Docker Compose (optional)

## 5-Minute Quick Start

### Option A: Running with Docker (Recommended)
This starts the listener along with a Prometheus instance to visualize metrics.
```bash
docker compose up
```

Once started, verify that the healthcheck passes:
```bash
docker compose ps
# The listener service should show "healthy" under the STATUS column.
```

You can also hit the endpoint directly:
```bash
curl http://localhost:9090/healthz
# {"status":"ok","time":"2024-01-01T00:00:00Z"}
```

### Option B: Running Locally
1.  Navigate to the directory:
    ```bash
    cd examples/go-payment-listener
    ```
2.  Install dependencies:
    ```bash
    go mod tidy
    ```
3.  Run the listener:
    ```bash
    go run ./cmd/listener --config config.example.yaml
    ```

## Log Output Examples

### 1. Info Level (Clean Routing)
```json
{"level":"info","tx_hash":"...","amount":"100.00","asset":"USDC","severity":"info","source":"muxed","routing_id":"123","message":"payment successfully routed"}
```

### 2. Warn Level (Compliance Warning)
Occurs when a payment is routable but has issues (e.g., leading zeros in a memo ID).
```json
{"level":"warn","tx_hash":"...","amount":"50.00","asset":"XLM","severity":"warn","source":"memo","warnings":[{"code":"NON_CANONICAL_ROUTING_ID","message":"..."}],"message":"payment routed with compliance warnings"}
```

### 3. Error Level (Unroutable / Alert)
Occurs when the payment cannot be safely credited to a user.
```json
{"level":"error","tx_hash":"...","severity":"error","alert":true,"error":{"code":"INVALID_DESTINATION","message":"..."},"message":"unroutable payment detected"}
```

## What This Demonstrates
This implementation explicitly uses `listener.ExtractRouting` (found in `internal/listener/router.go`) to process every payment. It demonstrates:
- **Graceful Shutdown**: Uses context-based cancellation for SIGINT/SIGTERM.
- **Resilience**: Implements exponential backoff for Horizon connection failures.
- **Observability**: Exports Prometheus metrics at `/metrics` and a liveness healthcheck at `/healthz` (port `metrics.port`).
- **Safety**: Never panics on malformed transaction data; instead, it logs an `alert=true` event for manual review.

## Link to Core Library
[Bluewhale (Go)](https://github.com/REDISHFISH/BLUEWHALE/tree/main/packages/core-go)

## Prometheus & Alertmanager Setup

The listener exports Prometheus metrics at `:9090/metrics`.  An example
[Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) rule
file is provided at [`alerts.example.yml`](./alerts.example.yml).

### Available metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `stellar_payments_total` | Counter | `severity` (info/warn/error) | Every processed payment |
| `stellar_routing_source_total` | Counter | `source` (muxed/memo/none) | Payments by routing method |
| `stellar_payment_unroutable_total` | Counter | – | Payments that could not be credited (contract senders, invalid checksums, etc.) |

### Enabling alerts

1. Copy `alerts.example.yml` into your Prometheus `rules/` directory.
2. Reference it from `prometheus.yml`:
   ```yaml
   rule_files:
     - "rules/alerts.example.yml"
   ```
3. Configure your Alertmanager receiver (Slack, PagerDuty, email) in
   `alertmanager.yml` and point Prometheus to it:
   ```yaml
   alerting:
     alertmanagers:
       - static_configs:
           - targets: ["alertmanager:9093"]
   ```
4. Reload Prometheus:
   ```bash
   curl -X POST http://localhost:9090/-/reload
   ```

### Key alert: UnroutablePaymentSpike

```yaml
- alert: UnroutablePaymentSpike
  expr: rate(stellar_payment_unroutable_total[5m]) > 5
  for: 1m
  labels:
    severity: critical
```

This alert fires when more than 5 unroutable payments per second are observed
over a 5-minute window — a strong signal of a contract-sender attack, burst of
invalid checksums, or a misconfigured integration.

## License
MIT
