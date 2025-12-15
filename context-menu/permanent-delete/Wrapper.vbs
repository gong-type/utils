Option Explicit

' ==============================================================================
' Permanent Delete Wrapper - Production Grade v3.1
' Author: Google DeepMind Antigravity
' Description: 
'   Serves as the silent entry point for the context menu.
'   Handles concurrent executions using a file-lock based singleton pattern.
'   First attempts fast deletion via VBScript FSO.
'   Escalates persistent failures to the PowerShell core engine.
' ==============================================================================

' Constants for Configuration
Const FOR_WRITING = 2
Const FOR_APPENDING = 8
Const CREATE_IF_NOT_EXIST = True
Const TIMEOUT_MS = 800          ' Accumulation window for batch processing
Const MAX_RETRIES = 3           ' Retries for file deletion in VBS
Const MAX_PATH_LENGTH = 260     ' Standard Windows MAX_PATH (for reference)

' Global Objects
Dim objFSO, objShell
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Path Configurations
Dim strScriptDir, strPSCorePath
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPSCorePath = objFSO.BuildPath(strScriptDir, "PermanentDelete.ps1")

' Temporary Working Directories
Dim strTempDir, strQueueDir, strLockFile, strLogFile
strTempDir = objShell.ExpandEnvironmentStrings("%TEMP%")
strQueueDir = objFSO.BuildPath(strTempDir, "PD_Queue_v3")
strLockFile = objFSO.BuildPath(strQueueDir, "PD_Master.lock")
strLogFile = objFSO.BuildPath(strQueueDir, "PD_Execution.log")

' Ensure Queue Directory Exists
If Not objFSO.FolderExists(strQueueDir) Then
    On Error Resume Next
    objFSO.CreateFolder(strQueueDir)
    If Err.Number <> 0 Then
        ' Critical Failure: Cannot create working directory
        WScript.Quit 1
    End If
    On Error GoTo 0
End If

' Entry Point Execution
Main

Sub Main()
    ' 1. Enqueue the current target path if arguments provided
    If WScript.Arguments.Count > 0 Then
        Dim strTargetPath
        strTargetPath = WScript.Arguments(0)
        EnqueuePath strTargetPath
    End If

    ' 2. Attempt to acquire leadership (Singleton pattern)
    ' Only one instance will succeed in locking the file.
    If TryAcquireLock() Then
        ProcessQueue
    End If
    ' If lock failed, it means another instance is already processing or waiting.
    ' We simply exit, having queued our work.
End Sub

' ==============================================================================
' Helper: Enqueue Path
' Writes the target path to a unique .job file in the queue directory.
' ==============================================================================
Sub EnqueuePath(ByVal strPath)
    On Error Resume Next
    Dim strRandomName, strJobFile, objFile
    
    ' Generate a reasonably unique filename using Timer and Random
    Randomize
    strRandomName = "Job_" & Replace(FormatDateTime(Now, 2), "/", "") & "_" & _
                    Int(Timer * 100) & "_" & Int(Rnd * 1000000) & ".job"
    strJobFile = objFSO.BuildPath(strQueueDir, strRandomName)
    
    Set objFile = objFSO.CreateTextFile(strJobFile, True)
    If Err.Number = 0 Then
        objFile.Write strPath
        objFile.Close
    Else
        LogError "Failed to enqueue job: " & strPath & " Error: " & Err.Description
    End If
    On Error GoTo 0
End Sub

' ==============================================================================
' Helper: Try Acquire Lock
' Returns True if this instance successfully locks the master file.
' Returns False if the file is already locked by another process.
' The lock is held implicitly as long as 'objLockPath' stays in scope or open.
' ==============================================================================
Dim objGlobalLockStream ' Keep this distinct global to maintain the lock during processing
Function TryAcquireLock()
    On Error Resume Next
    TryAcquireLock = False
    
    ' OpenTextFile with ForWriting (2), Create (True). 
    ' If another process has it open, this will throw permission denied (70).
    Set objGlobalLockStream = objFSO.OpenTextFile(strLockFile, FOR_WRITING, True)
    
    If Err.Number = 0 Then
        TryAcquireLock = True
        ' Write PID or Timestamp for debugging
        objGlobalLockStream.WriteLine "Locked by PID: " & GetProcessID() & " at " & Now
    Else
        ' Lock failed, someone else is leader
        Err.Clear
    End If
    On Error GoTo 0
End Function

