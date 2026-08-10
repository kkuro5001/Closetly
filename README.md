# Closetly

Closetlyは、自分の服を写真で管理できるクローゼットアプリです。

スマートフォンで服を撮影し、カテゴリ・色・季節を登録して管理できます。

# 機能

## カメラ機能

- カメラで服を撮影
- 撮影した画像を表示
- Go APIへ画像送信
- Python APIで画像解析（YOLO導入予定）

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
YOLO
```

### Frontend

- Flutter
- Dart

### Backend

- Go
- Gin

### AI

- Python
- FastAPI
- YOLOv8

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

- YOLOによる服カテゴリ自動判定
- 色の自動判定
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
