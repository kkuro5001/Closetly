import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/clothing.dart';
import 'package:frontend/models/outfit.dart';
import 'package:frontend/utils/outfit_utils.dart';

Clothing c(int id, String category) => Clothing(
    id: id, imagePath: 'p$id', category: category, color: '黒', season: '春秋');

void main() {
  final all = [c(1, 'トップス'), c(2, 'パンツ'), c(3, 'アウター')];

  group('resolveOutfitClothes', () {
    test('コーデ側の順序で引き当てる', () {
      final o = Outfit(name: 'a', clothingIds: [3, 1]);
      expect(resolveOutfitClothes(o, all).map((e) => e.id), [3, 1]);
    });
    test('削除済みの id は飛ばす', () {
      final o = Outfit(name: 'a', clothingIds: [1, 99]);
      expect(resolveOutfitClothes(o, all).map((e) => e.id), [1]);
    });
    test('全部なくても空リスト', () {
      final o = Outfit(name: 'a', clothingIds: [99]);
      expect(resolveOutfitClothes(o, all), isEmpty);
    });
    test('重複 id は1回だけ', () {
      final o = Outfit(name: 'a', clothingIds: [1, 1]);
      expect(resolveOutfitClothes(o, all).length, 1);
    });
  });

  group('validateOutfitInput', () {
    test('名前が空・空白だけはエラー', () {
      expect(validateOutfitInput('', 2), isNotNull);
      expect(validateOutfitInput('  ', 2), isNotNull);
    });
    test('1着以下はエラー', () {
      expect(validateOutfitInput('a', 1), isNotNull);
    });
    test('名前あり2着以上はOK', () {
      expect(validateOutfitInput('a', 2), isNull);
    });
  });

  group('filterByCategory', () {
    test('null は全件', () => expect(filterByCategory(all, null).length, 3));
    test('指定カテゴリのみ', () {
      expect(filterByCategory(all, 'パンツ').map((e) => e.id), [2]);
    });
  });
}
