# 作業状況メモ

時系列の作業記録。下に行くほど新しい。古い節の「残っていること」などは当時のままなので、今の状態は次の「現在の状態」を見る。
各機能の設計や問題の詳細は [color-autofill.md](color-autofill.md) / [clothing-edit.md](clothing-edit.md) /
[closet-filter.md](closet-filter.md) / [home-dashboard.md](home-dashboard.md) を参照。

## 現在の状態 (2026-10-30 時点)
### 本番で動いているもの (master `609319d`, PR #23 まで)
| 機能 | PR | 状態 |
| --- | --- | --- |
| 色の自動入力 (Go → Python の OpenCV 色解析) | #14 | 本番で動作確認済み |
| フロントのキャッシュ設定 (nginx の no-cache) | #15 | 本番で確認済み(次のデプロイからパージ不要) |
| CD 後の古いイメージ削除 (`docker image prune -f`) | #16 | 反映済み |
| Go の CORS を `CORS_ALLOWED_ORIGINS` で絞る | #18 | 本番で確認済み(下記) |
| カテゴリ・季節の選択肢の共通化 | #19 | 反映済み |
| クローゼットの絞り込み・並び替え | #20 | デプロイ済み・画面は未確認 |
| ホーム画面(登録数・集計・今の季節の服) | #21 | デプロイ済み・画面は未確認 |
| 服の編集(カテゴリ・色・季節) | #22 | デプロイ済み・画面は未確認 |

- PR #23(docs の更新)のマージ後も、master の CI と CD は成功(2026-10-29 07:30 UTC)。
- 本番の CORS (2026-10-30 確認): `Origin: https://closetly.kkuro.com` のプリフライトは `204` +
  `access-control-allow-origin: https://closetly.kkuro.com`、関係ないオリジンは `403`。

### 残っていること
- 編集・絞り込み・ホーム画面のブラウザ/実機での画面確認と、本番の Supabase での編集(update ポリシー)の動作確認
- スマホ実機での確認(全機能)
- 色名の判定しきい値 (HSV) を実際の服の写真で検証する
- 既存の `flutter analyze` の指摘2件 (`lib/main.dart`) は未対応
- (任意) CD が PR の CI の完了でも動いてしまう件(下記「本番への反映結果」の補足)
- (任意) `no-store` を外して `no-cache` だけにする改善(下記「本番への反映結果」)

## 進捗: 完了(Docker での通し確認まで済み、push 済み)

## ブランチ / 作業場所(2026-10-29 当時。すべて master にマージ済み)
- `feature/keep-supabase`: Python の色解析 (`4215997`) まで commit・push 済み
- worktree `.claude/worktrees/agent-a14bcde4850f99738`(ブランチ `worktree-agent-a14bcde4850f99738`)で残りを実装中。**未 push**
  - `a3b5336` 撮影した写真から色を自動入力する機能を追加 (Sonnet が実装)
  - `05a8784` 解析中に手入力された色を自動入力で上書きしないよう修正し、検証結果をdocsに追記 (Opus のレビュー修正)
  - このメモ (`docs/progress.md`)

## 完了したこと
| 項目 | 内容 |
| --- | --- |
| Python | OpenCV で色解析 (`Python/color_analyzer.py`)。GrabCut で背景除去 → Lab 空間の k-means で代表色 → HSV で色名に変換 |
| フロント | 写真選択後に Go `/upload` を呼んで色欄に自動入力 (`color_service.dart`, `camera_page.dart`)。解析中はインジケーター表示、失敗しても手入力・保存は可能、手入力を優先 |
| Go | CORS ミドルウェア追加、`setupRouter()` に分離、`upload_test.go` を新規作成 |
| デプロイ | `docker-compose.yml` に `PYTHON_API_URL` 追加、フロントの Dockerfile に `API_BASE_URL` ビルド引数追加、Go/Python の CI/CD を再有効化 |
| ドキュメント | `CLAUDE.md` 更新、`docs/color-autofill.md` 作成 |

## テスト結果
- `go vet` / `go test` → 成功
- `python -m compileall` → 成功
- `flutter test` → 5件すべて成功
- `flutter analyze` → 2件(既存の `lib/main.dart` の指摘で今回の変更とは無関係)
- CI/CD・docker-compose の YAML 構文 → 問題なし(実際の GitHub Actions 実行は未確認)

## 残っていること(当時。1〜2 は対応済み → 下記「再開後の結果」、3 はブラウザのみ確認済み)
1. **Docker での通し確認(実行中)**
   - Docker Desktop を起動し `docker compose up --build -d go python` を実行
   - Go のイメージはビルド完了、Python のイメージ(ultralytics / torch を含むため大きい)は 10 分以上かかってビルド中
   - 完了後に以下を確認する
     ```
     curl -F image=@Go/sample.jpg http://localhost:8080/upload
     curl -i -X OPTIONS http://localhost:8080/upload -H "Origin: http://localhost" -H "Access-Control-Request-Method: POST"
     docker compose down
     ```
2. 問題なければ worktree のブランチを `feature/keep-supabase` に取り込んで push
3. 未確認: ブラウザ・実機での画面操作

## 本番に出す前に必要なこと
- ~~GitHub の `vars.API_BASE_URL` に、ブラウザから届く Go サーバーのアドレスを設定する~~ → `https://closetly-go.kkuro.com` を設定済み
- ~~フロントを HTTPS で配信する場合、Go も HTTPS にしないとブラウザに通信を止められる(mixed-content)~~ → Go も `https://closetly-go.kkuro.com` で HTTPS 配信
- 色名の判定しきい値は実際の服の写真でまだ検証していない(未対応)
- ~~CORS が `*`(全オリジン許可)なので、本番では許可するオリジンを絞ることを検討~~ → PR #18 で `CORS_ALLOWED_ORIGINS` により限定済み

## 一時停止 (2026-10-29)
ユーザーの指示で、Docker での通し確認の途中で作業を止めた。

