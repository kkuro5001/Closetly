FROM python:3.11-slim

# pythonのログを即時出力 /pycを作らない
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

#先にrequirements.txtをコピーして、依存関係のインストール
COPY requirements.txt .

# OpenCV / YOLO 用ライブラリ
RUN apt-get update && apt-get install -y --no-install-recommends\
    libglib2.0-0 \
    libgl1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]