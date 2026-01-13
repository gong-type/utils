Option Explicit

' ==============================================================================
' NukeIt Wrapper - Ultra Silent Edition v4.0
' 
' Features:
' - Zero flicker, zero windows
' - Batch processing with file queue
' - Smart routing: Simple files = VBS, Complex = PowerShell
' - Reserved name detection (nul, con, aux, etc.)
' - Executable detection (avoids SmartScreen)
' - Long path support
' ==============================================================================

Const FOR_WRITING = 2
Const FOR_READING = 1
Const BATCH_DELAY_MS = 150

Dim fso, shell
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

Dim scriptDir, psCorePath, queueDir, lockFile, batchFile
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psCorePath = fso.BuildPath(scriptDir, "NukeIt.ps1")
queueDir = fso.BuildPath(shell.ExpandEnvironmentStrings("%TEMP%"), "NukeIt_Queue")
lockFile = fso.BuildPath(queueDir, "master.lock")
batchFile = fso.BuildPath(queueDir, "batch.txt")

' Windows Reserved Names
Dim reservedNames
reservedNames = Array("con","prn","aux","nul","com1","com2","com3","com4","com5","com6","com7","com8","com9","lpt1","lpt2","lpt3","lpt4","lpt5","lpt6","lpt7","lpt8","lpt9")

' Executable extensions (skip VBS delete to avoid SmartScreen)
Dim exeExtensions
exeExtensions = Array(".exe",".msi",".bat",".cmd",".com",".scr",".pif",".vbs",".vbe",".js",".jse",".wsf",".wsh",".ps1",".msc",".dll",".sys")

' Ensure queue directory exists
EnsureDir queueDir

' Main entry
Main

Sub Main()
    If WScript.Arguments.Count > 0 Then
        EnqueuePath WScript.Arguments(0)
    End If
    
    If TryAcquireLock() Then
        ProcessQueue
    End If
End Sub

Sub EnsureDir(path)
    On Error Resume Next
    If Not fso.FolderExists(path) Then
        fso.CreateFolder(path)
    End If
    On Error GoTo 0
End Sub

Sub EnqueuePath(strPath)
    On Error Resume Next
    Dim f, strName, strFull
    
    ' Generate unique job file name
    Do
        strName = "job_" & fso.GetTempName() & ".txt"
        strFull = fso.BuildPath(queueDir, strName)
        If Not fso.FileExists(strFull) Then Exit Do
    Loop
    
    Set f = fso.CreateTextFile(strFull, True)
    f.Write strPath
    f.Close
    On Error GoTo 0
End Sub

Dim globalLockStream
Function TryAcquireLock()
    On Error Resume Next
    TryAcquireLock = False
    Set globalLockStream = fso.OpenTextFile(lockFile, FOR_WRITING, True)
    If Err.Number = 0 Then TryAcquireLock = True
    On Error GoTo 0
End Function

Function IsExecutable(strPath)
    IsExecutable = False
    Dim ext, i
    ext = LCase(fso.GetExtensionName(strPath))
    If ext <> "" Then ext = "." & ext
    
    For i = 0 To UBound(exeExtensions)
        If ext = exeExtensions(i) Then
            IsExecutable = True
            Exit Function
        End If
    Next
End Function

