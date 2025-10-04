param([string[]]$Paths)

# 如果资源管理器没有用数组方式传参，用 $args 兜底
if (-not $Paths -or $Paths.Count -eq 0) { $Paths = $args }

$ErrorActionPreference = 'SilentlyContinue'

foreach ($p in $Paths) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }
  if (Test-Path -LiteralPath $p) {
    try { attrib -r -s -h -a $p -Recurse 2>$null } catch {}
    Remove-Item -LiteralPath $p -Recurse -Force -Confirm:$false
  }
}
