# ---- ビルド用: Goのツール一式が入ったイメージでバイナリだけ作る
FROM golang:1.25 AS build

WORKDIR /app

COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY . .

# 実行用イメージにlibcが無いため静的リンクでビルドする
RUN CGO_ENABLED=0 go build -o main .

# ---- 実行用: バイナリと/testで読む画像だけを載せて軽くする
FROM gcr.io/distroless/static-debian12

WORKDIR /app

COPY --from=build /app/main .
COPY --from=build /app/sample2.jpg .

EXPOSE 8080

CMD ["./main"]
