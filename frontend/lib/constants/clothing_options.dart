// 服のカテゴリ・季節の選択肢(登録・編集・絞り込みで共通して使う)

const categoryOptions = [
  "Tシャツ",
  "シャツ",
  "パーカー",
  "セーター",
  "アウター",
  "パンツ",
  "スカート",
  "ワンピース",
  "靴",
  "帽子",
  "その他",
];

const seasonOptions = [
  "春秋",
  "夏",
  "冬",
  "オールシーズン",
];

// 選択肢に現在の値が含まれていない場合(古いデータなど)、
// 編集時に値が勝手に変わらないよう先頭に追加した一覧を返す
List<String> optionsWithCurrent(List<String> options, String current) {
  if (options.contains(current)) {
    return options;
  }
  return [current, ...options];
}
