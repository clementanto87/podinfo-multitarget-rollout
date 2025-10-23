# --- Build stage ---
    FROM golang:1.20-alpine AS builder
    WORKDIR /src
    ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

    COPY go.mod go.sum* ./
    RUN go mod download

    COPY . .
    ARG BUILD_DATE
    ARG GIT_COMMIT
    RUN go build -ldflags="-s -w -X main.BuildDate=${BUILD_DATE} -X main.Commit=${GIT_COMMIT}" \
        -o /podinfo ./cmd/podinfo

    # --- Final minimal image ---
    FROM alpine:3.18
    RUN addgroup -S app && adduser -S -G app app
    USER app
    WORKDIR /home/app

    COPY --from=builder /podinfo /home/app/podinfo

    EXPOSE 8080
    HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://localhost:9898/healthz || exit 1

    ENTRYPOINT ["/home/app/podinfo"]
    CMD ["--port=8080"]