Function HasReservedName(strPath)
    HasReservedName = False
    Dim parts, p, baseName, i
    
    parts = Split(strPath, "\")
    For Each p In parts
        baseName = LCase(p)
        If InStr(baseName, ".") > 0 Then
            baseName = Left(baseName, InStr(baseName, ".") - 1)
        End If
        
        For i = 0 To UBound(reservedNames)
            If baseName = reservedNames(i) Then
                HasReservedName = True
                Exit Function
            End If
        Next
    Next
End Function

Function HasLongPath(strPath)
    HasLongPath = Len(strPath) > 240
End Function

Function NeedsPowerShell(strPath)
    NeedsPowerShell = False
    
    ' Executables -> PS (avoid SmartScreen)
    If IsExecutable(strPath) Then
        NeedsPowerShell = True
        Exit Function
    End If
    
    ' Reserved names -> PS
    If HasReservedName(strPath) Then
        NeedsPowerShell = True
        Exit Function
    End If
    
    ' Long paths -> PS
    If HasLongPath(strPath) Then
        NeedsPowerShell = True
        Exit Function
    End If
End Function

Sub ProcessQueue()
    ' Wait for batch collection
    WScript.Sleep BATCH_DELAY_MS
    
    Dim vbsTargets, psTargets, cmdTargets
    vbsTargets = ""
    psTargets = ""
    cmdTargets = ""
    
    On Error Resume Next
    Dim colFiles, f, strTarget, hasWork
    hasWork = True
    
    ' Collect all jobs
    Do While hasWork
        hasWork = False
        Set colFiles = fso.GetFolder(queueDir).Files
        
        For Each f In colFiles
            If LCase(Right(f.Name, 4)) = ".txt" And Left(f.Name, 4) = "job_" Then
                hasWork = True
                
                Dim s
                Set s = fso.OpenTextFile(f.Path, FOR_READING)
                strTarget = ""
                If Err.Number = 0 Then
                    If Not s.AtEndOfStream Then strTarget = s.ReadAll
                    s.Close
                End If
                Err.Clear
                
                ' Delete job file
                f.Delete True
                
                If strTarget <> "" Then
                    ' Route based on file type
                    If fso.FolderExists(strTarget) Then
                        ' Folders -> Directly to PowerShell (PS folder logic is much more robust)
                        psTargets = psTargets & " """ & strTarget & """"
                    ElseIf IsExecutable(strTarget) Then
                        ' Executables -> CMD only (avoid SmartScreen completely)
                        If cmdTargets <> "" Then cmdTargets = cmdTargets & "|"
                        cmdTargets = cmdTargets & strTarget
                    ElseIf HasReservedName(strTarget) Or HasLongPath(strTarget) Then
                        ' Reserved names / long paths -> PowerShell
                        psTargets = psTargets & " """ & strTarget & """"
                    Else
                        ' Normal files -> VBS fast path
                        If vbsTargets <> "" Then vbsTargets = vbsTargets & "|"
                        vbsTargets = vbsTargets & strTarget
                    End If
                End If
            End If
        Next
        
        ' Check for more jobs
        If fso.GetFolder(queueDir).Files.Count > 1 Then hasWork = True
        If hasWork Then WScript.Sleep 50
    Loop
    
    ' Process CMD targets first (executables - completely silent via cmd)
    If cmdTargets <> "" Then
        Dim cmdItems, c, cmdBatch, failedCmd
        cmdItems = Split(cmdTargets, "|")
        
        ' Try batch delete first (much faster for multiple files)
        If UBound(cmdItems) > 0 Then
            cmdBatch = ""
            For Each c In cmdItems
                cmdBatch = cmdBatch & """" & c & """ "
            Next
            shell.Run "cmd /c del /f /q /a " & cmdBatch, 0, True
        End If
        
        ' Check which ones failed and retry individually
        failedCmd = ""
        For Each c In cmdItems
            If fso.FileExists(c) Then
                ' Try with attrib first
                shell.Run "cmd /c attrib -r -s -h """ & c & """ & del /f /q /a """ & c & """", 0, True
                
                If fso.FileExists(c) Then
                    ' Send to PowerShell as last resort
                    psTargets = psTargets & " """ & c & """"
                End If
            End If
        Next
    End If
    
    ' Process VBS targets (fast path for normal files)
    If vbsTargets <> "" Then
        Dim targets, t, deleted
        targets = Split(vbsTargets, "|")
        
        For Each t In targets
            deleted = False
            Err.Clear
            
            If fso.FileExists(t) Then
                fso.DeleteFile t, True
                If Err.Number = 0 Then deleted = True
            Else
                ' Already gone or is folder (folders shouldn't be here now)
                If Not fso.FolderExists(t) Then deleted = True
            End If
            
            ' If VBS failed, send to PowerShell
            If Not deleted Then
                psTargets = psTargets & " """ & t & """"
            End If
        Next
    End If
    
    ' Process PowerShell targets (heavy path - reserved names, long paths, failed items)
    If Len(Trim(psTargets)) > 0 Then
        ' Run completely hidden
        shell.Run "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psCorePath & """" & psTargets, 0, False
    End If
    
    ' Cleanup
    If IsObject(globalLockStream) Then globalLockStream.Close
    On Error Resume Next
    fso.DeleteFile lockFile, True
    On Error GoTo 0
End Sub
