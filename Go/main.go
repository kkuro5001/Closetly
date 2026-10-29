package main

import "github.com/gin-gonic/gin"

// Flutter Webはブラウザから別オリジンのGo APIを叩くためCORSを許可する
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")

		//プリフライトは本処理に進まず204で返す
		if c.Request.Method == "OPTIONS" {
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
