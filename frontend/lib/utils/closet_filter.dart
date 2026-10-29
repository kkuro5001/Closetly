import '../constants/clothing_options.dart';
import '../models/clothing.dart';

// クローゼットの並び順
enum ClosetSort {
  newest, // 新しい順(デフォルト)
  oldest, // 古い順
  category, // カテゴリ順
}

// クローゼットの絞り込み・並び替え条件
// 同じ項目内は OR、項目どうしは AND で絞り込む。空の集合はその項目で絞り込まない
class ClosetFilter {
  final Set<String> categories;
  final Set<String> seasons;
  final Set<String> colors;
  final ClosetSort sort;

  const ClosetFilter({
    this.categories = const {},
    this.seasons = const {},
    this.colors = const {},
    this.sort = ClosetSort.newest,
  });

  // 絞り込み条件が1つでも指定されているか(並び順は含めない)
  bool get hasActiveFilter =>
      categories.isNotEmpty || seasons.isNotEmpty || colors.isNotEmpty;

  ClosetFilter copyWith({
    Set<String>? categories,
    Set<String>? seasons,
    Set<String>? colors,
    ClosetSort? sort,
  }) {
    return ClosetFilter(
      categories: categories ?? this.categories,
      seasons: seasons ?? this.seasons,
      colors: colors ?? this.colors,
      sort: sort ?? this.sort,
    );
  }

  // 絞り込みだけ解除する(並び順は維持)
  ClosetFilter clearFilters() => ClosetFilter(sort: sort);

  // 絞り込みと並び替えを適用した新しいリストを返す(元のリストは変更しない)
  List<Clothing> apply(List<Clothing> items) {
    final result = items.where((c) {
      if (categories.isNotEmpty && !categories.contains(c.category)) {
        return false;
      }
      if (seasons.isNotEmpty && !seasons.contains(c.season)) return false;
      if (colors.isNotEmpty && !colors.contains(c.color.trim())) return false;
      return true;
    }).toList();

    result.sort(_comparator);
    return result;
  }

  int _comparator(Clothing a, Clothing b) {
    switch (sort) {
      case ClosetSort.newest:
        return _compareCreatedAt(b, a);
      case ClosetSort.oldest:
        return _compareCreatedAt(a, b);
      case ClosetSort.category:
        final byCategory =
            _categoryRank(a.category).compareTo(_categoryRank(b.category));
        if (byCategory != 0) return byCategory;
        if (a.category != b.category) {
          return a.category.compareTo(b.category);
        }
        // 同じカテゴリ内は新しい順
        return _compareCreatedAt(b, a);
    }
  }

  // createdAt が無いものは最も古いものとして扱う。同時刻なら id で安定させる
  static int _compareCreatedAt(Clothing a, Clothing b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) {
      return (a.id ?? 0).compareTo(b.id ?? 0);
    }
    if (aTime == null) return -1;
    if (bTime == null) return 1;
    final c = aTime.compareTo(bTime);
    if (c != 0) return c;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  // 選択肢リストにあるカテゴリはその並び順、未知の値は末尾
  static int _categoryRank(String category) {
    final i = categoryOptions.indexOf(category);
    return i == -1 ? categoryOptions.length : i;
  }
}

// 読み込み済みの服に実在する値だけをチップの選択肢にする
// 既知の選択肢は定義順、未知の値(過去データなど)は末尾に辞書順で並べる
List<String> availableCategories(List<Clothing> items) =>
    _available(items.map((c) => c.category), categoryOptions);

List<String> availableSeasons(List<Clothing> items) =>
    _available(items.map((c) => c.season), seasonOptions);

// 色は自由入力なので、出現した値を前後の空白除去・重複排除して辞書順で返す
List<String> availableColors(List<Clothing> items) {
  final set =
      items.map((c) => c.color.trim()).where((s) => s.isNotEmpty).toSet();
  return set.toList()..sort();
}

List<String> _available(Iterable<String> values, List<String> known) {
  final present = values.where((s) => s.isNotEmpty).toSet();
  final ordered = known.where(present.contains).toList();
  final unknown = present.difference(known.toSet()).toList()..sort();
  return [...ordered, ...unknown];
}
