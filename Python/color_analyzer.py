import cv2
import numpy as np

# 解析前に縮小する長辺サイズ(速度優先)
MAX_SIDE = 200

# k-meansのクラスタ数
CLUSTER_COUNT = 4


# 画像(BGR)から服のメインカラーを解析する
def analyze_color(img):

    small = _resize(img)

    # 背景を除いた服の画素だけ取り出す
    mask = _foreground_mask(small)
    pixels = small[mask]

    # 前景がほとんど取れなかったら画像全体で解析
    if len(pixels) < 100:
        print("前景抽出失敗 画像全体で色解析")
        pixels = small.reshape(-1, 3)

    bgr, ratio = _dominant_color(pixels)

    name_ja, name_en = _color_name(bgr)

    b, g, r = (int(v) for v in bgr)

    return {
        "color": name_ja,
        "color_en": name_en,
        "hex": f"#{r:02x}{g:02x}{b:02x}",
        "ratio": round(float(ratio), 3),
    }


# 長辺がMAX_SIDEになるよう縮小
def _resize(img):

    h, w = img.shape[:2]
    scale = MAX_SIDE / max(h, w)

    if scale >= 1:
        return img

    return cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)


# GrabCutで背景を除去して前景マスクを返す
# 服は画像の中央付近に写っている前提で、外周5%を背景として初期化する
def _foreground_mask(img):

    h, w = img.shape[:2]
    margin_x = max(1, int(w * 0.05))
    margin_y = max(1, int(h * 0.05))
    rect = (margin_x, margin_y, w - margin_x * 2, h - margin_y * 2)

    mask = np.zeros((h, w), np.uint8)
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)

    try:
        cv2.grabCut(img, mask, rect, bgd_model, fgd_model, 3, cv2.GC_INIT_WITH_RECT)
    except cv2.error as e:
        print("GrabCut失敗:", e)
        return np.ones((h, w), bool)

    return (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)


# k-meansで画素をクラスタリングし、一番面積の大きい色を返す
def _dominant_color(pixels):

    # 人の見た目に近いLab空間でクラスタリング
    lab = cv2.cvtColor(pixels.reshape(-1, 1, 3), cv2.COLOR_BGR2LAB).reshape(-1, 3)
    data = lab.astype(np.float32)

    k = min(CLUSTER_COUNT, len(data))
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)

    _, labels, centers = cv2.kmeans(data, k, None, criteria, 3, cv2.KMEANS_PP_CENTERS)

    counts = np.bincount(labels.flatten(), minlength=k)
    top = int(np.argmax(counts))

    center_lab = np.uint8([[centers[top]]])
    center_bgr = cv2.cvtColor(center_lab, cv2.COLOR_LAB2BGR)[0][0]

    return center_bgr, counts[top] / counts.sum()


# BGRの代表色をHSVの範囲で色名に変換する
# OpenCVのHSVは H:0-179 S:0-255 V:0-255
def _color_name(bgr):

    h, s, v = (int(x) for x in cv2.cvtColor(np.uint8([[bgr]]), cv2.COLOR_BGR2HSV)[0][0])

    # 無彩色
    if v < 50:
        return "黒", "black"

    if s < 40:
        if v > 200:
            return "白", "white"
        return "グレー", "gray"

    # 有彩色
    if h < 8 or h >= 170:
        if v < 120:
            return "ボルドー", "burgundy"
        if s < 120:
            return "ピンク", "pink"
        return "赤", "red"

    if h < 22:
        if v < 150:
            return "茶色", "brown"
        if s < 120:
            return "ベージュ", "beige"
        return "オレンジ", "orange"

    if h < 34:
        if v < 150:
            return "カーキ", "khaki"
        if s < 100:
            return "ベージュ", "beige"
        return "黄色", "yellow"

    if h < 85:
        if v < 120:
            return "カーキ", "khaki"
        return "緑", "green"

    if h < 100:
        return "水色", "light blue"

    if h < 130:
        if v < 120:
            return "ネイビー", "navy"
        if s < 120 and v > 180:
            return "水色", "light blue"
        return "青", "blue"

    if h < 150:
        return "紫", "purple"

    return "ピンク", "pink"
