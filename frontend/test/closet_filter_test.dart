import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/clothing.dart';
import 'package:frontend/utils/closet_filter.dart';

Clothing c(int id, String category, String color, String season, int day) =>
    Clothing(
      id: id,
      imagePath: 'u/original/$id.jpg',
      category: category,
      color: color,
      season: season,
      createdAt: DateTime(2026, 1, day),
    );

void main() {
  final items = [
    c(1, 'Tシャツ', '白', '夏', 1),
    c(2, 'パンツ', '黒', 'オールシーズン', 2),
    c(3, 'アウター', '黒', '冬', 3),
    c(4, 'Tシャツ', '黒', '夏', 4),
    c(5, '謎カテゴリ', '赤', '春秋', 5),
  ];

  List<int?> ids(List<Clothing> l) => l.map((e) => e.id).toList();

  test('条件なしは新しい順で全件', () {
    expect(ids(const ClosetFilter().apply(items)), [5, 4, 3, 2, 1]);
  });

  test('古い順', () {
    expect(ids(const ClosetFilter(sort: ClosetSort.oldest).apply(items)),
        [1, 2, 3, 4, 5]);
  });

  test('カテゴリ順は定義順、未知は末尾、同カテゴリは新しい順', () {
    final r = const ClosetFilter(sort: ClosetSort.category).apply(items);
    expect(ids(r), [4, 1, 3, 2, 5]);
  });

  test('同一項目内はOR', () {
    final r = const ClosetFilter(categories: {'Tシャツ', 'パンツ'}).apply(items);
    expect(ids(r), [4, 2, 1]);
  });

  test('項目どうしはAND', () {
    final r = const ClosetFilter(
      categories: {'Tシャツ'},
      colors: {'黒'},
    ).apply(items);
    expect(ids(r), [4]);
  });

  test('3項目の組み合わせで0件になる', () {
    final r = const ClosetFilter(
      categories: {'Tシャツ'},
      colors: {'黒'},
      seasons: {'冬'},
    ).apply(items);
    expect(r, isEmpty);
  });

  test('存在しない値で絞ると0件', () {
    expect(const ClosetFilter(colors: {'緑'}).apply(items), isEmpty);
  });

  test('未知のカテゴリも絞り込める', () {
    expect(
        ids(const ClosetFilter(categories: {'謎カテゴリ'}).apply(items)), [5]);
  });

  test('絞り込みと並び替えの併用', () {
    final r = const ClosetFilter(colors: {'黒'}, sort: ClosetSort.oldest)
        .apply(items);
    expect(ids(r), [2, 3, 4]);
  });

  test('clearFiltersは絞り込みだけ解除して並び順を維持', () {
    const f = ClosetFilter(
      categories: {'パンツ'},
      sort: ClosetSort.oldest,
    );
    expect(f.hasActiveFilter, isTrue);
    final cleared = f.clearFilters();
    expect(cleared.hasActiveFilter, isFalse);
    expect(cleared.sort, ClosetSort.oldest);
    expect(ids(cleared.apply(items)), [1, 2, 3, 4, 5]);
  });

  test('元のリストを変更しない', () {
    final before = ids(items);
    const ClosetFilter(sort: ClosetSort.oldest).apply(items);
    expect(ids(items), before);
  });

  test('createdAtがnullのものは最も古い扱い', () {
    final list = [
      c(1, 'パンツ', '黒', '夏', 1),
      Clothing(id: 9, imagePath: 'x', category: 'パンツ', color: '黒', season: '夏'),
    ];
    expect(ids(const ClosetFilter().apply(list)), [1, 9]);
    expect(
        ids(const ClosetFilter(sort: ClosetSort.oldest).apply(list)), [9, 1]);
  });

  test('色の前後空白は無視される', () {
    final list = [c(1, 'パンツ', ' 黒 ', '夏', 1)];
    expect(availableColors(list), ['黒']);
    expect(const ClosetFilter(colors: {'黒'}).apply(list), hasLength(1));
  });

  test('availableは実在値のみ、定義順、未知は末尾', () {
    expect(availableCategories(items),
        ['Tシャツ', 'アウター', 'パンツ', '謎カテゴリ']);
    expect(availableSeasons(items), ['春秋', '夏', '冬', 'オールシーズン']);
    expect(availableColors(items), unorderedEquals(['黒', '白', '赤']));
    expect(availableCategories([]), isEmpty);
  });
}
