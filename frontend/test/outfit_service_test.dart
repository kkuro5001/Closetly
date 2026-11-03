import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/services/outfit_service.dart';

void main() {
  OutfitService build(MockClient client, {String? token = 'tok'}) =>
      OutfitService(
        client: client,
        baseUrl: 'http://test',
        accessToken: () => token,
      );

  test('Authorizationヘッダーと本文を付けて送り、提案を解析する', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          '{"suggestions":[{"name":"通勤コーデ","clothing_ids":[1,2],"reason":"落ち着いた色"}]}',
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final result =
        await build(client).suggestOutfits(scene: '通勤', season: '春秋');

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://test/suggest-outfit');
    expect(captured.headers['Authorization'], 'Bearer tok');
    expect(captured.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(captured.body), {'scene': '通勤', 'season': '春秋'});
    expect(result, hasLength(1));
    expect(result.first.name, '通勤コーデ');
    expect(result.first.clothingIds, [1, 2]);
    expect(result.first.reason, '落ち着いた色');
  });

  test('suggestionsが無い応答は例外になる', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    expect(build(client).suggestOutfits(), throwsException);
  });

  for (final c in {
    400: '2着以上',
    401: 'ログインし直して',
    503: '設定されていません',
    500: 'HTTP 500',
  }.entries) {
    test('HTTP ${c.key} のエラーメッセージ', () async {
      final client = MockClient((request) async => http.Response('x', c.key));
      expect(
        build(client).suggestOutfits(),
        throwsA(predicate((e) => e.toString().contains(c.value))),
      );
    });
  }

  test('トークンが無ければ送信せずエラーにする', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    await expectLater(
      build(client, token: null).suggestOutfits(),
      throwsA(predicate((e) => e.toString().contains('ログインしていません'))),
    );
    expect(called, isFalse);
  });
}
