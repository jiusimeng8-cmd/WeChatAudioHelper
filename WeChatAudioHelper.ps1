param(
    [int]$PollIntervalMs = 700,
    [int]$RestoreDelayMs = 1200,
    [string[]]$ProcessNames = @('Weixin', 'WeChat', 'WeChatApp', 'WeChatAppCore'),
    [switch]$Once
)

$ErrorActionPreference = 'Stop'

$source = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace WeChatAudioHelper {
    public enum EDataFlow { eRender = 0, eCapture = 1, eAll = 2 }
    public enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2 }
    public enum AudioSessionState { Inactive = 0, Active = 1, Expired = 2 }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorComObject { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator {
        int NotImpl1();
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice endpoint);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
    }

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume {
        int RegisterControlChangeNotify(IntPtr notify);
        int UnregisterControlChangeNotify(IntPtr notify);
        int GetChannelCount(out uint channelCount);
        int SetMasterVolumeLevel(float levelDb, Guid eventContext);
        int SetMasterVolumeLevelScalar(float level, Guid eventContext);
        int GetMasterVolumeLevel(out float levelDb);
        int GetMasterVolumeLevelScalar(out float level);
        int SetChannelVolumeLevel(uint channelNumber, float levelDb, Guid eventContext);
        int SetChannelVolumeLevelScalar(uint channelNumber, float level, Guid eventContext);
        int GetChannelVolumeLevel(uint channelNumber, out float levelDb);
        int GetChannelVolumeLevelScalar(uint channelNumber, out float level);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool isMuted, Guid eventContext);
        int GetMute(out bool isMuted);
        int GetVolumeStepInfo(out uint step, out uint stepCount);
        int VolumeStepUp(Guid eventContext);
        int VolumeStepDown(Guid eventContext);
        int QueryHardwareSupport(out uint hardwareSupportMask);
        int GetVolumeRange(out float volumeMindB, out float volumeMaxdB, out float volumeIncrementdB);
    }

    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionManager2 {
        int NotImpl0();
        int NotImpl1();
        int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnum);
    }

    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionEnumerator {
        int GetCount(out int sessionCount);
        int GetSession(int sessionCount, out IAudioSessionControl session);
    }

    [Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl {
        int GetState(out AudioSessionState state);
        int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
    }

    [Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl2 {
        int GetState(out AudioSessionState state);
        int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
        int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string value, Guid eventContext);
        int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string path);
        int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string path, Guid eventContext);
        int GetGroupingParam(out Guid groupingParam);
        int SetGroupingParam(Guid groupingParam, Guid eventContext);
        int RegisterAudioSessionNotification(IntPtr client);
        int UnregisterAudioSessionNotification(IntPtr client);
        int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        int GetProcessId(out uint retv);
        int IsSystemSoundsSession();
        int SetDuckingPreference(bool optOut);
    }

    [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ISimpleAudioVolume {
        int SetMasterVolume(float level, ref Guid eventContext);
        int GetMasterVolume(out float level);
        int SetMute(bool isMuted, ref Guid eventContext);
        int GetMute(out bool isMuted);
    }

    public class SessionInfo {
        public uint ProcessId;
        public string DisplayName = "";
        public int State;
        public float Volume;
        public bool Mute;
    }

    public class AudioHelper {
        const int CLSCTX_ALL = 23;

        static IMMDevice GetDefaultDevice(EDataFlow flow) {
            var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            IMMDevice device;
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(flow, ERole.eMultimedia, out device));
            return device;
        }

        static object Activate(IMMDevice device, Guid iid) {
            object obj;
            Marshal.ThrowExceptionForHR(device.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out obj));
            return obj;
        }

        public static float GetMasterVolume() {
            IMMDevice device = null;
            object endpointObj = null;
            try {
                device = GetDefaultDevice(EDataFlow.eRender);
                endpointObj = Activate(device, typeof(IAudioEndpointVolume).GUID);
                var endpoint = (IAudioEndpointVolume)endpointObj;
                float value;
                Marshal.ThrowExceptionForHR(endpoint.GetMasterVolumeLevelScalar(out value));
                return value;
            } finally {
                if (endpointObj != null) Marshal.ReleaseComObject(endpointObj);
                if (device != null) Marshal.ReleaseComObject(device);
            }
        }

        public static void SetMasterVolume(float level) {
            IMMDevice device = null;
            object endpointObj = null;
            try {
                device = GetDefaultDevice(EDataFlow.eRender);
                endpointObj = Activate(device, typeof(IAudioEndpointVolume).GUID);
                var endpoint = (IAudioEndpointVolume)endpointObj;
                var empty = Guid.Empty;
                Marshal.ThrowExceptionForHR(endpoint.SetMasterVolumeLevelScalar(level, empty));
            } finally {
                if (endpointObj != null) Marshal.ReleaseComObject(endpointObj);
                if (device != null) Marshal.ReleaseComObject(device);
            }
        }

        public static List<SessionInfo> GetSessions(EDataFlow flow) {
            IMMDevice device = null;
            object managerObj = null;
            IAudioSessionEnumerator sessionEnum = null;
            var result = new List<SessionInfo>();
            try {
                device = GetDefaultDevice(flow);
                managerObj = Activate(device, typeof(IAudioSessionManager2).GUID);
                var manager = (IAudioSessionManager2)managerObj;
                Marshal.ThrowExceptionForHR(manager.GetSessionEnumerator(out sessionEnum));
                int count;
                Marshal.ThrowExceptionForHR(sessionEnum.GetCount(out count));
                for (int i = 0; i < count; i++) {
                    IAudioSessionControl session = null;
                    try {
                        if (sessionEnum.GetSession(i, out session) != 0 || session == null) continue;
                        var session2 = session as IAudioSessionControl2;
                        var simple = session as ISimpleAudioVolume;
                        if (session2 == null || simple == null) continue;
                        uint pid;
                        if (session2.GetProcessId(out pid) != 0 || pid == 0) continue;
                        AudioSessionState state;
                        if (session.GetState(out state) != 0) continue;
                        float volume;
                        if (simple.GetMasterVolume(out volume) != 0) continue;
                        bool mute;
                        if (simple.GetMute(out mute) != 0) continue;
                        string display;
                        if (session.GetDisplayName(out display) != 0 || display == null) display = "";
                        result.Add(new SessionInfo {
                            ProcessId = pid,
                            DisplayName = display,
                            State = (int)state,
                            Volume = volume,
                            Mute = mute
                        });
                    } finally {
                        if (session != null) Marshal.ReleaseComObject(session);
                    }
                }
                return result;
            } finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (managerObj != null) Marshal.ReleaseComObject(managerObj);
                if (device != null) Marshal.ReleaseComObject(device);
            }
        }

        public static void SetSessionVolume(uint processId, float level) {
            IMMDevice device = null;
            object managerObj = null;
            IAudioSessionEnumerator sessionEnum = null;
            try {
                device = GetDefaultDevice(EDataFlow.eRender);
                managerObj = Activate(device, typeof(IAudioSessionManager2).GUID);
                var manager = (IAudioSessionManager2)managerObj;
                Marshal.ThrowExceptionForHR(manager.GetSessionEnumerator(out sessionEnum));
                int count;
                Marshal.ThrowExceptionForHR(sessionEnum.GetCount(out count));
                for (int i = 0; i < count; i++) {
                    IAudioSessionControl session = null;
                    try {
                        if (sessionEnum.GetSession(i, out session) != 0 || session == null) continue;
                        var session2 = session as IAudioSessionControl2;
                        var simple = session as ISimpleAudioVolume;
                        if (session2 == null || simple == null) continue;
                        uint pid;
                        if (session2.GetProcessId(out pid) != 0 || pid != processId) continue;
                        var empty = Guid.Empty;
                        Marshal.ThrowExceptionForHR(simple.SetMasterVolume(level, ref empty));
                    } finally {
                        if (session != null) Marshal.ReleaseComObject(session);
                    }
                }
            } finally {
                if (sessionEnum != null) Marshal.ReleaseComObject(sessionEnum);
                if (managerObj != null) Marshal.ReleaseComObject(managerObj);
                if (device != null) Marshal.ReleaseComObject(device);
            }
        }
    }

    public class ForegroundWindow {
        [DllImport("user32.dll")]
        static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        public static uint GetForegroundProcessId() {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return 0;
            uint processId;
            GetWindowThreadProcessId(hwnd, out processId);
            return processId;
        }
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp

function Get-NormalizedProcessName {
    param([uint32]$ProcessIdValue)
    try {
        return (Get-Process -Id $ProcessIdValue -ErrorAction Stop).ProcessName.ToLowerInvariant()
    } catch {
        return $null
    }
}

function Get-WeChatPidSet {
    param([string[]]$Names)
    $set = @{}
    foreach ($name in $Names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            $set[[uint32]$_.Id] = $true
        }
    }
    return $set
}

