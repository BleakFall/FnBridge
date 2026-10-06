# FnBridge

把外接键盘的标准 F 键(如 HHKB 的 Fn+数字)转换成 macOS 妙控键盘 F 区等价的系统功能:亮度、调度中心、Spotlight、媒体控制、音量。菜单栏常驻、逐键开关、开机自启。

Turns the standard F1–F12 keycodes sent by external keyboards (e.g. HHKB Fn+number) into the equivalent macOS media functions: brightness, Mission Control, Spotlight, media keys, volume. Menu-bar resident, per-key toggles, launch at login.

## 功能 | Features

- F1/F2 屏幕亮度、F3 调度中心、F4 聚焦搜索、F7–F9 媒体、F10–F12 音量
- 每个键可独立开启/关闭,含全局总开关
- 菜单栏常驻;可选显示程序坞图标、开机自启
- 中英双语

## 安装 | Install

从源码构建(或从 Releases 下载):

```bash
git clone <repo>
cd FnBridge
xcodebuild -project FnBridge.xcodeproj -scheme FnBridge -configuration Release build
```

把 `build/Release/FnBridge.app` 拖进 `/Applications` 后运行。

## 授权 | Permissions

首次运行需要两项授权(系统会弹窗):

1. **输入监控**(读取按键)与 **辅助功能**(发送系统事件):
   系统设置 → 隐私与安全性 → 分别勾选 FnBridge
2. 授权后**完全退出并重新打开** App 才生效

## 使用说明 | Notes

- 本 App 只拦截**标准 F 键码**。妙控键盘/笔记本键盘在媒体层发出的按键不经过本 App,不受影响。
- 若系统开启"将 F1、F2 等键用作标准功能键",则**所有键盘**(包括内置键盘)的 F 键都会被拦截转换——用不到时请关闭对应键的开关。
- F5(听写)与 F6(专注模式)无公开 API,暂不支持,保持普通 F 键。

## 已知限制 | Known Limitations

- F4 依赖系统默认的 Spotlight 快捷键(⌘空格);改过快捷键则 F4 无效
- 亮度控制只对内建/Apple 显示器有效,第三方外接屏不响应(系统行为)
- 无法区分按键来自哪块键盘

## 开发 | Development

```bash
xcodebuild test -project FnBridge.xcodeproj -scheme FnBridge -destination 'platform=macOS'
```

- 设计文档:`docs/superpowers/specs/`
- 图标脚本:`tools/make_icons.py`(`tools/.venv/bin/python tools/make_icons.py` 复现)
- 发布自行分发请配置 Developer ID 签名并公证:`codesign` + `xcrun notarytool`

## License

MIT