### 止めた時点の状態
- Python イメージのビルドは約30分経過した時点で中断した(完了していない)。Go イメージはビルド済み。
  Python の依存インストールは Dockerfile の1つの `RUN` で行っているため、再開するとそのステップは最初からやり直しになる。
- `docker compose down` 済み。起動中のコンテナはない。
- worktree の変更はローカルの `feature/keep-supabase` に取り込み済み(fast-forward)。**GitHub へは未 push**。

### 再開手順(実施済み)
メインのフォルダ (`C:\Personal_production\Closetly`) で以下を行う。
1. Docker Desktop を起動する
2. `docker compose up --build -d go python`(Python のビルドに30分以上かかる見込み)
3. 動作確認
   ```
   curl -F image=@Go/sample.jpg http://localhost:8080/upload
   curl -i -X OPTIONS http://localhost:8080/upload -H "Origin: http://localhost" -H "Access-Control-Request-Method: POST"
   ```
   - 1つ目: `color` に色名が入った JSON が返ること
   - 2つ目: `204` と `Access-Control-Allow-Origin: *` が返ること
4. `docker compose down`
5. 結果をこのファイルと `color-autofill.md` に追記して commit
6. `git push origin feature/keep-supabase`
7. 後片付け: worktree を削除する (`git worktree remove .claude/worktrees/agent-a14bcde4850f99738`、ブランチ `worktree-agent-a14bcde4850f99738` も削除)

## 再開後の結果 (2026-10-29)
- `docker compose up --build -d go python` はビルド成功(前回途中までのキャッシュが効き、短時間で完了)。
- **問題**: Go コンテナが起動できなかった。
  `Bind for 0.0.0.0:8080 failed: port is already allocated`
  → 原因は別プロジェクトのコンテナ `sec_docker-php-apache-1` が 8080 番を使っていたこと。
  → 他のプロジェクトは止めず、ビルド済みの Go イメージを確認用にポート 18080 で起動して回避した:
  ```
  docker run -d --rm --name closetly-go-test --network closetly_default -p 18080:8080 -e PYTHON_API_URL=http://python:8000 closetly-go
  ```
  (`docker-compose.yml` の 8080 はそのまま。普段の開発で同じ衝突が起きたら、相手のコンテナを止めるか compose のポートを変える)
- 確認結果(Go → Python の通し、すべて期待どおり):
  | 確認 | 結果 |
  | --- | --- |
  | `Go/sample.jpg`(黒いTシャツ単体) | `"color":"黒"`, hex `#141414`, ratio 0.926 → 正しい |
  | `Go/sample2.jpg`(人物の全身コーデ: 薄緑のジャケット + 黒のインナー/パンツ) | `"color":"黒"`, ratio 0.484 |
  | OPTIONS プリフライト | `204` + `Access-Control-Allow-Origin: *` / Methods / Headers |
  | 画像なしで POST | `400` |
- **わかった制限**: 1枚に複数の服が写っている写真では、面積が一番大きい色が選ばれる(sample2 ではジャケットの緑ではなくパンツ等の黒)。
  服を1着ずつ撮って登録する使い方なら問題ないが、コーデ写真には向かない。色欄は手で直せるので致命的ではない。
- ブラウザでの画面操作は下記「アプリでの動作確認」で確認済み(スマホ実機は未確認)。

## アプリでの動作確認 (2026-10-29, Flutter Web + Chrome)
### 手順
- バックエンド: `docker compose up -d python` と、Go を 18080 番で起動(8080 は別プロジェクトが使用中のため)
- フロント: `flutter run -d web-server --web-port 5050 --dart-define=API_BASE_URL=http://localhost:18080`
- Chrome で `http://localhost:5050` を開き、テストユーザーでログイン → カメラ画面 → 「写真を追加」で `Go/sample.jpg` を選択

### 結果
| 確認 | 結果 |
| --- | --- |
| 写真を選ぶと色欄に自動入力される | 「黒」が入った |
| ブラウザ → Go の通信 (CORS) | ブラウザのコンソールに `色解析レスポンス: 200 {"color":"黒", ...}`。CORS エラーなし |
| 色欄を手で直せる | 「チャコール」に書き換えられた |
| 保存 | 本番の Supabase にデータが入るため実行していない |

- コンソールに出ていた `Unhandled error detected in the injected client.js` は Flutter の開発用デバッグスクリプト (dwds) のエラーで、アプリや今回の変更とは無関係。
- 解析中のインジケーターは処理が一瞬で終わったため目視できなかった(ログ上は開始→終了を確認)。

### 遭遇した問題: テストユーザーでログインできない
- 「テストユーザーでログイン」を押すとログイン失敗になった。
- 原因: **Supabase のプロジェクトが一時停止していた**。プロジェクトのドメイン
  `ensmryjkvsjkzoqotqlk.supabase.co` が DNS で「Non-existent domain」になっていた
  (`supabase.com` や `github.com` には接続できたので手元のネットワークの問題ではない)。
- ~~一時停止を防ぐ `supabase-keepalive.yml` が master に入っていない~~ → **これは誤りだった(訂正)**。
  ローカルの `master` が古いままだったこと、Git Bash で `git show origin/master:パス` がパス変換されて失敗していたことが原因で、
  「入っていない」と誤って判断した。`git ls-tree origin/master .github/workflows/` で確認すると master に入っている。
- GitHub API で keepalive の実行履歴を確認した結果:
  | 実行日時 (UTC) | 契機 | 結果 |
  | --- | --- | --- |
  | 2026-10-15 | 手動 | 成功 |
  | 2026-10-16 / 19 / 22 / 25 | 定期 | 成功 |
  | 2026-10-28 | 定期 | **失敗**(プロジェクトがすでに停止していたためと思われる) |
- gh をインストール・ログインして 10/28 の失敗ログを確認した結果、`curl` が **exit code 6(ホスト名を解決できない)** で失敗していた。
  つまり 10/28 の時点でプロジェクトはすでに停止しており、停止したのは 10/25(成功)〜10/28 の間。
