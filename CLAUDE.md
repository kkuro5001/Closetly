# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Closetly is a wardrobe-management app: photograph or pick a photo of a piece of clothing, tag it (category/color/season), and browse it later in a closet grid. See [README.md](README.md) for the feature list.

Both the images (Supabase Storage) and the clothing metadata (Supabase Postgres) live in Supabase — there is no local database. The Go/Python AI-classification pipeline described below still exists in the repo but is no longer called from the Flutter app; clothing is tagged by hand at registration time.

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
1. `frontend/lib/pages/camera_page.dart` captures a photo (camera) or picks one (gallery) via `image_picker`, reading it as bytes (`Uint8List`) so the same code path works on web and mobile. Picking a photo only updates the preview — it does **not** upload anything yet.
2. Category (a fixed dropdown list) and season are picked from a dropdown; color is typed in (no automatic classification is called).
3. Pressing "保存" does both steps together: uploads the bytes to Supabase Storage via `frontend/lib/services/storage_service.dart` (`uploadOriginal`, using `uploadBinary` — not `upload`, which takes a `dart:io File` and breaks on web), then calls `frontend/lib/services/clothing_service.dart`'s `insertClothing` with the returned storage path plus category/color/season, inserting a row into the Supabase `clothes` table — `user_id` is filled in server-side via the column default (`auth.uid()`), so the client never sends it. A SnackBar reports success or failure of the combined operation.
4. `frontend/lib/pages/closet_page.dart` loads rows via `clothingService.getAllClothing()` and resolves each row's stored path to a fresh signed URL via `storageService.getSignedUrl` at display time (the bucket is private, so URLs are not persisted — they're re-signed on every read).

### Auth
`frontend/lib/auth/auth_gate.dart` gates the app on `Supabase.instance.client.auth.currentSession`, routing to `LoginPage` or `MainPage`. Supabase project URL/anon key live in `frontend/lib/config/supabase_config.dart`.

### Supabase (Storage)
Bucket: `closetly-image` (private). Objects are namespaced as `{userId}/original/{fileName}` and `{userId}/processed/{fileName}` — the RLS policies below rely on the first path segment being the uploader's `auth.uid()`.

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

-- 画像削除 (delete own images)
create policy "画像削除"
on storage.objects
for delete
to authenticated
using (
  (storage.foldername(name))[1] = (select auth.uid()::text)
);
```

### Supabase (Postgres — clothing metadata)
Table: `public.clothes` (schema/policies in `supabase/clothes_table.sql`) — `id`, `user_id` (defaults to `auth.uid()`), `image_path`, `category`, `color`, `season`, `created_at` (DB-side default `now()`, not set by the client). RLS restricts select/insert/delete to rows where `user_id = auth.uid()`. `frontend/lib/services/clothing_service.dart` is the only code that touches this table; `frontend/lib/models/clothing.dart` maps rows to/from `Clothing` (note the Postgres columns are snake_case, e.g. `image_path`, while the Dart field is `imagePath`). Deleting a clothing item (`frontend/lib/pages/clothing_detail_page.dart`) removes both the `clothes` row and the underlying Storage object — the two are not linked by a DB constraint, just the `image_path` string, so the app must delete both sides itself.

### Go/Python AI pipeline (`Go/`, `Python/`) — currently unused by the frontend
`Go/upload.go`'s single handler (`POST /upload`) reads the multipart `image` field, forwards the raw bytes to `${PYTHON_API_URL}/predict` (`Python/main.py`, YOLOv8-based), and relays the JSON response back verbatim. `PYTHON_API_URL` is required (set via env var, e.g. in `docker-compose.yml`/the CD deploy step) — the handler errors out if it's unset. Nothing in `frontend/` calls this anymore (see Image flow above) — it still builds/deploys via CI/CD but is dead code from the app's perspective.

### CI/CD
- `.github/workflows/ci.yml`: on push/PR to `master`, runs `go test ./...` and `python -m compileall .`, then (on push to `master` only) builds and pushes `kkuro5001/closetly-{go,python,frontend}` Docker images to Docker Hub.
- `.github/workflows/cd.yml`: triggered by a successful CI run; self-hosted runners pull the new images and restart the `closetly-go`/`closetly-python`/`closetly-frontend` containers. The Go container is started with `PYTHON_API_URL` pointing at the Python container's LAN address.
