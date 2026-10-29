# 色の自動入力 (color autofill) 実装記録

写真を選ぶ/撮ると、Go API (`POST /upload`) 経由で Python の OpenCV 色解析 (`Python/color_analyzer.py`) を呼び、
`camera_page.dart` の「色」欄に色名を自動で入れる機能の実装記録。

## 全体の流れ

```
Flutter (camera_page)
  -> ColorService.analyzeColor(bytes)   multipart field "image"
  -> Go  POST {API_BASE_URL}/upload     (CORS ミドルウェア付き)
  -> Python POST {PYTHON_API_URL}/predict  (生バイト)
  <- JSON {"color":"ネイビー","color_en","hex","ratio"}
  <- Go が JSON をそのまま中継
  -> colorController.text = color  (編集可能なまま)
```

## 前提の確認(ベースブランチの問題)

作業ブランチ (`worktree-agent-...`) は `master` (041fc48) から作られており、`Python/color_analyzer.py` が存在しなかった。
色解析は `feature/keep-supabase` ブランチの 4215997「OpenCVで服の色を解析する機能をPython APIに追加」にのみ入っていた。
そのため `git merge --ff-only feature/keep-supabase` で取り込んでから作業した(コミット履歴にそのコミットが含まれる)。
master へマージする際は feature/keep-supabase 側のコミットも一緒にマージされる点に注意。

## 設計判断と理由

### CORS (Go 側で許可) vs nginx リバースプロキシ
- Flutter Web はブラウザで動くため、フロント (例 `:80`) から Go (`:8080`) へは別オリジン通信になる。
- 案A: nginx で `/api` を Go にプロキシして同一オリジンにする。CORS 不要・mixed-content も避けやすいが、
  フロントのコンテナ構成、CD の `docker run`(単体コンテナ起動)、nginx 設定の追加が必要で変更範囲が大きい。
- 案B (採用): Go に gin の自前ミドルウェアで CORS を付ける。依存追加なし・数十行で済み、ローカル開発 (`flutter run -d chrome`) でも同じ動きになる。
- 許可オリジンは環境変数 `CORS_ALLOWED_ORIGINS`(カンマ区切り)で指定し、一致したときだけ `Access-Control-Allow-Origin` にそのオリジンを返す。
  CD では `https://closetly.kkuro.com` を渡している。未設定のときはローカル開発用に `localhost` / `127.0.0.1`(ポートは問わない)だけを許可する。
  許可外のオリジンからのプリフライトは 403。`Origin` ヘッダーのないリクエスト(スマホのネイティブアプリや curl)は CORS の対象外なのでそのまま通る。
  (以前は `*` で全オリジンを許可していた)
- 許可: メソッド `POST, GET, OPTIONS`、ヘッダ `Content-Type`。OPTIONS は `AbortWithStatus(204)` で本処理に入れず返す。

### URL は `--dart-define` (`API_BASE_URL`)
- Flutter Web はビルド時に値が確定する静的ファイルなので、実行時の環境変数は読めない。
  `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')` をビルド時に埋め込む方式にした。
- `frontend/Dockerfile` に `ARG API_BASE_URL` を追加し `flutter build web --dart-define=API_BASE_URL=$API_BASE_URL` に渡す。
  CI は `--build-arg API_BASE_URL=${{ vars.API_BASE_URL || 'http://localhost:8080' }}`(GitHub の Repository variables)。
- 副作用: URL を変えるにはフロントの再ビルドが必要。

### 失敗時の扱い
- 色解析はあくまで補助。タイムアウト 15 秒、HTTP 非 200、JSON 不正、通信エラーはすべて `debugPrint` のみで色欄は触らない。
- Python が解析できないと `"color": "unknown"` を 200 で返すため、`unknown`/空文字は「失敗扱い(null)」にして色欄を変更しない。
- 保存処理 (`saveClothing`) は一切変更していない。解析中でも保存可能で、そのときは色欄の現在値が保存される。

### 古い結果の上書き防止 (stale-result guard)
- `_colorRequestId` をリクエストごとにインクリメントし、レスポンス到着時に自分の番号が最新か確認する。
  別の写真が選ばれていたら結果を破棄する(ユーザーが手で入力済みの値や新しい結果を潰さないため)。
- `mounted` もチェック。インジケーターの消灯 (`isAnalyzingColor`) も最新リクエストのみが行う
  (古いリクエストが新しいリクエストの表示を消さないため)。
- 制限: 解析結果が返る前にユーザーが色欄へ手入力した場合は、結果で上書きされる(同一写真の間は検知していない)。

### YOLO のカテゴリに色判定を頼らない理由
- YOLOv8n (COCO) は服の色を出すモデルではなく、COCO に服のクラスが乏しいため `category` も当てにならない。
  `main.py` の以前の `color` はハードコードの `"black"` だった。