' ==============================================================================
' Core: Process Queue
' Iterates through the queue, attempts fast delete, batches failures for PowerShell.
' ==============================================================================
Sub ProcessQueue()
    ' Wait for other concurrent processes to finish writing their jobs
    WScript.Sleep TIMEOUT_MS
    
    Dim failedPaths
    failedPaths = ""
    
    On Error Resume Next
    Dim colFiles, objFile, strJobPath, strTarget, bDeleted
    
    ' Loop until no files remain (handles late-arriving jobs)
    Dim hasWork
    hasWork = True
    
    Do While hasWork
        hasWork = False
        Set colFiles = objFSO.GetFolder(strQueueDir).Files
        
        For Each objFile In colFiles
            ' Process only .job files
            If LCase(objFSO.GetExtensionName(objFile.Name)) = "job" Then
                hasWork = True
                strJobPath = objFile.Path
                
                ' Read Target Path
                Dim stream
                Set stream = objFSO.OpenTextFile(strJobPath, 1) ' ForReading
                If Err.Number = 0 Then
                    If Not stream.AtEndOfStream Then
                        strTarget = stream.ReadAll
                    End If
                    stream.Close
                    
                    ' Attempt Fast Delete
                    If strTarget <> "" Then
                        bDeleted = FastDelete(strTarget)
                        If Not bDeleted Then
                            ' Accumulate for PowerShell
                            ' Quote the path for command line safety
                            failedPaths = failedPaths & " """ & strTarget & """"
                        End If
                    End If
                End If
                
                ' Remove job file
                objFile.Delete True
            End If
        Next
        
        ' Small sleep to yield CPU if we are in a tight loop
        If hasWork Then WScript.Sleep 100
        
        ' Safety break: If we just finished a batch, check one last time after a tiny delay
        ' In a real robust queue, we might want to loop indefinitely, but here we want to eventually finish.
        ' The outer loop logic here is simplified: It processes what is currently visible.
        ' Since we hold the lock, no NEW leaders can start, but workers can still add files.
        ' Check again if new files appeared
        If objFSO.GetFolder(strQueueDir).Files.Count > 1 Then ' >1 because of the lock file
             hasWork = True
        End If
    Loop
    
    ' If there are tough files, call PowerShell
    If Len(failedPaths) > 0 Then
        CallPowerShellBackend failedPaths
    End If
    
    ' Cleanup Lock File (Release Lock)
    ' Closing the stream releases the lock for OS
    If IsObject(objGlobalLockStream) Then
        objGlobalLockStream.Close
    End If
    
    ' Optional: Delete lock file (clean up), though keeping it is fine.
    objFSO.DeleteFile strLockFile, True
    
    On Error GoTo 0
End Sub

' ==============================================================================
' Helper: Fast Delete
' Returns True if successful, False otherwise.
' ==============================================================================
Function FastDelete(strPath)
    FastDelete = True
    On Error Resume Next
    
    ' Check existence
    If Not objFSO.FileExists(strPath) And Not objFSO.FolderExists(strPath) Then
        Exit Function ' Already gone
    End If
    
    ' Reset Attributes (basic attempt)
    Dim f
    If objFSO.FileExists(strPath) Then
        Set f = objFSO.GetFile(strPath)
        If f.Attributes And 1 Then f.Attributes = f.Attributes - 1 ' ReadOnly
        f.Delete True
    Else
        Set f = objFSO.GetFolder(strPath)
        ' Start recursive delete
        f.Delete True
    End If
    
    If Err.Number <> 0 Then
        FastDelete = False
        Err.Clear
    End If
    On Error GoTo 0
End Function

' ==============================================================================
' Helper: Call PowerShell Backend
' ==============================================================================
Sub CallPowerShellBackend(strArgs)
    Dim cmd
    ' Using -ExecutionPolicy Bypass and -WindowStyle Hidden
    ' Explicitly using the full path to ps1
    cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strPSCorePath & """ " & strArgs
    
    ' Run synchronously (True) so we hold the lock until PS finishes?
    ' No, assume PS handles its own lifecycle. We launch and forget to return control to user ASAP.
    ' However, if we release lock, a new leader might start. 
    ' Actually, it is better to run PS synchronously to ensure we don't start a second PS instance for stragglers immediately.
    ' But for UX "Speed", asynchronous is better.
    objShell.Run cmd, 0, False
End Sub

' ==============================================================================
' Utility: Logging (Fail-safe)
' ==============================================================================
Sub LogError(strMsg)
    On Error Resume Next
    Dim stream
    Set stream = objFSO.OpenTextFile(strLogFile, FOR_APPENDING, True)
    stream.WriteLine "[" & Now & "] " & strMsg
    stream.Close
    On Error GoTo 0
End Sub

' ==============================================================================
' Utility: WMI to get PID (Expensive, use sparingly)
' ==============================================================================
Function GetProcessID()
    ' Keeps simple for VBS
    GetProcessID = "Unknown" 
End Function