- keepalive は3日おきに成功していたのに停止した理由は**未解明**。
  考えられる可能性: REST API へのアクセスだけでは Supabase の「利用あり」とみなされない / 無料プランの別の停止条件 / 手動停止。
  Supabase ダッシュボードで停止理由(通知メール含む)を確認する必要がある。
- 対処: ユーザーが Supabase のダッシュボードからプロジェクトを再開 → `/auth/v1/health` が 200 になったのを確認してからログインし直して成功。
- 外部サービス (本番 Supabase) へのログインとファイル選択ダイアログの操作は、Claude からは行わずユーザーに操作してもらった。

## 残っていること
- ~~master へのマージ~~ → PR #14 でマージ済み
- ~~本番用に GitHub の `vars.API_BASE_URL` を設定~~ → 設定済み
- スマホ実機での確認

## プルリクエスト作成 (2026-10-29)
- `gh` が入っていなかったため `winget install GitHub.cli` でインストール(v2.103.3)し、ユーザーが `gh auth login --web` でログイン。
- インストール直後は既存のシェルの PATH に `gh` が無いため、`C:\Program Files\GitHub CLI\gh.exe` のフルパスで実行した。
- PR #14 を作成。CI (`test-and-build`) は成功。`Supabase Preview` は skipping(連携設定が無いため)。

## Supabase が一時停止した原因 (2026-10-29 判明)
- 同じアカウントの別プロジェクト ShukatsuHub に届いた Supabase のメール(10/27 13:08 JST):
  「free-tier projects are automatically paused after 7 days of inactivity」として一時停止。
- ShukatsuHub の keepalive (DB に `SELECT 1`) は **10/26 12:35 JST に成功**しており、その翌日に「7日間アクセスなし」として停止された。
  Closetly も 10/25 に keepalive (REST API で SELECT) が成功した直後、10/28 までに停止している。
- **結論: keepalive の定期的な読み取りアクセスは、Supabase の「アクティビティ」として数えられていなかった。**
  ワークフロー自体の不具合ではなく、この方式では一時停止を防げない。
  (Supabase が何をアクティビティとみなすかは公開されていないため、どのアクセスなら数えられるかは不明)
- 対策の選択肢:
  1. Pro プランにする(確実に止まらない唯一の方法)
  2. 止まったらダッシュボードから手動で再開する(90日以内なら可能)← 当面はこれで様子を見る方針を提案
  3. keepalive を書き込み (insert/update) にする(効果は未検証)
- 補足: 同時期に ShukatsuHub には「RLS が無効なテーブルがある (rls_disabled_in_public)」というセキュリティ警告も届いていたが、
  これは一時停止とは無関係。Closetly は警告の対象外。

## 本番デプロイ (2026-10-29)
### 流れ
1. Proxmox に Python 用の CT を新しく立て、runner `closetly-python` (ラベル `python`) を登録(ユーザー作業)。3つの runner がすべて online であることを確認。
2. YOLO 削除のコミットを push → PR #14 の CI 成功 → PR #14 をマージ (`b2d1373`)。
3. master の CI: テスト・Go/Python/フロントのイメージ作成と Docker Hub への push がすべて成功。
4. CD: `deploy-go` / `deploy-python` / `deploy-frontend` すべて成功。

### 本番での確認 (`https://closetly-go.kkuro.com`)
| 確認 | 結果 |
| --- | --- |
| `/upload` に黒いTシャツの写真 | `{"color":"黒",...}`(HTTP 200, 1.4秒) |
| CORS プリフライト | `204` + `access-control-allow-origin: *`(マージ前は 404 だった) |
| マージ前に出ていた `{"error":"python error"}` | 解消。新しい CT の Python (`192.168.11.37:8000`) に Go から届いている |
| Python のバージョン | YOLO 削除版(レスポンスに `category` が無い) |

- 新しい CT (LXC) でも、`deploy-python` に `--security-opt apparmor=unconfined` を付けずに Python が起動できた。

### 遭遇した問題
1. **フロントが `localhost:8080` を呼ぶ版でビルドされた**
   - 原因: GitHub の `vars.API_BASE_URL` が未設定のままマージしたため、CI が初期値 `http://localhost:8080` でビルドした。
   - 対処: ユーザーが `gh variable set API_BASE_URL --body "https://closetly-go.kkuro.com"` を実行し、`gh run rerun` で master の CI を再実行。
     CI のログで `API_BASE_URL=https://closetly-go.kkuro.com` が渡されていることを確認。
   - Claude からの `gh variable set` はリポジトリ設定の変更として権限確認で拒否されたため、ユーザーに実行してもらった。
2. **再実行後の CD で `deploy-go` が失敗**
   - ジョブの `Deploy Go` ステップが `in_progress` のまま runner 情報が空になり、18秒で失敗扱いになった。ログも残っていない(runner との接続が途中で切れたと思われる)。
   - 再実行は同じコミット (`b2d1373`) のビルドで Go のイメージは1回目と同じ中身のため、本番の Go は1回目のデプロイの新しい版のまま動いている(CORS 有効を確認)。影響なし。
   - 同じことが続くようなら Go の runner のログ(`_diag` フォルダ)を確認する。
3. **デプロイ後もフロントが古いまま見える**
   - 原因: Cloudflare が `main.dart.js` をキャッシュしていた(`cf-cache-status: HIT`, `Cache-Control: max-age=14400` = 最大4時間)。
   - キャッシュを避けて (`?v=...` 付きで) 取得すると、新しい版 (`closetly-go.kkuro.com` を呼ぶ) が配信されていることを確認。
   - 対処: Cloudflare のダッシュボードでキャッシュを削除 (Caching → Configuration → Purge Everything) するか、最大4時間待つ。
   - 今後の改善案 → 下記「キャッシュの設定」で対応。

### 本番での最終確認 (2026-10-29)
- ユーザーが Cloudflare のダッシュボードで「すべてをパージ」を実行。
- `https://closetly.kkuro.com` を開き、写真を選ぶと色欄に色が自動で入ることをユーザーが確認。**本番で色の自動入力が動作。**

## キャッシュの設定 (2026-10-29)
### 目的
デプロイのたびに Cloudflare のキャッシュを手で削除しなくても、新しいアプリがすぐ届くようにする。

