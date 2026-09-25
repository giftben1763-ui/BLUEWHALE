package metrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	PaymentsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "stellar_payments_total",
			Help: "Total number of processed payments by severity.",
		},
		[]string{"severity"},
	)

	RoutingSourceTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "stellar_routing_source_total",
			Help: "Total number of payments by routing source.",
		},
		[]string{"source"},
	)

	// PaymentUnroutableTotal counts payments that could not be credited to any
	// user account (e.g. contract-sender deposits, invalid checksums, missing
	// memos).  Exposed as stellar_payment_unroutable_total so that Alertmanager
	// rules can fire on rate(stellar_payment_unroutable_total[5m]) > 5.
	PaymentUnroutableTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "stellar_payment_unroutable_total",
			Help: "Total number of payments that could not be routed to a user account.",
		},
	)
)

func Register() {
	prometheus.MustRegister(PaymentsTotal)
	prometheus.MustRegister(RoutingSourceTotal)
	prometheus.MustRegister(PaymentUnroutableTotal)
}

// healthzHandler returns 200 OK with a JSON body as long as the process is running.
// Orchestrators (Kubernetes, ECS, Docker Compose) use this endpoint to gate traffic
// and restart unhealthy containers.
func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
		"time":   time.Now().UTC().Format(time.RFC3339),
	})
}

func Serve(port int) error {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", healthzHandler)
	return http.ListenAndServe(fmt.Sprintf(":%d", port), mux)
}