- 色は OpenCV (GrabCut で背景除去 → Lab 空間 k-means → HSV 範囲で色名化) で画像から直接求める。YOLO の結果(検出有無)には依存させない。
- ただし `main.py` は「物体検出なし」の場合も色解析結果を含めて返す実装になっている(feature/keep-supabase の実装)ので、色は取れる。
  フロントは `category` を使わず `color` のみ使う。

### Go の中継について
- `UploadHandler` は Python のステータスに関わらず 200 + 本文をそのまま返す(既存挙動、今回は変更せず)。
  Python が 500 を返すと本文が JSON でなく、フロント側の JSON パース失敗 → 例外 → ログのみ、で吸収される。

## 実装したもの
- `frontend/lib/config/api_config.dart`: `ApiConfig.baseUrl`
- `frontend/lib/services/color_service.dart`: `http.MultipartRequest` + `MultipartFile.fromBytes`(Web 対応、`dart:io` 不使用)。
  `http.Client` をコンストラクタ注入できる(テスト用 `MockClient`)。
- `frontend/lib/pages/camera_page.dart`: `_pickImage` の最後で `_autofillColor` を呼ぶ。色欄の `suffixIcon` に小さな `CircularProgressIndicator`。
- `Go/main.go`: `corsMiddleware()` と `setupRouter()`(テストから組み立て可能に分離)。
- `Go/upload_test.go`: 偽 Python サーバー (`httptest`) で中継・400・プリフライトを検証。
  (既存の `Go/test.go` は `_test.go` ではないのでテストにならない点に注意。)
- `frontend/Dockerfile`, `docker-compose.yml` (go に `PYTHON_API_URL=http://python:8000`)。
- `.github/workflows/ci.yml`, `cd.yml`: 「現在未使用のため無効化」でコメントアウトされていた Go/Python の手順・ジョブを復活。
- `CLAUDE.md` 更新。

## 遭遇した問題と対処

1. **color_analyzer.py が作業ブランチに無かった** -> 上記のとおり feature/keep-supabase を fast-forward マージ。
2. **`flutter test` が `widget_test.dart` で失敗**: 中身が全てコメントアウトで `main` が無く
   `Missing definition of main method`。カウンターのテンプレート自体が現アプリと無関係なので、
   `ApiConfig.baseUrl` のデフォルト値を確認する小さなテストに置き換えた。
3. **`flutter analyze` の info**: `color_service.dart` の `dart:typed_data` import が不要 (`foundation.dart` が再エクスポート) と出たので削除。
4. **`flutter pub get` が `linux/macos/windows` の generated_plugin* ファイルを書き換えた**: 本変更と無関係なので `git checkout` で戻した。
5. **CI の `go-version: '1.22'`**: コメントアウトされていた元の設定のままだと `Go/go.mod` が `go 1.25.0` なので古すぎて失敗するはず。`'1.25'` に更新した
   (CI 上での実行は未確認)。
6. **`python -m compileall` が `Python/__pycache__` を作る**: コミットに入れないよう削除した。
7. **`docker compose` が使えなかった**: 下記テスト結果参照。
8. bash の here-doc を含む複合コマンドが作業ツリー隔離チェックで拒否されたため、ファイル作成は Write ツールに切り替えた(コード上の問題ではない)。

## テストコマンドと実際の結果

| コマンド | 結果 |
|---|---|
| `cd Go && go vet ./...` | 問題なし (exit 0) |
| `cd Go && go test ./...` | `ok  Go` (新規 3 テスト: 中継 / 画像なし 400 / プリフライト 204 を含む) |
| `cd Python && python -m compileall -q .` | exit 0 |
| `cd frontend && flutter pub get` | 成功 |
| `cd frontend && flutter analyze` | 2 件の既存の指摘のみ(`lib/main.dart` の未使用 import `navigation/main_page.dart` (warning) と `anonKey` 非推奨 (info))。今回の変更に起因するものは 0 件。既存のため未修正 |
| `cd frontend && flutter test` | `All tests passed!` (color_service_test 4 件 + widget_test 1 件 = 5 件) |
| `docker compose up --build -d go python` + curl | **未実施**。Docker Desktop が起動しておらず `dockerDesktopLinuxEngine` パイプに接続できなかった |

補足: `gofmt -l .` は既存の `Go/test.go`, `Go/upload.go` を指摘する(元からのフォーマット差。今回は触れていない)。

### 実際に確認できていないこと
- 実コンテナでの Go -> Python の通し動作(curl `-F image=@Go/sample.jpg http://localhost:8080/upload` と OPTIONS プリフライト)。
  Go の中継と CORS は `httptest` の偽 Python で検証したのみ。Docker 起動後に次を実行してほしい:
  ```
  docker compose up --build -d go python
  curl -F image=@Go/sample.jpg http://localhost:8080/upload
  curl -i -X OPTIONS http://localhost:8080/upload -H "Origin: http://localhost" -H "Access-Control-Request-Method: POST"
  docker compose down
  ```
