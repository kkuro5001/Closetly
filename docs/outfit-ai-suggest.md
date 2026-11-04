# AIコーデ提案 (outfit AI suggest) 実装記録

手持ちの服から、Gemini に「今日のコーデ」を最大3件提案してもらい、気に入ったものを `outfits` に保存できる機能の記録。
Go 側 (`Go/suggest.go`) は司令塔が実装、Flutter 側 (`outfit_suggest_page.dart` / `outfit_service.dart`) をこの作業で実装した。

## 全体の流れ

```
Flutter (OutfitSuggestPage)
  -> OutfitService.suggestOutfits(scene, season)
       Authorization: Bearer <Supabase アクセストークン>
       本文 {"scene": "...", "season": "春秋"}
  -> Go  POST {API_BASE_URL}/suggest-outfit
       1. Supabase /auth/v1/user にトークンを問い合わせてログイン確認
       2. そのトークンで本人の服(カテゴリ・色・季節だけ。画像は送らない)を Supabase から取得
       3. Gemini (既定 gemini-3.6-flash, GEMINI_MODEL で変更可) に generateContent + responseJsonSchema で提案させる
       4. 本人の服に無い id・重複を除き、2着未満の提案は捨てて最大3件返す
  <- {"suggestions":[{"name","clothing_ids":[...],"reason"}]}
  -> 提案カード(名前・理由・服のサムネイル)を表示
  -> 「このコーデを保存」で createOutfit(name, note=reason, clothingIds)
```

エラー: 400(服が2着未満/場面が長い)、401(未ログイン)、502(Gemini/Supabase 失敗)、503(GEMINI_API_KEY などが未設定)。
Flutter 側は 400/401/503 を日本語メッセージにし、それ以外は「提案の取得に失敗しました (HTTP n)」とする。

## Go 側の設計と理由(土台)

- APIキーはブラウザ (Flutter Web) に入れると誰でも見えるので、Go サーバーから Gemini を呼ぶ。キーは URL ではなく `x-goog-api-key` ヘッダーで渡す。
- Go API は今までログイン確認が無く、そのままだと誰でも Gemini の無料枠を使えてしまうため、トークン確認を入れた。
- JWT を自前で検証せず Supabase の `/auth/v1/user` に問い合わせる。鍵の種類(JWT の署名方式)に依存しないため。
- 服はクライアントから受け取らず、トークンで Supabase から取る。他人の服 id が混ざらない。
- 利用者の入力(場面)は「場面の説明としてのみ扱う」とプロンプトで明示(プロンプトインジェクション対策)。
- `gemini-2.5-flash` は 2026-12-01 で別モデルに転送される廃止予定のため使わない。
- CORS の Allow-Headers に Authorization を追加済み。CD は `secrets.GEMINI_API_KEY` と SUPABASE_URL/ANON_KEY を Go コンテナに渡す。docker compose は `.env` の GEMINI_API_KEY を読む。

## Flutter 側の設計判断と理由

### 提案画面 (`frontend/lib/pages/outfit_suggest_page.dart`)
- 入力: 場面(任意、200字まで。Go の上限に合わせて `maxLength`)、季節(既定は `seasonForMonth(今の月)`)。
- 提案中はボタン・入力欄を無効にして連打を防ぐ。さらに `_requestId` をリクエストごとに増やし、結果が返ったときに最新でなければ捨てる(`color-autofill.md` の stale-result guard と同じ考え方)。`mounted` も確認する。
- 読み込み中は「数十秒かかることがあります」と表示(タイムアウトは 60 秒)。失敗時はエラーメッセージと「再試行」ボタン。提案が0件(Go が全部捨てた場合)もエラー扱いにして再試行できるようにした。
- 服のサムネイルは、提案と同時に `ClothingService().getAllClothing()` を `Future.wait` で取り、id -> `Clothing` の表で `imagePath` を引く。表に無い id(提案後に削除された服など)は表示を飛ばすだけ。
- 保存: `createOutfit` の `note` に reason を入れる。保存中は押せない、保存済みのカードは「保存済み」表示で再保存できない(同じ提案を何度も保存して重複するのを防ぐ)。
- 戻るときは `PopScope` で、保存した件数が1以上なら `true` で pop する(一覧側が再読み込みする約束)。AppBar の戻る・システムの戻る両方がここを通る。
  保存件数は、保存中に提案を取り直しても数え落とさないよう、リクエスト番号とは別のカウンタで持つ。

### `OutfitService` の変更(テスト用の最小限)
- コンストラクタに `String? Function()? accessToken` を追加。未指定なら従来どおり Supabase のセッションから取る。既存の公開メソッドの名前・引数は変えていない。
  理由: テストでは `Supabase.instance` が初期化されておらず、`currentSession` を読むと落ちるため。

