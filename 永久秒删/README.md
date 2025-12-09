# 永久秒删

一个绕过回收站的快速删除工具，提供右键菜单和命令行两种使用方式。

## 功能
- 右键菜单一键永久删除文件/文件夹
- 命令行调用脚本快速删除
- 删除前自动移除只读/系统/隐藏属性

## 文件说明
- `PermanentDelete.ps1`：核心删除脚本
- `Add-PermanentDelete-ContextMenu.reg`：添加右键菜单
- `Remove-PermanentDelete-ContextMenu.reg`：移除右键菜单
- `使用说明.md`：详细图文教程

## 安装
1. 将 `PermanentDelete.ps1` 复制到 `C:\Scripts\`
   ```powershell
   mkdir C:\Scripts -Force
   copy PermanentDelete.ps1 C:\Scripts\
   ```
2. 双击运行 `Add-PermanentDelete-ContextMenu.reg`，确认导入注册表。

## 使用
- **右键菜单**：在文件或文件夹上右键 → 选择“永久删除”。
- **命令行**：
  ```powershell
  powershell.exe -File "C:\Scripts\PermanentDelete.ps1" "文件或文件夹路径"
  ```

## 卸载
双击运行 `Remove-PermanentDelete-ContextMenu.reg` 移除右键菜单。

## 注意
- ⚠️ 删除不可恢复，操作前请确认文件不再需要。
- 如需更多细节，请查看同目录下的 `使用说明.md`。
