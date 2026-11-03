# コーディネート(手動作成)

## 作ったもの
- `frontend/lib/navigation/main_page.dart`: 4つ目のタブ「コーデ」を追加。4項目になるため `BottomNavigationBarType.fixed` を指定。タブ切替でページを作り直す仕組み(IndexedStack 不使用)は維持
- `frontend/lib/pages/outfits_page.dart`: コーデ一覧。名前+服のサムネイル横並びのカード、空/エラー表示、引っ張って更新、右下に作成ボタン、AppBar に AI 提案ボタン(`OutfitSuggestPage` を開き、true が返れば再読み込み)
- `frontend/lib/pages/outfit_editor_page.dart`: 名前入力+服のグリッド複数選択(チェック表示)、カテゴリチップで絞り込み。2着以上&名前必須で保存、保存中は二重送信しない
- `frontend/lib/pages/outfit_detail_page.dart`: 服一覧(タップで `ClothingDetailPage`)、note 表示、「今日このコーデを着た」(`recordWear`)、削除(確認ダイアログ)
- `frontend/lib/utils/outfit_utils.dart`: 純粋関数(`resolveOutfitClothes` / `validateOutfitInput` / `filterByCategory`)
- `frontend/test/outfit_utils_test.dart`: 上記の単体テスト(9件)

## 設計判断
- **一覧は outfits と clothes を並行取得する**: `Outfit` は服の id しか持たず、サムネイルには `imagePath` が要る。`Future.wait` で両方読み、`resolveOutfitClothes` で引き当てる。DB に既にある `outfit_items` の結合をいじらず土台を変えないため。
- **存在しない id は黙って飛ばす**: 服が削除されると DB 側で outfit_items から外れるが、取得タイミングによっては一覧にない id が残りうる。0〜1着のコーデもエラーにせず表示し、詳細では「削除された服はこのコーデから外れています」と案内する。0着のときは着用ボタンを無効化。
- **入力チェックは純粋関数に切り出し**: 保存ボタンの有効/無効判定と保存時の再チェックの両方で同じ関数を使う(名前の空白のみも不可)。
- **二重送信防止**: `isSaving` フラグで保存ボタン無効化+関数冒頭で return。失敗時は SnackBar を出してフラグを戻し、再試行できる。コーデ本体のロールバックは `createOutfit` 側(土台)が担当。
- **詳細画面の戻り値**: 削除時は true。服を詳細から編集/削除した場合も `changed` を立て、戻るときに true を返す(`PopScope` で制御)。一覧が古いサムネイルを持たないため。
- **着用記録は端末ローカルの `DateTime.now()`**: 指示どおり。重複は `recordWear` 側で無視される。
- **カテゴリチップは実在するものだけ**: `categoryOptions` の定義順で、登録済みの服にあるカテゴリのみ表示(0件の選択肢を出さない)。選択は絞り込みを変えても保持される。

## 発生した問題
- 長い複合コマンドが worktree 検証で拒否されたため、ファイル作成は Write/Edit に分けた。
- テストの import を `package:closetly/` と誤って書いた(実際のパッケージ名は `frontend`)。修正済み。
- 初回の analyze で新規 info 2件(文字列補間の不要な波括弧、`(_, __)`)が出たので修正し、既存2件のみに戻した。
- `flutter pub get` が `pubspec.lock` と各プラットフォームの generated ファイルを書き換えるため、コミット前に `git checkout --` で戻した(これまでの docs と同様)。

## テスト結果
```
cd frontend && flutter analyze && flutter test
flutter analyze: 2 issues found(既存の lib/main.dart のみ。新規なし)
flutter test: All tests passed! (+50)
```

## 未確認
- 実機・ブラウザでの表示確認は未実施(サムネイル横スクロール、グリッドの選択表示、狭い幅でのレイアウト)。
- ページ(Supabase 直依存)のウィジェットテストは未追加。ロジックのみ単体テスト。
- 実 DB(マイグレーション適用後)での保存・削除・着用記録の動作は未確認。
- 詳細画面は服一覧を全件取得して絞るため、服が数千件規模になると非効率。必要になったら `in` クエリに変える。
