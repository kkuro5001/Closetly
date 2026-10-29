import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/clothing.dart';
import 'package:frontend/utils/wardrobe_stats.dart';

Clothing c(String category, String color, String season) => Clothing(
      imagePath: 'p',
      category: category,
      color: color,
      season: season,
    );

void main() {
  group('seasonForMonth', () {
    const expected = {
      1: "冬", 2: "冬", 3: "春秋", 4: "春秋", 5: "春秋", 6: "夏",
      7: "夏", 8: "夏", 9: "春秋", 10: "春秋", 11: "春秋", 12: "冬",
    };
    for (final e in expected.entries) {
      test('${e.key}月は${e.value}', () {
        expect(seasonForMonth(e.key), e.value);
      });
    }
    test('範囲外は例外', () {
      expect(() => seasonForMonth(0), throwsArgumentError);
      expect(() => seasonForMonth(13), throwsArgumentError);
    });
  });

  group('countBy', () {
    test('空リストは空', () {
      expect(countByCategory([]), isEmpty);
      expect(countByColor([]), isEmpty);
    });

    test('件数の多い順、同数は名前順', () {
      final list = [
        c('パンツ', '黒', '夏'),
        c('シャツ', '白', '夏'),
        c('シャツ', '黒', '冬'),
        c('パンツ', '黒', '冬'),
        c('靴', '白', '夏'),
        c('シャツ', '黒', '冬'),
      ];
      final cat = countByCategory(list);
      expect(cat.map((e) => '${e.name}:${e.count}').toList(),
          ['シャツ:3', 'パンツ:2', '靴:1']);
      final col = countByColor(list);
      expect(col.map((e) => '${e.name}:${e.count}').toList(), ['黒:4', '白:2']);
      // 同数のときは名前の昇順
      final tie = countByCategory([c('b', 'x', '夏'), c('a', 'x', '夏')]);
      expect(tie.map((e) => e.name).toList(), ['a', 'b']);
    });

    test('空の色は未設定にまとめる', () {
      final col = countByColor([c('靴', '', '夏'), c('靴', ' ', '夏')]);
      expect(col.single.name, '未設定');
      expect(col.single.count, 2);
    });
  });

  group('clothesForSeason', () {
    final list = [
      c('a', '黒', '夏'),
      c('b', '黒', 'オールシーズン'),
      c('c', '黒', '冬'),
      c('d', '黒', '春秋'),
    ];
    test('季節一致 + オールシーズン、順序保持', () {
      expect(clothesForSeason(list, '夏').map((e) => e.category).toList(),
          ['a', 'b']);
      expect(clothesForSeason(list, '春秋').map((e) => e.category).toList(),
          ['b', 'd']);
    });
    test('空リスト', () {
      expect(clothesForSeason([], '夏'), isEmpty);
    });
    test('オールシーズンのみでも全季節で出る', () {
      final only = [c('x', '白', 'オールシーズン')];
      for (final s in ['春秋', '夏', '冬']) {
        expect(clothesForSeason(only, s), hasLength(1));
      }
    });
  });
}
