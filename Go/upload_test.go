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

	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, newUploadRequest(t, "image"))

	if rec.Code != 200 {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if rec.Body.String() != fakeResponse {
		t.Errorf("body = %s, want %s", rec.Body.String(), fakeResponse)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Errorf("Allow-Origin = %q, want *", got)
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

func TestCORSPreflight(t *testing.T) {
	req := httptest.NewRequest(http.MethodOptions, "/upload", nil)
	req.Header.Set("Origin", "http://localhost:5000")
	req.Header.Set("Access-Control-Request-Method", "POST")

	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, req)

	if rec.Code != 204 {
		t.Fatalf("status = %d, want 204", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Errorf("Allow-Origin = %q, want *", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(got, "POST") {
		t.Errorf("Allow-Methods = %q, POST を含むべき", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "Content-Type") {
		t.Errorf("Allow-Headers = %q, Content-Type を含むべき", got)
	}
}
