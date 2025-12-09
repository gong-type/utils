# 目录结构导出工具（右键菜单版）

导出指定目录的树形结构，支持设置深度、忽略文件夹、导出到文件或剪贴板。

## 亮点
- 右键菜单弹出 GUI，配置深度和忽略列表
- 默认忽略常见目录：`node_modules, .git, bin, obj, .vs, dist, build, __pycache__`
- 支持导出到目标目录 / 桌面 / 剪贴板，且可自动打开结果

## 文件
- `ExportTree-ContextMenu.ps1`：右键菜单 GUI 版脚本
- `Add-ExportTree-ContextMenu.reg`：添加右键菜单
- `Remove-ExportTree-ContextMenu.reg`：移除右键菜单
- `Export-DirectoryTree.ps1`：命令行交互版（可选）
- `使用说明.md`：详细指南与示例

## 安装（右键菜单版）
1. 复制脚本到 `C:\Scripts\`
   ```powershell
   mkdir C:\Scripts -Force
   copy ExportTree-ContextMenu.ps1 C:\Scripts\
   ```
2. 双击运行 `Add-ExportTree-ContextMenu.reg`，确认导入注册表。

## 使用
- 在文件夹或其空白处右键 → 选择“输出结构树” → 在弹窗中配置后导出。

## 卸载
双击运行 `Remove-ExportTree-ContextMenu.reg`。

## 注意
- 脚本需保存为 **UTF-16 LE** 以兼容 PowerShell 5.1。
- 首次运行如被执行策略限制，可在管理员 PowerShell 执行：
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
