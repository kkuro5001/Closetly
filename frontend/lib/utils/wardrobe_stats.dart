import '../models/clothing.dart';

// ホーム画面の集計ロジック(UIに依存しない純粋関数)

const seasonAll = "オールシーズン";

/// 月(1-12)から季節を返す。
/// 6-8月: 夏 / 12-2月: 冬 / それ以外(3-5月, 9-11月): 春秋
String seasonForMonth(int month) {
  if (month < 1 || month > 12) {
    throw ArgumentError.value(month, 'month', '1〜12で指定してください');
  }
  if (month >= 6 && month <= 8) return "夏";
  if (month == 12 || month <= 2) return "冬";
  return "春秋";
}

/// 集計結果の1項目(名前と件数)
class CountEntry {
  final String name;
  final int count;
  const CountEntry(this.name, this.count);

  @override
  String toString() => 'CountEntry($name, $count)';
}

/// 件数の多い順、同数なら名前順に並べて返す
List<CountEntry> _countBy(
  Iterable<Clothing> clothes,
  String Function(Clothing) key,
) {
  final map = <String, int>{};
  for (final c in clothes) {
    final k = key(c).trim();
    // 空文字は「未設定」にまとめる
    final name = k.isEmpty ? "未設定" : k;
    map[name] = (map[name] ?? 0) + 1;
  }
  final list = map.entries.map((e) => CountEntry(e.key, e.value)).toList();
  list.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
  return list;
}

List<CountEntry> countByCategory(Iterable<Clothing> clothes) =>
    _countBy(clothes, (c) => c.category);

List<CountEntry> countByColor(Iterable<Clothing> clothes) =>
    _countBy(clothes, (c) => c.color);

/// 指定した季節の服 + オールシーズンの服(元の順序を保つ)
List<Clothing> clothesForSeason(Iterable<Clothing> clothes, String season) {
  return clothes
      .where((c) => c.season == season || c.season == seasonAll)
      .toList();
}
