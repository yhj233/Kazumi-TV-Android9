<div align=center>

<h1>Kazumi</h1>

<img src="assets/images/logo/logo_rounded.png" width=200></img>

<a href="https://t.me/kazumi_app"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white"></img></a>

<img src="https://img.shields.io/badge/Flutter-03A9F4?style=for-the-badge&logo=flutter&logoColor=white"></img>
<img src="https://img.shields.io/badge/Dart-00B4AB?style=for-the-badge&logo=Dart&logoColor=white"></img>

<a href="https://trendshift.io/repositories/11432"><img src="https://trendshift.io/api/badge/trendshift/repositories/11432/yearly?language=Dart"></img></a>
<a href="https://hellogithub.com/repository/Predidit/Kazumi" target="_blank"><img src="https://abroad.hellogithub.com/v1/widgets/recommend.svg?rid=68d824ea55ee4b07aba6fe1dd61ac939&claim_uid=J9Qu6aDd8LT1nU0"/></img></a>

<p>使用 Flutter 开发的基于自定义规则的番剧采集与在线观看程序。使用最多五行基于 <code>Xpath</code> 语法的选择器构建自己的规则。支持规则导入与规则分享。支持基于 <code>Anime4K</code> 的实时超分辨率。绝赞开发中 (～￣▽￣)～</p>
</div>

## 支持平台

