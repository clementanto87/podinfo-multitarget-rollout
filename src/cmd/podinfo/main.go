package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var cachedSecret string
var secretLastFetch time.Time

// getSecret fetches a secret from AWS Secrets Manager with in-memory caching.
func getSecret(ctx context.Context, arn string) (string, error) {
	if cachedSecret != "" && time.Since(secretLastFetch) < 5*time.Minute {
		return cachedSecret, nil
	}

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to load AWS config: %w", err)
	}
	svc := secretsmanager.NewFromConfig(cfg)
	out, err := svc.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &arn,
	})
	if err != nil {
		return "", fmt.Errorf("failed to get secret value: %w", err)
	}
	cachedSecret = *out.SecretString
	secretLastFetch = time.Now()
	return cachedSecret, nil
}

// correlationID generates a random request ID.
func correlationID() string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 8)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return fmt.Sprintf("req-%s", string(b))
}

// httpHandler is the main request handler logic.
func httpHandler(w http.ResponseWriter, r *http.Request) {
	id := r.Header.Get("X-Correlation-ID")
	if id == "" {
		id = correlationID()
	}
	w.Header().Set("X-Correlation-ID", id)

	ctx := r.Context()
	secretArn := os.Getenv("SUPER_SECRET_TOKEN_ARN")
	if secretArn != "" {
		if _, err := getSecret(ctx, secretArn); err != nil {
			// Do not log the secret itself, just the error.
			log.Printf("WARN: could not fetch secret: %v", err)
		}
	}
	log.Printf("Handled %s %s id=%s", r.Method, r.URL.Path, id)

	fmt.Fprintf(w, "podinfo up\ncorrelation-id: %s\n", id)
}

// healthHandler provides a simple health check endpoint.
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

// createMux creates and configures the HTTP request multiplexer.
func createMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/", httpHandler)
	mux.HandleFunc("/healthz", healthHandler)
	mux.Handle("/metrics", promhttp.Handler())
	return mux
}

// lambdaAdapter wraps the http.Handler to be compatible with Lambda API Gateway events.
type lambdaAdapter struct {
	httpMux *http.ServeMux
}

func (h *lambdaAdapter) handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// This is a simplified adapter. For a production system, a library like
	// https://github.com/awslabs/aws-lambda-go-api-proxy would be more robust.
	// However, for this take-home, this demonstrates the principle.
	// Note: This adapter does not handle binary responses, complex headers, etc.
	
	// Create a new HTTP request from the Lambda event
	httpReq, err := http.NewRequest(req.HTTPMethod, req.Path, nil)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	
	// A simple response writer to capture the response
	res := &responseWriter{}

	// Serve the request
	h.httpMux.ServeHTTP(res, httpReq)

	// Return the response in the format API Gateway expects
	return events.APIGatewayProxyResponse{
		StatusCode: res.statusCode,
		Body:       res.body,
		Headers:    map[string]string{"Content-Type": "text/plain"},
	}, nil
}

// A simple responseWriter to satisfy the http.ResponseWriter interface
type responseWriter struct {
	statusCode int
	body       string
	header     http.Header
}

func (w *responseWriter) Header() http.Header {
	if w.header == nil {
		w.header = make(http.Header)
	}
	return w.header
}

func (w *responseWriter) Write(b []byte) (int, error) {
	w.body += string(b)
	return len(b), nil
}

func (w *responseWriter) WriteHeader(statusCode int) {
	w.statusCode = statusCode
}


func main() {
	rand.Seed(time.Now().UnixNano())
	
	// Check if running in AWS Lambda environment
	if _, ok := os.LookupEnv("AWS_LAMBDA_RUNTIME_API"); ok {
		log.Println("Starting podinfo in Lambda mode")
		adapter := &lambdaAdapter{httpMux: createMux()}
		lambda.Start(adapter.handler)
	} else {
		log.Println("Starting podinfo in EC2/server mode")
		mux := createMux()
		port := os.Getenv("PORT")
		if port == "" {
			port = "9898"
		}

		log.Printf("Starting podinfo on :%s", port)
		if err := http.ListenAndServe(":"+port, mux); err != nil {
			log.Fatalf("failed to start server: %v", err)
		}
	}
}