### 調べたこと(本番のレスポンスヘッダー)
| ファイル | Cache-Control | cf-cache-status |
| --- | --- | --- |
| `/`(index.html) | なし | `DYNAMIC`(HTML は Cloudflare がもともとキャッシュしない) |
| `main.dart.js` / `flutter_service_worker.js` | `max-age=14400`(4時間) | `HIT` / `MISS` |

- nginx は既定の設定で Cache-Control を付けておらず、Cloudflare が `.js` を最大4時間キャッシュしていた。
- 古い `main.dart.js` が残ると、`index.html` が新しくても古いアプリが動いてしまう。

### 変更
- `frontend/nginx.conf` を新規作成し、`frontend/Dockerfile` で `/etc/nginx/conf.d/default.conf` にコピーする。
  - アプリの入り口になるファイル(`/`, `index.html`, `main.dart.js`, `flutter.js`, `flutter_bootstrap.js`,
    `flutter_service_worker.js`, `version.json`, `manifest.json`)に `Cache-Control: no-cache, no-store, must-revalidate` を付ける。
    Cloudflare はオリジンの `no-cache` / `no-store` に従うので、エッジに古いファイルを残さなくなる。
  - 画像・フォント・`assets/` などはこれまでどおりキャッシュさせる(変更が少なく、毎回取り直すと遅くなるため)。
  - 存在しないパスは `index.html` を返す (SPA のフォールバック)。

### 確認
- `nginx:alpine` にダミーファイルと `nginx.conf` をマウントして確認:
  - `nginx -t` 成功
  - 入り口のファイルと `/` には `Cache-Control: no-cache, no-store, must-revalidate` が付く
  - `favicon.png` / `assets/a.txt` には付かない
  - `/some/route` などの存在しないパスは `index.html`(no-cache 付き)を返す
- フロントのイメージ全体のビルド (Flutter) はローカルでは行わず、CI のビルドに任せた(時間がかかるため)。
- 本番への反映後に、`main.dart.js` のヘッダーが `no-cache` になり `cf-cache-status` が `HIT` にならないことを確認する。

### 気をつける点
- Cloudflare 側で「Cache Everything」のようなページルールや、エッジのキャッシュ時間を固定する設定を入れると、
  オリジンの指定より Cloudflare の設定が優先されることがある。その場合はそちらも見直す。
- 今回の nginx.conf を入れる前に Cloudflare にキャッシュされたファイルは、反映直後にもう一度だけパージが必要になる可能性がある
  (現在はパージ済みなので、次のデプロイから効く想定)。

### 作業中に起きた問題
1. **別のブランチにコミットしてしまった**
   - 作業の途中で、メインのフォルダが別の作業により `feature/cd-image-prune` ブランチ(master から作成、`cd.yml` と `Go/Dockerfile` を編集中)に切り替わっていた。
   - それに気づかず、キャッシュ設定のコミットを `feature/cd-image-prune` に作ってしまった(push はしていない)。
   - 対処: `git reset --keep HEAD~1` で自分のコミットだけを取り消した(`--keep` はコミットに含まれないローカルの変更を残す。
     編集中の `cd.yml` / `Go/Dockerfile` には触れていない)。そのうえで、編集中の作業を邪魔しないよう別の worktree で
     `feature/keep-supabase` をチェックアウトし、同じ変更を入れ直してコミット・push した。
   - 教訓: コミットや push の前に `git status -sb` で今いるブランチを確認する。
2. **docs の追記に失敗した**: Windows の Python から Git Bash の `/tmp` のパスが見えず、ファイルを読めなかった。
   scratchpad のフォルダ(Windows のパス)を使ってやり直した。

### 本番への反映結果 (2026-10-29, PR #15 マージ後)
- PR #15 をマージ (`29f867c`)。master の CI 成功、CD (`deploy-go` / `deploy-python` / `deploy-frontend`) すべて成功。
- 途中で GitHub API への接続が `TLS handshake timeout` になったが、少し待って再試行したら取得できた(一時的なネットワークの問題)。
- 補足: CD は `workflow_run` で Closetly-CI の完了をきっかけに動くため、**PR の CI が終わったときにも CD が動いている**
  (master のイメージを取り直して入れ替えるだけなので害はないが、PR を出すたびに本番のコンテナが再起動する)。
  必要なら `cd.yml` の `if:` に `github.event.workflow_run.event == 'push'` を加えて、master への push のときだけ動かすようにできる。

#### ヘッダーの確認
| ファイル | 反映直後 | キャッシュを避けて取得 | もう一度パージした後 |
| --- | --- | --- | --- |
| `/` | no-cache / `DYNAMIC` | - | no-cache / `DYNAMIC` |
| `main.dart.js` | `max-age=14400` / `HIT`(古いコピー) | no-cache / `BYPASS` | **no-cache / `BYPASS`** |
| `flutter_service_worker.js` | `max-age=14400` / `HIT`(古いコピー) | no-cache / `BYPASS` | **no-cache / `BYPASS`** |
| `flutter_bootstrap.js` | `max-age=14400` / `HIT`(古いコピー) | no-cache / `BYPASS` | `max-age=14400` / `HIT`(下記) |
| `favicon.png` | `max-age=14400` / `HIT` | `max-age=14400` / `MISS` | `max-age=14400` / `HIT`(想定どおり) |

- 反映直後は、前回パージした後に古い設定のまま Cloudflare に保存されたコピーが残っていたため、ユーザーがもう一度「すべてをパージ」した。
- 2回目のパージ後、`main.dart.js` と `flutter_service_worker.js` は `BYPASS`(Cloudflare が保存せずオリジンから返す)になった。
  → **次のデプロイからはパージ不要。**
