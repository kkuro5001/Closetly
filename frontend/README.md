- page/
画面そのもの
- widgets/
部品を置く
- services/
API通信を書く
- models/
データ構造を書く

upload_service.dart
- Android Emulator専用の特殊IP
    Uri.parse('http://10.0.2.2:8080/upload'),
- 実機でテストする場合
    Uri.parse('http://ローカルIPに変更:8080/upload')
    ipconfig

