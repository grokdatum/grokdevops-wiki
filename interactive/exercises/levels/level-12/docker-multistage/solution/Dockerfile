FROM golang:1.21 AS builder
WORKDIR /app
COPY main.go .
RUN go build -o myapp main.go

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/myapp .
CMD ["./myapp"]
