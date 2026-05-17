from fastapi import FastAPI, Request
import uvicorn
from ultralytics import YOLO
import cv2
import numpy as np

app = FastAPI()

# YOLOモデル読み込み
model = YOLO("yolov8n.pt")

# 画像を受け取って服のカテゴリや色を予測する
@app.post("/predict")
async def predict(request: Request):

    print("===== PYTHON START =====")

    image_bytes = await request.body()

    print("画像受信完了")
    print("画像バイト数:", len(image_bytes))

    # --------- YOLOでカテゴリを判別する

    # bytes -> numpy配列
    np_arr = np.frombuffer(image_bytes, np.uint8)

    print("numpy変換完了")

    # numpy -> OpenCV画像
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    # 画像デコード確認
    if img is None:

        print("画像デコード失敗")

        return {
            "category": "unknown",
            "color": "unknown",
            "suggestion": "image decode failed"
        }

    print("画像デコード成功")
    print("画像shape:", img.shape)

    # ---------------- YOLO予測
    print("YOLO推論開始")

    results = model(img)

    print("YOLO推論完了")

    # 最初の予測
    result = results[0]

    # 予測結果
    labels = result.names
    boxes = result.boxes

    print("検出数:", len(boxes))

    # 検出一覧表示
    for box in boxes:

        cls_id = int(box.cls[0])

        conf = float(box.conf[0])

        label = labels[cls_id]

        print(
            "検出:",
            label,
            "confidence:",
            conf
        )

    # 検出なし
    if len(boxes) == 0:

        print("物体検出なし")

        return {
            "category": "unknown",
            "color": "unknown",
            "suggestion": "no clothes detected"
        }

    # 一番スコアが高いもの
    cls_id = int(boxes.cls[0])

    category = labels[cls_id]

    print("最終カテゴリ:", category)

    response = {
        "category": category,
        "color": "black",
        "suggestion": "white pants recommended"
    }

    print("pythonからgoに予測結果返信")
    print(response)

    print("===== PYTHON END =====")

    return response

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)