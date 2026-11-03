import '../models/clothing.dart';
import '../models/wear_log.dart';

// 着用記録の集計(UI 非依存の純粋関数)。
// 「今日」は引数で受け取る(DateTime.now() を中で呼ばない)ので、テストで日付を固定できる。

/// 1着分の着用の集計結果
class WearSummary {
  final int count;
  final DateTime? lastWornOn;

  const WearSummary({required this.count, this.lastWornOn});
}

/// 「しばらく着ていない」服と、その判定の基準日・経過日数
class StaleEntry {
  final Clothing clothing;

  /// 最後に着た日(一度も着ていなければ登録日。登録日も無ければ null)
  final DateTime? since;

  /// since からの経過日数(since が null のときは null)
  final int? days;

  const StaleEntry({required this.clothing, this.since, this.days});
}

/// 服と着用回数
class FrequentEntry {
  final Clothing clothing;
  final int count;
  final DateTime lastWornOn;

  const FrequentEntry({
    required this.clothing,
    required this.count,
    required this.lastWornOn,
  });
}

/// 2つの日付の差(日数)。時刻・夏時間の影響を受けないよう UTC の暦日で数える
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// 服 id ごとの着用回数と最後に着た日
Map<int, WearSummary> summarizeWearLogs(List<WearLog> logs) {
  final counts = <int, int>{};
  final last = <int, DateTime>{};
  for (final log in logs) {
    counts[log.clothingId] = (counts[log.clothingId] ?? 0) + 1;
    final prev = last[log.clothingId];
    if (prev == null || log.wornOn.isAfter(prev)) {
      last[log.clothingId] = log.wornOn;
    }
  }
  return {
    for (final id in counts.keys)
      id: WearSummary(count: counts[id]!, lastWornOn: last[id]),
  };
}

/// しばらく着ていない服。最後に着た日(無ければ登録日)から [days] 日以上経っているもの。
/// - 一度も着ていない服は登録日から [days] 日以上経っていれば含める。登録したばかりは含めない
/// - 登録日(createdAt)が null で記録も無い服は、判断材料が無いので含める
/// - 基準日が古い順(基準日が不明なものは先頭)
List<StaleEntry> staleClothes(
  List<Clothing> clothes,
  List<WearLog> logs,
  DateTime today, {
  int days = 30,
}) {
  final summary = summarizeWearLogs(logs);
  final result = <StaleEntry>[];

  for (final c in clothes) {
    final id = c.id;
    if (id == null) continue;

    final DateTime? since = summary[id]?.lastWornOn ??
        (c.createdAt == null ? null : dateOnly(c.createdAt!.toLocal()));

    if (since == null) {
      result.add(StaleEntry(clothing: c));
      continue;
    }
    final elapsed = daysBetween(since, today);
    if (elapsed >= days) {
      result.add(StaleEntry(clothing: c, since: since, days: elapsed));
    }
  }

  result.sort((a, b) {
    if (a.since == null && b.since == null) return 0;
    if (a.since == null) return -1;
    if (b.since == null) return 1;
    return a.since!.compareTo(b.since!);
  });
  return result;
}

/// よく着る服。着用回数の多い順に上位 [limit] 件。同数なら最後に着た日が新しい順。
/// 0回の服は含めない。
List<FrequentEntry> frequentClothes(
  List<Clothing> clothes,
  List<WearLog> logs, {
  int limit = 5,
}) {
  final summary = summarizeWearLogs(logs);
  final result = <FrequentEntry>[];

  for (final c in clothes) {
    final id = c.id;
    final s = id == null ? null : summary[id];
    if (s == null || s.count == 0 || s.lastWornOn == null) continue;
    result.add(FrequentEntry(
      clothing: c,
      count: s.count,
      lastWornOn: s.lastWornOn!,
    ));
  }

  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return b.lastWornOn.compareTo(a.lastWornOn);
  });
  return result.take(limit).toList();
}