## 直面した問題と解決

- `Supabase.instance` に依存するコードは単体テストで動かせない -> トークン取得関数を差し替え可能にした(上記)。
- `Exception.toString()` は `Exception: ...` と付くため、画面にはそのまま出さず接頭辞を外して表示する。
- 提案を取り直した後に、前の提案の保存が完了した場合の扱い: 画面の状態(保存済みマーク)は新しい提案には反映せず、保存件数だけ数える。

## テスト

- 新規 `frontend/test/outfit_service_test.dart`(`MockClient`): Authorization ヘッダー・本文・URL、200 の解析、`suggestions` が無い応答、400/401/503/500 のメッセージ、トークン無しのとき送信せずエラー。
- `flutter test`: 全件成功(48件)。`flutter analyze`: 既存の `lib/main.dart` の2件のみ。
- 画面 (`OutfitSuggestPage`) のウィジェットテストは書いていない(`Supabase` と `ClothingThumbnail` の署名付きURL取得に依存するため)。

## 未確認の点

- 実際の Gemini を呼んでの動作確認はしていない(`GEMINI_API_KEY` を設定した実機/実環境での確認が必要)。提案の質、応答時間(60秒に収まるか)は未確認。
- 画面は実機・ブラウザで目視していない(analyze と単体テストのみ)。
- 提案の服が多い場合のサムネイル横スクロールのレイアウトは未確認。

## 本番で「Failed to fetch」になる問題 (2026-11-04)
### 症状
本番(`https://closetly.kkuro.com`)で「AIにコーデを提案してもらう」を押すと、
`ClientException: Failed to fetch, uri=https://closetly-go.kkuro.com/suggest-outfit` になることがある。

### 調べたこと
- プリフライトは `204`、トークンなしは `401`。どちらも CORS ヘッダー付きで正常。testuser のトークンで curl すると `200`(約8〜20秒)。
- 本番サイトのページ上から `fetch` で同じリクエストを繰り返すと、成功と「Failed to fetch」が混ざった(季節の値とは関係なかった)。
- curl で8回続けて呼ぶと 6回が **`502`**(0.3〜1.2秒で返る)。そのときの応答は Cloudflare の `error code: 502`(`text/plain`)で、
  Go の JSON ではなく、**CORS ヘッダーも `x-served-by` も無い**。
  → Go が返した 502 を Cloudflare が自前のエラーページに差し替え、CORS ヘッダーが消えるため、ブラウザでは中身が読めず「Failed to fetch」になる。
- Go が 502 を返すのは「服の取得失敗」か「Gemini の呼び出し失敗」。短い時間で続けて呼ぶと失敗が増えたので、Gemini の無料枠の回数制限(429)と推測。
- **Go のログで確認**(ユーザーが `docker logs closetly-go --since 2h 2>&1 | grep Gemini` を実行): 失敗は Gemini の **503 が6件、429 が5件**。
  - 503 は Gemini 側の一時的な過負荷。ユーザーが最初に見たエラーはこちらと考えられる。
  - 429 は調査で短時間に Gemini を20回ほど呼んだために出たもの。**ユーザーから「Gemini を試すときに無料枠を消費するのは控えて」と言われた**ので、
    今後の確認は Go のテストのフェイク(`fakeGemini`)と Flutter の `MockClient` で行い、本番の `/suggest-outfit` を実際のトークンで呼ばない。

### 直したこと
- Go: 外部サービスの失敗は 502 ではなく **500** で返す(Cloudflare に差し替えられないように)。Gemini が 429 を返したときは **429** をそのまま返す。
- Flutter: 429 のとき「AIの利用回数の上限に達しました。少し待ってから試してください」、500(Gemini の 503 もここ)のとき
  「AIの提案を取得できませんでした。時間をおいて試してください」を表示する。
- テスト: Go は Gemini 429 → 429、Gemini 503 → 500 を確認。Flutter は 429 / 500 のメッセージを追加。`go test ./...` 成功、`flutter test test/outfit_service_test.dart` 9件成功。

### 未確認・残り
- Cloudflare が 500 / 429 を差し替えずにそのまま通すかは、デプロイ後に本番で確認する(401 はそのまま通ることは確認済み)。
- (任意) Gemini の 503 は一時的なので、Go 側で1回だけ再試行する案もある(無料枠の消費が増える可能性があるので未対応)。
- 季節に「冬」を指定しても、夏向けのコーデ名・理由が返ってくることがあった(プロンプトでは「優先する」だけで、テスト用の服の季節の偏りもある)。
