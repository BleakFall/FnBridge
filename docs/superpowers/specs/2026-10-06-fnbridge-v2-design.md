# FnBridge v2 设计文档

日期:2026-10-06
状态:已通过用户评审(形态=可切换;Bundle ID=com.daixingwen.fnbridge;许可证=MIT)

## 1. 背景与目标

FnBridge 把外接键盘(如 HHKB 的 Fn+数字)发出的标准 F1–F12 键码转换成妙控键盘 F 区等价的系统功能(亮度、调度中心、Spotlight、媒体、音量)。F1–F12 的映射与逐键开关在 v1 已实现并实测可用。

v2 的目标:把它从"能用的原型"升级为**可发布给社区的完整产品**:

1. 修复 review 发现的可靠性 bug(重点是事件钩子静默死亡)
2. 菜单栏常驻 + 后台运行,可切换的 Dock/状态栏形态
3. 设置界面重做,告别"简装"
4. Python 绘制的 App 图标与状态栏图标
5. 发布要素:双语、README、LICENSE、稳定的 Bundle ID、降低部署目标

## 2. 范围

### 做

- 上述 5 项目标涉及的全部工作
- 全局总开关(暂停/恢复所有 F 键拦截)
- 开机自启(SMAppService)
- 简体中文 + English 双语
- 单元测试(纯逻辑部分)

### 不做(YAGNI,留待后续版本)

- 按键重映射引擎(F 键只能开/关原映射,不能改绑)
- F5 听写 / F6 专注模式的触发(无公开 API)
- 按设备过滤(只拦截特定键盘的 F 键)
- 公证/签名自动化(README 写自助步骤)
- 自动更新(Sparkle 等)

## 3. 已定决策

| 决策点 | 结论 |
|---|---|
| 运行形态 | 可切换:默认菜单栏应用(无 Dock 图标),设置内提供"在程序坞显示"开关 |
| 状态栏图标 | 设置内提供"在状态栏显示图标"开关 |
| Bundle ID | `com.daixingwen.fnbridge`(定死,不再变更) |
| 部署目标 | macOS 13.0 Ventura(全部所需 API 的最低交集) |
| 许可证 | MIT |
| 语言 | 简体中文 + English |

## 4. 架构

### 4.1 代码结构

```
FnBridge/
├── App/
│   ├── FnBridgeApp.swift   @main,注入 AppDelegate
│   └── AppDelegate.swift           NSApplicationDelegate:生命周期、reopen 恢复、形态切换
├── Core/
│   ├── FKeyAction.swift            F 键定义(枚举,纯数据,可单测)
│   ├── KeyMonitor.swift            事件钩子(启动/停止/自愈/节流)
│   └── SystemEventPoster.swift     系统事件发送(aux key / Spotlight / Mission Control)
├── Settings/
│   ├── SettingsView.swift          TabView 三页容器
│   ├── GeneralTab.swift            通用页
│   ├── KeyMappingTab.swift         按键映射页
│   └── PermissionsTab.swift        权限与诊断页
├── MenuBar/
│   └── MenuBarController.swift     NSStatusItem 管理(显示/隐藏/菜单内容)
└── Resources/
    ├── Localizable.xcstrings       双语文案
    └── Assets.xcassets             AppIcon + 状态栏模板图
```

拆分动机:每个文件单一职责,纯逻辑(FKeyAction 判定、键码映射)与副作用(事件发送、UI)分离,前者可单元测试。

### 4.2 运行形态与生命周期

- **启动即工作**:App 启动时自动 `KeyMonitor.start()`(移出现 window 的 onAppear),失败仅记录并在窗口/菜单栏提示
- **默认形态**:`NSApplication.activationPolicy = .accessory`(无 Dock 图标)+ 菜单栏图标常驻
- **两个运行时开关**(通用 Tab):
  - "在程序坞显示" ⇄ `NSApp.setActivationPolicy(.regular / .accessory)`
  - "在状态栏显示图标" ⇄ `MenuBarController` 创建/移除 `NSStatusItem`
  - 两者状态持久化到 UserDefaults
- **防失联保障**:
  - 同时隐藏两处时,先弹确认对话框告知"App 将不可见,重新打开 App 可找回"
  - 实现 `applicationShouldHandleReopen` → 激活并弹出设置窗口;即使图标全部隐藏,从启动台/访达再次打开即找回
