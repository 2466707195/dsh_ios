# DSH iOS — DeepSeek Harness 复刻 iOS 客户端

基于 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)（Android/Flutter 版）复刻的 **iOS 客户端**。采用与原项目相同的技术栈 **Flutter**，最大化代码复用。

## ✅ 已实现的真实功能

| 功能 | 状态 | 说明 |
|---|---|---|
| **DeepSeek 流式对话** | ✅ | SSE 流式，打字机效果，真实调用官方 API |
| **思考链展示** | ✅ | 折叠卡片显示 `reasoning_content`（v4 思考模型） |
| **多会话管理** | ✅ | 新建/切换/删除/自动标题，本地持久化 |
| **Markdown + 代码高亮** | ✅ | `flutter_markdown` + `flutter_highlight` |
| **API Key 安全存储** | ✅ | 存入 iOS Keychain（`flutter_secure_storage`） |
| **连接测试** | ✅ | 一键校验 apiKey/model 是否可用 |
| **停止生成** | ✅ | 生成中可中断 |
| **中英双语** | ✅ | 跟随系统 |

## ⚠️ 与原项目的差异（iOS 平台限制）

原项目依赖 Android 专属能力，**iOS 沙盒/系统策略无法实现**，故未纳入：

- ❌ **手机本机跑 Linux 环境**（PRoot）— iOS 禁止子进程/挂载
- ❌ **手机操控（无障碍读取屏幕/点按）** — iOS 无等效无障碍接口
- ❌ **SSH 遥控电脑 DSH / WebRTC 远程** — 可实现但本复刻聚焦对话核心，未含
- ❌ **Live2D 伙伴 / 桌宠 / 插件系统** — 非核心，未纳入

> 说明：本客户端直接连 **DeepSeek 官方 API**（OpenAI 兼容），这是"能真实使用"最稳妥的落地方式；连自建 DSH-Web 的部分可后续按 `dsh_client` 协议扩展。

## 🚀 运行步骤（需 macOS + Xcode）

本工程在 Windows 上编写，**编译 iOS 需在 Mac 上进行**：

```bash
# 1. 安装 Flutter（若未安装）
# https://docs.flutter.dev/get-started/install/macos

# 2. 进入工程目录
cd dsh_ios

# 3. 拉取依赖
flutter pub get

# 4. 连接 iPhone 或启动模拟器
flutter devices

# 5. 运行
flutter run
# 或指定 iOS
flutter run -d iphone
```

### 首次配置
1. 打开 App → 底部「设置」Tab
2. 填入 DeepSeek **API Key**（在 [platform.deepseek.com](https://platform.deepseek.com) 申请）
3. Base URL 保持默认 `https://api.deepseek.com`
4. 选择模型（推荐 `deepseek-flash`）
5. 点「保存」→「测试连接」确认 ✅
6. 回到「对话」Tab 即可开始聊天

## 📁 工程结构

```
dsh_ios/
├── lib/
│   ├── main.dart                    # 入口 + 底部 Tab 导航
│   ├── models/
│   │   ├── chat_message.dart        # 消息模型（含思考链）
│   │   ├── conversation.dart        # 会话模型
│   │   └── app_settings.dart        # API 配置
│   ├── services/
│   │   ├── deepseek_service.dart    # DeepSeek API 客户端（SSE 流式）
│   │   └── storage_service.dart     # 本地持久化（Keychain + SharedPreferences）
│   ├── providers/
│   │   ├── storage_provider.dart    # 存储 Provider（唯一来源）
│   │   ├── settings_provider.dart   # 设置状态
│   │   └── conversation_provider.dart # 会话/生成状态机
│   ├── screens/
│   │   ├── chat_screen.dart         # 对话页
│   │   ├── conversations_screen.dart# 历史列表页
│   │   └── settings_screen.dart     # 设置页
│   └── widgets/
│       ├── message_bubble.dart      # 消息气泡 + Markdown + 思考链
│       └── chat_input_bar.dart      # 输入栏
└── ios/
    └── Runner/
        ├── Info.plist               # iOS 配置（含 ATS 放行）
        └── AppDelegate.swift        # 入口
```

## 🔧 技术栈

- **Flutter 3.27+** / Dart 3.5+
- **状态管理**：flutter_riverpod（AsyncNotifier）
- **网络**：http（SSE 流式解析）
- **存储**：shared_preferences + flutter_secure_storage（Keychain）
- **Markdown**：flutter_markdown + flutter_highlight

## 📝 说明

- `ios/Runner/AppDelegate_v2.swift` 为备用入口写法（适配不同 Flutter 版本的 `@main` 标注），实际以 `AppDelegate.swift` 为准，可手动删除多余文件。
- 工程未提交 Xcode 工程文件（`.xcodeproj`），首次在 Mac 上执行 `flutter create .` 可自动补全 iOS 工程骨架（不会覆盖已有 lib/）：
  ```bash
  cd dsh_ios && flutter create --org com.dsh --project-name dsh_ios .
  ```
- API Key 仅存本地 Keychain，不上传任何服务器。
