package main

import "github.com/gin-gonic/gin"

func main() {

	r := gin.Default()

	//画像受け取り + Pythonへ転送
	r.POST("/upload", UploadHandler)

	r.GET("/test", TestHandler)

	r.Run(":8080")
}