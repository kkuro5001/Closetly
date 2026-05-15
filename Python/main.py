from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()

#yoloのモデル読み込み
model = YOLO("yolov8m.pt")

# 画像を受け取って服のカテゴリや色を予測する
@app.post("/predict")
async def predict(request: Request):
    image_bytes = await request.body()

    print("画像受信完了")

    #YOLOでカテゴリを判別する
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    #yoloで予測
    results = model(img)

    #予測結果からカテゴリと色を抽出する（ここでは仮の値を使用）
    labels = results.names
    boxes = results.boxes

    if len(boxes) == 0:
        return {
            "category": "unknown",
            "color": "unknown",
            "suggestion": "no clothes detected"
        }

    #一番スコアが高いものを取得
    cls_id = int(boxes.cls[0])
    category = labels[cls_id]


    result = {
        "category": category,
        "color": "black",
        "suggestion": "white pants recommended"
    }
    print("pythonからgoに予測結果返信 ")

    return result

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)