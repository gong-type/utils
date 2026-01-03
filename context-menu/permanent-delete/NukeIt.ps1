<#
.SYNOPSIS
    NukeIt - Ultimate Silent Deletion Engine v4.0
    Zero UI, Maximum Power, Handles Everything
    
.DESCRIPTION
    Features:
    - 100% Silent: No popups, no windows, errors go to log file
    - UNC Path: Handles reserved names (nul, con, aux, etc.)
    - Long Path: Supports paths over 260 characters
    - Process Unlock: Uses RestartManager API to release locks
    - NTFS Tricks: Robocopy mirror delete for stubborn files
    - CMD Delete: Falls back to del /f /q for edge cases
    - Permission Fix: Takes ownership and resets ACL when needed
    - Auto Elevate: Silently requests admin when required
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# Configuration
# ============================================================================
$LogFile = "$env:TEMP\NukeIt.log"
$MaxLogSize = 1MB
$CriticalProcesses = @(
    "explorer", "csrss", "wininit", "winlogon", "services", "lsass", 
    "smss", "System", "svchost", "dwm", "spoolsv", "SearchIndexer",
    "RuntimeBroker", "ShellExperienceHost", "StartMenuExperienceHost"
)

# ============================================================================
# Logging (Silent - Only to file)
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    # Rotate log if too large
    if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt $MaxLogSize) {
        Remove-Item "$LogFile.old" -Force -ErrorAction SilentlyContinue
        Rename-Item $LogFile "$LogFile.old" -Force -ErrorAction SilentlyContinue
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# ============================================================================
# Helper Functions
# ============================================================================
function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UNCPath {
    param([string]$Path)
    $Path = $Path.Trim().Trim('"')
    if ($Path.StartsWith("\\?\")) { return $Path }
    if ($Path.StartsWith("\\")) { return "\\?\UNC\" + $Path.Substring(2) }
    return "\\?\" + $Path
}

function Test-PathExists {
    param([string]$Path)
    $normal = Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($normal) { return $true }
    $unc = Get-UNCPath $Path
    return Test-Path -LiteralPath $unc -ErrorAction SilentlyContinue
}

# Executable extensions that may trigger SmartScreen
$ExeExtensions = @('.exe', '.msi', '.bat', '.cmd', '.com', '.scr', '.pif', '.dll', '.sys')

function Test-IsExecutable {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    return $ExeExtensions -contains $ext
}

function Test-NeedsElevation {
    param([string]$Path)
    
    # System paths always need elevation
    $sysRoot = $env:SystemRoot -replace '\\', '\\'
    $progFiles = $env:ProgramFiles -replace '\\', '\\'
    $progFilesX86 = ${env:ProgramFiles(x86)} -replace '\\', '\\'
    
    if ($Path -match "^$sysRoot" -or $Path -match "^$progFiles" -or ($progFilesX86 -and $Path -match "^$progFilesX86")) {
        return $true
    }
    
    # Try write access
    try {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite).Dispose()
        }
    } catch [System.UnauthorizedAccessException] {
        return $true
    } catch {}
    
    return $false
}

# ============================================================================
# P/Invoke: RestartManager for Process Unlock
# ============================================================================
$rmCode = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class RestartManager {
    [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
    public static extern int RmStartSession(out uint h, int f, string k);
    
    [DllImport("rstrtmgr.dll")]
    public static extern int RmEndSession(uint h);
    
    [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
    public static extern int RmRegisterResources(uint h, uint n, string[] r, uint a, uint[] ra, uint s, string[] sn);
    
    [DllImport("rstrtmgr.dll")]
    public static extern int RmGetList(uint h, out uint pn, ref uint p, [In, Out] RM_PROCESS_INFO[] pi, ref uint r);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string strServiceShortName;
        public int ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)] public bool bRestartable;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RM_UNIQUE_PROCESS {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    public static List<int> GetLockingProcesses(string path) {
        var pids = new List<int>();
        uint handle;
        
        if (RmStartSession(out handle, 0, Guid.NewGuid().ToString()) != 0) return pids;
        
        try {
            if (RmRegisterResources(handle, 1, new[] { path }, 0, null, 0, null) != 0) return pids;
            
            uint needed = 0, count = 0, reason = 0;
            int result = RmGetList(handle, out needed, ref count, null, ref reason);
            
            if (result == 234 && needed > 0) { // ERROR_MORE_DATA
                var info = new RM_PROCESS_INFO[needed];
                count = needed;
                
                if (RmGetList(handle, out needed, ref count, info, ref reason) == 0) {
                    for (int i = 0; i < count; i++) {
                        pids.Add(info[i].Process.dwProcessId);
                    }
                }
            }
        } finally {
            RmEndSession(handle);
        }
        
        return pids;
    }
}
"@

try {
    Add-Type -TypeDefinition $rmCode -ErrorAction Stop
} catch {
    # Type already loaded, ignore
}

# ============================================================================
# Deletion Methods (Ordered by aggression level)
# ============================================================================

# Method 1: Standard PowerShell Remove-Item
function Remove-Standard {
    param([string]$Path)
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
}

# Method 2: UNC Path deletion (handles reserved names, long paths)
function Remove-UNC {
    param([string]$Path)
    $unc = Get-UNCPath $Path
    Remove-Item -LiteralPath $unc -Recurse -Force -ErrorAction Stop
}

# Method 3: CMD del/rmdir (sometimes works when PS fails)
function Remove-CMD {
    param([string]$Path)
    $unc = Get-UNCPath $Path
    
    if (Test-Path -LiteralPath $Path -PathType Leaf -ErrorAction SilentlyContinue) {
        $result = cmd /c "del /f /q /a `"$unc`"" 2>&1
    } else {
        $result = cmd /c "rd /s /q `"$unc`"" 2>&1
    }
    
    if (Test-PathExists $Path) {
        throw "CMD delete failed: $result"
    }
}

# Method 4: Robocopy mirror (empty folder trick)
function Remove-Robocopy {
    param([string]$Path)
    
    if (-not (Test-Path -LiteralPath $Path -PathType Container -ErrorAction SilentlyContinue)) {
        throw "Robocopy only works for folders"
    }
    
    $emptyDir = "$env:TEMP\NukeIt_Empty_$(Get-Random)"
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    
    try {
        $result = robocopy $emptyDir $Path /MIR /NFL /NDL /NJH /NJS /NC /NS /NP 2>&1
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } finally {
        Remove-Item -LiteralPath $emptyDir -Force -ErrorAction SilentlyContinue
    }
}

# Method 5: Take ownership and reset permissions
function Remove-WithOwnership {
    param([string]$Path)
    
    $unc = Get-UNCPath $Path
    
    # Take ownership
    takeown /f $unc /r /d y 2>&1 | Out-Null
    
    # Reset permissions
    icacls $unc /reset /t /c /q 2>&1 | Out-Null
    icacls $unc /grant "${env:USERNAME}:F" /t /c /q 2>&1 | Out-Null
    
    # Try delete again
    Remove-Item -LiteralPath $unc -Recurse -Force -ErrorAction Stop
}

# Method 6: Unlock processes and retry
function Remove-WithUnlock {
    param([string]$Path)
    
    $pids = [RestartManager]::GetLockingProcesses($Path)
    
    if ($pids.Count -eq 0) {
        throw "No locking processes found"
    }
    
    foreach ($pid in $pids) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction Stop
            if ($CriticalProcesses -notcontains $proc.ProcessName) {
                Write-Log "Terminating process: $($proc.ProcessName) (PID: $pid)" "WARN"
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            } else {
                Write-Log "Skipping critical process: $($proc.ProcessName) (PID: $pid)" "WARN"
            }
        } catch {}
    }
    
    Start-Sleep -Milliseconds 300
    
    # Retry with UNC
    $unc = Get-UNCPath $Path
    Remove-Item -LiteralPath $unc -Recurse -Force -ErrorAction Stop
}

# ============================================================================
# Main Deletion Logic
# ============================================================================
function Invoke-Nuke {
    param([string]$Path)
    
    $Path = $Path.Trim().Trim('"')
    if ([string]::IsNullOrEmpty($Path)) { return $true }
    
    # Check existence
    if (-not (Test-PathExists $Path)) {
        Write-Log "Path not found (already deleted?): $Path"
        return $true
    }
    
    $isExe = Test-IsExecutable $Path
    $unc = Get-UNCPath $Path
    
    # For executables: Use CMD only to avoid SmartScreen
    if ($isExe) {
        Write-Log "Executable detected, using CMD-only path: $Path"
        
        # Method 1: CMD del with UNC path
        $result = cmd /c "del /f /q /a `"$unc`"" 2>&1
        if (-not (Test-PathExists $Path)) {
            Write-Log "SUCCESS [CMD-EXE]: $Path"
            return $true
        }
        
        # Method 2: CMD del with normal path
        $result = cmd /c "del /f /q /a `"$Path`"" 2>&1
        if (-not (Test-PathExists $Path)) {
            Write-Log "SUCCESS [CMD-EXE]: $Path"
            return $true
        }
        
        # Method 3: attrib to remove readonly, then delete
        cmd /c "attrib -r -s -h `"$unc`"" 2>&1 | Out-Null
        $result = cmd /c "del /f /q /a `"$unc`"" 2>&1
        if (-not (Test-PathExists $Path)) {
            Write-Log "SUCCESS [CMD-ATTRIB-EXE]: $Path"
            return $true
        }
        
        # Method 4: Unlock and retry (minimal PS interaction)
        try {
            $pids = [RestartManager]::GetLockingProcesses($Path)
            if ($pids.Count -gt 0) {
                foreach ($pid in $pids) {
                    try {
                        $proc = Get-Process -Id $pid -ErrorAction Stop
                        if ($CriticalProcesses -notcontains $proc.ProcessName) {
                            Write-Log "Terminating process: $($proc.ProcessName) (PID: $pid)" "WARN"
                            taskkill /F /PID $pid 2>&1 | Out-Null
                        }
                    } catch {}
                }
                Start-Sleep -Milliseconds 300
                $result = cmd /c "del /f /q /a `"$unc`"" 2>&1
                if (-not (Test-PathExists $Path)) {
                    Write-Log "SUCCESS [CMD-UNLOCK-EXE]: $Path"
                    return $true
                }
            }
        } catch {}
        
        Write-Log "FAILED all CMD methods for executable: $Path" "ERROR"
        return $false
    }
    
    # For non-executables: Use full method chain
    # Clear read-only attributes
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            $item = Get-Item -LiteralPath $unc -Force -ErrorAction SilentlyContinue
        }
        
        if ($null -ne $item) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
            }
            
            if ($item.PSIsContainer) {
                Get-ChildItem -LiteralPath $unc -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                        $_.Attributes = $_.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
                    }
                }
            }
        }
    } catch {}
    
    # Try deletion methods in order
    $methods = @(
        @{ Name = "Standard";      Func = { Remove-Standard $Path } },
        @{ Name = "UNC";           Func = { Remove-UNC $Path } },
        @{ Name = "CMD";           Func = { Remove-CMD $Path } },
        @{ Name = "Robocopy";      Func = { Remove-Robocopy $Path } },
        @{ Name = "WithOwnership"; Func = { Remove-WithOwnership $Path } },
        @{ Name = "WithUnlock";    Func = { Remove-WithUnlock $Path } }
    )
    
    foreach ($method in $methods) {
        try {
            & $method.Func
            
            if (-not (Test-PathExists $Path)) {
                Write-Log "SUCCESS [$($method.Name)]: $Path"
                return $true
            }
        } catch {
            # Continue to next method
        }
    }
    
    Write-Log "FAILED all methods: $Path" "ERROR"
    return $false
}

# ============================================================================
# Entry Point
# ============================================================================
if ($Paths.Count -eq 0) { exit 0 }

Write-Log "=== NukeIt v4.0 Started ===" "INFO"
Write-Log "Paths to delete: $($Paths.Count)"

# Check if elevation is needed
$needsAdmin = $false
if (-not (Test-IsAdmin)) {
    foreach ($p in $Paths) {
        $cleanPath = $p.Trim().Trim('"')
        if (Test-NeedsElevation $cleanPath) {
            $needsAdmin = $true
            break
        }
    }
}

if ($needsAdmin) {
    Write-Log "Elevation required, relaunching..."
    $quotedPaths = ($Paths | ForEach-Object { "`"$($_.Trim().Trim('"'))`"" }) -join " "
    Start-Process "powershell.exe" -ArgumentList @(
        "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
        "-File", "`"$PSCommandPath`"", $quotedPaths
    ) -Verb RunAs -WindowStyle Hidden
    exit 0
}

# Process each path
$failed = @()
foreach ($path in $Paths) {
    $cleanPath = $path.Trim().Trim('"')
    if (-not (Invoke-Nuke $cleanPath)) {
        $failed += $cleanPath
    }
}

if ($failed.Count -gt 0) {
    Write-Log "=== Completed with $($failed.Count) failures ===" "WARN"
} else {
    Write-Log "=== All deletions successful ===" "INFO"
}

exit 0
