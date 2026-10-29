FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
# Go APIのURL(ブラウザから到達できるアドレスを指定する)
ARG API_BASE_URL=http://localhost:8080
RUN flutter pub get && flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
# 入り口のファイルをキャッシュさせない設定
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
