package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Supabase(認証と服の取得)の偽物。validToken 以外は 401 を返す
func fakeSupabase(t *testing.T, validToken string, clothesJSON string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("apikey") != "anon-key" {
			t.Errorf("apikey ヘッダーが渡っていない: %q", r.Header.Get("apikey"))
		}
		if r.Header.Get("Authorization") != "Bearer "+validToken {
			w.WriteHeader(401)
			return
		}
		switch r.URL.Path {
		case "/auth/v1/user":
			w.Write([]byte(`{"id":"user-1"}`))
		case "/rest/v1/clothes":
			w.Write([]byte(clothesJSON))
		default:
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

// Gemini の偽物。受け取ったリクエストを記録し、output をモデルの返答として返す
func fakeGemini(t *testing.T, status int, output string, gotBody *string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("x-goog-api-key") != "gemini-key" {
			t.Errorf("APIキーがヘッダーで渡っていない")
		}
		if !strings.HasSuffix(r.URL.Path, "/models/test-model:generateContent") {
			t.Errorf("想定外のパス: %s", r.URL.Path)
		}
		b, _ := io.ReadAll(r.Body)
		if gotBody != nil {
			*gotBody = string(b)
		}
		w.WriteHeader(status)
		resp := map[string]any{
			"candidates": []any{
				map[string]any{"content": map[string]any{"parts": []any{map[string]any{"text": output}}}},
			},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func setSuggestEnv(t *testing.T, supabaseURL, geminiURL string) {
	t.Setenv("SUPABASE_URL", supabaseURL)
	t.Setenv("SUPABASE_ANON_KEY", "anon-key")
	t.Setenv("GEMINI_API_KEY", "gemini-key")
	t.Setenv("GEMINI_MODEL", "test-model")
	t.Setenv("GEMINI_API_BASE_URL", geminiURL)
}

func postSuggest(t *testing.T, auth string, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest("POST", "/suggest-outfit", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, req)
	return rec
}

const twoClothes = `[{"id":1,"category":"シャツ","color":"白","season":"春秋"},{"id":2,"category":"パンツ","color":"黒","season":"オールシーズン"},{"id":3,"category":"靴","color":"黒","season":"オールシーズン"}]`

func TestSuggestRequiresConfig(t *testing.T) {
	t.Setenv("SUPABASE_URL", "")
	t.Setenv("SUPABASE_ANON_KEY", "")
	t.Setenv("GEMINI_API_KEY", "")
	rec := postSuggest(t, "Bearer x", `{}`)
	if rec.Code != 503 {
		t.Fatalf("status = %d, want 503", rec.Code)
	}
}

func TestSuggestRequiresLogin(t *testing.T) {
	sb := fakeSupabase(t, "good", twoClothes)
	gm := fakeGemini(t, 200, `{"suggestions":[]}`, nil)
	setSuggestEnv(t, sb.URL, gm.URL)

	if rec := postSuggest(t, "", `{}`); rec.Code != 401 {
		t.Errorf("ヘッダー無し: status = %d, want 401", rec.Code)
	}
	if rec := postSuggest(t, "Bearer bad", `{}`); rec.Code != 401 {
		t.Errorf("無効なトークン: status = %d, want 401", rec.Code)
	}
}

func TestSuggestReturnsValidatedSuggestions(t *testing.T) {
	sb := fakeSupabase(t, "good", twoClothes)
	// 99 は本人の服に無い id、1 は重複、2つ目の提案は有効な服が1着だけになる
	output := `{"suggestions":[
		{"name":"きれいめ","clothing_ids":[1,2,99,1],"reason":"白と黒で合わせやすい"},
		{"name":"だめな案","clothing_ids":[3,99],"reason":"x"}
	]}`
	var gotBody string
	gm := fakeGemini(t, 200, output, &gotBody)
	setSuggestEnv(t, sb.URL, gm.URL)

	rec := postSuggest(t, "Bearer good", `{"scene":"通勤","season":"春秋"}`)
	if rec.Code != 200 {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}

	var res struct {
		Suggestions []outfitSuggestion `json:"suggestions"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	if len(res.Suggestions) != 1 {
		t.Fatalf("提案数 = %d, want 1: %+v", len(res.Suggestions), res.Suggestions)
	}
	s := res.Suggestions[0]
	if s.Name != "きれいめ" || len(s.ClothingIDs) != 2 || s.ClothingIDs[0] != 1 || s.ClothingIDs[1] != 2 {
		t.Errorf("提案の中身が想定と違う: %+v", s)
	}

	// プロンプトに服の一覧・場面・季節が入り、JSONで返すよう指定していること
	for _, want := range []string{"通勤", "春秋", "responseJsonSchema", "application/json", `\"id\":3`} {
		if !strings.Contains(gotBody, want) {
			t.Errorf("Gemini へのリクエストに %q が含まれていない", want)
		}
	}
}

func TestSuggestNeedsTwoClothes(t *testing.T) {
	sb := fakeSupabase(t, "good", `[{"id":1,"category":"シャツ","color":"白","season":"夏"}]`)
	gm := fakeGemini(t, 200, `{"suggestions":[]}`, nil)
	setSuggestEnv(t, sb.URL, gm.URL)

	if rec := postSuggest(t, "Bearer good", `{}`); rec.Code != 400 {
		t.Errorf("status = %d, want 400", rec.Code)
	}
}

func TestSuggestRejectsLongScene(t *testing.T) {
	sb := fakeSupabase(t, "good", twoClothes)
	gm := fakeGemini(t, 200, `{"suggestions":[]}`, nil)
	setSuggestEnv(t, sb.URL, gm.URL)

	body := `{"scene":"` + strings.Repeat("あ", maxSceneLength+1) + `"}`
	if rec := postSuggest(t, "Bearer good", body); rec.Code != 400 {
		t.Errorf("status = %d, want 400", rec.Code)
	}
}

func TestSuggestGeminiRateLimited(t *testing.T) {
	sb := fakeSupabase(t, "good", twoClothes)
	gm := fakeGemini(t, 429, `{}`, nil)
	setSuggestEnv(t, sb.URL, gm.URL)

	if rec := postSuggest(t, "Bearer good", `{}`); rec.Code != 429 {
		t.Errorf("status = %d, want 429", rec.Code)
	}
}

// 502 は Cloudflare に差し替えられて CORS ヘッダーが消えるので返さない
func TestSuggestGeminiError(t *testing.T) {
	sb := fakeSupabase(t, "good", twoClothes)
	gm := fakeGemini(t, 503, `{}`, nil)
	setSuggestEnv(t, sb.URL, gm.URL)

	if rec := postSuggest(t, "Bearer good", `{}`); rec.Code != 500 {
		t.Errorf("status = %d, want 500", rec.Code)
	}
}

func TestCORSPreflightAllowsAuthorization(t *testing.T) {
	t.Setenv("CORS_ALLOWED_ORIGINS", "")
	req := httptest.NewRequest("OPTIONS", "/suggest-outfit", nil)
	req.Header.Set("Origin", "http://localhost:5000")
	rec := httptest.NewRecorder()
	setupRouter().ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "Authorization") {
		t.Errorf("Allow-Headers = %q, Authorization を含むべき", got)
	}
}
