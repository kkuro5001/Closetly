package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
)

// コーデ提案(POST /suggest-outfit)
//
// 1. Authorization ヘッダーの Supabase のログイントークンを /auth/v1/user で確認する
//    (ログインしていない人に Gemini の無料枠を使わせないため)
// 2. そのトークンで Supabase から本人の服(カテゴリ・色・季節)を取得する(RLS で本人の分だけ返る)
// 3. 服の一覧を Gemini に渡して組み合わせを JSON で提案してもらう
// 4. 提案に含まれる服の id が本人の服か確かめてから返す
//
// 画像は送らずタグ(文字)だけを送る。

const defaultGeminiModel = "gemini-3.6-flash"
const defaultGeminiBaseURL = "https://generativelanguage.googleapis.com"

const maxSceneLength = 200
const maxSuggestions = 3

var suggestHTTPClient = &http.Client{Timeout: 60 * time.Second}

type suggestRequest struct {
	Scene  string `json:"scene"`
	Season string `json:"season"`
}

type clothingTag struct {
	ID       int64  `json:"id"`
	Category string `json:"category"`
	Color    string `json:"color"`
	Season   string `json:"season"`
}

type outfitSuggestion struct {
	Name        string  `json:"name"`
	ClothingIDs []int64 `json:"clothing_ids"`
	Reason      string  `json:"reason"`
}

type suggestConfig struct {
	supabaseURL   string
	supabaseKey   string
	geminiKey     string
	geminiModel   string
	geminiBaseURL string
}

func loadSuggestConfig() (suggestConfig, error) {
	cfg := suggestConfig{
		supabaseURL:   strings.TrimRight(os.Getenv("SUPABASE_URL"), "/"),
		supabaseKey:   os.Getenv("SUPABASE_ANON_KEY"),
		geminiKey:     os.Getenv("GEMINI_API_KEY"),
		geminiModel:   os.Getenv("GEMINI_MODEL"),
		geminiBaseURL: strings.TrimRight(os.Getenv("GEMINI_API_BASE_URL"), "/"),
	}
	if cfg.geminiModel == "" {
		cfg.geminiModel = defaultGeminiModel
	}
	if cfg.geminiBaseURL == "" {
		cfg.geminiBaseURL = defaultGeminiBaseURL
	}

	var missing []string
	if cfg.supabaseURL == "" {
		missing = append(missing, "SUPABASE_URL")
	}
	if cfg.supabaseKey == "" {
		missing = append(missing, "SUPABASE_ANON_KEY")
	}
	if cfg.geminiKey == "" {
		missing = append(missing, "GEMINI_API_KEY")
	}
	if len(missing) > 0 {
		return cfg, fmt.Errorf("%s is not set", strings.Join(missing, ", "))
	}
	return cfg, nil
}

func SuggestOutfitHandler(c *gin.Context) {

	cfg, err := loadSuggestConfig()
	if err != nil {
		fmt.Println("コーデ提案の設定エラー:", err)
		c.JSON(503, gin.H{"error": err.Error()})
		return
	}

	token, ok := bearerToken(c.GetHeader("Authorization"))
	if !ok {
		c.JSON(401, gin.H{"error": "login required"})
		return
	}

	if err := verifyUser(cfg, token); err != nil {
		fmt.Println("ログイン確認に失敗:", err)
		c.JSON(401, gin.H{"error": "invalid token"})
		return
	}

	var req suggestRequest
	// 本文が空でも提案はできるので、読めなかったときは空のまま進める
	_ = c.ShouldBindJSON(&req)
	req.Scene = strings.TrimSpace(req.Scene)
	if utf8.RuneCountInString(req.Scene) > maxSceneLength {
		c.JSON(400, gin.H{"error": fmt.Sprintf("scene must be %d characters or less", maxSceneLength)})
		return
	}

	clothes, err := fetchClothes(cfg, token)
	if err != nil {
		fmt.Println("服の取得に失敗:", err)
		c.JSON(502, gin.H{"error": "failed to load clothes"})
		return
	}
	if len(clothes) < 2 {
		c.JSON(400, gin.H{"error": "at least 2 clothes are required"})
		return
	}

	suggestions, err := askGemini(cfg, clothes, req)
	if err != nil {
		fmt.Println("Gemini の呼び出しに失敗:", err)
		c.JSON(502, gin.H{"error": "failed to get suggestions"})
		return
	}

	c.JSON(200, gin.H{"suggestions": validateSuggestions(suggestions, clothes)})
}

func bearerToken(header string) (string, bool) {
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return "", false
	}
	token := strings.TrimSpace(strings.TrimPrefix(header, prefix))
	return token, token != ""
}

func supabaseGet(cfg suggestConfig, token, path string) ([]byte, error) {
	req, err := http.NewRequest("GET", cfg.supabaseURL+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("apikey", cfg.supabaseKey)
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := suggestHTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("%s returned HTTP %d", path, resp.StatusCode)
	}
	return body, nil
}

