//服のメタデータをSupabaseに保存・取得する
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clothing.dart';

class ClothingService {

  final _supabase = Supabase.instance.client;
  static const _table = 'clothes';

  // 服を保存
  Future<void> insertClothing(Clothing clothing) async {
    await _supabase.from(_table).insert(clothing.toMap());
  }

  // 服のカテゴリ・色・季節を更新(画像は変更しない)
  Future<void> updateClothing(
    int id, {
    required String category,
    required String color,
    required String season,
  }) async {

    debugPrint("服を更新: id=$id category=$category color=$color season=$season");

    final rows = await _supabase
        .from(_table)
        .update({
          'category': category,
          'color': color,
          'season': season,
        })
        .eq('id', id)
        .select();

    // RLSで更新が拒否された場合、エラーにならず0件更新になるため明示的に検出する
    if (rows.isEmpty) {
      throw Exception("更新できませんでした(対象が存在しないか、更新権限がありません)");
    }
  }

  // 服を削除
  Future<void> deleteClothing(int id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  // 全ての服を取得
  Future<List<Clothing>> getAllClothing() async {

    final rows = await _supabase
        .from(_table)
        .select()
        .order('created_at', ascending: false);

    return rows.map((row) => Clothing.fromMap(row)).toList();
  }
}
