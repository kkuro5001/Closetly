import '../models/clothing.dart';
import '../models/outfit.dart';

// コーデに必要な最低着数
const minOutfitItems = 2;

// コーデの clothingIds を服一覧から引き当てる。
// 一覧にない id(削除済み・取得前)は黙って飛ばし、コーデ側の並び順を保つ
List<Clothing> resolveOutfitClothes(Outfit outfit, List<Clothing> all) {
  final byId = {
    for (final c in all)
      if (c.id != null) c.id!: c,
  };
  final seen = <int>{};
  final result = <Clothing>[];
  for (final id in outfit.clothingIds) {
    final clothing = byId[id];
    if (clothing != null && seen.add(id)) result.add(clothing);
  }
  return result;
}

// エディタの入力チェック。問題なければ null、あればユーザーに見せるメッセージ
String? validateOutfitInput(String name, int selectedCount) {
  if (name.trim().isEmpty) return "コーデの名前を入力してください";
  if (selectedCount < minOutfitItems) {
    return "服を$minOutfitItems着以上選んでください";
  }
  return null;
}

// カテゴリで絞り込む(null なら全件)
List<Clothing> filterByCategory(List<Clothing> all, String? category) {
  if (category == null) return all;
  return all.where((c) => c.category == category).toList();
}
