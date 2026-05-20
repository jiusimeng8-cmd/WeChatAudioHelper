# WeChatAudioHelper

WeChatAudioHelper is a small local Windows utility for recovering system and
WeChat mixer volume after WeChat voice input changes the volume unexpectedly.

The core logic lives in `WeChatAudioHelper.ps1`. The optional WinForms tray
shell starts and supervises the script, provides a tray menu, and can register
the app for current-user startup.

## Features

- Records the latest non-recording system master volume as the restore baseline.
- Records WeChat audio session volume from the Windows mixer.
- Detects active WeChat capture sessions and restores volume after recording ends.
- Does not intentionally lower volume.
- Does not read or restore mute state, to avoid muting the system or WeChat by mistake.
- Keeps script and tray logs capped at about 10 MB each, with one `.old` backup.

## Files

- `WeChatAudioHelper.ps1`: main audio monitoring and restore script.
- `Program.cs`: WinForms tray shell source code.
- `WeChatAudioHelper.csproj`: .NET project for building the tray shell.
- `start-wechat-audio-helper.bat`: starts the tray shell when present, otherwise starts the script.

Runtime files such as `*.log`, `*.old`, `bin/`, `obj/`, and local `WeChatAudioHelper.exe`
builds are intentionally ignored by git.

## Requirements

- Windows
- Windows PowerShell 5.1 or newer
- WeChat desktop client
- Optional for tray shell builds: .NET 6 SDK or newer with Windows Desktop support

## Run

Start the helper with:

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

## Tray Shell

When `WeChatAudioHelper.exe` is available, `start-wechat-audio-helper.bat` starts
the tray shell. The tray menu supports:

- `开机自启`: toggles current-user startup through
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
- `退出`: exits the tray shell and stops the background script process.

## Known Limits

1. WeChat must expose an active capture session on the default recording device.
2. The helper uses the default playback and recording devices. Non-default device
   routing may be inaccurate.
3. If the helper starts after recording already began, the first restore may not
   have a good pre-recording baseline.
4. The tray shell depends on `WeChatAudioHelper.ps1` being next to the executable.
