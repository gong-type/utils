# Directory Tree Export - Enhanced Version with Chinese UI
param ([string]$TargetDir = ".")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Config = @{ DefaultDepth = 3; DefaultIgnore = @("node_modules", ".git", "bin", "obj", ".vs", "dist", "build", "__pycache__", ".idea", "vendor", "packages") }

# Calculate folder size recursively
function Get-FolderSize {
    param ([string]$Path)
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) { $size = 0 }
        return $size
    } catch { return 0 }
}

function Get-DirectoryTree {
    param ([string]$RootPath, [int]$MaxDepth, [string[]]$IgnoreList, [bool]$ShowFiles, [bool]$ShowSize, [bool]$ShowDate)
    $script:TreeLines = [System.Collections.ArrayList]::new()
    $script:FileCount = 0; $script:DirCount = 0
    
    # Handle root path - ensure it ends with backslash for root directories
    $normalizedPath = $RootPath.TrimEnd('\')
    if ($normalizedPath -match '^[A-Za-z]:$') {
        $normalizedPath = $normalizedPath + '\'
    }
    
    $resolvedPath = Resolve-Path $normalizedPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) { return @("Error: $RootPath") }
    
    $fullPath = $resolvedPath.Path
    $rootName = Split-Path $fullPath -Leaf
    # For drive roots like C:\, use the full path as the name
    if ([string]::IsNullOrEmpty($rootName)) { $rootName = $fullPath }
    
    # Show root folder with size if enabled
    $rootLine = $rootName
    if ($ShowSize) {
        $rootSize = Get-FolderSize -Path $resolvedPath.Path
        $rootLine += "  [" + (Format-FileSize $rootSize) + "]"
    }
    [void]$script:TreeLines.Add($rootLine)
    
    Build-TreeRecursive -CurrentPath $resolvedPath.Path -Indent "" -CurrentDepth 0 -MaxDepth $MaxDepth -IgnoreList $IgnoreList -ShowFiles $ShowFiles -ShowSize $ShowSize -ShowDate $ShowDate
    return $script:TreeLines.ToArray()
}

