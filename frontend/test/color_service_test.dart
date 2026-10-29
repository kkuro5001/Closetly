import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/services/color_service.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  test('multipartのimageフィールドで送信し、colorを返す', () async {
    late http.BaseRequest captured;
    final client = MockClient.streaming((request, bodyStream) async {
      captured = request;
      final body = utf8.encode(
        '{"category":"shirt","color":"ネイビー","color_en":"navy","hex":"#172558","ratio":0.49}',
      );
      return http.StreamedResponse(
        Stream.value(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = ColorService(client: client, baseUrl: 'http://test');
    final color = await service.analyzeColor(bytes);

    expect(color, 'ネイビー');
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://test/upload');
    expect(captured.headers['content-type'], startsWith('multipart/form-data'));
  });

  test('colorがunknownならnullを返す', () async {
    final client = MockClient(
      (request) async => http.Response('{"color":"unknown"}', 200),
    );

    final service = ColorService(client: client, baseUrl: 'http://test');

    expect(await service.analyzeColor(bytes), isNull);
  });

  test('HTTPエラーは例外になる', () async {
    final client = MockClient((request) async => http.Response('err', 500));

    final service = ColorService(client: client, baseUrl: 'http://test');

    expect(service.analyzeColor(bytes), throwsException);
  });

  test('JSONでない応答は例外になる', () async {
    final client = MockClient((request) async => http.Response('oops', 200));

    final service = ColorService(client: client, baseUrl: 'http://test');

    expect(service.analyzeColor(bytes), throwsA(isA<FormatException>()));
  });
}
