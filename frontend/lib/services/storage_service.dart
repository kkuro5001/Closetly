import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class StorageService {
  final _supabase = Supabase.instance.client;
  static const _bucket = 'closet-images';

  /// オリジナル画像をアップロード
  Future<String> uploadOriginal(File imageFile, String userId, String fileName) async {
    final path = '$userId/original/$fileName';
    await _supabase.storage.from(_bucket).upload(
      path,
      imageFile,
      fileOptions: const FileOptions(upsert: true),
    );
    return path;
  }

  /// 加工済み画像をアップロード
  Future<String> uploadProcessed(File imageFile, String userId, String fileName) async {
    final path = '$userId/processed/$fileName';
    await _supabase.storage.from(_bucket).upload(
      path,
      imageFile,
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