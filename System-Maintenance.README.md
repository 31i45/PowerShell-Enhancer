# Windows 系统维护指南 / Windows System Maintenance Guide

## 概述 / Overview

此维护系统旨在帮助保持Windows 11系统的最佳性能。它包含自动化脚本用于清理临时文件、浏览器缓存、监控磁盘空间和优化系统性能。

This maintenance system is designed to keep your Windows 11 system running at optimal performance. It includes automated scripts for cleaning temporary files, browser caches, monitoring disk space, and optimizing system performance.

## 主要功能 / Key Features

- 自动清理浏览器缓存 / Automated browser cache cleanup
- 临时文件清理 / Temporary file cleanup
- 磁盘空间监控 / Disk space monitoring
- 系统优化建议 / System optimization recommendations
- 详细的维护日志 / Detailed maintenance logs

## 快速参考 / Quick Reference

### 运行维护任务 / Running Maintenance Tasks

运行以下命令执行维护任务：/ Run the following commands to perform maintenance tasks:

```powershell
# 全面系统维护 / Full system maintenance
.\System-Maintenance.ps1 -Tasks All

# 仅清理浏览器缓存 / Clean browser caches only
.\System-Maintenance.ps1 -Tasks BrowserCache

# 仅清理临时文件 / Clean temporary files only
.\System-Maintenance.ps1 -Tasks TempFiles

# 仅检查磁盘空间 / Check disk space only
.\System-Maintenance.ps1 -Tasks DiskCheck

# 安静模式（适用于计划任务）/ Quiet mode (suitable for scheduled tasks)
.\System-Maintenance.ps1 -Tasks All -LogOnly
```

### 定期维护计划 / Maintenance Schedule

为了保持系统最佳性能，建议以下维护计划：/ To maintain optimal system performance, the following maintenance schedule is recommended:

| 任务 / Task | 频率 / Frequency | 命令 / Command |
|-------------|-----------------|----------------|
| 浏览器缓存清理 / Browser cache cleanup | 每周 / Weekly | `.\System-Maintenance.ps1 -Tasks BrowserCache` |
| 临时文件清理 / Temporary files cleanup | 每两周 / Bi-weekly | `.\System-Maintenance.ps1 -Tasks TempFiles` |
| 全面系统维护 / Full system maintenance | 每月 / Monthly | `.\System-Maintenance.ps1 -Tasks All` |

### 设置计划任务 / Setting up Scheduled Tasks

1. 打开任务计划程序 / Open Task Scheduler:
   - 按下 Win + R
   - 输入 "taskschd.msc" 并按回车

2. 创建月度维护任务 / Create Monthly Maintenance Task:
   - 点击右侧面板中的"创建基本任务" / Click "Create Basic Task" in the right panel
   - 名称 / Name: "Monthly System Maintenance"
   - 触发器 / Trigger: 每月，在每月1日凌晨3:00运行 / Monthly, run at 3:00 AM on the 1st of each month
   - 操作 / Action: 启动程序 / Start a program
   - 程序 / Program: powershell.exe
   - 参数 / Arguments: `-NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\System-Maintenance.ps1" -Tasks All -LogOnly`

3. 创建每周浏览器缓存清理 / Create Weekly Browser Cache Cleanup:
   - 点击"创建基本任务" / Click "Create Basic Task"
   - 名称 / Name: "Weekly Browser Cache Cleanup"
   - 触发器 / Trigger: 每周，在每周日凌晨3:00运行 / Weekly, run at 3:00 AM every Sunday
   - 操作 / Action: 启动程序 / Start a program
   - 程序 / Program: powershell.exe
   - 参数 / Arguments: `-NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\System-Maintenance.ps1" -Tasks BrowserCache -LogOnly`

## 最佳实践 / Best Practices

### 系统维护 / System Maintenance

- 保持C盘至少15%的可用空间 / Keep at least 15% free space on your C: drive
- 大型文件和程序安装到D盘 / Install large files and programs to the D: drive
- 定期检查启动项，禁用不必要的程序 / Regularly check startup items and disable unnecessary programs
- 安装或卸载大型程序后运行维护脚本 / Run the maintenance script after installing/uninstalling large programs

### 日常使用 / Daily Usage

- 定期清空浏览器缓存和下载文件夹 / Regularly clear browser caches and download folders
- 使用D盘存储大型文件，保持C盘空间充足 / Use the D: drive for storing large files to keep the C: drive spacious
- 定期重启计算机以应用系统更新和清理内存 / Regularly restart your computer to apply system updates and clear memory

### 监控与警告 / Monitoring and Warnings

注意以下警告信号：/ Watch for the following warning signs:
- C盘可用空间低于15% / C: drive space below 15% free
- 任务管理器中异常高的CPU使用率 / Unusual high CPU usage in Task Manager
- 启动时间变慢 / Slow startup times
- 启动列表中出现意外程序 / Unexpected programs in startup list

## 故障排除 / Troubleshooting

### 常见问题 / Common Issues

**问题：脚本无法运行 / Problem: Script won't run**
- 解决方案：以管理员身份运行PowerShell并执行：`Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser`
- Solution: Run PowerShell as administrator and execute: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser`

**问题：磁盘空间仍然不足 / Problem: Disk space still low**
- 解决方案：使用磁盘清理工具(cleanmgr)，检查大型文件和应用程序，考虑卸载不必要的程序
- Solution: Use Disk Cleanup tool (cleanmgr), check for large files and applications, consider uninstalling unnecessary programs

**问题：系统性能仍然缓慢 / Problem: System performance still slow**
- 解决方案：检查启动项，运行病毒扫描，考虑更新驱动程序
- Solution: Check startup items, run virus scan, consider updating drivers

### 日志文件 / Log Files

维护日志存储在 `Maintenance-Logs` 文件夹中，可用于诊断问题。
Maintenance logs are stored in the `Maintenance-Logs` folder and can be used for diagnosing issues.

## 完成的优化 / Completed Optimizations

以下优化已经实施：/ The following optimizations have been implemented:

- 清理了不必要的Python组件 / Cleaned up unnecessary Python components
- 移除冗余的LM Studio CUDA文件 / Removed redundant LM Studio CUDA files
- 将下载文件夹移动到D盘 / Moved Downloads folder to D: drive
- 禁用不必要的启动程序 / Disabled unnecessary startup programs
- 设置Storage Sense进行自动清理 / Set up Storage Sense for automatic cleanup
- 创建全面的维护脚本 / Created comprehensive maintenance script

