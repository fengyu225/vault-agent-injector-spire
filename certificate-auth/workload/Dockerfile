FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY . /app/

RUN go mod download
RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux go build -o bin/dbclient

FROM alpine:3.19

RUN apk add --no-cache postgresql-client

WORKDIR /app
COPY --from=builder /app/bin/dbclient /usr/local/bin/
RUN chmod +x /usr/local/bin/dbclient

ENTRYPOINT ["dbclient"]