- **关窗不退出**:红叉只关窗;⌘Q 退出整个 App
- **开机自启**:`SMAppService.mainApp.register()/unregister()`,通用 Tab 开关

### 4.3 菜单栏菜单

状态栏图标(模板图,自适应明暗)点击弹出:

```
✓ 权限正常            (或 ⚠️ 缺少"输入监控"权限 → 点击跳转系统设置)
─────────────
☐ 启用 F 键转换        (全局总开关,暂停时不拦截任何键)
─────────────
打开设置…
开机自启               (子项开关,与通用 Tab 同步)
─────────────
退出 FnBridge ⌘Q
```

## 5. 设置界面

TabView 三页替代现有单屏,窗口标题"设置",约 560×640 可调:

1. **通用**:总开关、开机自启、程序坞显示、状态栏图标显示、形态切换防失联提示
2. **按键映射**:F1–F12 卡片式布局(键帽样式 + 功能名 + 开关),F5/F6 显示"暂不支持"置灰,保留"恢复默认";底部说明"会拦截所有键盘的标准 F 键码"
3. **权限与诊断**:输入监控/辅助功能状态 + 分步引导(含"完全退出重开"提醒)、最近按键码、最近触发记录

## 6. Review 修复清单

| # | 问题 | 修复 |
|---|---|---|
| 1 | tap 被系统超时禁用后静默死亡 | 回调中处理 `.tapDisabledByTimeout` → `CGEventTapEnable` 重启;`.tapDisabledByUserInput` → 更新状态供 UI 提示 |
| 2 | F5/F6 残留启用状态导致死键 | `isInterceptable = supported && isEnabled`;不支持的键永不拦截 |
| 3 | 0.12s 全局节流吞掉快速连按 | 节流改为每键独立:`[FKeyAction: TimeInterval]` 字典按 action 记录 lastFire,互不影响 |
| 4 | Bundle ID 占位符 | 改为 `com.daixingwen.fnbridge` |
| 5 | 部署目标 27.0 | 降到 13.0 |
| 6 | 全键盘拦截行为未说明 | README + 按键映射页底部说明 |

### 已知限制(README 写明,不修)

- F4 依赖系统 Spotlight 快捷键为默认 ⌘空格;用户改过快捷键则 F4 无效
- 合成亮度事件只对内建/Apple 显示器有效,第三方外接屏不响应
- 无法区分按键来自哪块键盘(需驱动级方案,超出本期)

## 7. 图标(Python 绘制)

- **App 图标**:Python(Pillow)绘制 1024×1024:macOS Big Sur+ 规范(圆角矩形、~82% 安全区、左侧高光);设计:深蓝紫渐变底 + 白色圆角键帽 + "F" 字样(细字重)。`iconutil` 导出全尺寸 icns
- **状态栏图标**:单色模板图(仅黑+透明),键帽/`fn` 造型,16pt、16@2x、18pt、18@2x、32pt/32@2x;代码中以 `isTemplate = true` 使用
- 生成脚本 `tools/make_icons.py` 入库,社区可复现

## 8. 发布要素

- `Localizable.xcstrings`:全部 UI 文案 zh-Hans + en
- `README.md`(双语):简介、截图、安装、权限引导(输入监控 + 辅助功能)、逐键开关说明、已知限制、自签名/公证自助步骤、开发说明
- `LICENSE`:MIT
- `docs/`:本设计文档

## 9. 测试与验收

### 单元测试(纯逻辑)

- FKeyAction:键码 ↔ 枚举映射完整;`isInterceptable` 对 unsupported 恒 false;defaultEnabled 正确
- 启用状态:持久化往返、非法值容错、reset

### 人工验收清单

- [ ] 全部 F1–F12(除 F5/F6)实测生效
- [ ] 关窗后 F 键仍生效;⌘Q 后不生效
- [ ] 隐藏 Dock + 隐藏状态栏 → 提示;重新打开 App 能找回设置窗口
- [ ] 程序坞/状态栏开关切换即时生效且重启后保持
- [ ] 开机自启注册/取消生效
- [ ] 总开关暂停后不拦截任何键
- [ ] 挂机 ≥1 小时(含触发数次超时)后 F 键仍生效
- [ ] 系统语言切英文后界面完整英文
