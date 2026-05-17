package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func TestHandler(c *gin.Context) {

	// ローカル画像読み込み
	imageBytes, err := os.ReadFile("sample.webp")
	if err != nil {

		c.JSON(500, gin.H{
			"error": "image read error",
		})

		return
	}

	fmt.Println("画像読み込み成功")

	// Pythonへ送信
	resp, err := http.Post(
		"http://python:8000/predict",
		"application/octet-stream",
		bytes.NewBuffer(imageBytes),
	)

	if err != nil {

		c.JSON(500, gin.H{
			"error": "python error",
		})

		return
	}

	defer resp.Body.Close()

	result, _ := io.ReadAll(resp.Body)

	fmt.Println("YOLO結果:")
	fmt.Println(string(result))

	c.Data(200, "application/json", result)
}