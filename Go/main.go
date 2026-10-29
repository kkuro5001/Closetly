package main

import (
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// 許可オリジンを環境変数CORS_ALLOWED_ORIGINS(カンマ区切り)から読む
func loadAllowedOrigins() map[string]bool {
	allowed := map[string]bool{}

	for _, o := range strings.Split(os.Getenv("CORS_ALLOWED_ORIGINS"), ",") {
		o = strings.TrimSpace(o)
		if o != "" {
			allowed[o] = true
		}
	}

	return allowed
}

// 許可リストが未設定ならローカル開発用にlocalhostだけを許可する
func isAllowedOrigin(origin string, allowed map[string]bool) bool {
	if len(allowed) > 0 {
		return allowed[origin]
	}

	// flutter runはポートが毎回変わるのでホスト名だけで判定する
	u, err := url.Parse(origin)
	if err != nil {
		return false
	}
	host := u.Hostname()
	return host == "localhost" || host == "127.0.0.1"
}

// Flutter Webはブラウザから別オリジンのGo APIを叩くため、許可したオリジンだけCORSを通す
func corsMiddleware() gin.HandlerFunc {
	allowed := loadAllowedOrigins()

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// オリジンごとに返すヘッダーが変わるのでキャッシュを分けさせる
		c.Header("Vary", "Origin")

		if origin != "" && isAllowedOrigin(origin, allowed) {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
			c.Header("Access-Control-Allow-Headers", "Content-Type")
		}

		//プリフライトは本処理に進まず返す(許可外のオリジンは403)
		if c.Request.Method == "OPTIONS" {
			if origin != "" && !isAllowedOrigin(origin, allowed) {
				c.AbortWithStatus(403)
				return
			}
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// テストからも組み立てられるようルーター生成を分離
func setupRouter() *gin.Engine {

	r := gin.Default()

	r.Use(corsMiddleware())

	//画像受け取り + Pythonへ転送
	r.POST("/upload", UploadHandler)

	r.GET("/test", TestHandler)

	return r
}

func main() {

	r := setupRouter()

	r.Run(":8080")
}
