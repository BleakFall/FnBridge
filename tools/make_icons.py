#!/usr/bin/env python3
"""生成 EasyMacKBControl 的 App 图标与状态栏模板图。

用法:tools/.venv/bin/python tools/make_icons.py
设计:深蓝紫渐变底 + 白色键帽 + "F" 字样(macOS Big Sur+ 圆角矩形规范)。
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "EasyMacKBControl" / "Assets.xcassets"

# 配色
BG_TOP = (94, 92, 230)      # 亮靛蓝 #5E5CE6
BG_BOTTOM = (44, 42, 110)   # 深靛紫 #2C2A6E
CAP_TOP = (255, 255, 255)
CAP_BOTTOM = (232, 232, 240)
GLYPH = (59, 56, 168)       # 键帽上的 "F"


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/System.ttf",
    ]:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    raise SystemExit("找不到可用系统字体(SFNS/Helvetica)")


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(size - 1, 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return img


def draw_app_icon(size: int) -> Image.Image:
    """返回指定尺寸的 App 图标(透明边距 + 圆角)。"""
    s = 1024  # 一律先画母版再缩放,保证各尺寸一致
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # 母版:1024 画布,图标 824×824 居中,圆角 185
    margin = 100
    radius = 185
    bbox = [margin, margin, s - margin, s - margin]

    # 键帽投影(柔和,向下偏移)
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [margin + 12, margin + 30, s - margin + 12, s - margin + 30],
        radius=radius, fill=(20, 18, 60, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, shadow)

    # 渐变底 + 圆角裁剪
    grad = vertical_gradient(s, BG_TOP, BG_BOTTOM).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(bbox, radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)

    # 白色键帽(居中 520×520,圆角 108),微渐变增加体积感
    cap_bbox = [252, 252, 772, 772]
    cap_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(cap_mask).rounded_rectangle(cap_bbox, radius=108, fill=255)
    cap = vertical_gradient(s, CAP_TOP, CAP_BOTTOM).convert("RGBA")
    img.paste(cap, (0, 0), cap_mask)

    # 键帽顶部高光线
    highlight = ImageDraw.Draw(img)
    highlight.rounded_rectangle(
        [cap_bbox[0] + 26, cap_bbox[1] + 22, cap_bbox[2] - 26, cap_bbox[1] + 34],
        radius=6, fill=(255, 255, 255, 200))

    # "F" 字样
    font = load_font(340)
    d = ImageDraw.Draw(img)
    d.text((512, 540), "F", font=font, fill=GLYPH + (255,), anchor="mm")

    return img.resize((size, size), Image.LANCZOS)


def draw_status_icon(size: int) -> Image.Image:
    """状态栏模板图:纯黑 + alpha,系统自动适配明暗。先画 36 再缩放。"""
    s = 36
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 7, 34, 29], radius=6, fill=(0, 0, 0, 255))
    font = load_font(15)
    d.text((18, 18), "fn", font=font, fill=(255, 255, 255, 255), anchor="mm")
    return img.resize((size, size), Image.LANCZOS)


def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def build_app_icon():
    out = ASSETS / "AppIcon.appiconset"
    entries = []
    # macOS AppIcon 标准 10 槽位:(逻辑尺寸, 倍率),文件像素 = 逻辑 × 倍率
    for logical, scale in [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
        (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]:
        physical = logical * scale
        name = f"appicon_{logical}x{logical}@{scale}x.png"
        save(draw_app_icon(physical), out / name)
        entries.append(
            {"filename": name, "idiom": "mac", "scale": f"{scale}x",
             "size": f"{logical}x{logical}"})
    contents = {"images": entries,
                "info": {"author": "xcode", "version": 1}}
    (out / "Contents.json").write_text(__import__("json").dumps(contents, indent=2))
    print(f"AppIcon: {len(entries)} 张 → {out}")


def build_status_icon():
    out = ASSETS / "StatusBarIcon.imageset"
    save(draw_status_icon(18), out / "statusbar_18.png")
    save(draw_status_icon(36), out / "statusbar_36.png")
    contents = {
        "images": [
            {"filename": "statusbar_18.png", "idiom": "universal", "scale": "1x"},
            {"filename": "statusbar_36.png", "idiom": "universal", "scale": "2x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }
    (out / "Contents.json").write_text(__import__("json").dumps(contents, indent=2))
    print(f"StatusBarIcon: 2 张 → {out}")


if __name__ == "__main__":
    build_app_icon()
    build_status_icon()
    print("完成")
