Option Explicit

' ==============================================================================
' Permanent Delete Wrapper - Pure Speed Edition v3.6
' Fix: Skip VBS delete for exe/msi/bat files to avoid SmartScreen warnings
' ==============================================================================

Const FOR_WRITING = 2
Const TIMEOUT_MS = 500 

Dim objFSO, objShell
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

Dim strScriptDir, strPSCorePath
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPSCorePath = objFSO.BuildPath(strScriptDir, "PermanentDelete.ps1")

Dim strTempDir, strQueueDir, strLockFile
strTempDir = objShell.ExpandEnvironmentStrings("%TEMP%")
strQueueDir = objFSO.BuildPath(strTempDir, "PD_Queue_v3")
strLockFile = objFSO.BuildPath(strQueueDir, "PD_Master.lock")

' Windows Reserved Names
Dim reservedNames
reservedNames = Array("con","prn","aux","nul","com1","com2","com3","com4","com5","com6","com7","com8","com9","lpt1","lpt2","lpt3","lpt4","lpt5","lpt6","lpt7","lpt8","lpt9")

' Executable extensions that may trigger SmartScreen warnings
Dim exeExtensions
exeExtensions = Array(".exe",".msi",".bat",".cmd",".com",".scr",".pif",".vbs",".vbe",".js",".jse",".wsf",".wsh",".ps1",".msc")

' Ensure Queue Directory
If Not objFSO.FolderExists(strQueueDir) Then
    On Error Resume Next
    objFSO.CreateFolder(strQueueDir)
    On Error GoTo 0
End If

Main

Sub Main()
    If WScript.Arguments.Count > 0 Then EnqueuePath WScript.Arguments(0)
    If TryAcquireLock() Then ProcessQueue
End Sub

Sub EnqueuePath(ByVal strPath)
    On Error Resume Next
    Dim strName, strFull, f
    Do
        strName = "J_" & objFSO.GetTempName() & ".job" 
        strFull = objFSO.BuildPath(strQueueDir, strName)
        If Not objFSO.FileExists(strFull) Then Exit Do
    Loop
    Set f = objFSO.CreateTextFile(strFull, True)
    f.Write strPath
    f.Close
    On Error GoTo 0
End Sub

Dim objGlobalLockStream
Function TryAcquireLock()
    On Error Resume Next
    TryAcquireLock = False
    Set objGlobalLockStream = objFSO.OpenTextFile(strLockFile, FOR_WRITING, True)
    If Err.Number = 0 Then TryAcquireLock = True
    On Error GoTo 0
End Function

' Check if file is an executable type (may trigger SmartScreen)
Function IsExecutable(strPath)
    IsExecutable = False
    Dim ext, i
    ext = LCase(objFSO.GetExtensionName(strPath))
    If ext <> "" Then ext = "." & ext
    
    For i = 0 To UBound(exeExtensions)
        If ext = exeExtensions(i) Then
            IsExecutable = True
            Exit Function
        End If
    Next
End Function

' Check if path contains Windows reserved names
Function HasReservedName(strPath)
    HasReservedName = False
    Dim i, baseName, parts, p
    
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

' Check if path should skip VBS and go directly to PowerShell
Function ShouldSkipVBS(strPath)
    ShouldSkipVBS = False
    
    ' Skip executables (avoid SmartScreen)
    If IsExecutable(strPath) Then
        ShouldSkipVBS = True
        Exit Function
    End If
    
    ' Skip reserved names
    If HasReservedName(strPath) Then
        ShouldSkipVBS = True
        Exit Function
    End If
End Function

Sub ProcessQueue()
    WScript.Sleep TIMEOUT_MS
    
    Dim failedPaths
    failedPaths = ""
    
    On Error Resume Next
    Dim colFiles, f, strTarget, hasWork, bDeleted
    hasWork = True
    
    Do While hasWork
        hasWork = False
        Set colFiles = objFSO.GetFolder(strQueueDir).Files
        
        For Each f In colFiles
            If LCase(Right(f.Name, 4)) = ".job" Then
                hasWork = True
                
                Dim s
                Set s = objFSO.OpenTextFile(f.Path, 1)
                strTarget = ""
                If Err.Number = 0 Then
                    If Not s.AtEndOfStream Then strTarget = s.ReadAll
                    s.Close
                End If
                
                f.Delete True 
                
                If strTarget <> "" Then
                    bDeleted = False
                    
                    ' Check if should skip VBS processing
                    If ShouldSkipVBS(strTarget) Then
                        ' Send directly to PowerShell
                        failedPaths = failedPaths & " """ & strTarget & """"
                    Else
                        ' Standard VBS fast delete
                        Err.Clear
                        If objFSO.FileExists(strTarget) Then
                            objFSO.DeleteFile strTarget, True
                            If Err.Number = 0 Then bDeleted = True
                        ElseIf objFSO.FolderExists(strTarget) Then
                            objFSO.DeleteFolder strTarget, True
                            If Err.Number = 0 Then bDeleted = True
                        Else
                            failedPaths = failedPaths & " """ & strTarget & """"
                            bDeleted = True
                        End If
                        
                        If Not bDeleted Then
                            failedPaths = failedPaths & " """ & strTarget & """"
                        End If
                    End If
                End If
            End If
        Next
        
        If objFSO.GetFolder(strQueueDir).Files.Count > 1 Then hasWork = True
        If hasWork Then WScript.Sleep 50
    Loop
    
    If Len(failedPaths) > 0 Then
        objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strPSCorePath & """ " & failedPaths, 0, False
    End If
    
    If IsObject(objGlobalLockStream) Then objGlobalLockStream.Close
    objFSO.DeleteFile strLockFile, True
    On Error GoTo 0
End Sub
