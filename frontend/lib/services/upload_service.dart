//flutterからGoに画像を送信する
import 'package:http/http.dart' as http;

class UploadService {
  static Future<String> uploadImage(String imagePath) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:8000/upload'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imagePath,
      ),
    );
    //送信
    var response = await request.send();
    //レスポンスを文字列として取得
    return await response.stream.bytesToString();
  }
}