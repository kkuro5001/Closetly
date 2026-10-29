# Closetly

Closetlyは、自分の服を写真で管理できるクローゼットアプリです。

スマートフォンで服を撮影し、カテゴリ・色・季節を登録して管理できます。

# 機能

## カメラ機能

- カメラで服を撮影
- 撮影した画像を表示
- Go API経由でPython APIへ画像送信
- OpenCVで服の色を解析し、色欄に自動入力

## 服の登録

- カテゴリ登録
- 色登録
- 季節登録

## クローゼット機能

- 登録した服を一覧表示
- 画像付きで確認可能
- 2列グリッド表示

## ログイン
- supabaseを利用している
- authgateによるセッション


# システム構成

```
Flutter
   ↓
Go(Gin)
   ↓
Python(FastAPI)
   ↓
OpenCV（色解析）
```

### Frontend

- Flutter
- Dart

### Backend

- Go
- Gin

### 画像解析

- Python
- FastAPI
- OpenCV

### Database

- SQLite

---

# ディレクトリ構成

```
Closetly
├── frontend(Flutter)
│   ├── pages
│   ├── models
│   ├── database
│   └── services
│
├── go
│   ├── main.go
│   └── upload.go
│
│
├── python
│   └── main.py
│
└── docker-compose.yml
```

---

# 開発環境

- Flutter
- Dart
- Go
- Gin
- Python
- FastAPI
- Docker
- SQLite

---

# CI/CD

GitHub Actions と Self-hosted Runner を使用して自動デプロイを行っています。

# 今後の実装予定

- 服カテゴリの自動判定
- 服検索機能
- フィルタ機能
- コーデ提案機能
- Cloudflare Tunnel対応
- 自宅サーバー公開
- ユーザー管理機能
- バックアップ機能

---

# 起動方法

## Docker

```bash
docker compose up --build
```

## Flutter

```bash
flutter pub get
flutter run
```
