param([string[]]$Paths)

if (-not $Paths -or $Paths.Count -eq 0) { $Paths = $args }

# Restart Manager API 用于检测文件占用
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class FileLocker {
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);
    
    [DllImport("rstrtmgr.dll")]
    static extern int RmEndSession(uint pSessionHandle);
    
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames, uint nApplications, uint rgApplications, uint nServices, uint rgsServiceNames);
    
    [DllImport("rstrtmgr.dll")]
    static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo, [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

    [StructLayout(LayoutKind.Sequential)]
    struct RM_UNIQUE_PROCESS { public int dwProcessId; public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string strServiceShortName;
        public int ApplicationType, AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)] public bool bRestartable;
    }

    public static List<string> GetLockingProcesses(string path) {
        var result = new List<string>();
        uint handle;
        if (RmStartSession(out handle, 0, Guid.NewGuid().ToString()) != 0) return result;
        try {
            string[] resources = { path };
            if (RmRegisterResources(handle, 1, resources, 0, 0, 0, null) != 0) return result;
            uint needed = 0, count = 0, reasons = 0;
            int ret = RmGetList(handle, out needed, ref count, null, ref reasons);
            if (ret == 234 && needed > 0) {
                var info = new RM_PROCESS_INFO[needed];
                count = needed;
                if (RmGetList(handle, out needed, ref count, info, ref reasons) == 0) {
                    for (int i = 0; i < count; i++) {
                        try {
                            var proc = System.Diagnostics.Process.GetProcessById(info[i].Process.dwProcessId);
                            result.Add(info[i].Process.dwProcessId + " - " + proc.ProcessName + " (" + proc.MainModule.FileName + ")");
                        } catch { result.Add(info[i].Process.dwProcessId + " - " + info[i].strAppName); }
                    }
                }
            }
        } finally { RmEndSession(handle); }
        return result;
    }
}
"@ -ErrorAction SilentlyContinue

$failedItems = @()

function Remove-ItemFast {
    param([string]$Path)
    
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.PSIsContainer) {
            [System.IO.Directory]::Delete($Path, $true)
        } else {
            # 尝试清除只读属性
            if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
            }
            [System.IO.File]::Delete($Path)
        }
        return $true
    } catch {
        return $_.Exception.Message
    }
}

# 新增对多个文件和路径的批量检测和处理
function Process-Paths {
    param(
        [string[]]$Paths
    )

    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (-not (Test-Path -LiteralPath $p)) { continue }

        $result = Remove-ItemFast -Path $p

        if ($result -ne $true) {
            # 删除失败，检测占用进程
            $lockers = @()
            try { $lockers = [FileLocker]::GetLockingProcesses($p) } catch {}

            if ($lockers.Count -gt 0) {
                $failedItems += [PSCustomObject]@{
                    Path = $p
                    Error = "文件被占用"
                    Processes = $lockers -join "`n"
                }
            } else {
                # 回退到 Remove-Item 尝试
                try {
                    attrib -r -s -h -a $p /s /d 2>$null
                    Remove-Item -LiteralPath $p -Recurse -Force -Confirm:$false -ErrorAction Stop
                } catch {
                    $failedItems += [PSCustomObject]@{
                        Path = $p
                        Error = $_.Exception.Message
                        Processes = ""
                    }
                }
            }
        }
    }
}

Process-Paths -Paths $Paths

# 显示失败结果
if ($failedItems.Count -gt 0) {
    $msg = "以下文件删除失败:`n`n"
    foreach ($item in $failedItems) {
        $msg += "路径: $($item.Path)`n"
        $msg += "原因: $($item.Error)`n"
        if ($item.Processes) {
            $msg += "占用进程:`n$($item.Processes)`n"
        }
        $msg += "`n"
    }
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show($msg, "删除失败", "OK", "Warning")
}
