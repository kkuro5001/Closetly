package main

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

const fakeResponse = `{"category":"shirt","color":"ネイビー","color_en":"navy","hex":"#172558","ratio":0.49,"suggestion":"x"}`

// 指定フィールド名のmultipartリクエストを作る
func newUploadRequest(t *testing.T, field string) *http.Request {
	t.Helper()

	body := &bytes.Buffer{}
	w := multipart.NewWriter(body)
	part, err := w.CreateFormFile(field, "test.jpg")
	if err != nil {
		t.Fatal(err)
	}
	part.Write([]byte("dummy-image-bytes"))
	w.Close()

	req := httptest.NewRequest(http.MethodPost, "/upload", body)
	req.Header.Set("Content-Type", w.FormDataContentType())
	return req
}

// Pythonの代わりになるテスト用サーバー
func newFakePython(t *testing.T) *httptest.Server {
	t.Helper()

	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/predict" {
			t.Errorf("想定外のパス: %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(fakeResponse))
	}))
}

func TestUploadRelaysJSON(t *testing.T) {
	fake := newFakePython(t)
	defer fake.Close()
	t.Setenv("PYTHON_API_URL", fake.URL)

	t.Setenv("CORS_ALLOWED_ORIGINS", "https://closetly.example.com")

	req := newUploadRequest(t, "image")
	req.Header.Set("Origin", "https://closetly.example.com")

	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, req)

	if rec.Code != 200 {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if rec.Body.String() != fakeResponse {
		t.Errorf("body = %s, want %s", rec.Body.String(), fakeResponse)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://closetly.example.com" {
		t.Errorf("Allow-Origin = %q, want https://closetly.example.com", got)
	}
}

func TestUploadMissingImage(t *testing.T) {
	t.Setenv("PYTHON_API_URL", "http://127.0.0.1:1")

	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, newUploadRequest(t, "other"))

	if rec.Code != 400 {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

// プリフライトのリクエストを送ってレスポンスを返す
func preflight(t *testing.T, origin string) *httptest.ResponseRecorder {
	t.Helper()

	req := httptest.NewRequest(http.MethodOptions, "/upload", nil)
	req.Header.Set("Origin", origin)
	req.Header.Set("Access-Control-Request-Method", "POST")

	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, req)
	return rec
}

func TestCORSPreflight(t *testing.T) {
	// 許可リスト未設定ならlocalhostはポートに関係なく通す
	t.Setenv("CORS_ALLOWED_ORIGINS", "")

	rec := preflight(t, "http://localhost:5000")

	if rec.Code != 204 {
		t.Fatalf("status = %d, want 204", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5000" {
		t.Errorf("Allow-Origin = %q, want http://localhost:5000", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(got, "POST") {
		t.Errorf("Allow-Methods = %q, POST を含むべき", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "Content-Type") {
		t.Errorf("Allow-Headers = %q, Content-Type を含むべき", got)
	}
}

func TestCORSPreflightRejectsOtherOrigin(t *testing.T) {
	t.Setenv("CORS_ALLOWED_ORIGINS", "https://closetly.example.com")

	// 許可リストを設定したらlocalhostも含めてリスト外は通さない
	for _, origin := range []string{"https://evil.example.com", "http://localhost:5000"} {
		rec := preflight(t, origin)

		if rec.Code != 403 {
			t.Errorf("%s: status = %d, want 403", origin, rec.Code)
		}
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
			t.Errorf("%s: Allow-Origin = %q, want empty", origin, got)
		}
	}
}

func TestCORSAllowsListedOrigins(t *testing.T) {
	t.Setenv("CORS_ALLOWED_ORIGINS", "https://closetly.example.com, http://localhost")

	for _, origin := range []string{"https://closetly.example.com", "http://localhost"} {
		rec := preflight(t, origin)

		if rec.Code != 204 {
			t.Errorf("%s: status = %d, want 204", origin, rec.Code)
		}
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != origin {
			t.Errorf("%s: Allow-Origin = %q, want %s", origin, got, origin)
		}
	}
}
