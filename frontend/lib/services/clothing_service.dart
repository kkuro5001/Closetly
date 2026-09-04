//服のメタデータをSupabaseに保存・取得する
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clothing.dart';

class ClothingService {

  final _supabase = Supabase.instance.client;
  static const _table = 'clothes';

  // 服を保存
  Future<void> insertClothing(Clothing clothing) async {
    await _supabase.from(_table).insert(clothing.toMap());
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
