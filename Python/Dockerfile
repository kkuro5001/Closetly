FROM python:3.11-slim

# pythonのログを即時出力 /pycを作らない
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

#先にrequirements.txtをコピーして、依存関係のインストール
COPY requirements.txt .

# opencv-python-headlessは必要なライブラリを同梱しているためaptでの追加は不要
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]