// コーディネート(outfits / outfit_items テーブル)の操作と、Go API 経由の AI 提案
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/outfit.dart';

class OutfitService {

  // accessToken はテストで差し替えるための口(未指定なら Supabase のセッションから取る)
  OutfitService({
    http.Client? client,
    String? baseUrl,
    String? Function()? accessToken,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _accessToken = accessToken;

  final http.Client _client;
  final String _baseUrl;
  final String? Function()? _accessToken;

  SupabaseClient get _supabase => Supabase.instance.client;

  // Gemini の応答は数十秒かかることがある
  static const _suggestTimeout = Duration(seconds: 60);

  // 自分のコーデをすべて取得(新しい順)。含まれる服の id も一緒に取る
  Future<List<Outfit>> getAllOutfits() async {
    final rows = await _supabase
        .from('outfits')
        .select('id, name, note, created_at, outfit_items(clothing_id)')
        .order('created_at', ascending: false);
    return rows.map((row) => Outfit.fromMap(row)).toList();
  }

  // コーデを保存する。服の登録に失敗したらコーデ本体も消して、中途半端に残さない
  Future<void> createOutfit({
    required String name,
    String note = '',
    required List<int> clothingIds,
  }) async {

    final outfit = await _supabase
        .from('outfits')
        .insert({'name': name, 'note': note})
        .select('id')
        .single();
    final outfitId = outfit['id'] as int;

    try {
      await _supabase.from('outfit_items').insert(
            clothingIds
                .toSet()
                .map((id) => {'outfit_id': outfitId, 'clothing_id': id})
                .toList(),
          );
    } catch (e) {
      debugPrint("コーデの服の登録に失敗したのでコーデを削除: $e");
      await _supabase.from('outfits').delete().eq('id', outfitId);
      rethrow;
    }
  }

  // コーデを削除(outfit_items は DB 側で一緒に消える。服そのものは消えない)
  Future<void> deleteOutfit(int id) async {
    await _supabase.from('outfits').delete().eq('id', id);
  }

  // Gemini にコーデを提案してもらう(Go API の POST /suggest-outfit)。
  // scene は「通勤」など任意の場面、season は今の季節。
  // Go 側でログインを確認するので、Supabase のアクセストークンを付けて送る
  Future<List<OutfitSuggestion>> suggestOutfits({
    String scene = '',
    String season = '',
  }) async {

    final token = _accessToken != null
        ? _accessToken()
        : _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception("ログインしていません");
    }

    final uri = Uri.parse('$_baseUrl/suggest-outfit');
    debugPrint("コーデ提案リクエスト送信: $uri");

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'scene': scene, 'season': season}),
        )
        .timeout(_suggestTimeout);

    final body = utf8.decode(response.bodyBytes);
    debugPrint("コーデ提案レスポンス: ${response.statusCode} $body");

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.statusCode));
    }

    final json = jsonDecode(body);
    final list = json is Map ? json['suggestions'] : null;
    if (list is! List) {
      throw Exception("提案の形式が想定と違います");
    }
    return list
        .map((e) => OutfitSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _errorMessage(int status) {
    switch (status) {
      case 400:
        return "提案するには服を2着以上登録してください";
      case 401:
        return "ログインし直してください";
      case 503:
        return "AI提案はまだ設定されていません";
      default:
        return "提案の取得に失敗しました (HTTP $status)";
    }
  }
}
