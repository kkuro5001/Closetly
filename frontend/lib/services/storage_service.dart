import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;
  static const _bucket = 'closet-images';

  /// オリジナル画像をアップロード（Web/モバイル共通でバイト列を使用）
  Future<String> uploadOriginal(Uint8List imageBytes, String userId, String fileName) async {
    final path = '$userId/original/$fileName';
    await _supabase.storage.from(_bucket).uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return path;
  }

  /// 加工済み画像をアップロード（Web/モバイル共通でバイト列を使用）
  Future<String> uploadProcessed(Uint8List imageBytes, String userId, String fileName) async {
    final path = '$userId/processed/$fileName';
    await _supabase.storage.from(_bucket).uploadBinary(
      path,
      imageBytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return path;
  }

  /// 公開URL取得（バケットが公開設定の場合のみ有効）
  String getPublicUrl(String path) {
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  /// 署名付きURL取得（非公開バケット用）
  Future<String> getSignedUrl(String path, {int expiresIn = 3600}) async {
    return await _supabase.storage
        .from(_bucket)
        .createSignedUrl(path, expiresIn);
  }
}