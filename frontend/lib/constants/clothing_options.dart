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

// サイズ入力欄の下に出す「よく使うサイズ」の候補。
// サイズは服の種類で表記が違う(靴の25.5、パンツのW30など)ため自由入力で、これは1タップ入力用の補助
const sizeSuggestions = [
  "XS",
  "S",
  "M",
  "L",
  "XL",
  "XXL",
  "フリー",
];

// サイズ入力欄の値を保存用に正規化する(前後の空白を除き、空なら未設定 = null)
String? normalizeSize(String input) {
  final trimmed = input.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// 選択肢に現在の値が含まれていない場合(古いデータなど)、
// 編集時に値が勝手に変わらないよう先頭に追加した一覧を返す
List<String> optionsWithCurrent(List<String> options, String current) {
  if (options.contains(current)) {
    return options;
  }
  return [current, ...options];
}
