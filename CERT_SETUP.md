# 配置 Apple 证书 → CI 出真机 .ipa

本工作流用你的 Apple 证书在 GitHub Actions 上签名并导出可装真机的 `.ipa`。
**证书只放在仓库 Secrets 里，代码/日志不会出现明文。**

## 一、需要的 6 个 Secrets

到仓库 **Settings → Secrets and variables → Actions → New repository secret** 逐个添加：

| Secret 名 | 值 | 说明 |
|---|---|---|
| `APPLE_CERTIFICATE_BASE64` | `.p12` 证书，base64 编码 | 见下「生成 .p12」 |
| `APPLE_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设的密码 | |
| `APPLE_PROVISION_PROFILE_BASE64` | `.mobileprovision`，base64 编码 | 见下「生成描述文件」 |
| `APPLE_TEAM_ID` | 10 位 Team ID | 见下「查 Team ID」 |
| `APPLE_BUNDLE_ID` | 如 `com.dsh.dshIos` | 必须与描述文件里的 Bundle ID 一致 |
| `APPLE_EXPORT_METHOD` | `ad-hoc` | 真机分发用 ad-hoc；上架用 app-store |

### base64 编码命令
- **macOS**：`base64 -i cert.p12 | pbcopy`
- **Windows (PowerShell)**：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Set-Clipboard`
- **Windows (cmd)**：`certutil -encode cert.p12 out.txt`（取 out.txt 中间正文，去掉 `-----BEGIN/END-----` 头尾）

## 二、获取这些文件

### 1. 查 Team ID
登录 [developer.apple.com/account](https://developer.apple.com/account) → **Membership details** → 复制 **Team ID**（10 位）。

### 2. 生成 .p12 证书
需要一台 Mac（或用 Windows 的 OpenSSL）：
1. 打开 **钥匙串访问** → 菜单 **证书助理 → 从证书颁发机构请求证书**，填邮箱，存到磁盘（生成 `.certSigningRequest`）。
2. 到 [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates) → **+** → 选 **Apple Distribution**（真机分发）或 **iOS Development** → 上传 `.certSigningRequest` → 下载 `.cer`。
3. 双击 `.cer` 导入钥匙串 → 在钥匙串里找到该证书 → 右键 **导出**，格式选 `.p12`，设一个密码 → 得到 `cert.p12`。

### 3. 生成描述文件 (.mobileprovision)
1. 确保你的测试 iPhone 的 **UDID** 已注册到开发者账号（ad-hoc 分发必须）。
2. 到 [Profiles](https://developer.apple.com/account/resources/profiles) → **+** → 选 **iOS App Development** 或 **Ad Hoc** → 选 App ID（Bundle ID 需为 `com.dsh.dshIos`，没有就先在 Identifiers 里创建）→ 勾选你的证书 + 勾选你的设备 → 下载 `.mobileprovision`。

> **Bundle ID 说明**：工作流会把工程 Bundle ID 改成 `APPLE_BUNDLE_ID`。最简单是固定用 `com.dsh.dshIos`，并在开发者后台为它建 App ID + 描述文件。

### 4. 注册测试设备（ad-hoc 必须）
[iPhone 的 UDID 查询](https://www.udid.io) → 到开发者后台 **Devices** 添加 → 重新生成描述文件并勾选该设备。

## 三、触发构建

配好 6 个 Secrets 后，二选一：
- **手动**：Actions → **iOS Build (signed)** → **Run workflow**
- **自动**：推一个改动 `lib/`、`ios/` 或 `pubspec.yaml` 的 commit

构建成功后在 **Artifacts** 下载 **`dsh-ios-signed-ipa`**（`.ipa`）。

## 四、装到真机

`.ipa` 已用你的证书签名，任选：
- **Sideloadly / AltStore**：拖入 `.ipa` → 连 iPhone → 安装（最简单）
- **Xcode**：Devices → 拖入 `.ipa`
- **命令行**：`xcrun devicectl device install app --device <UDID> dsh-ios.ipa`

## 五、常见报错

| 现象 | 原因 / 解决 |
|---|---|
| `No valid code signing certificates were found` | `.p12` 或密码不对；确认 `APPLE_CERTIFICATE_PASSWORD` 是导出时设的密码 |
| `no profiles for ... matching` | 描述文件 Bundle ID ≠ `APPLE_BUNDLE_ID`；或设备未勾选 |
| `Provisioning profile doesn't include signing certificate` | 生成描述文件时没勾选你的 `.p12` 证书，重新生成并勾选 |
| 安装到真机提示"不受信任" | 设备需在 设置 → 通用 → VPN与设备管理 里信任你的证书 |
| 免费 Apple ID 能用吗 | 可以，但只能用 Xcode 本地构建（7 天有效、限自己设备）；CI 签名需付费开发者账号 |

## 六、没有开发者账号的替代

免费 Apple ID 只能在 **本地 Mac + Xcode** 构建（`flutter run` / `flutter build ipa`），Xcode 会自动用"个人团队"签名。CI 无法用免费 Apple ID 出包。
