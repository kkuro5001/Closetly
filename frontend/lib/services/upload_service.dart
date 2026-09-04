//flutterからGoに画像を送信する
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class UploadService {
  static Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    var request = http.MultipartRequest(
      'POST',
      //todo : ipをgoのサーバーのipに変更すること
      Uri.parse('http://10.0.2.2:8080/upload'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
      ),
    );
    //送信
    var response = await request.send();
    //レスポンスを文字列として取得
    return await response.stream.bytesToString();
  }
}