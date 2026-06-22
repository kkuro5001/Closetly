package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

func TestHandler(c *gin.Context) {
	fmt.Println("===== TEST START =====")

	// ローカル画像読み込み
	imageBytes, err := os.ReadFile("sample2.jpg")
	if err != nil {
		fmt.Println("画像読み込み失敗")
		fmt.Println(err)

		c.JSON(500, gin.H{
			"error": "image read error",
		})
		return
	}

	fmt.Println("画像読み込み成功")
	fmt.Println("画像サイズ:", len(imageBytes), "bytes")

	// 環境変数から Python API のURLを取得
	pythonAPIURL := os.Getenv("PYTHON_API_URL")
	if pythonAPIURL == "" {
		c.JSON(500, gin.H{
			"error": "PYTHON_API_URL is not set",
		})
		return
	}

	// Pythonへ送信
	fmt.Println("Pythonへ送信開始:", pythonAPIURL+"/predict")

	start := time.Now()

	resp, err := http.Post(
		pythonAPIURL+"/predict",
		"application/octet-stream",
		bytes.NewBuffer(imageBytes),
	)
	if err != nil {
		fmt.Println("Python通信失敗")
		fmt.Println(err)

		c.JSON(500, gin.H{
			"error": "python error: " + err.Error(),
		})
		return
	}
	defer resp.Body.Close()

	elapsed := time.Since(start)

	fmt.Println("Pythonレスポンス受信")
	fmt.Println("Status:", resp.Status)
	fmt.Println("通信時間:", elapsed)

	// レスポンス読み込み
	result, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("レスポンス読み込み失敗")
		fmt.Println(err)

		c.JSON(500, gin.H{
			"error": "response read error",
		})
		return
	}

	// 生レスポンス表示
	fmt.Println("===== RAW RESPONSE =====")
	fmt.Println(string(result))
	fmt.Println("========================")

	fmt.Println("YOLO結果返却完了")
	fmt.Println("===== TEST END =====")

	// Flutter / curlへ返却
	c.Data(resp.StatusCode, "application/json", result)
}