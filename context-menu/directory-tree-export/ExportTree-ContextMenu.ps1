<#
.SYNOPSIS
    GUI Wrapper for Export-DirectoryTree.
.DESCRIPTION
    Provides a Windows Forms interface to configure export settings.
#>
param (
    [string]$TargetDir = "."
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Form Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "Export Directory Tree"
$form.Size = New-Object System.Drawing.Size(450, 450)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Label: Directory
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Location = New-Object System.Drawing.Point(20, 20)
$lblPath.Size = New-Object System.Drawing.Size(400, 20)
$lblPath.Text = "Target: $TargetDir"
$form.Controls.Add($lblPath)

# GroupBox: Settings
$grpSettings = New-Object System.Windows.Forms.GroupBox
$grpSettings.Location = New-Object System.Drawing.Point(20, 50)
$grpSettings.Size = New-Object System.Drawing.Size(400, 180)
$grpSettings.Text = "Settings"
$form.Controls.Add($grpSettings)

# Depth
$lblDepth = New-Object System.Windows.Forms.Label
$lblDepth.Location = New-Object System.Drawing.Point(20, 30)
$lblDepth.Text = "Max Depth:"
$lblDepth.AutoSize = $true
$grpSettings.Controls.Add($lblDepth)

$numDepth = New-Object System.Windows.Forms.NumericUpDown
$numDepth.Location = New-Object System.Drawing.Point(120, 28)
$numDepth.Minimum = -1
$numDepth.Maximum = 100
$numDepth.Value = 3
$grpSettings.Controls.Add($numDepth)

$lblDepthHint = New-Object System.Windows.Forms.Label
$lblDepthHint.Location = New-Object System.Drawing.Point(250, 30)
$lblDepthHint.Text = "(-1 for unlimited)"
$lblDepthHint.AutoSize = $true
$grpSettings.Controls.Add($lblDepthHint)

# Ignore
$lblIgnore = New-Object System.Windows.Forms.Label
$lblIgnore.Location = New-Object System.Drawing.Point(20, 70)
$lblIgnore.Text = "Ignore Folders:"
$lblIgnore.AutoSize = $true
$grpSettings.Controls.Add($lblIgnore)

$txtIgnore = New-Object System.Windows.Forms.TextBox
$txtIgnore.Location = New-Object System.Drawing.Point(120, 68)
$txtIgnore.Size = New-Object System.Drawing.Size(260, 23)
$txtIgnore.Text = "node_modules, .git, bin, obj, .vs, dist, build, __pycache__"
$grpSettings.Controls.Add($txtIgnore)

# Include Files
$chkFiles = New-Object System.Windows.Forms.CheckBox
$chkFiles.Location = New-Object System.Drawing.Point(20, 110)
$chkFiles.Text = "Include Files (Not just folders)"
$chkFiles.AutoSize = $true
$grpSettings.Controls.Add($chkFiles)

# Output Options
$grpOutput = New-Object System.Windows.Forms.GroupBox
$grpOutput.Location = New-Object System.Drawing.Point(20, 240)
$grpOutput.Size = New-Object System.Drawing.Size(400, 100)
$grpOutput.Text = "Output Action"
$form.Controls.Add($grpOutput)

$radClip = New-Object System.Windows.Forms.RadioButton
$radClip.Location = New-Object System.Drawing.Point(20, 30)
$radClip.Text = "Copy to Clipboard"
$radClip.Checked = $true
$radClip.AutoSize = $true
$grpOutput.Controls.Add($radClip)

$radFile = New-Object System.Windows.Forms.RadioButton
$radFile.Location = New-Object System.Drawing.Point(200, 30)
$radFile.Text = "Save to tree.txt"
$radFile.AutoSize = $true
$grpOutput.Controls.Add($radFile)

$chkOpen = New-Object System.Windows.Forms.CheckBox
$chkOpen.Location = New-Object System.Drawing.Point(200, 60)
$chkOpen.Text = "Open file after saving"
$chkOpen.Enabled = $false
$chkOpen.AutoSize = $true
$grpOutput.Controls.Add($chkOpen)

$radFile.Add_CheckedChanged({ $chkOpen.Enabled = $radFile.Checked })

# Buttons
$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Location = New-Object System.Drawing.Point(120, 360)
$btnExport.Size = New-Object System.Drawing.Size(100, 30)
$btnExport.Text = "Export"
$btnExport.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnExport)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(230, 360)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($btnCancel)

# Show Dialog
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Export-DirectoryTree.ps1"

    $ignoreList = $txtIgnore.Text -split "," | ForEach-Object { $_.Trim() }

    $params = @{
        Path = $TargetDir
        MaxDepth = [int]$numDepth.Value
        Ignore = $ignoreList
    }

    if ($chkFiles.Checked) { $params.ShowFiles = $true }

    try {
        # Call the core logic
        $output = & $scriptPath @params
        $textOutput = $output -join [Environment]::NewLine

        if ($radClip.Checked) {
            Set-Clipboard -Value $textOutput
            [System.Windows.Forms.MessageBox]::Show("Directory tree copied to clipboard!", "Success", "OK", "Information")
        } elseif ($radFile.Checked) {
            $outFile = Join-Path $TargetDir "tree.txt"
            $textOutput | Out-File -FilePath $outFile -Encoding UTF8
            if ($chkOpen.Checked) {
                Invoke-Item $outFile
            } else {
                 [System.Windows.Forms.MessageBox]::Show("Saved to $outFile", "Success", "OK", "Information")
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error", "OK", "Error")
    }
}
