using Microsoft.Win32;
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace WeChatAudioHelper
{
    internal static class Program
    {
        private static Mutex singleInstanceMutex;

        [STAThread]
        private static void Main()
        {
            bool createdNew;
            singleInstanceMutex = new Mutex(true, "WeChatAudioHelper.Singleton", out createdNew);
            if (!createdNew)
            {
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new TrayApplicationContext());

            singleInstanceMutex.ReleaseMutex();
            singleInstanceMutex.Dispose();
        }
    }

    internal sealed class TrayApplicationContext : ApplicationContext
    {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string RunValueName = "WeChatAudioHelper";

        private readonly NotifyIcon notifyIcon;
        private readonly ContextMenuStrip contextMenu;
        private readonly ToolStripMenuItem autoStartMenuItem;
        private readonly ToolStripMenuItem exitMenuItem;
        private readonly System.Windows.Forms.Timer supervisorTimer;
        private readonly string baseDirectory;
        private readonly string scriptPath;
        private readonly string logPath;
        private readonly string oldLogPath;

        private Process workerProcess;
        private int lastWorkerPid;
        public TrayApplicationContext()
        {
            baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            scriptPath = Path.Combine(baseDirectory, "WeChatAudioHelper.ps1");
            logPath = Path.Combine(baseDirectory, "WeChatAudioHelper-tray.log");
            oldLogPath = logPath + ".old";

            autoStartMenuItem = new ToolStripMenuItem("开机自启");
            autoStartMenuItem.Click += AutoStartMenuItem_Click;

            exitMenuItem = new ToolStripMenuItem("退出");
            exitMenuItem.Click += ExitMenuItem_Click;

            contextMenu = new ContextMenuStrip();
            contextMenu.Items.Add(autoStartMenuItem);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add(exitMenuItem);
            contextMenu.Opening += ContextMenu_Opening;

            notifyIcon = new NotifyIcon
            {
                Text = "WeChatAudioHelper",
                Icon = SystemIcons.Information,
                Visible = true,
                ContextMenuStrip = contextMenu
            };

            supervisorTimer = new System.Windows.Forms.Timer();
            supervisorTimer.Interval = 2000;
            supervisorTimer.Tick += SupervisorTimer_Tick;

            UpdateAutoStartMenuState();
            EnsureWorkerRunning();
            supervisorTimer.Start();
            Log("tray shell started");
        }

        private void ContextMenu_Opening(object sender, System.ComponentModel.CancelEventArgs e)
        {
            UpdateAutoStartMenuState();
        }

        private void AutoStartMenuItem_Click(object sender, EventArgs e)
        {
            try
            {
                if (IsAutoStartEnabled())
                {
                    DisableAutoStart();
                }
                else
                {
                    EnableAutoStart();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("开机自启设置失败:\r\n" + ex.Message, "WeChatAudioHelper", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }

            UpdateAutoStartMenuState();
        }

        private void ExitMenuItem_Click(object sender, EventArgs e)
        {
            ExitThread();
        }

        protected override void ExitThreadCore()
        {
            supervisorTimer.Stop();
            supervisorTimer.Dispose();
            StopWorker();

            notifyIcon.Visible = false;
            notifyIcon.Dispose();
            contextMenu.Dispose();

            base.ExitThreadCore();
        }

        private void SupervisorTimer_Tick(object sender, EventArgs e)
        {
            try
            {
                EnsureWorkerRunning();
            }
            catch (Exception ex)
            {
                Log("supervisor error: " + ex.Message);
            }
        }

        private void EnsureWorkerRunning()
        {
            if (!File.Exists(scriptPath))
            {
                throw new FileNotFoundException("未找到 WeChatAudioHelper.ps1", scriptPath);
            }

            if (workerProcess != null)
            {
                try
                {
                    if (!workerProcess.HasExited)
                    {
                        return;
                    }

                    Log("worker exited, pid=" + workerProcess.Id + ", code=" + workerProcess.ExitCode);
                }
                catch
                {
                }

                try
                {
                    workerProcess.Dispose();
                }
                catch
                {
                }

                workerProcess = null;
            }

            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\"", scriptPath),
                WorkingDirectory = baseDirectory,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            workerProcess = Process.Start(startInfo);
            if (workerProcess == null)
            {
                throw new InvalidOperationException("启动后台脚本失败");
            }

            lastWorkerPid = workerProcess.Id;
            Log("worker started, pid=" + lastWorkerPid);
        }

        private void StopWorker()
        {
            Process process = workerProcess;
            workerProcess = null;

            if (process != null)
            {
                try
                {
                    if (!process.HasExited)
                    {
                        process.Kill();
                        process.WaitForExit(3000);
                        Log("worker killed on exit, pid=" + process.Id);
                    }
                }
                catch (Exception ex)
                {
                    Log("worker stop error: " + ex.Message);
                }
                finally
                {
                    process.Dispose();
                }
            }
            else if (lastWorkerPid > 0)
            {
                try
                {
                    using (Process fallback = Process.GetProcessById(lastWorkerPid))
                    {
                        fallback.Kill();
                        fallback.WaitForExit(3000);
                        Log("worker fallback killed on exit, pid=" + lastWorkerPid);
                    }
                }
                catch
                {
                }
            }
        }

        private void UpdateAutoStartMenuState()
        {
            bool enabled = IsAutoStartEnabled();
            autoStartMenuItem.Checked = enabled;
            autoStartMenuItem.Text = enabled ? "开机自启（已开启）" : "开机自启（已关闭）";
        }

        private void Log(string message)
        {
            try
            {
                RotateLogIfNeeded();
                File.AppendAllText(logPath, string.Format("[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}{2}", DateTime.Now, message, Environment.NewLine));
            }
            catch
            {
            }
        }

        private void RotateLogIfNeeded()
        {
            try
            {
                FileInfo logFile = new FileInfo(logPath);
                if (logFile.Exists && logFile.Length >= 10 * 1024 * 1024)
                {
                    if (File.Exists(oldLogPath))
                    {
                        File.Delete(oldLogPath);
                    }

                    File.Move(logPath, oldLogPath);
                }
            }
            catch
            {
            }
        }

        private static bool IsAutoStartEnabled()
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false))
            {
                string value = key == null ? null : key.GetValue(RunValueName) as string;
                return !string.IsNullOrWhiteSpace(value);
            }
        }

        private static void EnableAutoStart()
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(RunKeyPath))
            {
                key.SetValue(RunValueName, Quote(Application.ExecutablePath), RegistryValueKind.String);
            }
        }

        private static void DisableAutoStart()
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true))
            {
                if (key != null)
                {
                    key.DeleteValue(RunValueName, false);
                }
            }
        }

        private static string Quote(string path)
        {
            return "\"" + path + "\"";
        }
    }
}
