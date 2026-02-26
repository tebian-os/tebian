FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY main.go .
RUN go build -o counter main.go

FROM alpine:3.19

WORKDIR /app
COPY --from=builder /app/counter .

EXPOSE 3001

CMD ["./counter"]