- `flutter_bootstrap.js` だけは2回目のパージ後も古いコピーが残っていた(`Age: 2129` = デプロイ前の 06:19 UTC ごろに保存されたもの)。
  パージで消えなかった理由は不明(Cloudflare 側の反映の遅れなどが考えられる)。
  - オリジンは正しく no-cache を返しているので、このコピーが期限切れ(保存から4時間、10:19 UTC = 19:19 JST ごろ)になれば以後は保存されない。
  - このファイルは `main.dart.js` を読み込む役目で、`main.dart.js` は毎回新しいものが届くため、アプリの動作への影響は小さい。
  - すぐ消したい場合は Cloudflare の「カスタムパージ」で `https://closetly.kkuro.com/flutter_bootstrap.js` を指定する。
- 未対応の改善案: `no-store` を外して `no-cache` だけにすると、ブラウザが「変更なし (304)」の確認だけで済み、
  毎回 `main.dart.js`(約 2.3MB、圧縮転送で約 0.8MB)を丸ごとダウンロードしなくて済む(Cloudflare は `no-cache` でも保存しないので効果は同じ)。

### 補足: 再実行時の `deploy-go` の失敗について (2026-10-29 追記)
- PR #16 (`feature/cd-image-prune`) で CLAUDE.md に「pull のたびに古いイメージが残り、Go のホストの 20GB のディスクがいっぱいになって runner がオフラインになった」と記録された。
- 上の「再実行後の CD で `deploy-go` が失敗」(ジョブの途中で runner 情報が空になり、ログも残らなかった)は、このディスク不足で Go の runner が落ちたのが原因だった可能性が高い。
- PR #16 で各デプロイの最後に `docker image prune -f` が入ったので、同じ失敗は起きにくくなっている。

## Go の CT のディスク逼迫と CD の改善 (2026-10-29, PR #16)
### 見つかったこと
- GitHub の Runners 一覧で Go の runner が **Offline** になっていた。
  - `svc.sh status` ではサービスは2か月以上 `active (running)` のままだったが、`CGroup` に `Runner.Listener`(実際に GitHub とつながるプロセス)がおらず、外側の `RunnerService.js` だけが動いていた。
- `df -h /` で Go の CT (`vm-102`, 20GB) のディスクが **100%(空き 0)** になっていた。これが runner が落ちた原因と考えられる。
  - `docker system df`: イメージ 21個 / 16.03GB のうち 11.61GB が削除可能。
  - `docker images` には3つしか出なかった。新しい Docker の表示ではタグの無い古いイメージ(`<none>`)が隠れるため。
  - 原因: CD は `docker pull` して入れ替えるだけで古いイメージを消しておらず、1.83GB の Go のイメージがデプロイのたびに残っていた。
  - 使われていない `containrrr/watchtower` のイメージも残っていた(昔試したものの名残。コンテナはすでに無かった)。

### 対処(CT 上、ユーザー作業)
- `docker image prune -a -f` と `docker container prune -f` → ディスク使用量 **19GB (100%) → 5.1GB (27%)**、イメージは2個 / 1.83GB に。
- `svc.sh stop` → `svc.sh start` で runner が復活し、Idle に戻った(入れ直しは不要だった)。
- 入れ直す場合の手順(GitHub で古い runner を Remove → `config.sh ... --labels go` → `svc.sh install`)も用意したが、使わずに済んだ。

### 再発防止 (PR #16)
- `cd.yml`: Go / Python / フロントの各デプロイの最後に `docker image prune -f` を追加(タグの無い古いイメージだけを消す。`-a` は付けない)。
- `Go/Dockerfile` をマルチステージビルドに変更:
  - ビルドは `golang:1.25`(`CGO_ENABLED=0` で静的リンク)、実行は `gcr.io/distroless/static-debian12`。
  - `main` と、`GET /test`(`Go/test.go`)が実行時に読む `sample2.jpg` だけをコピーする。
  - イメージは **1.83GB → 40.8MB**。
- 確認: `go test ./...` 成功。ローカルでマルチステージ版の Go と YOLO なしの Python をつなぎ、`POST /upload` で `{"color":"黒",...}` が返ること、`OPTIONS /upload` が 204 を返すことを確認。
- マージ後の CD のログで、Go の古いイメージ(`a9e9b83e…`)が prune で消えたこと(553.8MB 回収)、フロントの CT でも古いイメージがまとめて消えたことを確認。

### 補足: Python の CT のサイズ
- YOLO を外した Python のイメージは約 0.35GB の見込み(YOLO 込みはローカルで 10.5GB だった)。
- CT はディスク 10GB / 2コア / メモリ 1GB(スワップ 512MB)を目安にした。CI のビルドは GitHub 側 (`ubuntu-latest`) で行うので、CT は runner の常駐と pull・起動だけで済む。
- prune がなければ Python も同じようにたまる(1回 0.35GB なので Go より遅いだけ)。

## CORS の許可オリジンを絞る / CD を master への push だけにする (2026-10-29, PR #18)
### 変更
- `Go/main.go`: `Access-Control-Allow-Origin: *` をやめ、環境変数 `CORS_ALLOWED_ORIGINS`(カンマ区切り)にあるオリジンだけをそのまま返す(`Vary: Origin` 付き)。
  - 許可外のオリジンのプリフライトは 403。
  - 未設定のときはローカル開発用に `localhost` / `127.0.0.1`(ポートは問わない)だけを許可(`flutter run` はポートが毎回変わるため)。
  - `Origin` ヘッダーの無いリクエスト(ネイティブアプリ・curl)はそのまま通る。CORS はブラウザ向けの制限で、API の認証の代わりにはならない。
