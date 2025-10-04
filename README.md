# 实用工具合集 (Utils Collection)

这是一个实用工具的集合，每个文件夹包含一个独立的工具。

## 🛠️ 工具列表

### 永久秒删
一个Windows工具，用于永久删除文件，绕过回收站。

- **功能**: 右键菜单永久删除文件/文件夹
- **安装**: 运行 `Add-PermanentDelete-ContextMenu.reg`
- **卸载**: 运行 `Remove-PermanentDelete-ContextMenu.reg`
- **使用说明**: 查看 `使用说明.md`

## 📁 项目结构

```
utils/
├── 永久秒删/          # Windows永久删除工具
│   ├── PermanentDelete.ps1
│   ├── Add-PermanentDelete-ContextMenu.reg
│   ├── Remove-PermanentDelete-ContextMenu.reg
│   └── 使用说明.md
└── README.md          # 项目说明文件
```

## ⚠️ 注意事项

- 使用永久删除工具前请谨慎，删除后无法恢复
- 建议先备份重要数据
- 部分工具可能需要管理员权限

## 🤝 贡献

欢迎提交更多实用工具的Pull Request！