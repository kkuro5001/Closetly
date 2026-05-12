Flutter + Go + Python + nginx + Docker

まずはGo + Pythonの接続をする
Flutterはdockerに入れるべきではない

起動
docker compose up --build

todo
main.goでMIME　画像チェック UUIDファイル名 画像保存時の衝突防止をする

curl.exe -X POST http://localhost:8080/upload -F "image=@test.jpg"
goからpythonのpredictのテスト

pubspec.yamlを変更した場合
flutter clean
flutter pub get