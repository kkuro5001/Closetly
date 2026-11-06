# 服のサイズ

## 作ったもの
服の登録時と編集時にサイズを入れられるようにした(任意項目)。
- DB: `clothes` に `size text`(null 可)を追加。既存DB用は `supabase/migrations/add_clothes_size.sql`、新規用は `supabase/clothes_table.sql` にも追記。
- `Clothing.size`(`String?`)。`fromMap` は `size` が無い / null の行も読める。`toMap` は size があるときだけ `size` を含める。
- `Clothing.copyWith(size: ...)`: 省略すると元の値を引き継ぎ、`null` を渡すと未設定に戻る(目印の `_unset` オブジェクトで区別)。
- `ClothingService.updateClothing` に `size` を追加(null なら未設定に戻す)。
- `widgets/size_field.dart`(`SizeField`): 自由入力の欄 + よく使うサイズ(`sizeSuggestions`: XS〜XXL、フリー)のチップ。選択中のチップをもう一度押すと空になる。登録画面と編集ダイアログの両方で使う。
- `normalizeSize`(`constants/clothing_options.dart`): 前後の空白を除き、空なら null。
- 表示: 詳細画面に「サイズ: M」(未設定なら「未設定」)、クローゼットのカードは「夏 · M」のように季節の横に併記。
- 登録後のリセット: 色と同じくサイズもクリアする(服ごとに違うことが多いため)。カテゴリ・季節は今まで通り残す。

## 設計判断
- **自由入力 + チップ**: カテゴリ・季節のような固定の選択肢にしなかったのは、服の種類で表記が違う(靴は 25.5、パンツは W30、子供服は 110 など)ため。固定リストだと足りないので自由入力にし、よく使うものだけ1タップで入れられるようにした。
- **任意項目(null 可)**: 既存の服にはサイズが無く、全部入れ直してもらうのは手間なので必須にしなかった。空欄は空文字ではなく null で保存し、「未設定」を1種類にした。
- **toMap で未設定なら送らない**: マイグレーション前に新しいフロントが動いても、サイズ空欄の登録は今まで通り成功する(列が無いと PostgREST がエラーにするため)。編集の update は未設定に戻すために常に `size` を送るので、マイグレーション前だと編集は失敗する。
- **絞り込み・並び替え・AI コーデ提案には入れていない**: 依頼は登録と編集。サイズで絞り込む需要があるかは未確認なので今回は見送った。Go の `/suggest-outfit` が取得する列(id/category/color/season)も変えていない。

## ユーザーが実行するSQL(Supabase SQL Editor)
**フロントをデプロイする前に**実行する。
```sql
alter table public.clothes add column if not exists size text;
```
RLS は既存の行単位ポリシーがそのまま効くので追加不要。
→ 本番DBで実行済み(2026-11-06)。

## テスト
- `flutter test`: 全件成功。追加したもの:
  - `test/clothing_edit_test.dart` の「サイズ」グループ(copyWith の省略/ null / 変更、size の無い行の fromMap、toMap、normalizeSize)
  - `test/size_field_test.dart`(チップで入力・同じチップで解除・手入力、AlertDialog の中でレイアウトエラーが出ないこと)
- `flutter analyze`: 新しい指摘なし(`main.dart` の既存2件のみ)。

## 未確認
- 実機・ブラウザでの見た目(チップの並び、編集ダイアログの幅)。
