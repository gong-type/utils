<#
.SYNOPSIS
    Permanent Delete Core - Pure Speed Edition
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Critical System Processes White-list
$CriticalProcesses = @("explorer","csrss","wininit","winlogon","services","lsass","smss","System","svchost","dwm","spoolsv")

# Use minimal UI
Add-Type -AssemblyName System.Windows.Forms

if ($Paths.Count -eq 0) { exit }

# ==============================================================================
# P/Invoke Definitions (RestartManager)
# ==============================================================================
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Collections.Generic;
    using System.Runtime.InteropServices;

    public class RM {
        [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
        public static extern int RmStartSession(out uint h, int f, string k);
        [DllImport("rstrtmgr.dll")] public static extern int RmEndSession(uint h);
        [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
        public static extern int RmRegisterResources(uint h, uint n, string[] r, uint a, uint[] ra, uint s, string[] sn);
        [DllImport("rstrtmgr.dll")]
        public static extern int RmGetList(uint h, out uint pn, ref uint p, [In, Out] RM_PI[] pi, ref uint r);

        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        public struct RM_PI {
            public RM_UP p;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string n;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string sn;
            public int at; public int as_; public uint ts; public bool br;
        }
        [StructLayout(LayoutKind.Sequential)] public struct RM_UP { public int id; public long st; }

        public static List<int> GetLocks(string p) {
            var l = new List<int>();
            uint h, pn=0, p_=0, r=0;
            if (RmStartSession(out h, 0, Guid.NewGuid().ToString()) != 0) return l;
            try {
                if (RmRegisterResources(h, 1, new[]{p}, 0, null, 0, null) != 0) return l;
                if (RmGetList(h, out pn, ref p_, null, ref r) == 234 && pn > 0) {
                    var i = new RM_PI[pn]; p_ = pn;
                    if (RmGetList(h, out pn, ref p_, i, ref r) == 0) {
                        for(int j=0; j<p_; j++) l.Add(i[j].p.id);
                    }
                }
            } finally { RmEndSession(h); }
            return l;
        }
    }
"@ -ErrorAction Stop
} catch { exit }

# ==============================================================================
# Helper Functions
# ==============================================================================
function Is-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Relaunch-Admin {
    $p = ($Paths | ForEach-Object { "`"$_`"" }) -join " "
    Start-Process "powershell.exe" -ArgumentList "-NoProfile","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"",$p -Verb RunAs -WindowStyle Hidden
    exit
}

function Needs-Elev {
    param($p)
    if ($p -match "^$($env:SystemRoot -replace '\\','\\')" -or $p -match "^$($env:ProgramFiles -replace '\\','\\')") { return $true }
    try { [System.IO.File]::Open($p,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite).Dispose() } catch [System.UnauthorizedAccessException] { return $true } catch {}
    return $false
}

# Elevation Check
if (-not (Is-Admin)) {
    foreach ($p in $Paths) { if (Needs-Elev $p) { Relaunch-Admin } }
}

$Failed = @()

foreach ($raw in $Paths) {
    $T = $raw.Trim().Trim('"')
    if (-not (Test-Path -LiteralPath $T)) { continue }

    # 1. Clear ReadOnly
    try {
        $i = Get-Item -LiteralPath $T -Force
        if ($i.Attributes -band 1) { $i.Attributes -= 1 }
        if ($i.PSIsContainer) { Get-ChildItem -LiteralPath $T -Recurse -Force -ErrorAction 0 | % { if ($_.Attributes -band 1) { $_.Attributes -= 1 } } }
    } catch {}

    # 2. Try Delete
    try { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction Stop; continue } catch {}

    # 3. Unlock & Retry
    try {
        $l = [RM]::GetLocks($T)
        if ($l.Count -gt 0) {
            foreach ($id in $l) {
                try {
                    $pr = Get-Process -Id $id -ErrorAction Stop
                    if ($CriticalProcesses -notcontains $pr.ProcessName) { Stop-Process -Id $id -Force -ErrorAction 0 }
                } catch {}
            }
            Start-Sleep -Milliseconds 200
            try { Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction Stop; continue } catch { $err = $_.Exception.Message }
        } else { $err = "Access Denied" }
    } catch { $err = $_.Exception.Message }
    
    $Failed += "$T`nError: $err"
}

# Only error UI
if ($Failed.Count -gt 0) {
    [System.Windows.Forms.MessageBox]::Show($Failed -join "`n`n", "Permanent Delete", "OK", "Warning")
}
