FROM python:3.11

WORKDIR /app

COPY requirements.txt .

# OpenCV / YOLO 用ライブラリ
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]