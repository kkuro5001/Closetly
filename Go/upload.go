package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

func UploadHandler(c *gin.Context) {

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(400, gin.H{"error": "file error"})
		return
	}

	defer file.Close()

	fmt.Println("受信:", header.Filename)

	//Pythonへ送信
	body := &bytes.Buffer{}
	io.Copy(body, file)

	fmt.Print("goからpythonへ画像送信")

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

	fmt.Println("goからflutterへ返却")

	//フロントへ返却
	c.Data(200, "application/json", result)
}