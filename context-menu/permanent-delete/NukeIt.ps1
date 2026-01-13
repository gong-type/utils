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

# ============================================================================
# Deletion Methods (Optimized & Targeted)
# ============================================================================

# Method: Unlock processes holding a path
function Invoke-Unlock {
    param([string]$Path)
    
    try {
        $pids = [RestartManager]::GetLockingProcesses($Path)
        if ($pids.Count -gt 0) {
            Write-Log "Found $($pids.Count) locking processes for: $Path" "WARN"
            foreach ($pid in $pids) {
                try {
                    $proc = Get-Process -Id $pid -ErrorAction Stop
                    if ($CriticalProcesses -notcontains $proc.ProcessName) {
                        Write-Log "Terminating process: $($proc.ProcessName) (PID: $pid)" "WARN"
                        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    }
                } catch {}
            }
            Start-Sleep -Milliseconds 200
        }
    } catch {
        Write-Log "Unlock failed for $Path: $($_.Exception.Message)" "DEBUG"
    }
}

# Method: Take ownership and reset permissions
function Invoke-TakeOwnership {
    param([string]$Path)
    
    $unc = Get-UNCPath $Path
    Write-Log "Taking ownership of: $Path" "INFO"
    
    # Take ownership
    takeown /f $unc /r /d y 2>&1 | Out-Null
    
    # Reset permissions (standard reset + explicit grant to current user)
    icacls $unc /reset /t /c /q 2>&1 | Out-Null
    icacls $unc /grant "${env:USERNAME}:(OI)(CI)F" /t /c /q 2>&1 | Out-Null
}

# Method: Optimized Folder Deletion
function Invoke-FolderNuke {
    param([string]$Path)
    
    $unc = Get-UNCPath $Path
    
    # 1. Proactive Unlock
    Invoke-Unlock $Path
    
    # 2. Try Standard RD first (fast for small/unlocked folders)
    cmd /c "rd /s /q `"$unc`"" 2>&1 | Out-Null
    if (-not (Test-PathExists $Path)) { return $true }
    
    # 3. Empty folder using Robocopy mirror trick (extremely fast and robust)
    Write-Log "Using Robocopy mirror to empty: $Path" "INFO"
    $emptyDir = "$env:TEMP\NukeIt_Empty_$(Get-Random)"
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    try {
        robocopy $emptyDir $Path /MIR /NFL /NDL /NJH /NJS /NC /NS /NP /R:0 /W:0 2>&1 | Out-Null
    } finally {
        Remove-Item -LiteralPath $emptyDir -Force -ErrorAction SilentlyContinue
    }
    
    # 4. Final destruction
    cmd /c "rd /s /q `"$unc`"" 2>&1 | Out-Null
    
    # 5. Fallback: Take ownership if still exists
    if (Test-PathExists $Path) {
        Invoke-TakeOwnership $Path
        cmd /c "rd /s /q `"$unc`"" 2>&1 | Out-Null
    }
    
    return (-not (Test-PathExists $Path))
}

# Method: Optimized File Deletion
function Invoke-FileNuke {
    param([string]$Path)
    
    $unc = Get-UNCPath $Path
    
    # 1. Proactive Unlock
    Invoke-Unlock $Path
    
    # 2. Standard CMD delete (handles RO, hidden, system)
    cmd /c "del /f /q /a `"$unc`"" 2>&1 | Out-Null
    if (-not (Test-PathExists $Path)) { return $true }
    
    # 3. Fallback: Take ownership
    Invoke-TakeOwnership $Path
    cmd /c "del /f /q /a `"$unc`"" 2>&1 | Out-Null
    
    return (-not (Test-PathExists $Path))
}

# ============================================================================
# Main Routing Logic
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
    
    $unc = Get-UNCPath $Path
    $isContainer = (Get-Item -LiteralPath $unc -Force -ErrorAction SilentlyContinue).PSIsContainer
    if ($null -eq $isContainer) {
        $isContainer = (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue).PSIsContainer
    }
    
    # Clear Read-Only attribute on target itself first
    try {
        $item = Get-Item -LiteralPath $unc -Force -ErrorAction SilentlyContinue
        if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
        }
    } catch {}
    
    $success = $false
    if ($isContainer) {
        Write-Log "Target is FOLDER: $Path"
        $success = Invoke-FolderNuke $Path
    } else {
        Write-Log "Target is FILE: $Path"
        $success = Invoke-FileNuke $Path
    }
    
    if ($success) {
        Write-Log "SUCCESS: $Path"
        return $true
    } else {
        Write-Log "FAILED: $Path" "ERROR"
        return $false
    }
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
