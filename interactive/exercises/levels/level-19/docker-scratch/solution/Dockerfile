FROM golang:1.21 AS builder
WORKDIR /app
COPY main.go .
RUN CGO_ENABLED=0 go build -o myapp main.go

FROM scratch
COPY --from=builder /app/myapp /myapp
CMD ["/myapp"]