function New-Snapshot {
    param([hashtable]$WechatPidSet)
    $masterVolume = [WeChatAudioHelper.AudioHelper]::GetMasterVolume()
    $sessions = @{}
    foreach ($session in [WeChatAudioHelper.AudioHelper]::GetSessions([WeChatAudioHelper.EDataFlow]::eRender)) {
        if ($WechatPidSet.ContainsKey([uint32]$session.ProcessId)) {
            $sessions[[uint32]$session.ProcessId] = [pscustomobject]@{
                ProcessId = [uint32]$session.ProcessId
                Volume    = [single]$session.Volume
            }
        }
    }
    return [pscustomobject]@{
        MasterVolume = [single]$masterVolume
        Sessions     = $sessions
        At           = Get-Date
    }
}

function Test-WeChatCaptureActive {
    param([hashtable]$WechatPidSet)
    $active = $false
    $pids = @()
    foreach ($session in [WeChatAudioHelper.AudioHelper]::GetSessions([WeChatAudioHelper.EDataFlow]::eCapture)) {
        $sessionProcessId = [uint32]$session.ProcessId
        if ($WechatPidSet.ContainsKey($sessionProcessId) -and $session.State -eq 1) {
            $active = $true
            $pids += $sessionProcessId
        }
    }
    return [pscustomobject]@{
        Active = $active
        Pids   = $pids
    }
}