- `cd.yml`:
  - Go のコンテナに `-e CORS_ALLOWED_ORIGINS=https://closetly.kkuro.com` を渡す。
  - 3つのジョブの `if:` に `workflow_run.event == 'push'` と `workflow_run.head_branch == 'master'` を追加。
    上の「本番への反映結果」の補足にある「PR の CI でも CD が動き、本番のコンテナが再起動する」問題への対応。
    `workflow_run` は常に master 側の `cd.yml` を使うので、この条件はマージ後から効く(PR #18 自身の CI ではまだ古い条件で CD が動いた)。
- `Go/upload_test.go`: 期待値を `*` から実際のオリジンに変更し、「リスト外は 403」「リストを設定したら localhost も拒否」「複数オリジン」のテストを追加。

### 確認
- `go vet` / `go test ./...` 成功。
- ローカルでイメージを `CORS_ALLOWED_ORIGINS=https://closetly.kkuro.com` で起動し、プリフライトを確認(本番オリジン → 204、`https://evil.example.com` → 403、`http://localhost:5050` → 403)。
- マージ後、本番 (`https://closetly-go.kkuro.com/upload`) でも同じ結果になり、本番オリジンからの POST で `{"color":"黒",...}` が返ることを確認。
- `https://closetly.kkuro.com` で写真を選ぶと色が自動で入ることをユーザーが確認。

### 気をつける点
- 本番のフロントを別のドメイン(`www.` 付きなど)からも開くようにする場合は、`cd.yml` の `CORS_ALLOWED_ORIGINS` に追加しないと、そのドメインでは色の自動入力が動かない。

## PR #16 / #18 の作業中に起きた問題 (2026-10-29)
1. **Bash から `gh` が見つからない**: `gh` が Git Bash の PATH に入っていなかったため、PowerShell から `C:\Program Files\GitHub CLI\gh.exe` のフルパスで実行した。
2. **PR #18 のマージが権限確認で拒否された**(「レビューなしのマージ」と判定。PR #16 では通った)。ユーザーにマージしてもらった。
   - その際、`!` で入力するコマンドを PowerShell の書き方(`& "C:\...\gh.exe" ...`)で案内してしまい、Bash で構文エラーになった。
     `!` は Bash で実行されるので、`"/c/Program Files/GitHub CLI/gh.exe" pr merge 18 --merge` が正しい。
3. **`gh pr checks --watch` が `TLS handshake timeout` で失敗**: 一時的なもので、再実行で成功。
4. **CI 待ちの間に別の PR (#19〜#21) が同時にマージされ、CI が2本並行して走った**: 両方の CI と、その後の CD がすべて成功したことを確認した。
   07:15 の CD が1回 `skipped` になっていたのは、新しい `if:` で PR の CI 由来の実行が止まったものと考えられる(起動元の CI までは特定していない)。
5. **作業ツリーに別の作業の未コミットの変更があった**(`CLAUDE.md` の RLS update ポリシーの記述、`supabase/clothes_table.sql`)。
   master に切り替えられなかったため、`git stash` で退避 → master を pull → `git stash pop` で元に戻した。これらのファイルはコミットに含めていない。

## 3つの機能を並行で実装 (2026-10-29)
ユーザーの依頼: 「服の編集」「クローゼットの絞り込み・並び替え」「ホーム画面の作り込み」を、ブランチと Claude を分けて Sonnet に実装させ、
終わったものからテスト → push → マージする。

### 進め方
1. **先に共通化 (PR #19)**: 3つとも「カテゴリ・季節の選択肢」を使うが、`camera_page.dart` の中にしかなかった。
   各自が別々に切り出すとマージ時に衝突するため、先に `frontend/lib/constants/clothing_options.dart` に切り出して master に入れた。
2. Sonnet 3人を、それぞれ別の worktree・別のブランチで並行して作業させた。担当以外のファイル(特に他の人のページ)を触らないこと、
   `CLAUDE.md` と `progress.md` は触らず docs は機能ごとの新しいファイルに書くことを指示して、衝突を避けた。
3. 終わった順に、Opus がコードを確認 → 最新の master に rebase → `flutter analyze` / `flutter test` → push → PR → CI 成功を確認 → マージ。

| 機能 | ブランチ | PR | docs | テスト(マージ時点) |
| --- | --- | --- | --- | --- |
| クローゼットの絞り込み・並び替え | `feature/closet-filter` | #20 | `docs/closet-filter.md` | 19件成功 |
| ホーム画面 | `feature/home-dashboard` | #21 | `docs/home-dashboard.md` | 38件成功 |
| 服の編集 | `feature/clothing-edit` | #22 | `docs/clothing-edit.md` | 41件成功 |

- どのブランチも `flutter analyze` は既存の `lib/main.dart` の2件のみで、新しい指摘なし。
- 3つとも別ファイルを担当させたので、rebase で衝突は起きなかった。
- 最後の PR #22 のマージ後、master の CI と CD (go / python / frontend) はすべて成功。

### Supabase の update ポリシー
- 編集機能には `clothes` テーブルの update の RLS ポリシーが必要だった(select / insert / delete しかなかった)。
- ユーザーの依頼で、手順を案内する専用の Claude Code を新しいターミナルタブで起動した
  (案内用の指示書をファイルに書き、`wt new-tab ... claude "<指示書を読んで案内して>"` で起動)。案内役は SQL を実行せず、ユーザーが SQL Editor で実行した。
- ポリシー名と定義は、案内役と実装役の Sonnet で同じになるように揃えた(実装中の Sonnet にメッセージで指定)。
- RLS で更新が拒否されても Supabase はエラーを返さず 0 件更新になるため、`updateClothing` は `.select()` で結果を受け取り、0 件ならエラーにしている。

### レビューで確認したこと
- 編集機能の詳細画面は `PopScope(canPop: false)` で戻る操作を受け、編集していれば `true` を返す。
  削除時の `Navigator.pop(context, true)` は `PopScope` に止められない(`didPop == true` で呼ばれるので二重に戻らない)ことを確認した。
- 絞り込みは、条件を変えても画像 URL の再署名・再取得が起きないよう、読み込み済みの一覧を画面側で絞り込む方式にした。

### 作業中に起きた問題
- Sonnet たちから「長いコマンドやヒアドキュメントがサンドボックスで拒否された」との報告があり、ファイル作成や分割したコマンドで対応していた。
- テストの import はパッケージ名が `frontend`(`package:frontend/...`)である点に注意が必要だった。
- `flutter pub get` / `flutter test` が `frontend/linux|macos|windows` の自動生成ファイルを書き換えるため、毎回元に戻してからコミットした。

### 未確認
- 3つとも、ブラウザ・実機での画面確認と、本番の Supabase での編集(更新)の動作は未確認。

## docs を最新の状態に合わせる (2026-10-30)
- master を pull (`a94ef10` → `609319d`、PR #22 / #23)。
- **問題**: 手元に未コミットの `CLAUDE.md` / `supabase/clothes_table.sql` の変更があり、pull が「上書きされる」として止まった。
  中身を比べると PR #23 で入った内容の古い版(SQL はポリシーの並び順の違いだけ)だったため、`git stash` で退避してから pull した。
  stash は消さずに残してある(不要なら `git stash drop`)。
- 古くなっていた記述を直した:
  - `progress.md` の先頭に「現在の状態」(本番に出ている機能・残っていること)を追加し、当時の「残っていること」「本番に出す前に必要なこと」に対応済みの印を付けた。
  - `color-autofill.md` の「未解決事項」のうち、`API_BASE_URL` 未設定・mixed-content・CORS `*` を対応済みにした。
  - 過去の記録は消さず、取り消し線と「→ 対応済み」で残した(なぜそうなったかを後から追えるようにするため)。
- 本番の CORS を確認: 許可オリジン `https://closetly.kkuro.com` は `204`、関係ないオリジンは `403`。
- (2026-11-04 追記) この節と先頭の「現在の状態」・`color-autofill.md` の修正は、コミットされないまま手元に残っていた。

## 着用記録・コーディネート・AIコーデ提案 (2026-11-03)
ユーザーの依頼: 「着用記録(最近着ていない服)」と「コーディネート(Gemini API で提案)」を追加したい。
Opus を司令塔にして、Sonnet を機能ごとに分けて worktree で開発する。Supabase の設定は、ユーザーと会話する案内役の CLI を別に立てて並行して進める。
マージはせず PR 作成まで(マージはユーザーが判断)。

### 先に決めたこと(ユーザーに確認)
- コーデ: 手動で作れる + 「AIに提案してもらう」ボタン(AI が使えなくても手動で作れる)。
- Gemini に送るのはタグ(カテゴリ・色・季節)だけで、画像は送らない(速くて安く、写真を外に出さない。無料枠では送った内容が Google のサービス改善に使われる場合がある)。
- Gemini は Go サーバーから呼ぶ。Flutter Web にキーを入れるとブラウザから誰でも見えるため。
- 着用記録は服単位 + コーデ単位(コーデの「今日着た」で全部の服に記録)。

### 進め方
1. **Opus が土台を先に作ってコミット (`76522fb`)**: SQL(`supabase/migrations/add_wear_logs_and_outfits.sql`)、Go の `POST /suggest-outfit`(+ テスト7件)、
   モデル(`wear_log.dart` / `outfit.dart`)、サービス(`wear_log_service.dart` / `outfit_service.dart`)、共通部品 `clothing_thumbnail.dart`、
   AI 提案画面の仮ファイル、CD / docker-compose の環境変数。
   3人が同じファイルを触ると衝突するので、共通部分と「画面の入口の約束」(`OutfitSuggestPage()` を引数なしで開き、保存したら true で戻る)を先に決めた。
2. Sonnet 3人を別々の worktree・ブランチで並行実行。担当ファイル以外・`CLAUDE.md`・`progress.md` は触らない指示。
3. 終わった順に Opus がコードを確認して `feature/wear-log-outfits` にマージ。衝突はなかった。

| 機能 | ブランチ | docs |
| --- | --- | --- |
| 着用記録(詳細画面・ホーム) | `feature/wear-log-ui` | `docs/wear-log.md` |
| コーデの手動作成(タブ・一覧・作成・詳細) | `feature/outfits-ui` | `docs/outfits.md` |
| AIコーデ提案画面 | `feature/outfit-ai-suggest` | `docs/outfit-ai-suggest.md` |

- まとめた後: `flutter analyze` は既存の `lib/main.dart` の2件のみ、`flutter test` 72件成功、`go test ./...` 成功。
- PR は1本にした。コーデの「今日着た」は着用記録を、AI 提案はコーデ保存を使うので、別々にマージすると順番によって動かないため。

### Go の `/suggest-outfit` で考えたこと
- **今まで Go API にはログイン確認が無かった**。そのまま Gemini を呼ぶ窓口を作ると、URL を知っている人なら誰でも無料枠を使い切れてしまう。
  → Supabase のアクセストークンを必須にし、Supabase の `/auth/v1/user` に問い合わせて確認する。
  JWT を Go 側で検証しない理由: プロジェクトの署名鍵の種類(共有鍵 / 非対称鍵)に左右されず、鍵を Go に持たせる必要もないため。
- 服の一覧はクライアントから受け取らず、同じトークンで Supabase から取る(RLS で本人の分だけ返る)。Gemini の返事に本人の服に無い id が混ざっても取り除ける。
- Gemini の API: ドキュメント(`ai.google.dev` は `aistudio.google.com` に移転していた)では新しい Interactions API が中心だったが、
  API リファレンスで `generateContent` が廃止されていないことを確認して使った。`responseMimeType: application/json` + `responseJsonSchema` で JSON の形を指定。
- モデル: `gemini-2.5-flash` は廃止予定(2026-12-01 から別モデルへ転送)と書かれていたので、安定版の `gemini-3.6-flash` を既定にし、`GEMINI_MODEL` で変えられるようにした。
- API キーは URL のクエリでなく `x-goog-api-key` ヘッダーで渡す(URL がログに残っても漏れない)。
- 利用者が入力する「場面」は、プロンプト内で「場面の説明としてのみ扱う」と明示し、200字までに制限。

### 作業中に起きた問題
- Sonnet の worktree は土台のコミットより前の master から作られていたため、各自 `git merge feature/wear-log-outfits` で土台を取り込んでから作業した(指示書に手順として書いておいた)。
- 前回と同じく、長い複合コマンドが拒否される、`flutter pub get` が `pubspec.lock` や各プラットフォームの生成ファイルを書き換える(コミット前に戻した)、テストの import は `package:frontend/` という問題があった。
- `gofmt -l` で既存の `main.go` などが未整形と出たが、今回の作業と関係ないので触っていない。

### 未確認
- 実際の Gemini を呼んだ動作(提案の質、60秒のタイムアウトに収まるか)。
- ブラウザ・実機での画面確認、Supabase に SQL を適用した実 DB での保存・削除・着用記録。
- 画面のウィジェットテストは無い(Supabase に直接依存するため)。純粋関数とサービス(MockClient)のテストのみ。

### Supabase と Gemini API キーの設定 (2026-11-03)
前回の update ポリシーと同じく、案内役の Claude Code を別タブで起動し(指示書を書いて `wt new-tab ... claude "<指示書を読んで案内して>"`)、開発と並行してユーザーと会話しながら進めた。
案内役は SQL を実行せず、リポジトリも変更しない取り決めにして、進み具合は一時ファイルに書かせ、司令塔(Opus)がそれを読んで docs に反映した。

- **SQL**: ユーザーが SQL Editor で `add_wear_logs_and_outfits.sql` を実行(エラーなし)。
  `pg_constraint` で、`wear_logs` の `unique (clothing_id, worn_on)` と外部キー6件がすべて `on delete cascade` であることを確認した。
  RLS ポリシーは 9件(ユーザーが行数を報告。表の中身までは見ていない)。
- **Gemini API キー**: Google AI Studio で発行。キー作成時に既存の(インポートした)Google Cloud プロジェクトを選ぶ欄があったが、
  課金が設定されたプロジェクトだと有料になるおそれがあるため、新しいプロジェクトで作った。キーは会話に貼らないようにした。
- **キーが `AIza` で始まらなかった**: 形式が変わった可能性があり、誤コピー(プロジェクト ID など)でないことを確かめるため、
  ユーザーが PowerShell から `GET https://generativelanguage.googleapis.com/v1beta/models`(ヘッダー `x-goog-api-key`)を呼び、200 が返ることを確認した。
- **GitHub Secrets**: `GEMINI_API_KEY` を登録し、`gh secret list` で確認。`SUPABASE_URL` / `SUPABASE_ANON_KEY` は cd.yml に直書き(公開値)なので Secret は不要
  (同名の既存 Secret は keepalive ワークフロー用)。
- **`gh` が入っていなかった**: PR 作成時に `gh` が無かったため、`winget install GitHub.cli` で入れ、ユーザーが `gh auth login --web` でログインした。
  インストール直後の既存ターミナルでは PATH が反映されないため、フルパス(`C:\Program Files\GitHub CLI\gh.exe`)で実行した。
- ローカル用の `.env` は作っていない(スキップ)。ローカルで AI 提案を試すには `.env` に `GEMINI_API_KEY` が必要。

## master を pull (2026-11-04)
- `609319d` → `6dcb692`(PR #24 / #25: 着用記録・コーデ・AI 提案、ディスク・CORS の経緯)。
- **問題**: 前回(2026-10-30)の docs の修正(`progress.md` / `color-autofill.md`)が未コミットのまま残っており、pull が止まった。
  origin には入っていない内容だったので `git stash` → pull → `git stash pop` で戻した。
- `progress.md` の末尾で衝突した(双方が末尾に節を追加していた)。両方残し、日付順(10-30 の節 → 11-03 の節)に並べて解消した。
- 先頭の「現在の状態」は 2026-10-30 時点のままで、PR #24 / #25 はまだ反映していない。

## テスト画像で色判定の検証と、testuser への登録 (2026-11-04)
ユーザーの依頼: 画像をたくさん入れてどんな色が認識されるか見たい、いろいろな種類の服でコーデを試したい。
- 画像は既に `origin/testdata/clothes-images` ブランチ(34枚 + `manifest.csv` + クレジットの README)にあったので、それを使った(master にはマージしていない)。
- **色判定**: `color_analyzer.py` を直接34枚にかけ、正解と比べた。一致19 / 近い7 / 外れ8。詳細と傾向は `color-autofill.md` の「テスト画像34枚での色判定の検証」。
  結果は写真付きのページ(claude.ai の非公開 Artifact)にまとめた。
- **コーデ用の登録**: ログイン画面の「テストユーザーでログイン」のアカウント(`test@gmail.com`)に、34枚を Storage(`{uid}/original/testdata-NN.jpg`)と
  `clothes` に登録した。カテゴリ・季節は manifest のもの、色は今回の自動判定の結果(正解ではない)。Supabase の REST API を Python から直接呼ぶ一時スクリプトで登録した。
  - 登録前に既存の件数を確認する「確認だけ」の実行を先にした(既存4件)。登録後は38件、署名付き URL で画像が取れることを確認。
  - 後で消すときは `image_path` が `testdata-` で始まるものを、Storage と `clothes` の両方から消す(DB の制約でつながっていないため)。
- **問題**:
  - ユーザーの回答が「いつものアカウント」と「testuser で試したい」の2つで少し食い違っていた。testuser を普段使っていると解釈して testuser に入れた。
  - Windows で Python の標準出力が cp932 になり日本語が文字化けした。`python -X utf8` で UTF-8 にして解決。
- **未確認**: 実際のアプリ画面でのクローゼット表示・コーデ作成・AI コーデ提案(Gemini)は、まだ試していない(ユーザーが試す)。

## AI コーデ提案の「Failed to fetch」 (2026-11-04)
- 本番で AI 提案が「Failed to fetch」になる件を調べた。Go が Gemini の失敗で返す 502 を Cloudflare が自前のエラーページに差し替え、CORS ヘッダーが消えていた。
  詳細は `outfit-ai-suggest.md` の「本番で「Failed to fetch」になる問題」。
- Go を 500 / 429 で返すように直し、Flutter に 429 のメッセージを追加した(未コミット・未デプロイ)。
- 調べ方: claude-in-chrome で本番サイトを開き、ページ上から testuser のトークンで `fetch` を繰り返して再現 → curl で失敗した回のヘッダーを確認。
  ブラウザのネットワーク一覧ツールでは失敗したリクエストの中身が見えず、ページの JS を長く待たせるとタイムアウトしたので、結果を `window` に貯めて後で読む形にした。