function Format-FileSize {
    param ([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Build-TreeRecursive {
    param ([string]$CurrentPath, [string]$Indent, [int]$CurrentDepth, [int]$MaxDepth, [string[]]$IgnoreList, [bool]$ShowFiles, [bool]$ShowSize, [bool]$ShowDate)
    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) { return }
    try { $items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue | Sort-Object @{Expression={-not $_.PSIsContainer}}, Name } catch { return }
    $filteredItems = $items | Where-Object {
        $n = $_.Name
        if ($_.PSIsContainer) { $ig = $false; foreach ($p in $IgnoreList) { if ($p -match '[\*\?]') { if ($n -like $p) { $ig = $true; break } } else { if ($n -eq $p) { $ig = $true; break } } }; return -not $ig }
        else { return $ShowFiles }
    }
    $arr = @($filteredItems); $cnt = $arr.Count
    for ($i = 0; $i -lt $cnt; $i++) {
        $item = $arr[$i]; $isLast = ($i -eq $cnt - 1)
        $branch = if ($isLast) { "+-- " } else { "|-- " }
        $line = "$Indent$branch$($item.Name)"
        
        if ($ShowSize) {
            if ($item.PSIsContainer) {
                # Calculate folder size
                $folderSize = Get-FolderSize -Path $item.FullName
                $line += "  [" + (Format-FileSize $folderSize) + "]"
            } else {
                $line += "  [" + (Format-FileSize $item.Length) + "]"
            }
        }
        
        if ($ShowDate) { $line += "  ($($item.LastWriteTime.ToString('yyyy-MM-dd')))" }
        [void]$script:TreeLines.Add($line)
        if ($item.PSIsContainer) { $script:DirCount++; $ni = if ($isLast) { "$Indent    " } else { "$Indent|   " }; Build-TreeRecursive -CurrentPath $item.FullName -Indent $ni -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth -IgnoreList $IgnoreList -ShowFiles $ShowFiles -ShowSize $ShowSize -ShowDate $ShowDate }
        else { $script:FileCount++ }
    }
}

# Chinese UI using Unicode code points
$UI = @{
    Title = [char]30446 + [char]24405 + [char]32467 + [char]26500 + [char]23548 + [char]20986   # 目录结构导出
    ShowFiles = [char]26174 + [char]31034 + [char]25991 + [char]20214                           # 显示文件
    ShowSize = [char]26174 + [char]31034 + [char]22823 + [char]23567                            # 显示大小
    ShowDate = [char]26174 + [char]31034 + [char]26085 + [char]26399                            # 显示日期
    Ignore = [char]24573 + [char]30053 + [char]21015 + [char]34920                              # 忽略列表
    Copy = [char]22797 + [char]21046 + " (Ctrl+C)"                                               # 复制 (Ctrl+C)
    Save = [char]20445 + [char]23384 + " (Ctrl+S)"                                               # 保存 (Ctrl+S)
    Copied = [char]24050 + [char]22797 + [char]21046 + "!"                                       # 已复制!
    Ready = [char]23601 + [char]32490                                                            # 就绪
    Loading = [char]21152 + [char]36733 + [char]20013 + "..."                                    # 加载中...
    Depth = [char]28145 + [char]24230 + ":"                                                      # 深度:
    Hint = "[1-9] " + [char]28145 + [char]24230 + " | [Ctrl+C] " + [char]22797 + [char]21046 + " | [Ctrl+S] " + [char]20445 + [char]23384 + " | [F5] " + [char]21047 + [char]26032
    Lines = [char]34892 + [char]25968                                                            # 行数
    Dirs = [char]25991 + [char]20214 + [char]22841                                               # 文件夹
    Files = [char]25991 + [char]20214                                                            # 文件
    DevPreset = [char]24320 + [char]21457 + [char]27169 + [char]24335                           # 开发模式
    CleanPreset = [char]31934 + [char]31616 + [char]27169 + [char]24335                         # 精简模式
    SizeNote = "(" + [char]21253 + [char]25324 + [char]25991 + [char]20214 + [char]22841 + ")"  # (含文件夹)
}

$bgDark = [System.Drawing.Color]::FromArgb(32, 32, 32)
$bgPanel = [System.Drawing.Color]::FromArgb(45, 45, 48)
$bgInput = [System.Drawing.Color]::FromArgb(30, 30, 30)
$accentBlue = [System.Drawing.Color]::FromArgb(0, 122, 204)
$accentGreen = [System.Drawing.Color]::FromArgb(78, 201, 176)
$textWhite = [System.Drawing.Color]::FromArgb(220, 220, 220)
$textGray = [System.Drawing.Color]::FromArgb(150, 150, 150)
$borderColor = [System.Drawing.Color]::FromArgb(63, 63, 70)

$form = New-Object System.Windows.Forms.Form
$form.Text = $UI.Title
$form.Size = New-Object System.Drawing.Size(720, 540)
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgDark
$form.ForeColor = $textWhite
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
$form.KeyPreview = $true

$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Dock = "Top"
$panelHeader.Height = 70
$panelHeader.BackColor = $bgPanel
$form.Controls.Add($panelHeader)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Location = New-Object System.Drawing.Point(12, 8)
$lblPath.Size = New-Object System.Drawing.Size(680, 20)
$lblPath.Text = $TargetDir
$lblPath.Font = New-Object System.Drawing.Font("Consolas", 9)
$lblPath.ForeColor = $accentGreen
$panelHeader.Controls.Add($lblPath)

$lblDepth = New-Object System.Windows.Forms.Label
$lblDepth.Location = New-Object System.Drawing.Point(12, 40)
$lblDepth.AutoSize = $true
$lblDepth.Text = $UI.Depth
$lblDepth.ForeColor = $textGray
$panelHeader.Controls.Add($lblDepth)

$numDepth = New-Object System.Windows.Forms.NumericUpDown
$numDepth.Location = New-Object System.Drawing.Point(60, 37)
$numDepth.Size = New-Object System.Drawing.Size(50, 24)
$numDepth.Minimum = 1
$numDepth.Maximum = 20
$numDepth.Value = 3
$numDepth.BackColor = $bgInput
$numDepth.ForeColor = $textWhite
$panelHeader.Controls.Add($numDepth)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Location = New-Object System.Drawing.Point(120, 40)
$lblHint.AutoSize = $true
$lblHint.Text = $UI.Hint
$lblHint.ForeColor = $textGray
$lblHint.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
$panelHeader.Controls.Add($lblHint)

$panelLeft = New-Object System.Windows.Forms.Panel
$panelLeft.Location = New-Object System.Drawing.Point(0, 70)
$panelLeft.Size = New-Object System.Drawing.Size(190, 410)
$panelLeft.BackColor = $bgPanel
$panelLeft.Anchor = "Top,Left,Bottom"
$form.Controls.Add($panelLeft)

$chkFiles = New-Object System.Windows.Forms.CheckBox
$chkFiles.Location = New-Object System.Drawing.Point(10, 10)
$chkFiles.Size = New-Object System.Drawing.Size(170, 22)
$chkFiles.Text = $UI.ShowFiles
$chkFiles.ForeColor = $textWhite
$chkFiles.Checked = $true
$chkFiles.FlatStyle = "Flat"
$panelLeft.Controls.Add($chkFiles)

$chkSize = New-Object System.Windows.Forms.CheckBox
$chkSize.Location = New-Object System.Drawing.Point(10, 35)
$chkSize.Size = New-Object System.Drawing.Size(170, 22)
$chkSize.Text = $UI.ShowSize + " " + $UI.SizeNote
$chkSize.ForeColor = $textWhite
$chkSize.FlatStyle = "Flat"
$panelLeft.Controls.Add($chkSize)

$chkDate = New-Object System.Windows.Forms.CheckBox
$chkDate.Location = New-Object System.Drawing.Point(10, 60)
$chkDate.Size = New-Object System.Drawing.Size(170, 22)
$chkDate.Text = $UI.ShowDate
$chkDate.ForeColor = $textWhite
$chkDate.FlatStyle = "Flat"
$panelLeft.Controls.Add($chkDate)

$sep1 = New-Object System.Windows.Forms.Label
$sep1.Location = New-Object System.Drawing.Point(10, 90)
$sep1.Size = New-Object System.Drawing.Size(170, 1)
$sep1.BackColor = $borderColor
$panelLeft.Controls.Add($sep1)

$lblIgnore = New-Object System.Windows.Forms.Label
$lblIgnore.Location = New-Object System.Drawing.Point(10, 100)
$lblIgnore.Size = New-Object System.Drawing.Size(170, 18)
$lblIgnore.Text = $UI.Ignore
$lblIgnore.ForeColor = $accentBlue
$lblIgnore.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
$panelLeft.Controls.Add($lblIgnore)

$txtIgnore = New-Object System.Windows.Forms.TextBox
$txtIgnore.Location = New-Object System.Drawing.Point(10, 122)
$txtIgnore.Size = New-Object System.Drawing.Size(170, 140)
$txtIgnore.Multiline = $true
$txtIgnore.ScrollBars = "Vertical"
$txtIgnore.BackColor = $bgInput
$txtIgnore.ForeColor = $textWhite
$txtIgnore.Font = New-Object System.Drawing.Font("Consolas", 8)
$txtIgnore.BorderStyle = "FixedSingle"
$txtIgnore.Text = $script:Config.DefaultIgnore -join "`r`n"
$panelLeft.Controls.Add($txtIgnore)

$btnPresetDev = New-Object System.Windows.Forms.Button
$btnPresetDev.Location = New-Object System.Drawing.Point(10, 270)
$btnPresetDev.Size = New-Object System.Drawing.Size(80, 26)
$btnPresetDev.Text = $UI.DevPreset
$btnPresetDev.FlatStyle = "Flat"
$btnPresetDev.BackColor = $bgDark
$btnPresetDev.ForeColor = $textWhite
$btnPresetDev.FlatAppearance.BorderColor = $borderColor
$btnPresetDev.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
$panelLeft.Controls.Add($btnPresetDev)

$btnPresetClean = New-Object System.Windows.Forms.Button
$btnPresetClean.Location = New-Object System.Drawing.Point(100, 270)
$btnPresetClean.Size = New-Object System.Drawing.Size(80, 26)
$btnPresetClean.Text = $UI.CleanPreset
$btnPresetClean.FlatStyle = "Flat"
$btnPresetClean.BackColor = $bgDark
$btnPresetClean.ForeColor = $textWhite
$btnPresetClean.FlatAppearance.BorderColor = $borderColor
$btnPresetClean.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
$panelLeft.Controls.Add($btnPresetClean)

$sep2 = New-Object System.Windows.Forms.Label
$sep2.Location = New-Object System.Drawing.Point(10, 305)
$sep2.Size = New-Object System.Drawing.Size(170, 1)
$sep2.BackColor = $borderColor
$panelLeft.Controls.Add($sep2)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Location = New-Object System.Drawing.Point(10, 315)
$btnCopy.Size = New-Object System.Drawing.Size(170, 36)
$btnCopy.Text = $UI.Copy
$btnCopy.FlatStyle = "Flat"
$btnCopy.BackColor = $accentBlue
$btnCopy.ForeColor = [System.Drawing.Color]::White
$btnCopy.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
$btnCopy.FlatAppearance.BorderSize = 0
$btnCopy.Cursor = "Hand"
$panelLeft.Controls.Add($btnCopy)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(10, 360)
$btnSave.Size = New-Object System.Drawing.Size(170, 32)
$btnSave.Text = $UI.Save
$btnSave.FlatStyle = "Flat"
$btnSave.BackColor = $bgDark
$btnSave.ForeColor = $textWhite
$btnSave.FlatAppearance.BorderColor = $borderColor
$btnSave.Cursor = "Hand"
$panelLeft.Controls.Add($btnSave)

$txtPreview = New-Object System.Windows.Forms.TextBox
$txtPreview.Location = New-Object System.Drawing.Point(195, 75)
$txtPreview.Size = New-Object System.Drawing.Size(508, 400)
$txtPreview.Multiline = $true
$txtPreview.ScrollBars = "Both"
$txtPreview.ReadOnly = $true
$txtPreview.BackColor = $bgInput
$txtPreview.ForeColor = $textWhite
$txtPreview.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtPreview.BorderStyle = "FixedSingle"
$txtPreview.WordWrap = $false
$txtPreview.Anchor = "Top,Left,Right,Bottom"
$form.Controls.Add($txtPreview)

$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.BackColor = $bgPanel
$form.Controls.Add($statusBar)
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.ForeColor = $textGray
$statusLabel.Text = $UI.Ready
$statusBar.Items.Add($statusLabel)

function Update-Preview {
    $statusLabel.Text = $UI.Loading
    $form.Refresh()
    $depth = [int]$numDepth.Value
    $ignoreList = $txtIgnore.Text -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
    $tree = Get-DirectoryTree -RootPath $TargetDir -MaxDepth $depth -IgnoreList $ignoreList -ShowFiles $chkFiles.Checked -ShowSize $chkSize.Checked -ShowDate $chkDate.Checked
    $txtPreview.Text = $tree -join "`r`n"
    $statusLabel.Text = "$($UI.Lines): $($tree.Count) | $($UI.Dirs): $script:DirCount | $($UI.Files): $script:FileCount | $($UI.Depth) $depth"
}

$numDepth.Add_ValueChanged({ Update-Preview })
$chkFiles.Add_CheckedChanged({ Update-Preview })
$chkSize.Add_CheckedChanged({ Update-Preview })
$chkDate.Add_CheckedChanged({ Update-Preview })

$script:FilterTimer = New-Object System.Windows.Forms.Timer
$script:FilterTimer.Interval = 500
$script:FilterTimer.Add_Tick({ $script:FilterTimer.Stop(); Update-Preview })
$txtIgnore.Add_TextChanged({ $script:FilterTimer.Stop(); $script:FilterTimer.Start() })

$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -ge [System.Windows.Forms.Keys]::D1 -and $e.KeyCode -le [System.Windows.Forms.Keys]::D9) { $numDepth.Value = [Math]::Min([int]($e.KeyCode) - [int][System.Windows.Forms.Keys]::D0, $numDepth.Maximum); $e.Handled = $true }
    elseif ($e.KeyCode -ge [System.Windows.Forms.Keys]::NumPad1 -and $e.KeyCode -le [System.Windows.Forms.Keys]::NumPad9) { $numDepth.Value = [Math]::Min([int]($e.KeyCode) - [int][System.Windows.Forms.Keys]::NumPad0, $numDepth.Maximum); $e.Handled = $true }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::D0 -or $e.KeyCode -eq [System.Windows.Forms.Keys]::NumPad0) { $numDepth.Value = 10; $e.Handled = $true }
    elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::C -and -not $txtPreview.Focused) { $btnCopy.PerformClick(); $e.Handled = $true }
    elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::S) { $btnSave.PerformClick(); $e.Handled = $true; $e.SuppressKeyPress = $true }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::F5) { Update-Preview; $e.Handled = $true }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
})

