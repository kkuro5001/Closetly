from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()

@app.post("/predict")
async def predict(request: Request):
    image_bytes = await request.body()

    #仮AIの処理をここに入れる YOLOなど
    result = {
        "category": "shirt",
        "color": "black",
        "suggestion": "white pants recommended"
    }

    return result

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)