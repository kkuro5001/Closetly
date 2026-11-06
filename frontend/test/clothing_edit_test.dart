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

  group('サイズ', () {
    final base = Clothing(
      id: 1,
      imagePath: 'u/original/a.jpg',
      category: 'パンツ',
      color: '黒',
      season: '春秋',
      size: 'M',
    );

    test('copyWithでsizeを省略すると元の値を引き継ぐ', () {
      expect(base.copyWith(color: '白').size, 'M');
    });

    test('copyWithでsizeにnullを渡すと未設定に戻る', () {
      expect(base.copyWith(size: null).size, isNull);
    });

    test('copyWithでsizeを変更できる', () {
      expect(base.copyWith(size: 'W30').size, 'W30');
    });

    test('fromMapはsize列がない/nullの古い行でも読める', () {
      final c = Clothing.fromMap({
        'id': 2,
        'image_path': 'x',
        'category': 'Tシャツ',
        'color': '白',
        'season': '夏',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(c.size, isNull);
    });

    test('toMapはsizeがあるときだけ含める', () {
      expect(base.toMap()['size'], 'M');
      expect(base.copyWith(size: null).toMap().containsKey('size'), isFalse);
    });

    test('normalizeSizeは空白を除き、空ならnull', () {
      expect(normalizeSize('  L '), 'L');
      expect(normalizeSize('   '), isNull);
      expect(normalizeSize(''), isNull);
    });
  });
}
