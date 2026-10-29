from fastapi import FastAPI, Request
import uvicorn
import cv2
import numpy as np

from color_analyzer import analyze_color

app = FastAPI()

# 画像を受け取って服の色を解析する
@app.post("/predict")
async def predict(request: Request):

    print("===== PYTHON START =====")

    image_bytes = await request.body()

    print("画像受信完了")
    print("画像バイト数:", len(image_bytes))

    # bytes -> numpy配列
    np_arr = np.frombuffer(image_bytes, np.uint8)

    print("numpy変換完了")

    # numpy -> OpenCV画像
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    # 画像デコード確認
    if img is None:

        print("画像デコード失敗")

        return {
            "color": "unknown",
        }

    print("画像デコード成功")
    print("画像shape:", img.shape)

    # ---------------- OpenCVで色解析
    response = analyze_color(img)

    print("pythonからgoに解析結果返信")
    print(response)

    print("===== PYTHON END =====")

    return response

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
