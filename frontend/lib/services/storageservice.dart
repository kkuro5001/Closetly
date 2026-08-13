// lib/services/storage_service.dart
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

  /// 加工済み画像をアップロード(YOLO処理後などを想定)
  Future<String> uploadProcessed(File imageFile, String userId, String fileName) async {
    final path = '$userId/processed/$fileName';
    await _supabase.storage.from(_bucket).upload(
      path,
      imageFile,
      fileOptions: const FileOptions(upsert: true),
    );
    return path;
  }

  String getPublicUrl(String path) {
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }
}