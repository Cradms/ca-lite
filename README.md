# CA Lite

长安车控 iOS 原生客户端（SwiftUI + WidgetKit），按 **长安车控 4.5.6 小组件版** 的
`Api.java` 协议复刻。轻量、不依赖自建服务器、无 WebView。

- 首页按 Android `HomeActivity` **1:1 复刻**：车辆卡（车名 + 剩余续航 + 蓝牙钥匙/刷新）、
  状态两行（发动机 · 车锁 / 逐项车窗 · 天窗 · 后备箱）、位置卡、全宽蓝牙钥匙按钮、
  全景照片·行车轨迹双列、7 组控车按钮（52pt 白底圆角 10）、footer 提示
- 车况 / 控车 / 位置 / 轨迹 / 记录 / 保养 / 消息，单 App 完成
- 桌面小组件：按车型显示车模图 + 续航 + 门锁，支持快捷控车
- 车型归一化：车名/车架号 → 12 个车型代码 → 对应车模图

## 工程结构

```
ca-lite/
├── project.yml               XcodeGen 定义（CaLite + CaLiteWidget）
├── CaLite/
│   ├── CarAPI.swift          接口层（登录/车况/控车/轨迹/记录/照片）
│   ├── CarModel.swift        车型归一化 + 中文名
│   ├── AppGroupStore.swift   App → 小组件共享状态
│   ├── RSACrypto.swift       RSA-OAEP(SHA256)，SPKI → PKCS#1
│   ├── CarHomeView.swift     首页
│   ├── LoginView.swift       短信验证码登录 + 控车码
│   ├── LocationView.swift    车辆位置 / 导航
│   ├── ExtraViews.swift      轨迹 / 记录 / 全景照片
│   ├── FuelView / MaintainView / MoreView
│   ├── RootView / AppDelegate
│   └── Assets.xcassets       13 张车型图 + 通用车模图
└── CaLiteWidget/             小组件（同名车型图副本）
```

标识符：

| 项 | 值 |
| --- | --- |
| App Bundle ID | `com.yg.calite` |
| Widget Bundle ID | `com.yg.calite.widget` |
| App Group | `group.com.yg.calite` |
| URL Scheme | `calite://` |

> 换自己的开发者账号时，App Group 需要在 Apple Developer 后台新建，并在两个
> entitlements 与 `Prefs.group` / `Shared.group` 里改成一致的值。

## 编译

```bash
brew install xcodegen
xcodegen generate
open CaLite.xcodeproj
```

Xcode 里选 Team → 真机运行，或 `Product > Archive` 导出 IPA。

命令行出未签名 IPA：

```bash
xcodegen generate
xcodebuild -project CaLite.xcodeproj -scheme CaLite -configuration Release \
  -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/CaLite.app Payload/
zip -qry CaLite-unsigned.ipa Payload
```

再自签（AltStore / Sideloadly / 自签证书）安装。

### 云端编译（GitHub Actions 不可用时用 Codemagic）

仓库带 `codemagic.yaml`，两条工作流：

- `ca-lite-unsigned`：push main 自动编译，产出 `CaLite-unsigned.ipa`
- `ca-lite-signed`：先在 Codemagic → Code signing identities 上传 p12 与 profile，再跑这条出已签名 IPA

在 Codemagic 里 Add application → 选 GitHub 仓库 → 它会自动读到这两条工作流。

> 注：本账号的 GitHub Actions runner 目前起不来（push 后立即 cancelled），所以 CI 出包走 Codemagic 或本地 Xcode。

## 接口说明

| 通道 | 域名 | 用途 |
| --- | --- | --- |
| 老通道 | `m.iov.changan.com.cn` | 短信登录、车况、控车、轨迹、记录、照片 |
| 开放平台 | `open.iov.changan.com.cn` | 扫码 OAuth、车型信息、VCS 签名接口 |
| 续期 | `incallapi.changan.com.cn` | refresh_token |

控车：`createPinVerifyCode → v2/security/key（SPKI 拆 PKCS#1）→ RSA-OAEP(SHA-256) 加密
{pinVerifyCode,cmd,type,pin} → v3/control/execute → getControlInfo 轮询`。

支持指令：`OpenEngine / CloseEngine / LockDoor / UnLockDoor / OpenWindow / WindowSlit /
CloseWindow / OpenDormer / CloseDormer / SkyWindowLiftUp / openAir / closeAir /
FlashLight / RemoteSearchCar / Whistle`。

## 已知限制

- 蓝牙钥匙（Android 端 `BleKeyClient.java` 的 BLE GATT 协议）未移植，需车端密钥与实车抓包
- 车况字段随车型/固件不同而缺失，界面按实际返回显示，空值 `--`
- 未在实车逐条验证，接口解析带多字段名与多层 data 兜底

## 签名（Widget 能不能用就看这一步）

小组件靠 **App Group** 和主 App 共享数据：`group.com.yg.calite`。
App Group 属于付费开发者账号能力，**免费 Apple ID 建不了**，所以：

| 安装方式 | 主 App | 小组件 |
| --- | --- | --- |
| Codemagic 已签名 IPA（付费账号） | ✅ | ✅ |
| Xcode 免费账号直连（7 天） | ✅ | ❌ 读不到数据 |
| AltStore / Sideloadly 自签 | ✅ | ❌ `.appex` 重签后失效 |
| TrollStore 安装未签名 IPA | ✅ | ✅ 保留 entitlements |

### 出已签名 IPA（付费账号）

1. **developer.apple.com → Identifiers**
   - 新建 App ID `com.yg.calite`，Capabilities 勾 **App Groups**
   - 新建 App ID `com.yg.calite.widget`，同样勾 **App Groups**
2. **App Groups** → 新建 `group.com.yg.calite` → 回到两个 App ID 里勾上这个组
3. **Certificates** → 建 `Apple Distribution` → 下载后在钥匙串里导出 `.p12`（设个密码）
4. **Profiles** → 建两个 **Ad Hoc** profile：
   - 一个绑 `com.yg.calite`
   - 一个绑 `com.yg.calite.widget`
   - 都选同一张证书 + 勾上你设备的 UDID
5. **Codemagic → 项目 → Code signing identities**：上传 1 个 `.p12` + 2 个 `.mobileprovision`
6. Codemagic 选 **CA Lite · 已签名 IPA** → Start

产物在 `build/ios/ipa/`，直接 AirDrop / 爱思助手装。

> 设备 UDID 获取：手机连 Mac → 访达 → 设备信息（点两下版本号显示 UDID），
> 或 https://udid.tech 用 Safari 装描述文件读取。
