# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Closetly is a wardrobe-management app: photograph or pick a photo of a piece of clothing, tag it (category/color/season), and browse it later in a closet grid. See [README.md](README.md) for the feature list.

Both the images (Supabase Storage) and the clothing metadata (Supabase Postgres) live in Supabase — there is no local database. The Go/Python pipeline is used only to auto-suggest the clothing color at registration time (OpenCV color analysis); everything else is tagged by hand.

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
2. Category (a fixed dropdown list) and season are picked from a dropdown; color is auto-suggested right after a photo is picked: `frontend/lib/services/color_service.dart` POSTs the bytes (multipart field `image`, web-safe) to the Go API (`POST /upload`, base URL from `frontend/lib/config/api_config.dart`, overridable with `--dart-define=API_BASE_URL=...`, default `http://localhost:8080`), which forwards to Python `/predict` and returns `color`. The result only fills the 色 text field (still editable); a failure/timeout (15s) is just logged and never blocks saving, and a stale result is discarded if another photo was picked meanwhile.
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

### Go/Python color-analysis pipeline (`Go/`, `Python/`)
`Go/upload.go`'s single handler (`POST /upload`) reads the multipart `image` field, forwards the raw bytes to `${PYTHON_API_URL}/predict` (`Python/main.py`), and relays the JSON response back verbatim (`{"category", "color", "color_en", "hex", "ratio", "suggestion"}`). The `color` value comes from `Python/color_analyzer.py` (OpenCV: GrabCut background removal + Lab k-means + HSV color naming); the YOLOv8 `category` is not used by the app. `PYTHON_API_URL` is required (set via env var: `docker-compose.yml` uses `http://python:8000`, CD uses the Python container's LAN address) — the handler errors out if it's unset. `Go/main.go` has a CORS middleware (`Access-Control-Allow-Origin: *`, OPTIONS preflight -> 204) because Flutter Web calls the Go API cross-origin; the router is built by `setupRouter()` and tested in `Go/upload_test.go`.

`API_BASE_URL` must be a browser-reachable address of the Go server. It is baked into the web build (`frontend/Dockerfile` `ARG API_BASE_URL` -> `--dart-define`); CI passes the repo variable `vars.API_BASE_URL` (fallback `http://localhost:8080`). Details and open issues: `docs/color-autofill.md`.

### CI/CD
- `.github/workflows/ci.yml`: on push/PR to `master`, runs `go test ./...` and `python -m compileall .`, then (on push to `master` only) builds and pushes `kkuro5001/closetly-{go,python,frontend}` Docker images to Docker Hub (the frontend image is built with `--build-arg API_BASE_URL`).
- `.github/workflows/cd.yml`: triggered by a successful CI run; self-hosted runners pull the new images and restart the `closetly-go`/`closetly-python`/`closetly-frontend` containers. The Go container is started with `PYTHON_API_URL` pointing at the Python container's LAN address.
