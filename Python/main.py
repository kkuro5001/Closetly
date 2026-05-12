from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()

# 画像を受け取って服のカテゴリや色を予測する
@app.post("/predict")
async def predict(request: Request):
    image_bytes = await request.body()

    print("画像受信完了")

    #仮AIの処理をここに入れる YOLOなど
    result = {
        "category": "shirt",
        "color": "black",
        "suggestion": "white pants recommended"
    }
    print("pythonからgoに予測結果返信 ")

    return result

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)