- ブラウザ (Flutter Web) / 実機での画面操作(インジケーター表示、実際の CORS 通過)。`camera_page` の UI は自動テスト無し。
- CI/CD ワークフローの実行(YAML の構文は目視確認のみ)。

## 未解決事項 / 注意
1. **本番の `API_BASE_URL`**: ブラウザから到達できる Go サーバーのアドレスを GitHub の `vars.API_BASE_URL` に設定する必要がある。
   未設定だとビルドが `http://localhost:8080` を埋め込み、利用者の端末の localhost を見に行って常に失敗(色欄は空のまま)する。
   CD の Go は LAN アドレス (192.168.11.37) の Python を見ている点も環境依存。
2. **mixed-content**: フロントを HTTPS で配信し、Go を HTTP で公開するとブラウザが通信をブロックする。Go 側も HTTPS にするか、リバースプロキシで揃える必要がある。
3. **HSV のしきい値は実写真で未検証**: `color_analyzer.py` の色名境界は実際の服写真で十分に検証していない。照明・背景次第で誤判定しうる。
   ユーザーが編集できる前提のため致命的ではないが、精度評価が必要。
4. **CORS が `*`**: 本番では許可オリジンの限定を検討。
5. ~~同一写真で手入力後に結果が届くと上書きされる~~ → 対応済み(下記「レビューでの修正」参照)。
6. ~~解析負荷/コスト: Python は YOLO 推論も毎回実行する~~ → YOLO を削除して解決(下記「YOLO の削除」参照)。レスポンス遅延が 15 秒を超えるとタイムアウトで諦める。
7. 既存の `flutter analyze` 指摘 (`lib/main.dart`) は未対応。

## レビューでの修正と再検証(Opus によるレビュー)
### 修正
- 解析中にユーザーが色を手入力した場合、あとから届いた解析結果で上書きされる問題があった。
  解析開始時の色欄の値を覚えておき、結果が届いた時点で値が変わっていれば自動入力しないようにした
  (`camera_page.dart` の `_autofillColor`)。手入力を常に優先する方針。

### 再実行したテスト
- `go vet ./...` / `go test -count=1 ./...` → `ok`
- `python -m compileall -q .` → 成功
- `flutter analyze` → 2件(どちらも既存の `lib/main.dart`、今回の変更とは無関係)
- `flutter test` → 5件すべて成功
- CI/CD・docker-compose の YAML を `yaml.safe_load` で読み込み、構文エラーがないことを確認
  (ci: `test-and-build` / cd: `deploy-go`, `deploy-python`, `deploy-frontend`)

### 遭遇した問題
- `flutter pub get` を実行すると `frontend/linux|macos|windows` の自動生成ファイルが書き換わる。
  今回の変更とは無関係なので `git checkout` で元に戻してからコミットしている。
- Docker Desktop が起動していなかったため起動した。
- Python イメージ(ultralytics / torch を含む)のビルドに10分以上かかり、ツールのタイムアウトを超えた。
  バックグラウンドで継続中。完了後に `curl` で `/upload` と CORS プリフライトを確認する予定。

## YOLO の削除 (2026-10-29)
### 理由
- アプリが使うのは `color` だけで、YOLO の `category` は使われていなかった。
- しかも yolov8n (COCO) は服の種類を見分けられず、`person` などしか返さないため役に立っていなかった。
- YOLO のために PyTorch が入り、イメージが巨大でビルドに30分以上かかっていた(今回の作業で何度もハマった原因)。
- 自宅サーバー (PVE) に Python を立て直すにあたり、軽くしたいという要望があった。

### 変更
- `Python/main.py`: YOLO の読み込み・推論を削除し、色解析だけを返す。レスポンスは `{"color","color_en","hex","ratio"}`。
  画像をデコードできない場合は `{"color":"unknown"}`(フロントは "unknown" を「解析できなかった」として扱い、色欄を変えない)。
- `Python/requirements.txt`: `ultralytics-opencv-headless` → `opencv-python-headless==4.12.0.88`
- `Python/Dockerfile`: apt での `libglib2.0-0` / `libgl1` / `ffmpeg` のインストールを削除(headless 版の OpenCV は必要なライブラリを同梱しているため)
- `README.md` / `CLAUDE.md` の YOLO の記述を OpenCV の色解析に更新

### 結果
| | YOLO あり | YOLO なし |
| --- | --- | --- |
| イメージサイズ | 3.51 GB | **138 MB** |
| ビルド時間 | 30分以上 | **61秒** |
| メモリ使用量(起動後) | 未計測 | 約 51 MB |

- 通し確認 (Go → Python): `sample.jpg` → 「黒」(0.26秒)、`sample2.jpg` → 「黒」、画像でないファイル → `{"color":"unknown"}`。削除前と同じ色の結果。
- apt パッケージを外しても `import cv2` を含めエラーなく起動した。
- `python -m compileall` 成功。Go とフロントは変更なし(テストの偽レスポンスに `category` が残っているが、余分なキーは無視されるので影響なし)。
