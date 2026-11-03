import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/clothing.dart';
import 'package:frontend/models/wear_log.dart';
import 'package:frontend/utils/wear_stats.dart';

Clothing c(int id, {DateTime? createdAt}) => Clothing(
      id: id,
      imagePath: 'p$id',
      category: 'トップス',
      color: '白',
      season: '春秋',
      createdAt: createdAt,
    );

WearLog w(int id, DateTime d) => WearLog(clothingId: id, wornOn: d);

void main() {
  final today = DateTime(2026, 11, 3);
  final longAgo = DateTime(2025, 1, 1);

  group('summarizeWearLogs', () {
    test('回数と最後に着た日', () {
      final s = summarizeWearLogs([
        w(1, DateTime(2026, 10, 1)),
        w(1, DateTime(2026, 10, 5)),
        w(2, DateTime(2026, 9, 1)),
      ]);
      expect(s[1]!.count, 2);
      expect(s[1]!.lastWornOn, DateTime(2026, 10, 5));
      expect(s[2]!.count, 1);
      expect(s[3], isNull);
    });
  });

  group('staleClothes', () {
    test('ちょうど30日前は含み、29日前は含まない', () {
      final r = staleClothes(
        [c(1, createdAt: longAgo), c(2, createdAt: longAgo)],
        [w(1, DateTime(2026, 10, 4)), w(2, DateTime(2026, 10, 5))],
        today,
      );
      expect(r.map((e) => e.clothing.id), [1]);
      expect(r.first.days, 30);
    });

    test('登録したばかりで未着用の服は含めない', () {
      final r = staleClothes([c(1, createdAt: DateTime(2026, 11, 1))], [], today);
      expect(r, isEmpty);
    });

    test('登録から30日以上経つ未着用の服は含める(基準は登録日)', () {
      final r = staleClothes([c(1, createdAt: DateTime(2026, 10, 4))], [], today);
      expect(r.length, 1);
      expect(r.first.since, DateTime(2026, 10, 4));
    });

    test('登録から29日の未着用は含めない', () {
      final r = staleClothes([c(1, createdAt: DateTime(2026, 10, 5))], [], today);
      expect(r, isEmpty);
    });

    test('createdAt が null で記録も無ければ含める', () {
      final r = staleClothes([c(1)], [], today);
      expect(r.length, 1);
      expect(r.first.days, isNull);
    });

    test('最近着ていれば登録が古くても含めない', () {
      final r = staleClothes(
          [c(1, createdAt: longAgo)], [w(1, DateTime(2026, 11, 2))], today);
      expect(r, isEmpty);
    });

    test('古い順に並ぶ', () {
      final r = staleClothes(
        [c(1, createdAt: longAgo), c(2, createdAt: longAgo), c(3, createdAt: longAgo)],
        [
          w(1, DateTime(2026, 8, 1)),
          w(2, DateTime(2026, 6, 1)),
          w(3, DateTime(2026, 7, 1)),
        ],
        today,
      );
      expect(r.map((e) => e.clothing.id), [2, 3, 1]);
    });

    test('服も記録も無ければ空', () {
      expect(staleClothes([], [], today), isEmpty);
    });

    test('days を変えられる', () {
      final r = staleClothes(
          [c(1, createdAt: longAgo)], [w(1, DateTime(2026, 10, 27))], today,
          days: 7);
      expect(r.length, 1);
    });
  });

  group('frequentClothes', () {
    test('回数の多い順、0回は含めない', () {
      final r = frequentClothes(
        [c(1), c(2), c(3)],
        [
          w(1, DateTime(2026, 10, 1)),
          w(2, DateTime(2026, 10, 1)),
          w(2, DateTime(2026, 10, 2)),
        ],
      );
      expect(r.map((e) => e.clothing.id), [2, 1]);
      expect(r.first.count, 2);
    });

    test('同数なら最後に着た日が新しい順', () {
      final r = frequentClothes(
        [c(1), c(2)],
        [w(1, DateTime(2026, 10, 1)), w(2, DateTime(2026, 10, 9))],
      );
      expect(r.map((e) => e.clothing.id), [2, 1]);
    });

    test('上位 limit 件だけ返す', () {
      final clothes = [for (var i = 1; i <= 7; i++) c(i)];
      final logs = [for (var i = 1; i <= 7; i++) w(i, DateTime(2026, 10, i))];
      expect(frequentClothes(clothes, logs).length, 5);
      expect(frequentClothes(clothes, logs, limit: 2).length, 2);
    });

    test('記録なしは空', () {
      expect(frequentClothes([c(1)], []), isEmpty);
    });
  });

  test('daysBetween は暦日で数える', () {
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    expect(daysBetween(DateTime(2026, 11, 3, 23), DateTime(2026, 11, 4, 1)), 1);
  });
}
