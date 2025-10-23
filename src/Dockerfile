# --- Build Stage ---
# Use an official Go image as the builder.
# Specify the Go version to ensure reproducible builds.
FROM golang:1.20-alpine AS builder

# Set the working directory inside the container.
WORKDIR /src

# Set build-time variables for Go compiler.
# CGO_ENABLED=0 disables Cgo, creating a static binary.
# GOOS=linux and GOARCH=amd64 are set for the target environment.
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

# Copy go.mod and go.sum files and download dependencies.
# This leverages Docker's layer caching, so dependencies are only
# re-downloaded if go.mod or go.sum change.
COPY go.mod go.sum* ./
RUN go mod download

# Copy the entire source code.
COPY . .

# Define build-time arguments for versioning.
ARG BUILD_DATE
ARG GIT_COMMIT

# Build the Go application.
# -ldflags="-s -w" strips debugging information, reducing binary size.
# The -X flag injects version information into the binary.
RUN go build -ldflags="-s -w -X main.BuildDate=${BUILD_DATE} -X main.Commit=${GIT_COMMIT}" \
    -o /podinfo ./cmd/podinfo


# --- Final Stage ---
# Use a minimal, secure base image. 'scratch' is the most minimal,
# but requires the binary to be fully static. Alpine is a good compromise.
FROM alpine:3.18

# Create a non-root user and group for security.
# Running as a non-root user is a critical security best practice.
RUN addgroup -S podinfo && adduser -S -G podinfo podinfo

# Switch to the non-root user.
USER podinfo

# Set the working directory for the non-root user.
WORKDIR /home/podinfo

# Copy the compiled binary from the builder stage.
# Also copy the SSL certificate authorities to make HTTPS calls.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /podinfo /home/podinfo/podinfo

# Expose the port the application will listen on (for EC2 mode).
EXPOSE 9898

# Set the default port for the application.
ENV PORT=9898

# Set the entrypoint for the container.
ENTRYPOINT ["/home/podinfo/podinfo"]