- Android 7.0 及以上（本仓库已适配 Android 9 电视盒子）
- Windows 10 及以上
- MacOS 10.15 及以上
- Linux (实验性)
- iOS 13 及以上 (需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ios))
- HarmonyOS 5.0 及以上 (位于 [分支仓库](https://github.com/ErBWs/Kazumi/releases/latest)，需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ohos))

## 本仓库说明（Android TV / Android 9 适配版）

这是 [`Predidit/Kazumi`](https://github.com/Predidit/Kazumi) 的移植分支，目标是让 Kazumi 运行在 **Android 9 (API 28) 的 Android TV 盒子**上。应用代码与上游保持一致，只做了最小必要改动：

| 改动 | 文件 | 说明 |
| --- | --- | --- |
| 固定 minSdk 为 24 | `android/app/build.gradle` | 上游跟随 `flutter.minSdkVersion`，会随 Flutter 升级不断抬高；固定为 24（Android 7.0）可稳定覆盖 Android 7 / 8 / 9 |
| 增加 TV 支持 | `android/app/src/main/AndroidManifest.xml` | `touchscreen` / `leanback` / `gamepad` 声明为非必需，注册 `LEANBACK_LAUNCHER`，新增 320x180 TV 横幅 |
| 新增云编译流水线 | `.github/workflows/build-android-tv.yml` | 只构建 Android，按 CPU 架构拆分打包，**每种架构单独上传为一个 artifact**（约 32 MB，方便下载） |

### 安装

到 [Actions](../../actions) 页面下载最新一次构建产物。每种架构是**独立**的 artifact，只下你需要的那个即可：

| artifact | 适用设备 |
| --- | --- |
| `Kazumi-TV-<版本>-armeabi-v7a` | 32 位 ARM 盒子（绝大多数老旧 / 中低端电视盒子） |
| `Kazumi-TV-<版本>-arm64-v8a` | 64 位 ARM 盒子（较新的盒子，如晶晨 S905X3 及以上） |
| `Kazumi-TV-<版本>-x86_64` | x86 盒子 / 模拟器 |
| `Kazumi-TV-<版本>-universal` | 内含全部架构，任何设备都能装，但体积约 170 MB，**默认不构建** |

> 不确定架构时，在盒子上执行 `adb shell getprop ro.product.cpu.abi` 查看。

手动触发构建时可在 `abi` 下拉框里指定只构建某一种架构；勾选 `publish_release` 还会把 APK 发布为 Release，得到可直接下载的 `.apk` 直链（无需下载 zip 再解压）。

若设备上已装过其它签名的 Kazumi，需先卸载（签名不同无法覆盖安装）。

### 已知限制

- **AV1 编码的视频在低端盒子上无法正常播放（硬件限制，非软件问题）**。
  实测咪咕 MGV3201-ZG（国科微 GK6323，4×Cortex-A9，2GB RAM）：
  系统的 `media_codecs.xml` 只声明 `video/avc` / `video/hevc` / `video/x-vnd.on2.vp9`，
  **没有 `video/av01`**；而部分番剧源（如 mgnacg）下发的是 **1080p AV1**（MP4 里 `ftyp` 带 `isomav01`）。
  > 播放器只能回退 dav1d 软解，4 个核会被打满（实测 330%/400%），
  > 日志持续输出 `Audio device underrun detected`，表现为黑屏很久才出画面、之后音画卡顿。
  >
  > 遇到这种情况请**更换规则/线路**，选择 H.264（avc）或 H.265（hevc）片源即可硬解流畅播放。
  > 由于软解时播放器可能既不报错也不出画面，本移植版会主动探测解码路径：
  > 一旦确认「AV1 + 软解」或「输出帧率低于片源帧率一半」或「40 秒拿不到时长」
  > 或「画面停滞 16 秒」，会在播放页弹出提示，直接告诉你换线路，而不是让你对着黑屏干等。
  > 查看当前片源编码：打开「设置 → 播放设置 → 诊断 → 调试模式」，日志里会打印
  > `解码路径 codec=... hwdec=...`；也可以直接把视频直链发给 PC 用 `ffprobe` 查看。

- **个别片源 CDN 首次请求极慢**（实测 `play.mknacg.top:9009` 等响应头要 **2 分 45 秒**，
  拿到响应后 1 秒内就开始播放）。这类等待发生在 TLS/HTTP 层，
  mpv 的 `network-timeout` 也管不到「等响应头」，所以只能靠提示 + 重试缓解：
  应用会在 40 秒、16 秒停滞时给出提示，并在失败后自动重试最多 3 次。

- **续播进度可能触发 TLS 握手被拒**：打开成功后 mpv 会为上次进度（例如 558 秒 → 字节 134MB）
  新建一条 Range 连接，部分 CDN 会直接拒绝握手
  （日志：`tls: mbedtls_ssl_handshake returned -0x4e` → `Seek failed` → 一直 `buffering`）。
  本移植版第 2 次起的自动重试会**放弃续播位置、从头播放**，并提示「已从头开始播放」，
  避免卡在 seek 重试循环里永远不出画面。

- **AGE 等部分规则在本机网络上完全无法解析**（2026-10 实测）：这类站点把播放器依赖的
  `app.js` 放在独立 CDN（如 `xcdn.khfed.com:8443`）上，而该域名在当前网络下 **TLS 握手被
  按 SNI 重置**——不带 SNI 或换成别的 SNI 都能握手成功，唯独带 `xcdn.khfed.com` 时 8 次里
  只成功 1 次。后果是页面里 `AGE` 这个全局对象没有定义（控制台：
  `Uncaught ReferenceError: AGE is not defined`），播放器根本不会初始化，最终表现为
  「视频解析超时」。这与 Android 版本无关，同一局域网内的 PC 用 curl 一样连不上。

  > 本移植版会把 WebView 的控制台/网络错误收集起来，超时后直接告诉你原因，例如
  > 「播放来源「AGE」的解析接口或脚本加载失败（源站不可用），请换一个播放来源」，
  > 而不是一句无用的「解析超时」。

- **WebView 版本偏老会影响部分源**：本机系统 WebView 是 Chrome 66（2018 年），
  少数站点用了更新的 JS 语法会直接报 `SyntaxError`，同样表现为解析超时。
  Android 9 允许手动升级 WebView（侧载新版 `com.android.webview` APK）来缓解。

- **局域网存在 MTU 黑洞**（实测：到外网 1450 字节的包被静默丢弃，1400 才通，网关本身 1500 正常）。
  这会让 TLS 握手的大包丢失、表现为「连接重置」或极慢。如果遇到大面积连接异常，
  可临时在盒子上执行 `su -c 'ip link set wlan0 mtu 1400'` 验证；根治要在路由器上
  改成 1492 以下的 MTU 或启用 MSS 钳制。

- **弹幕**需要 DanDanPlay 开放平台的凭据。在仓库 `Settings → Secrets and variables → Actions` 添加
  `DANDANAPI_APPID` / `DANDANAPI_KEY`（可选 `KAZUMI_APPID` / `KAZUMI_KEY`）后重新触发构建即可启用；
  未配置时应用可正常使用，仅弹幕功能不可用。
- 遥控器操作沿用 Flutter 默认的焦点导航，部分触屏手势界面建议配合鼠标 / 飞鼠使用。

### 关于签名

本仓库在 `android/keystore/kazumi-tv-release.jks` 内置了一份**固定的 release 签名密钥**，
`android/app/build.gradle` 会优先使用它（文件缺失时自动退回 debug 签名）。

这样做的原因：之前用 `signingConfigs.debug`，而 GitHub Actions 的 runner 每次都会重新生成
debug keystore，导致**每次构建的签名都不一样**，安装时会报
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`，必须先卸载（会清空所有设置和观看记录）。

> 注意：该 keystore 随仓库公开。它只用于本仓库的侧载包身份识别，
> 不影响任何账号安全；若你介意，可以换成自己的密钥并改用仓库 Secrets 注入。

从旧版本（临时 debug 签名）升级到本版本时仍需卸载一次，之后即可直接覆盖安装。


## 屏幕截图

<table>
  <tr>
    <td><img alt="homepage" src="static/screenshot/img_1.png"></td>
    <td><img alt="timetable" src="static/screenshot/img_2.png"></td>
    <td><img alt="details" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="selection-page" src="static/screenshot/img_4.png"></td>
    <td><img alt="rules-mange" src="static/screenshot/img_5.png"></td>
    <td><img alt="rules-edit" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

- [X]  规则编辑器
- [X]  番剧目录
- [X]  番剧搜索
- [X]  番剧时间表
- [X]  番剧字幕
- [X]  分集播放
- [X]  视频播放器
- [X]  多视频源支持
- [X]  规则分享
- [X]  硬件加速
- [X]  高刷适配
- [X]  追番列表
- [X]  番剧弹幕
- [X]  在线更新
- [X]  历史记录
- [X]  倍速播放
- [X]  配色方案
- [X]  跨设备同步
- [X]  无线投屏 (DLNA)
- [X]  外部播放器播放
- [X]  超分辨率
- [X]  一起看
- [X]  番剧下载
- [ ]  番剧更新提醒
- [ ]  还有更多 (/・ω・＼)

## 下载

通过本页面 [Releases](https://github.com/Predidit/Kazumi/releases/latest) 选项卡下载：

<a href="https://github.com/Predidit/Kazumi/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

### Android

<a href="https://f-droid.org/packages/com.predidit.kazumi">
  <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-zh-hans.svg"
  alt="Get it on F-Droid" width="200">
</a>

### GNU/Linux

<a href="https://flathub.org/apps/io.github.Predidit.Kazumi">
  <img src="https://flathub.org/api/badge?svg&locale=zh-Hans" alt="Get it on Flathub" width="175"/>
</a>

#### Arch Linux

可以从 [AUR](http://aur.archlinux.org) 安装。

##### AUR

```bash
[yay/paru] -S kazumi # 从源码构建
[yay/paru] -S kazumi-bin # 二进制包
```

## 贡献

欢迎向我们的 [规则仓库](https://github.com/Predidit/KazumiRules) 提交您的自定义规则。您可以自由选择是否在规则中留下您的ID。详细的规则编写教程可以参考 [规则开发文档](https://kazumi.app/docs/rules/develop-rules)

## Q&A

<details>
<summary>使用者 Q&A</summary>

#### Q: 为什么少数番剧中有广告？

A: 本项目未插入任何广告。广告来自视频源, 请不要相信广告中的任何内容, 并尽量选择没有广告的视频源观看。

#### Q: 为什么我启用超分辨率功能后播放卡顿？

A: 超分辨率功能对 GPU 性能要求较高, 如果没有在高性能独立显卡上运行 Kazumi, 尽量选择效率档而非质量档。对低分辨率视频源而非高分辨率视频源使用超分也可以降低性能消耗。

#### Q: 为什么播放视频时内存占用较高？

A: 本程序在视频播放时, 会尽可能多地缓存视频到内存, 以提供较好的观看体验。如果您的内存较为紧张, 可以在播放设置选项卡启用低内存模式, 这将限制缓存。

#### Q: 为什么少数番剧无法通过外部播放器观看？

A: 部分视频源的番剧使用了反盗链措施, 这可以被 Kazumi 解决, 但无法被外部播放器解决。

#### Q: 为什么下载的 Linux 版本缺少图标和托盘功能？

A: 使用 .deb 版本进行安装, tar.gz 版本仅为方便二次打包, 这一格式先天缺乏图标和托盘功能支持。

</details>

<details>
<summary>规则编写者 Q&A</summary>

#### Q: 为什么我的自定义规则无法实现检索？

A: 目前我们对 `Xpath` 语法的支持并不完整, 我们目前只支持以 `//` 开头的选择器。建议参照我们给出的示例规则构建自定义规则。

#### Q: 为什么我的自定义规则可以实现检索, 但不能实现观看？

A: 尝试关闭自定义规则的使用内置播放器选项, 这将尝试使用 `webview` 进行播放, 提高兼容性。但在内置播放器可用时, 建议启用内置播放器, 以获得更加流畅并带有弹幕的观看体验。

</details>

<details>
<summary>开发者 Q&A</summary>

#### Q: 我在尝试自行编译该项目, 但编译没有成功。

A: 本项目编译需要良好的网络环境, 除了由 Google 托管的 Flutter 相关依赖外, 本项目同样依赖托管在 MavenCentral/Github/SourceForge 上的资源。如果您位于中国大陆, 可能需要设置恰当的镜像地址。

</details>

## 开发

欢迎您提交 PR！在开始之前, 请阅读 [贡献指引](static/doc/CONTRIBUTING.md) 以了解我们对 PR 和 AI 参与辅助开发的规定。

## 美术资源

本项目图标来自 [Yuquanaaa](https://www.pixiv.net/users/66219277) 发表在 [Pixiv](https://www.pixiv.net/artworks/116666979) 上的作品。

此图标由其原作者 [Yuquanaaa](https://www.pixiv.net/users/66219277) 拥有版权。我们已获得原作者的授权和许可, 可以在本项目中使用这一图标。这一图标不是自由使用的, 未经原作者明确授权, 任何人不得擅自使用、复制、修改或分发这一图标。

本项目内嵌字体为 [Mi Sans](https://hyperos.mi.com/font/zh/details/sc/) 字体, 由 [Xiaomi](https://www.mi.com/index.html) 开发和拥有版权。

## 免责声明

本项目基于 GNU 通用公共许可证第 3 版（GPL-3.0）授权。我们不对其适用性、可靠性或准确性作出任何明示或暗示的保证。在法律允许的最大范围内, 作者和贡献者不承担任何因使用本软件而产生的直接、间接、偶然、特殊或后果性的损害赔偿责任。

使用本项目需遵守所在地法律法规, 不得进行任何侵犯第三方知识产权的行为。因使用本项目而产生的数据和缓存应在24小时内清除, 超出 24 小时的使用需获得相关权利人的授权。

## 隐私政策

我们不收集任何用户数据, 不使用任何遥测组件。

## 代码签名策略

提交者: [贡献者](https://github.com/Predidit/Kazumi/graphs/contributors)
审阅者: [所有者](https://github.com/Predidit)

## 赞助


| ![signpath](https://signpath.org/assets/favicon-50x50.png)                                                                                                                      | Free code signing on Windows provided by[SignPath.io](https://about.signpath.io/), certficate by [SignPath Foundation](https://signpath.org/) |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://kilo.ai/favicon/favicon.svg" width="50">                                                                                                                      | **Automatic PR review provided by [Kilo Code](https://kilo.ai/), sponsored by the [Kilo OSS Program](https://kilo.ai/oss)**                   |
| <a href="https://m.do.co/c/0062035db3e4"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_icon_blue.svg" width="50" height="50"></a> | **Cloud infrastructure is supported by [DigitalOcean](https://m.do.co/c/0062035db3e4)**                                                       |

## 致谢

特别感谢 [XpathSelector](https://github.com/simonkimi/xpath_selector) 这个优秀的项目是本项目的基石。

特别感谢 [弹弹play](https://www.dandanplay.com/) 本项目使用了 弹弹play开放平台 以提供弹幕交互。

特别感谢 [Bangumi](https://bangumi.tv/) 本项目使用了 Bangumi 开放 API 以提供番剧元数据。

特别感谢 [Anime4K](https://github.com/bloc97/Anime4K) 本项目使用 Anime4K 进行实时超分。

特别感谢 [SyncPlay](https://github.com/Syncplay/syncplay) 本项目使用 SyncPlay 协议并通过 SyncPlay 公共服务器实现一起看功能。

特别感谢 [所有贡献者](https://github.com/Predidit/Kazumi/graphs/contributors) 本项目因为你们变得更好。

特别感谢 [trace.moe](https://trace.moe) 本项目使用了 trace.moe 提供的图片识别番剧功能。

感谢 [media-kit](https://github.com/media-kit/media-kit) 本项目跨平台媒体播放能力来自 media-kit。

感谢 [avbuild](https://github.com/wang-bin/avbuild) 本项目使用了来自 avbuild 的树外补丁实现非标准视频流播放。

感谢 [hive](https://github.com/isar/hive) 本项目持久化储存能力来自 hive。
