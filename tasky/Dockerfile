# SECURITY RISKS IN THIS DOCKERFILE:
# 1. Base Images:
#    - Using non-LTS golang version
#    - No image signature verification
#    - No vulnerability scanning
# 2. Runtime:
#    - Running as root user
#    - No resource limits
#    - No security profiles
# 3. Build:
#    - No multi-stage build optimization
#    - No dependency scanning
#    - No binary scanning

# SECURITY RECOMMENDATIONS:
# 1. Base Images:
#    - Use golang:1.21-alpine (latest LTS)
#    - Implement image signing
#    - Add vulnerability scanning
# 2. Runtime:
#    - Use non-root user
#    - Add resource limits
#    - Implement seccomp/AppArmor
# 3. Build:
#    - Optimize multi-stage build
#    - Scan dependencies
#    - Implement binary scanning

# Building stage
# RISK: Using older Golang version
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .

# Initialize a new module
RUN rm -f go.mod go.sum && \
    go mod init github.com/jeffthorne/tasky && \
    go get github.com/dgrijalva/jwt-go@v3.2.0+incompatible && \
    go get github.com/gin-gonic/gin@v1.9.1 && \
    go get github.com/joho/godotenv@v1.4.0 && \
    go get go.mongodb.org/mongo-driver@v1.9.1 && \
    go get golang.org/x/crypto@v0.23.0 && \
    go mod tidy

# RISK: No binary scanning
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Release stage
# RISK: No image signature verification
FROM alpine:3.17.0 as release

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets

# RISK: Unnecessary file addition
RUN echo "This is a deliberately insecure configuration for training purposes. \n Mongo SSH \n user: ubuntu \n pass: password123." > /app/wizexercise.txt

# RISK: Exposed port without TLS
EXPOSE 8080

# CRITICAL SECURITY RISK: Running as root
# This allows:
# 1. Full system access
# 2. Ability to modify any files
# 3. Capability to run privileged operations
USER root

ENTRYPOINT ["/app/tasky"]


