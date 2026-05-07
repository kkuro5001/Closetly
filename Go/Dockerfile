FROM golang:1.22

WORKDIR /app
COPY . .

RUN go mod init Go
RUN go get github.com/gin-gonic/gin
RUN go build -o main .

CMD ["./main"]