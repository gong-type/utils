# Windows 关机助手

一个现代化设计的 Windows 关机程序，提供友好的触摸屏界面和流畅的动画效果。

## ✨ 特性

- **现代化UI**：Material Design 风格，700×600 大窗口设计
- **触摸屏优化**：大按钮（70px高度）适合触控操作
- **丝滑动画**：窗口淡入、按钮缩放、阴影扩散等流畅动画
- **单文件部署**：打包为单个 exe 文件（约 66MB）
- **无需管理员权限**：使用 shutdown 命令，普通用户即可运行

## 🎨 界面设计

- **窗口尺寸**：700×600px 居中弹窗
- **标题栏**：红色背景（#F44336），可拖动
- **电源图标**：120×120px 大尺寸图标
- **按钮布局**：
  - 左侧：立即关机（红色醒目）
  - 右侧：取消（白色安全）
- **动画效果**：
  - 窗口淡入（0.4秒，缩放 0.9→1.0）
  - 按钮悬停放大（1.0→1.02）
  - 按钮点击缩小（1.0→0.97）

## 🚀 使用方法

### 构建项目

```bash
dotnet publish -c Release -o bin\Release\publish
```

### 运行程序

直接运行 `WindowsShutdown.exe` 即可，无需管理员权限。

## 📋 系统要求

- **操作系统**：Windows 10/11
- **.NET 运行时**：.NET 6.0（自包含版本已内置）
- **权限**：普通用户权限

## 🔧 技术栈

- .NET 6.0 WPF
- XAML + C#
- Material Design 配色
- 单文件发布（SelfContained）

## 📝 配置说明

### 修改窗口大小

编辑 `MainWindow.xaml` 中的窗口属性：

```xml
<Window Height="600" Width="700">
```

### 修改颜色主题

```xml
<!-- 红色主题 -->
<Border Background="#F44336"/>

<!-- 白色按钮 -->
<Style x:Key="ModernButton" TargetType="Button">
    <Setter Property="Background" Value="White"/>
</Style>
```

### 调整动画速度

```xml
<!-- 淡入动画持续时间 -->
<DoubleAnimation Duration="0:0:0.4"/>

<!-- 按钮悬停动画 -->
<DoubleAnimation Duration="0:0:0.15"/>
```

## 📄 许可证

MIT License
