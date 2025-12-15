Option Explicit

' ==============================================================================
' Permanent Delete Wrapper - Pure Speed Edition
' ==============================================================================

Const FOR_WRITING = 2
Const TIMEOUT_MS = 500 ' Reduced wait time for snappier feel

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

' Ensure Queue Directory
If Not objFSO.FolderExists(strQueueDir) Then
    On Error Resume Next
    objFSO.CreateFolder(strQueueDir)
    On Error GoTo 0
End If

Main

Sub Main()
    ' 1. Enqueue
    If WScript.Arguments.Count > 0 Then EnqueuePath WScript.Arguments(0)

    ' 2. Try to be Leader
    If TryAcquireLock() Then ProcessQueue
End Sub

Sub EnqueuePath(ByVal strPath)
    On Error Resume Next
    ' Minimalistic random name
    Randomize
    Dim f
    Set f = objFSO.CreateTextFile(strQueueDir & "\J_" & Int(Timer*100) & "_" & Int(Rnd*100000) & ".job", True)
    f.Write strPath
    f.Close
    On Error GoTo 0
End Sub

Dim objGlobalLockStream
Function TryAcquireLock()
    On Error Resume Next
    TryAcquireLock = False
    ' Exclusive lock attempt
    Set objGlobalLockStream = objFSO.OpenTextFile(strLockFile, FOR_WRITING, True)
    If Err.Number = 0 Then TryAcquireLock = True
    On Error GoTo 0
End Function

Sub ProcessQueue()
    WScript.Sleep TIMEOUT_MS
    
    Dim failedPaths
    failedPaths = ""
    
    On Error Resume Next
    Dim colFiles, f, strJobPath, strTarget, bDeleted, hasWork
    hasWork = True
    
    Do While hasWork
        hasWork = False
        Set colFiles = objFSO.GetFolder(strQueueDir).Files
        
        For Each f In colFiles
            If Right(f.Name, 4) = ".job" Then
                hasWork = True
                strJobPath = f.Path
                
                ' Read Path
                Dim s
                Set s = objFSO.OpenTextFile(strJobPath, 1)
                If Err.Number = 0 Then
                    If Not s.AtEndOfStream Then strTarget = s.ReadAll
                    s.Close
                    
                    ' FAST DELETE v2 (Direct FSO)
                    If strTarget <> "" Then
                        Err.Clear
                        If objFSO.FileExists(strTarget) Then
                            objFSO.DeleteFile strTarget, True
                        ElseIf objFSO.FolderExists(strTarget) Then
                            objFSO.DeleteFolder strTarget, True
                        End If
                        
                        If Err.Number <> 0 Then
                            ' Keep for PS
                            failedPaths = failedPaths & " """ & strTarget & """"
                        End If
                    End If
                End If
                
                f.Delete True
            End If
        Next
        If hasWork Then WScript.Sleep 50 
        If objFSO.GetFolder(strQueueDir).Files.Count > 1 Then hasWork = True
    Loop
    
    If Len(failedPaths) > 0 Then
        ' Launch PS silently
        objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strPSCorePath & """ " & failedPaths, 0, False
    End If
    
    If IsObject(objGlobalLockStream) Then objGlobalLockStream.Close
    objFSO.DeleteFile strLockFile, True
    On Error GoTo 0
End Sub
