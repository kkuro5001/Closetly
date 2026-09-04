# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Closetly is a wardrobe-management app: photograph a piece of clothing, have it auto-classified, and browse it later in a closet grid. See [README.md](README.md) for the feature list.

Pipeline: `Flutter (frontend) → Go/Gin (Go) → Python/FastAPI + YOLOv8 (Python)`, with both the images (Supabase Storage) and the clothing metadata (Supabase Postgres) living in Supabase — there is no local database.

## Commands

### Run everything (Docker)
```bash
docker compose up --build   # or: make up
make down                   # docker compose down
make Logs                   # docker compose logs -f
```
Ports: Go `8080`, Python `8000`, frontend `80`.

### Go (`Go/`)
```bash
go test ./...        # run tests (this is what CI runs)
go run .             # run the API locally
```

### Python (`Python/`)
```bash
python -m compileall .        # what CI runs (syntax check only, no test suite)
python main.py                 # run the FastAPI server locally (uvicorn, port 8000)
```

### Frontend (`frontend/`)
```bash
flutter pub get
flutter run                    # launch on a connected device/emulator
flutter analyze                # static analysis
flutter test                   # run widget/unit tests
```
Camera capture requires a real device or an Android/iOS emulator — desktop (Windows) needs the Visual Studio toolchain installed, and the image add/upload flow needs `dart:typed_data`-based (byte) APIs rather than `dart:io File`/`Image.file`, since those are unsupported on Flutter Web.

## Architecture

### Image flow
1. `frontend/lib/pages/camera_page.dart` captures a photo (camera) or picks one (gallery) via `image_picker`, reading it as bytes (`Uint8List`) so the same code path works on web and mobile.
2. The bytes are uploaded to Supabase Storage via `frontend/lib/services/storage_service.dart` (`uploadOriginal`/`uploadProcessed`, using `uploadBinary` — not `upload`, which takes a `dart:io File` and breaks on web). The returned storage *path* (not a URL) is what gets persisted.
3. The same bytes are also POSTed to the Go backend (`frontend/lib/services/upload_service.dart` → `Go/upload.go`'s `UploadHandler`) which streams them on to the Python service's `/predict` endpoint (`Python/main.py`) for YOLO-based category detection, and returns the JSON result back through Go to Flutter.
4. `camera_page.dart` merges the AI result (category/color/suggestion) with user-edited fields and calls `frontend/lib/services/clothing_service.dart`'s `insertClothing`, which inserts a row (image path + category/color/season) into the Supabase `clothes` table — `user_id` is filled in server-side via the column default (`auth.uid()`), so the client never sends it.
5. `frontend/lib/pages/closet_page.dart` loads rows via `clothingService.getAllClothing()` and resolves each row's stored path to a fresh signed URL via `storageService.getSignedUrl` at display time (the bucket is private, so URLs are not persisted — they're re-signed on every read).

### Auth
`frontend/lib/auth/auth_gate.dart` gates the app on `Supabase.instance.client.auth.currentSession`, routing to `LoginPage` or `MainPage`. Supabase project URL/anon key live in `frontend/lib/config/supabase_config.dart`.

### Supabase (Storage)
Bucket: `closety-image` (private). Objects are namespaced as `{userId}/original/{fileName}` and `{userId}/processed/{fileName}` — the RLS policies below rely on the first path segment being the uploader's `auth.uid()`.

```sql
-- 画像取得 (read own images)
create policy "画像取得"
on storage.objects
for select
to authenticated
using (
  (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- 画像追加 (upload own images)
create policy "画像追加"
on storage.objects
for insert
to authenticated
with check (
  (storage.foldername(name))[1] = (select auth.uid()::text)
);
```

### Supabase (Postgres — clothing metadata)
Table: `public.clothes` (schema/policies in `supabase/clothes_table.sql`) — `id`, `user_id` (defaults to `auth.uid()`), `image_path`, `category`, `color`, `season`, `created_at`. RLS restricts select/insert to rows where `user_id = auth.uid()`. `frontend/lib/services/clothing_service.dart` is the only code that touches this table; `frontend/lib/models/clothing.dart` maps rows to/from `Clothing` (note the Postgres columns are snake_case, e.g. `image_path`, while the Dart field is `imagePath`).

### Go service (`Go/`)
Single handler in `upload.go`: `POST /upload` reads the multipart `image` field, forwards the raw bytes to `${PYTHON_API_URL}/predict`, and relays the JSON response back verbatim. `PYTHON_API_URL` is required (set via env var, e.g. in `docker-compose.yml`/the CD deploy step) — the handler errors out if it's unset.

### CI/CD
- `.github/workflows/ci.yml`: on push/PR to `master`, runs `go test ./...` and `python -m compileall .`, then (on push to `master` only) builds and pushes `kkuro5001/closetly-{go,python,frontend}` Docker images to Docker Hub.
- `.github/workflows/cd.yml`: triggered by a successful CI run; self-hosted runners pull the new images and restart the `closetly-go`/`closetly-python`/`closetly-frontend` containers. The Go container is started with `PYTHON_API_URL` pointing at the Python container's LAN address.
