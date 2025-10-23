package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var cachedSecret string
var secretLastFetch time.Time

func getSecret(ctx context.Context, arn string) (string, error) {
	if cachedSecret != "" && time.Since(secretLastFetch) < 5*time.Minute {
		return cachedSecret, nil
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return "", err
	}
	svc := secretsmanager.NewFromConfig(cfg)
	out, err := svc.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &arn,
	})
	if err != nil {
		return "", err
	}
	cachedSecret = *out.SecretString
	secretLastFetch = time.Now()
	return cachedSecret, nil
}

func correlationID() string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 8)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return fmt.Sprintf("req-%s", string(b))
}

func handler(w http.ResponseWriter, r *http.Request) {
	id := r.Header.Get("X-Correlation-ID")
	if id == "" {
		id = correlationID()
	}
	w.Header().Set("X-Correlation-ID", id)

	ctx := r.Context()
	secretArn := os.Getenv("SUPER_SECRET_TOKEN_ARN")
	if secretArn != "" {
		if _, err := getSecret(ctx, secretArn); err != nil {
			log.Printf("WARN: could not fetch secret: %v", err)
		}
	}
	log.Printf("Handled %s %s id=%s", r.Method, r.URL.Path, id)

	fmt.Fprintf(w, "podinfo up\ncorrelation-id: %s\n", id)
}

func health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/", handler)
	http.HandleFunc("/healthz", health)
	http.Handle("/metrics", promhttp.Handler())

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting podinfo on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