function Restore-Snapshot {
    param($Snapshot)
    [WeChatAudioHelper.AudioHelper]::SetMasterVolume([single]$Snapshot.MasterVolume)
    foreach ($entry in $Snapshot.Sessions.GetEnumerator()) {
        [WeChatAudioHelper.AudioHelper]::SetSessionVolume([uint32]$entry.Value.ProcessId, [single]$entry.Value.Volume)
    }
}

$processNamesNormalized = @($ProcessNames | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
if ($processNamesNormalized.Count -eq 0) {
    throw 'No process names provided.'
}

Write-Host "[wechat-audio-helper] started" -ForegroundColor Cyan
Write-Host "[wechat-audio-helper] process names: $($processNamesNormalized -join ', ')"
Write-Host "[wechat-audio-helper] poll=${PollIntervalMs}ms restoreDelay=${RestoreDelayMs}ms"

$baseline = $null
$lastIdleSnapshot = $null
$active = $false
$inactiveSince = $null
$lastRestoreAt = $null
$IdleBaselineCooldownMs = 3000
$MinBaselineMasterVolume = [single]0.08
$logPath = Join-Path $PSScriptRoot 'WeChatAudioHelper-ps1.log'
$maxLogBytes = 10MB
$oldLogPath = "$logPath.old"

function Rotate-HelperLogIfNeeded {
    try {
        if ((Test-Path -LiteralPath $logPath) -and ((Get-Item -LiteralPath $logPath).Length -ge $maxLogBytes)) {
            if (Test-Path -LiteralPath $oldLogPath) {
                Remove-Item -LiteralPath $oldLogPath -Force -ErrorAction SilentlyContinue
            }
            Move-Item -LiteralPath $logPath -Destination $oldLogPath -Force
        }
    }
    catch {
    }
}

function Write-HelperLog {
    param([string]$Message)
    try {
        Rotate-HelperLogIfNeeded
        Add-Content -Path $logPath -Value ("[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}" -f (Get-Date), $Message) -Encoding UTF8
    }
    catch {
    }
}

while ($true) {
    try {
        $wechatPidSet = Get-WeChatPidSet -Names $processNamesNormalized
        $foregroundPid = [WeChatAudioHelper.ForegroundWindow]::GetForegroundProcessId()
        $foregroundName = if ($foregroundPid -gt 0) { Get-NormalizedProcessName -ProcessIdValue $foregroundPid } else { $null }
        $foregroundIsWeChat = $foregroundName -and ($processNamesNormalized -contains $foregroundName)
        $capture = Test-WeChatCaptureActive -WechatPidSet $wechatPidSet

        $allowIdleBaselineRefresh = $true
        if ($lastRestoreAt -and (((Get-Date) - $lastRestoreAt).TotalMilliseconds -lt $IdleBaselineCooldownMs)) {
            $allowIdleBaselineRefresh = $false
        }

        if (-not $capture.Active -and $allowIdleBaselineRefresh) {
            $candidateSnapshot = New-Snapshot -WechatPidSet $wechatPidSet
            if ($candidateSnapshot.MasterVolume -gt $MinBaselineMasterVolume) {
                $lastIdleSnapshot = $candidateSnapshot
                if (-not $active) {
                    $baseline = $lastIdleSnapshot
                }
                Write-HelperLog ("idle baseline accepted master={0:P0} sessionCount={1} foregroundIsWeChat={2}" -f $candidateSnapshot.MasterVolume, $candidateSnapshot.Sessions.Count, [bool]$foregroundIsWeChat)
            }
            elseif ($candidateSnapshot.MasterVolume -le $MinBaselineMasterVolume) {
                Write-Host ("[wechat-audio-helper] skip suspicious idle baseline master={0:P0}" -f $candidateSnapshot.MasterVolume) -ForegroundColor DarkYellow
                Write-HelperLog ("idle baseline skipped suspicious master={0:P0} foregroundIsWeChat={1}" -f $candidateSnapshot.MasterVolume, [bool]$foregroundIsWeChat)
            }
        }

        if ($capture.Active) {
            if (-not $baseline) {
                if ($lastIdleSnapshot) {
                    $baseline = $lastIdleSnapshot
                }
            }
            if (-not $active -and $baseline) {
                Write-Host ("[wechat-audio-helper] capture active, baseline at {0:HH:mm:ss}, master={1:P0}, pids={2}" -f $baseline.At, $baseline.MasterVolume, (($capture.Pids | Sort-Object -Unique) -join ',')) -ForegroundColor Yellow
                Write-HelperLog ("capture active baselineAt={0:HH:mm:ss} master={1:P0} pids={2}" -f $baseline.At, $baseline.MasterVolume, (($capture.Pids | Sort-Object -Unique) -join ','))
            }
            $active = $true
            $inactiveSince = $null
        }
        elseif ($active -and $baseline) {
            if (-not $inactiveSince) {
                $inactiveSince = Get-Date
            }
            elseif (((Get-Date) - $inactiveSince).TotalMilliseconds -ge $RestoreDelayMs) {
                Restore-Snapshot -Snapshot $baseline
                Write-Host ("[wechat-audio-helper] restored baseline from {0:HH:mm:ss}" -f $baseline.At) -ForegroundColor Green
                Write-HelperLog ("restored baseline from {0:HH:mm:ss} master={1:P0} sessionCount={2}" -f $baseline.At, $baseline.MasterVolume, $baseline.Sessions.Count)
                $lastIdleSnapshot = $baseline
                $active = $false
                $inactiveSince = $null
                $lastRestoreAt = Get-Date
            }
        }
        else {
            $inactiveSince = $null
        }

        if ($Once) {
            $summary = [pscustomobject]@{
                ForegroundPid      = $foregroundPid
                ForegroundName     = $foregroundName
                ForegroundIsWeChat = [bool]$foregroundIsWeChat
                WeChatPids         = @($wechatPidSet.Keys | Sort-Object)
                CaptureActive      = [bool]$capture.Active
                CapturePids        = @($capture.Pids | Sort-Object -Unique)
                BaselineReady      = [bool]($null -ne $baseline)
            }
            $summary | Format-List | Out-String | Write-Host
            break
        }
    }
    catch {
        Write-Warning $_
    }

    Start-Sleep -Milliseconds $PollIntervalMs
}
