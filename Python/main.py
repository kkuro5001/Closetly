from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()

@app.post("/process")