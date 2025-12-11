<#
.SYNOPSIS
    Generates a directory tree structure.
.DESCRIPTION
    Outputs a tree view of the directory structure. Supports ignoring specific folders and limiting depth.
.PARAMETER Path
    The root directory path.
.PARAMETER MaxDepth
    Maximum depth to traverse. Default is 3. Set to -1 for unlimited.
.PARAMETER Ignore
    Comma-separated list of folder names to ignore.
.PARAMETER ShowFiles
    Switch to include files in the output. Default is directories only.
#>
param (
    [string]$Path = ".",
    [int]$MaxDepth = 3,
    [string[]]$Ignore = @("node_modules", ".git", "bin", "obj", ".vs", "dist", "build", "__pycache__"),
    [switch]$ShowFiles
)

function Get-Tree {
    param (
        [string]$CurrentPath,
        [string]$Indent,
        [int]$CurrentDepth
    )

    if ($MaxDepth -ne -1 -and $CurrentDepth -gt $MaxDepth) { return }

    $Items = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue | Sort-Object Name

    # Filter items
    $Items = $Items | Where-Object {
        if ($_.PSIsContainer) {
            return $Ignore -notcontains $_.Name
        } else {
            return $ShowFiles
        }
    }

    $Count = $Items.Count
    $Index = 0

    foreach ($Item in $Items) {
        $Index++
        $IsLast = $Index -eq $Count
        $Marker = if ($IsLast) { "└── " } else { "├── " }

        Write-Output "$Indent$Marker$($Item.Name)"

        if ($Item.PSIsContainer) {
            $NextIndent = if ($IsLast) { "$Indent    " } else { "$Indent│   " }
            Get-Tree -CurrentPath $Item.FullName -Indent $NextIndent -CurrentDepth ($CurrentDepth + 1)
        }
    }
}

$Root = Resolve-Path $Path
Write-Output "$($Root.Path)"
Get-Tree -CurrentPath $Root -Indent "" -CurrentDepth 1
