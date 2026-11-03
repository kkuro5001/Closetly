// 着用記録(wear_logs テーブル)の取得・追加・削除
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wear_log.dart';

class WearLogService {

  final _supabase = Supabase.instance.client;
  static const _table = 'wear_logs';

  // 自分の着用記録をすべて取得(新しい日付順)
  Future<List<WearLog>> getAllWearLogs() async {
    final rows = await _supabase
        .from(_table)
        .select('clothing_id, worn_on')
        .order('worn_on', ascending: false);
    return rows.map((row) => WearLog.fromMap(row)).toList();
  }

  // 1着分の着用記録を取得(新しい日付順)
  Future<List<WearLog>> getWearLogsForClothing(int clothingId) async {
    final rows = await _supabase
        .from(_table)
        .select('clothing_id, worn_on')
        .eq('clothing_id', clothingId)
        .order('worn_on', ascending: false);
    return rows.map((row) => WearLog.fromMap(row)).toList();
  }

  // 指定した服をその日に着たと記録する(コーデなら複数着をまとめて)。
  // すでに同じ日の記録がある服は無視する(unique(clothing_id, worn_on) + ON CONFLICT DO NOTHING)
  Future<void> recordWear(List<int> clothingIds, DateTime day) async {
    if (clothingIds.isEmpty) return;
    final rows = clothingIds
        .toSet()
        .map((id) => WearLog(clothingId: id, wornOn: day).toMap())
        .toList();
    await _supabase.from(_table).upsert(
          rows,
          onConflict: 'clothing_id,worn_on',
          ignoreDuplicates: true,
        );
  }

  // その日の記録を取り消す
  Future<void> removeWear(int clothingId, DateTime day) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('clothing_id', clothingId)
        .eq('worn_on', dateKey(day));
  }
}
