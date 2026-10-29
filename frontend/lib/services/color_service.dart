import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// 画像をGo API(→Python)へ送って服の色を解析してもらうサービス
class ColorService {
  ColorService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 15);

  // 色名(例: ネイビー)を返す。解析できなかった場合はnull、通信失敗などは例外
  Future<String?> analyzeColor(Uint8List bytes) async {

    final uri = Uri.parse('$_baseUrl/upload');

    debugPrint("色解析リクエスト送信: $uri (${bytes.length} bytes)");

    // dart:io Fileを使うとWebで動かないのでバイト列から送る
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'image.jpg',
        ),
      );

    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed).timeout(_timeout);

    debugPrint("色解析レスポンス: ${response.statusCode} ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("色解析に失敗しました: HTTP ${response.statusCode}");
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final color = json is Map ? json['color'] : null;

    // Python側が解析できなかった場合は "unknown" が返る
    if (color is! String || color.isEmpty || color == 'unknown') {
      debugPrint("色を特定できませんでした");
      return null;
    }

    return color;
  }
}