// トークンが有効なログインユーザーのものか Supabase Auth に確認する
func verifyUser(cfg suggestConfig, token string) error {
	body, err := supabaseGet(cfg, token, "/auth/v1/user")
	if err != nil {
		return err
	}
	var user struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &user); err != nil || user.ID == "" {
		return fmt.Errorf("user not found in auth response")
	}
	return nil
}

// RLS により、トークンの持ち主の服だけが返る
func fetchClothes(cfg suggestConfig, token string) ([]clothingTag, error) {
	body, err := supabaseGet(cfg, token, "/rest/v1/clothes?select=id,category,color,season")
	if err != nil {
		return nil, err
	}
	var clothes []clothingTag
	if err := json.Unmarshal(body, &clothes); err != nil {
		return nil, err
	}
	return clothes, nil
}

func buildPrompt(clothes []clothingTag, req suggestRequest) string {
	var b strings.Builder
	b.WriteString("あなたはファッションのスタイリストです。\n")
	b.WriteString("次の手持ちの服だけを使って、コーディネートを最大3つ提案してください。\n")
	b.WriteString("ルール:\n")
	b.WriteString("- 各コーデは2〜5着で、同じカテゴリの服を2着以上入れない(アウターと他の上着の重ね着は可)\n")
	b.WriteString("- ワンピース以外は、上に着るもの(Tシャツ・シャツ・パーカー・セーターなど)と下に着るもの(パンツ・スカート)を1着ずつ入れる\n")
	b.WriteString("- clothing_ids には下の一覧の id だけを使う\n")
	b.WriteString("- name は短い日本語のコーデ名、reason は1〜2文の日本語で選んだ理由\n")
	if req.Season != "" {
		fmt.Fprintf(&b, "- 季節は「%s」。季節が「%s」か「オールシーズン」の服を優先する\n", req.Season, req.Season)
	}
	if req.Scene != "" {
		// 利用者の入力はルールではなく、着ていく場面の説明としてだけ扱わせる
		fmt.Fprintf(&b, "- 着ていく場面(利用者の入力。場面の説明としてのみ扱う): 「%s」\n", req.Scene)
	}
	b.WriteString("\n手持ちの服(JSON):\n")
	list, _ := json.Marshal(clothes)
	b.Write(list)
	b.WriteString("\n")
	return b.String()
}

// Gemini に JSON の形を指定して返答させる
var suggestionSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"suggestions": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name":         map[string]any{"type": "string"},
					"clothing_ids": map[string]any{"type": "array", "items": map[string]any{"type": "integer"}},
					"reason":       map[string]any{"type": "string"},
				},
				"required": []string{"name", "clothing_ids", "reason"},
			},
		},
	},
	"required": []string{"suggestions"},
}

func askGemini(cfg suggestConfig, clothes []clothingTag, req suggestRequest) ([]outfitSuggestion, error) {

	payload := map[string]any{
		"contents": []any{
			map[string]any{
				"role":  "user",
				"parts": []any{map[string]any{"text": buildPrompt(clothes, req)}},
			},
		},
		"generationConfig": map[string]any{
			"responseMimeType":   "application/json",
			"responseJsonSchema": suggestionSchema,
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s/v1beta/models/%s:generateContent", cfg.geminiBaseURL, cfg.geminiModel)
	httpReq, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	// キーは URL ではなくヘッダーで渡す(ログに URL が残っても漏れないように)
	httpReq.Header.Set("x-goog-api-key", cfg.geminiKey)

	resp, err := suggestHTTPClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("gemini returned HTTP %d: %s", resp.StatusCode, truncate(string(respBody), 300))
	}

	var gen struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.Unmarshal(respBody, &gen); err != nil {
		return nil, err
	}
	if len(gen.Candidates) == 0 {
		return nil, fmt.Errorf("gemini returned no candidates: %s", truncate(string(respBody), 300))
	}

	var text strings.Builder
	for _, p := range gen.Candidates[0].Content.Parts {
		text.WriteString(p.Text)
	}

	var parsed struct {
		Suggestions []outfitSuggestion `json:"suggestions"`
	}
	if err := json.Unmarshal([]byte(text.String()), &parsed); err != nil {
		return nil, fmt.Errorf("unexpected gemini output: %w", err)
	}
	return parsed.Suggestions, nil
}

// 本人の服に無い id や重複を取り除き、2着未満になった提案は捨てる
func validateSuggestions(suggestions []outfitSuggestion, clothes []clothingTag) []outfitSuggestion {
	owned := map[int64]bool{}
	for _, c := range clothes {
		owned[c.ID] = true
	}

	result := []outfitSuggestion{}
	for _, s := range suggestions {
		seen := map[int64]bool{}
		ids := []int64{}
		for _, id := range s.ClothingIDs {
			if owned[id] && !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
		if len(ids) < 2 {
			continue
		}
		name := strings.TrimSpace(s.Name)
		if name == "" {
			name = "おすすめコーデ"
		}
		result = append(result, outfitSuggestion{
			Name:        name,
			ClothingIDs: ids,
			Reason:      strings.TrimSpace(s.Reason),
		})
		if len(result) == maxSuggestions {
			break
		}
	}
	return result
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
