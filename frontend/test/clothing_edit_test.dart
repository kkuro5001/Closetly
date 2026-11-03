import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/constants/clothing_options.dart';
import 'package:frontend/models/clothing.dart';

void main() {
  test('copyWithは指定項目だけ変更し他は引き継ぐ', () {
    final c = Clothing(
      id: 1,
      imagePath: 'u/original/a.jpg',
      category: 'Tシャツ',
      color: '白',
      season: '夏',
      createdAt: DateTime(2026, 1, 1),
    );
    final e = c.copyWith(color: '黒');
    expect(e.color, '黒');
    expect(e.category, 'Tシャツ');
    expect(e.season, '夏');
    expect(e.id, 1);
    expect(e.imagePath, c.imagePath);
    expect(e.createdAt, c.createdAt);
  });

  test('optionsWithCurrentは一覧にない値を先頭に追加する', () {
    final r = optionsWithCurrent(categoryOptions, '古いカテゴリ');
    expect(r.first, '古いカテゴリ');
    expect(r.length, categoryOptions.length + 1);
  });

  test('optionsWithCurrentは一覧にある値ならそのまま返す', () {
    expect(optionsWithCurrent(seasonOptions, '夏'), seasonOptions);
  });
}
