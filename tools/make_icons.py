#!/usr/bin/env python3
"""生成 EasyMacKBControl 的 App 图标与状态栏模板图。

用法:tools/.venv/bin/python tools/make_icons.py
设计:深蓝紫渐变底 + 白色键帽 + "F" 字样(macOS Big Sur+ 圆角矩形规范)。
"""
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "EasyMacKBControl" / "Assets.xcassets"

# 配色
BG_TOP = (94, 92, 230)      # 亮靛蓝 #5E5CE6
BG_BOTTOM = (44, 42, 110)   # 深靛紫 #2C2A6E
CAP_TOP = (255, 255, 255)
CAP_BOTTOM = (232, 232, 240)
GLYPH = (59, 56, 168)       # 键帽上的 "F"


def load_font(size: int, weight: Optional[int] = None) -> ImageFont.FreeTypeFont:
    for candidate in [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/System.ttf",
    ]:
        try:
            font = ImageFont.truetype(candidate, size)
            if weight is not None and candidate.endswith("SFNS.ttf"):
                # SFNS 为可变字体,轴顺序 [Width, OpticalSize, GRAD, Weight];400=Regular,700=Bold
                font.set_variation_by_axes([100, 28, 400, weight])
            return font
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
    """返回指定尺寸的 App 图标(macOS Big Sur+ 规范:全幅不透明、系统叠加圆角)。"""
    s = 1024  # 一律先画母版再缩放,保证各尺寸一致

    # 全幅渐变底(不透明、铺满画布;圆角由 macOS 自行裁剪,勿烘焙透明边角)
    img = vertical_gradient(s, BG_TOP, BG_BOTTOM).convert("RGB")

    # 白色键帽(居中 520×520,圆角 108),微渐变增加体积感
    cap_bbox = [252, 252, 772, 772]
    cap = vertical_gradient(s, CAP_TOP, CAP_BOTTOM).convert("RGB")
    cap_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(cap_mask).rounded_rectangle(cap_bbox, radius=108, fill=255)
    img.paste(cap, (0, 0), cap_mask)

    # "F" 字样
    font = load_font(340)
    d = ImageDraw.Draw(img)
    d.text((512, 540), "F", font=font, fill=GLYPH, anchor="mm")

    return img.resize((size, size), Image.LANCZOS)


def draw_status_icon(size: int) -> Image.Image:
    """状态栏模板图:圆角键帽 + 镂空粗体 "F"(alpha 0),系统按 alpha 适配明暗。

    以 8× 母版(288px)绘制再缩到目标尺寸,超采样保证字形与圆角边缘平滑,
    避免小字号直接栅格化产生的锯齿(旧实现 2x 图直接画 36px,几乎无抗锯齿)。
    """
    s = 288
    k = s / 36.0
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 圆角键帽(30×30 居中),黑底——模板渲染下由系统按菜单栏明暗自动着色
    d.rounded_rectangle([3 * k, 3 * k, 33 * k, 33 * k], radius=7 * k, fill=(0, 0, 0, 255))

    # 粗体 "F" 镂空:在字形区域把 alpha 置 0,模板渲染下即透明孔洞
    font = load_font(int(22 * k), weight=700)
    glyph = Image.new("L", (s, s), 0)
    ImageDraw.Draw(glyph).text((18 * k, 18 * k), "F", font=font, fill=255, anchor="mm")
    alpha = Image.composite(Image.new("L", (s, s), 0), img.getchannel("A"), glyph)
    img.putalpha(alpha)

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
