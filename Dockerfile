# Stage 1: Build email-builder
FROM node:18 AS email-builder
WORKDIR /app/email-builder
COPY frontend/email-builder/package.json frontend/email-builder/yarn.lock ./
RUN yarn install
COPY frontend/email-builder/ ./
RUN yarn build

# Stage 2: Build frontend
FROM node:18 AS frontend-builder
WORKDIR /app
COPY frontend/package.json frontend/yarn.lock ./
# Create static directory structure for postinstall script
RUN mkdir -p ../static/public/static
COPY frontend/ ./
RUN yarn install
COPY --from=email-builder /app/email-builder/dist ./public/static/email-builder
RUN yarn build

# Stage 3: Build backend
FROM golang:1.20 AS backend-builder
WORKDIR /app

# Install stuffbin for embedding assets
RUN go install github.com/knadh/stuffbin/...@latest

# Copy Go module files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and static files
COPY . .
COPY --from=frontend-builder /app/dist ./frontend/dist

# Build the binary
ARG VERSION=v4.0.0
ARG LAST_COMMIT=unknown
RUN CGO_ENABLED=0 go build -o listmonk \
    -ldflags="-s -w -X 'main.buildString=${VERSION} (#${LAST_COMMIT})' -X 'main.versionString=${VERSION}'" \
    cmd/*.go

# Pack static assets into the binary
RUN /go/bin/stuffbin -a stuff -in listmonk -out listmonk \
    config.toml.sample \
    schema.sql queries:/queries permissions.json \
    static/public:/public \
    static/email-templates \
    frontend/dist:/admin \
    i18n:/i18n

# Stage 4: Runtime
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata shadow su-exec

WORKDIR /listmonk

# Copy the packed binary and entrypoint
COPY --from=backend-builder /app/listmonk .
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose the application port
EXPOSE 9000

# Set the entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Define the command to run the application
CMD ["./listmonk"]
