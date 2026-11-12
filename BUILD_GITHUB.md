# 用 GitHub Actions 构建未签名 iOS IPA

本工程自带 `.github/workflows/ios.yml`，用 GitHub 免费的 **macOS runner** 编译并产出**未签名 `.ipa`**，你下载后自行用 Apple 证书签名/侧载。无需本地 Mac。

## 使用步骤

1. 把整个 `dsh_ios/` 推到你的 GitHub 仓库：
   ```bash
   cd dsh_ios
   git init && git add -A && git commit -m "dsh iOS 复刻"
   git remote add origin https://github.com/<你>/dsh_ios.git
   git push -u origin main
   ```
2. 推送 `main` 自动触发 **iOS Build**（也可到 Actions 页手动 **Run workflow**）。
3. 跑完在 **Actions → 该次运行 → Artifacts** 下载 **`dsh-ios-unsigned-ipa`**（未签名 `.ipa`）。
   - 同处也有 `dsh-ios-unsigned-app`（裸 `Runner.app`），二选一即可。

## 工作流做了什么

| 步骤 | 命令 / 作用 |
|---|---|
| `flutter create --platforms=ios` | 仓库 `lib/` 已存在，此命令只补齐 iOS 工程骨架（`project.pbxproj`、`Podfile`、`Assets.xcassets`），**不覆盖已有代码** |
| `flutter pub get` | 拉取依赖 |
| `pod install` | 安装 iOS 原生依赖（flutter_secure_storage 等） |
| `flutter build ios --release --no-codesign` | 无签名编译，产出 `Runner.app` |
| 打包 | `Payload/Runner.app` → zip 成 `dsh-ios-unsigned.ipa` |
| 上传 Artifact | 供你下载 |

## ⚠️ 关键：未签名 .ipa 不能直接装真机

iOS 强制代码签名，**未签名 `.ipa` 无法直接安装**。它只是把编译产物按 ipa 规范打包好，方便你拿到后自行签名。签名方式任选：

### 方式 1：用开发者证书重签（命令行）
```bash
# 解压
unzip dsh-ios-unsigned.ipa -d extracted
# 用自己的证书 + 描述文件重签（需 macOS + 已导入钥匙串的证书）
codesign -f -s "你的证书名" \
  --provisioning-profile 你的.mobileprovision \
  extracted/Payload/Runner.app
# 重新打包
cd extracted && zip -qry ../dsh-signed.ipa Payload
```

### 方式 2：用侧载工具（推荐，最省事）
用 [AltStore](https://altstore.io) 或 [Sideloadly](https://sideloadly.io) 直接打开未签名 `.ipa`，工具会自动用你的 Apple ID 签名并安装到真机。
- 免费 Apple ID 即可（签名 7 天有效，仅限自己设备）。
- 付费开发者账号可签出更长有效期/可分发的包。

### 方式 3：Xcode
把 `Payload/Runner.app` 拖进 Xcode Devices 安装，或直接在 Mac 上 `flutter run` 让 Xcode 自动签名。

## 常见问题

- **Flutter 版本**：工作流锁定 `3.27.4`，与 `pubspec.yaml` 约束对齐；如需改版本，编辑 workflow 里的 `flutter-version`。
- **构建失败**：先看 `flutter analyze` 步骤（已设为 `--no-fatal-infos --no-fatal-warnings`，仅提示不阻断），真正失败看 `Build iOS` 日志。
- **想要已签名可直装的包**：需在 CI 配置你的证书 Secrets 或本地 `flutter build ipa`，本工作流按需求只产出未签名包。
