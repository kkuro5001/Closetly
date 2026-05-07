package main

import (
	"bytes"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	//画像受け取り + Pythonへ転送
	r.POST("/upload", func(c *gin.Context) {
		file, _, err := c.Request.FormFile("image")
		if err != nil {
			c.JSON(400, gin.H{"error": "file error"})
			return
		}
		defer file.Close()

		body := &bytes.Buffer{}
		io.Copy(body, file)

		resp, err := http.Post(
			"http://python:8000/predict",
			"application/octet-stream",
			body,
		)

		if err != nil {
			c.JSON(500, gin.H{"error": "python error"})
			return
		}
		defer resp.Body.Close()

		result, _ := io.ReadAll(resp.Body)

		c.Date(200, "application/json", result)
	})

	r.Run(":8080")
}