$btnCopy.Add_Click({
    if ($txtPreview.Text.Length -gt 0) {
        Set-Clipboard -Value $txtPreview.Text
        $statusLabel.Text = $UI.Copied + " ($($txtPreview.Text.Length))"
        $oc = $btnCopy.BackColor; $btnCopy.BackColor = $accentGreen; $btnCopy.Text = $UI.Copied
        $ft = New-Object System.Windows.Forms.Timer; $ft.Interval = 1200
        $ft.Add_Tick({ $btnCopy.BackColor = $oc; $btnCopy.Text = $UI.Copy; $ft.Stop(); $ft.Dispose() })
        $ft.Start()
    }
})

$btnSave.Add_Click({
    $sd = New-Object System.Windows.Forms.SaveFileDialog
    $sd.InitialDirectory = $TargetDir
    $sd.Filter = "Text (*.txt)|*.txt|Markdown (*.md)|*.md|All (*.*)|*.*"
    $sd.FileName = "tree.txt"
    if ($sd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtPreview.Text | Out-File -FilePath $sd.FileName -Encoding UTF8
        $statusLabel.Text = ([char]24050 + [char]20445 + [char]23384 + ": " + $sd.FileName)
        $msg = [char]26159 + [char]21542 + [char]25171 + [char]24320 + [char]25991 + [char]20214 + "?"
        if ([System.Windows.Forms.MessageBox]::Show($msg, [char]20445 + [char]23384 + [char]25104 + [char]21151, "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::Yes) { Invoke-Item $sd.FileName }
    }
})

$btnPresetDev.Add_Click({ $txtIgnore.Text = @("node_modules",".git",".svn","bin","obj",".vs",".idea","dist","build","__pycache__","vendor","packages","coverage",".cache","*.log") -join "`r`n" })
$btnPresetClean.Add_Click({ $txtIgnore.Text = @(".*","node_modules","__pycache__") -join "`r`n" })

$form.Add_Shown({ Update-Preview; $txtPreview.Focus() })
$form.Add_Resize({ $panelLeft.Height = $form.ClientSize.Height - 92; $txtPreview.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 205), ($form.ClientSize.Height - 100)) })

[void]$form.ShowDialog()
$script:FilterTimer.Dispose()
$form.Dispose()
