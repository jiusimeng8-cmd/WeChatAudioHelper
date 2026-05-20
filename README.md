# WeChatAudioHelper

**English** | [中文](#中文)

WeChatAudioHelper is a lightweight Windows utility that automatically restores
system volume and WeChat mixer volume after WeChat voice input or voice messages
unexpectedly lower the volume.

Keywords: WeChat volume restore, WeChat voice input volume fix, Windows audio
helper, PowerShell audio session, 微信音量恢复, 微信语音输入音量变小, 微信麦克风音量修复.

## Why

After I started doing more vibe coding, I tried a lot of voice input tools and
eventually found that WeChat voice input still worked best for me. The annoying
part was that when I listened to music and pressed the WeChat voice input
shortcut, WeChat would lower the volume to 5% and sometimes never restore it.

I built this small helper with AI to work around that problem. I am not sure
whether this is only my setup or a common WeChat/Windows behavior, but I hope it
can remove a small daily frustration for people who run into the same thing.

Technically, the helper keeps a recent safe volume baseline and restores it when
WeChat recording stops.

## Features

- Restores Windows system master volume after WeChat recording ends.
- Restores WeChat mixer session volume.
- Detects WeChat capture sessions from the default recording device.
- Runs locally with no network service and no account login.
- Provides a PowerShell core script plus an optional WinForms tray shell.
- Supports current-user startup from the tray menu.
- Caps script and tray logs at about 10 MB each, with one `.old` backup.
- Does not intentionally lower volume.
- Does not read or restore mute state, to avoid muting the system or WeChat by mistake.

## Requirements

- Windows
- Windows PowerShell 5.1 or newer
- WeChat desktop client
- Optional for tray shell builds: .NET 6 SDK or newer with Windows Desktop support

## Quick Start

Start the helper:

```powershell
.\start-wechat-audio-helper.bat
```

Or run the PowerShell script directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WeChatAudioHelper.ps1
```

Run a one-time diagnostic check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WeChatAudioHelper.ps1 -Once
```

The diagnostic output includes the foreground process, detected WeChat process
IDs, whether a WeChat capture session is active, and whether a restore baseline
is ready.

## Options

```powershell
-PollIntervalMs 700
-RestoreDelayMs 1200
-ProcessNames Weixin,WeChat,WeChatApp,WeChatAppCore
```

## Build Tray Shell

Install the .NET SDK, then build:

```powershell
dotnet build -c Release
```

To publish a single-file Windows executable:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

Place the built `WeChatAudioHelper.exe` next to `WeChatAudioHelper.ps1`.

## Project Files

- `WeChatAudioHelper.ps1`: main audio monitoring and restore script.
- `Program.cs`: WinForms tray shell source code.
- `WeChatAudioHelper.csproj`: .NET project for building the tray shell.
- `start-wechat-audio-helper.bat`: starts the tray shell when present, otherwise starts the script.

Runtime files such as `*.log`, `*.old`, `bin/`, `obj/`, and local
`WeChatAudioHelper.exe` builds are intentionally ignored by git.

## Known Limits

1. WeChat must expose an active capture session on the default recording device.
2. The helper uses the default playback and recording devices. Non-default device
   routing may be inaccurate.
3. If the helper starts after recording already began, the first restore may not
   have a good pre-recording baseline.
4. The tray shell depends on `WeChatAudioHelper.ps1` being next to the executable.

## License

MIT

---

## 中文

[English](#wechataudiohelper) | **中文**

WeChatAudioHelper 是一个轻量级 Windows 本地工具，用来解决微信语音输入、语音消息
或录音结束后，系统音量/微信混音器音量被压低后没有自动恢复的问题。

关键词：微信音量恢复、微信语音输入音量变小、微信麦克风音量修复、微信录音后音量变小、
Windows 音频恢复、PowerShell 音频会话、WeChat volume restore.

## 为什么需要它

自从我开始接触 vibe coding 之后，试过很多语音输入相关的软件，最后发现对我来说
还是微信语音输入最好用。麻烦的是，当我一边听歌一边用微信语音输入时，按下快捷键后，
微信会把音量压到 5%，而且有时候不会自己回弹。

所以我通过 AI 开发了这个小插件，用来绕过这个问题。我不确定这是我个人环境的问题，
还是大家都会遇到的微信/Windows 行为，但如果你也被这个问题打断过，它应该能解决掉
一部分困扰。

技术上，它会持续记录最近一次非录音状态下的安全音量基线，并在检测到微信录音结束后
自动恢复。

## 功能

- 微信录音结束后自动恢复 Windows 系统主音量。
- 自动恢复微信在系统混音器里的会话音量。
- 通过默认录音设备检测微信 capture session。
- 完全本地运行，不需要联网服务，不需要账号登录。
- 提供 PowerShell 核心脚本，也提供可选的 WinForms 托盘壳。
- 托盘菜单支持当前用户开机自启。
- 脚本日志和托盘日志都限制在约 10MB，并保留一份 `.old` 旧日志。
- 不会主动把音量压低。
- 不读取也不恢复静音状态，避免误把系统或微信静音。

## 环境要求

- Windows
- Windows PowerShell 5.1 或更新版本
- 微信 Windows 桌面版
- 如果要编译托盘版：需要带 Windows Desktop 支持的 .NET 6 SDK 或更新版本

## 快速开始

启动工具：

```powershell
.\start-wechat-audio-helper.bat
```

也可以直接运行 PowerShell 脚本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WeChatAudioHelper.ps1
```

运行一次自检：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WeChatAudioHelper.ps1 -Once
```

自检会输出当前前台进程、识别到的微信 PID、是否检测到微信录音 capture session，
以及是否已经拿到可恢复的音量基线。

## 参数

```powershell
-PollIntervalMs 700
-RestoreDelayMs 1200
-ProcessNames Weixin,WeChat,WeChatApp,WeChatAppCore
```

## 编译托盘版

安装 .NET SDK 后执行：

```powershell
dotnet build -c Release
```

发布单文件 Windows 可执行程序：

```powershell
dotnet publish -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

把编译出的 `WeChatAudioHelper.exe` 放在 `WeChatAudioHelper.ps1` 旁边即可。

## 项目文件

- `WeChatAudioHelper.ps1`：核心音频监听与恢复脚本。
- `Program.cs`：WinForms 托盘壳源码。
- `WeChatAudioHelper.csproj`：托盘壳 .NET 项目文件。
- `start-wechat-audio-helper.bat`：启动脚本，优先启动托盘壳，没有 EXE 时启动 PowerShell 脚本。

运行时文件，例如 `*.log`、`*.old`、`bin/`、`obj/` 和本地构建的
`WeChatAudioHelper.exe`，都会被 git 忽略。

## 已知限制

1. 依赖微信在默认录音设备上暴露 active capture session。
2. 依赖默认播放/录音设备；如果微信走了非默认设备，可能不准确。
3. 如果工具在录音已经开始后才启动，第一次恢复可能没有准确的录音前基线。
4. 托盘壳依赖 `WeChatAudioHelper.ps1` 和 EXE 放在同一目录。

## 许可证

MIT
