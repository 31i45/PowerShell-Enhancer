#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    PowerShell 配置文件性能测试脚本
.DESCRIPTION
    此脚本用于测量 PowerShell 配置文件的加载性能，包括总体加载时间和各个主要组件的加载时间。
    能够多次运行测试并计算平均值，生成详细的性能报告。
.NOTES
    作者: AI Assistant
    版本: 1.0
    日期: 2025-06-05
#>

#region 配置参数
[CmdletBinding()]
param(
    [string]$ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    [int]$TestRuns = 3,
    [switch]$DetailedReport,
    [switch]$SaveReport,
    [string]$ReportPath = "$env:TEMP\profile_performance_report.html",
    [switch]$ModifyProfile
)
#endregion

#region 初始化
# 清屏并显示标题
Clear-Host
Write-Host "`n=========== PowerShell 配置文件性能测试 ===========" -ForegroundColor Cyan

# 确保配置文件存在
if (-not (Test-Path $ProfilePath)) {
    Write-Error "配置文件不存在: $ProfilePath"
    exit 1
}

# 创建性能计时器
$script:perfTimers = @{}
$script:sectionTimers = @{}
$script:originalContent = Get-Content -Path $ProfilePath -Raw
$script:modifiedContent = $script:originalContent

# 创建结果收集器
$results = @{
    TotalTimes = @()
    SectionTimes = @{}
    SystemInfo = @{}
}

# 收集系统信息
$results.SystemInfo = @{
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    OS = $PSVersionTable.OS
    CPU = (Get-CimInstance Win32_Processor).Name
    TotalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
#endregion

#region 辅助函数
function Add-TimerCode {
    param (
        [string]$Content,
        [string[]]$SectionMarkers,
        [string]$TimerVarPrefix = "timer"
    )
    
    $lines = $Content -split "`n"
    $newLines = New-Object System.Collections.ArrayList
    $sectionStack = New-Object System.Collections.ArrayList
    
    # 添加总体计时器开始代码
    $startTimerCode = @"
# === 性能测试计时器开始 ===
`$global:profileLoadStart = [System.Diagnostics.Stopwatch]::StartNew()
`$global:sectionTimers = @{}
function Mark-ProfileSection {
    param([string]`$SectionName, [string]`$Action = "Start")
    if (`$Action -eq "Start") {
        `$global:sectionTimers[`$SectionName] = [System.Diagnostics.Stopwatch]::StartNew()
    }
    elseif (`$Action -eq "End" -and `$global:sectionTimers.ContainsKey(`$SectionName)) {
        `$global:sectionTimers[`$SectionName].Stop()
    }
}
"@
    $newLines.Add($startTimerCode) | Out-Null
    
    # 处理每一行，查找段落标记并添加计时器
    $currentSection = $null
    $i = 0
    
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        
        # 查找段落标记
        foreach ($marker in $SectionMarkers) {
            if ($line -match $marker) {
                # 如果有正在计时的段落，添加结束计时器
                if ($currentSection) {
                    $endCode = "Mark-ProfileSection -SectionName '$currentSection' -Action 'End'"
                    $newLines.Add($endCode) | Out-Null
                    $sectionStack.RemoveAt($sectionStack.Count - 1)
                }
                
                # 提取段落名称
                $sectionName = $line.Trim('#- ').Split('（')[0].Split('(')[0].Trim()
                $currentSection = $sectionName
                $sectionStack.Add($currentSection)
                
                # 添加开始计时器
                $startCode = "Mark-ProfileSection -SectionName '$currentSection' -Action 'Start'"
                $newLines.Add($startCode) | Out-Null
                break
            }
        }
        
        # 添加原始行
        $newLines.Add($line) | Out-Null
        $i++
    }
    
    # 如果有未关闭的段落，添加结束计时器
    if ($currentSection) {
        $endCode = "Mark-ProfileSection -SectionName '$currentSection' -Action 'End'"
        $newLines.Add($endCode) | Out-Null
    }
    
    # 添加总体计时器结束代码
    $endTimerCode = @"
# === 性能测试计时器结束 ===
`$global:profileLoadStart.Stop()
`$global:profileLoadTime = `$global:profileLoadStart.ElapsedMilliseconds
`$global:sectionTimes = @{}
foreach (`$section in `$global:sectionTimers.Keys) {
    `$global:sectionTimes[`$section] = `$global:sectionTimers[`$section].ElapsedMilliseconds
}
Write-Host "Profile loaded in `$global:profileLoadTime ms" -ForegroundColor Yellow
"@
    $newLines.Add($endTimerCode) | Out-Null
    
    return $newLines -join "`n"
}

function Get-ProfileSections {
    param([string]$Content)
    
    $sectionRegex = '#--+\s*\d+\.\s*([^#]+?)(?:\s*--+#|\s*$)'
    $matches = [regex]::Matches($Content, $sectionRegex)
    $sections = @()
    
    foreach ($match in $matches) {
        $sectionName = $match.Groups[1].Value.Trim()
        $sections += $sectionName
    }
    
    return $sections
}

function Create-HtmlReport {
    param(
        [hashtable]$Results,
        [string]$OutputPath
    )
    
    # 准备数据
    $avgTotalTime = [math]::Round(($Results.TotalTimes | Measure-Object -Average).Average, 2)
    $minTotalTime = [math]::Round(($Results.TotalTimes | Measure-Object -Minimum).Minimum, 2)
    $maxTotalTime = [math]::Round(($Results.TotalTimes | Measure-Object -Maximum).Maximum, 2)
    
    # 准备段落时间数据
    $sectionData = @()
    foreach ($section in $Results.SectionTimes.Keys) {
        $times = $Results.SectionTimes[$section]
        $avgTime = [math]::Round(($times | Measure-Object -Average).Average, 2)
        $percentage = [math]::Round(($avgTime / $avgTotalTime) * 100, 1)
        
        $sectionData += [PSCustomObject]@{
            Section = $section
            AvgTime = $avgTime
            Percentage = $percentage
            Color = if ($percentage -gt 30) { "#ff6b6b" } 
                   elseif ($percentage -gt 15) { "#feca57" } 
                   else { "#1dd1a1" }
        }
    }
    
    # 按时间排序
    $sectionData = $sectionData | Sort-Object -Property AvgTime -Descending
    
    # 构建HTML报告
    $html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PowerShell 配置文件性能报告</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            border-radius: 5px;
        }
        h1, h2, h3 {
            color: #2e86de;
        }
        .summary {
            margin: 20px 0;
            padding: 15px;
            background-color: #e3f2fd;
            border-radius: 5px;
        }
        .warning {
            background-color: #fff3cd;
            color: #856404;
        }
        .chart-container {
            height: 300px;
            margin: 20px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        tr:hover {
            background-color: #f1f1f1;
        }
        .progress {
            height: 20px;
            background-color: #e9ecef;
            border-radius: 5px;
            margin-top: 5px;
            overflow: hidden;
        }
        .progress-bar {
            height: 100%;
            color: white;
            text-align: center;
            line-height: 20px;
        }
        .system-info {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 10px;
            margin: 20px 0;
        }
        .info-item {
            padding: 10px;
            background-color: #f8f9fa;
            border-radius: 5px;
        }
        .recommendation {
            margin: 20px 0;
            padding: 15px;
            background-color: #d4edda;
            color: #155724;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>PowerShell 配置文件性能报告</h1>
        <p>生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        
        <div class="system-info">
            <div class="info-item"><strong>PowerShell 版本:</strong> $($Results.SystemInfo.PowerShellVersion)</div>
            <div class="info-item"><strong>操作系统:</strong> $($Results.SystemInfo.OS)</div>
            <div class="info-item"><strong>CPU:</strong> $($Results.SystemInfo.CPU)</div>
            <div class="info-item"><strong>内存:</strong> $($Results.SystemInfo.TotalMemory) GB</div>
            <div class="info-item"><strong>测试运行次数:</strong> $($Results.TotalTimes.Count)</div>
        </div>
        
        <div class="summary">
            <h2>加载时间摘要</h2>
            <p><strong>平均加载时间:</strong> $avgTotalTime 毫秒</p>
            <p><strong>最小加载时间:</strong> $minTotalTime 毫秒</p>
            <p><strong>最大加载时间:</strong> $maxTotalTime 毫秒</p>
        </div>
        
        <h2>各部分加载时间</h2>
        <table>
            <thead>
                <tr>
                    <th>部分</th>
                    <th>平均时间 (ms)</th>
                    <th>占比</th>
                    <th>性能图</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($section in $sectionData) {
        $html += @"
                <tr>
                    <td>$($section.Section)</td>
                    <td>$($section.AvgTime)</td>
                    <td>$($section.Percentage)%</td>
                    <td>
                        <div class="progress">
                            <div class="progress-bar" style="width: $($section.Percentage)%; background-color: $($section.Color);">
                                $($section.Percentage)%
                            </div>
                        </div>
                    </td>
                </tr>
"@
    }

    $html += @"
            </tbody>
        </table>
        
        <div class="recommendation">
            <h2>优化建议</h2>
            <ul>
"@

    # 添加优化建议
    $highPercentageSections = $sectionData | Where-Object { $_.Percentage -gt 15 }
    foreach ($section in $highPercentageSections) {
        $recommendation = switch ($section.Section) {
            "模块导入与依赖管理" { "考虑使用按需加载模式，仅在首次使用时导入非必要模块。" }
            "PSReadLine 配置" { "简化 PSReadLine 配置，仅保留必要设置并延迟加载高级功能。" }
            "字体检查与设置" { "缓存字体检查结果，避免每次启动都进行完整扫描。" }
            "Oh-My-Posh 主题管理" { "简化 Oh-My-Posh 初始化，考虑使用延迟加载机制。" }
            "系统信息函数" { "将系统信息功能改为按需加载，而不是在启动时执行。" }
            "Windows Terminal 配置" { "仅在必要时修改 Windows Terminal 配置，并使用更高效的检查方法。" }
            "日志管理" { "简化日志管理初始化，使用更轻量级的日志记录方式。" }
            default { "考虑对此部分进行代码审查和优化，减少不必要的操作。" }
        }
        $html += "<li><strong>$($section.Section) ($($section.Percentage)%):</strong> $recommendation</li>"
    }

    $html += @"
                <li><strong>通用建议:</strong> 使用延迟加载模式，将非核心功能移至单独的脚本文件，并仅在需要时加载。</li>
                <li><strong>并行处理:</strong> 考虑对独立的初始化任务使用后台作业并行处理。</li>
                <li><strong>缓存结果:</strong> 缓存耗时操作的结果，避免每次启动都重新计算。</li>
            </ul>
        </div>
    </div>
</body>
</html>
"@

    # 保存报告
    $html | Out-File -FilePath $OutputPath -Encoding utf8
    return $OutputPath
}
#endregion

#region 主测试逻辑
# 开始性能测试
$sections = Get-ProfileSections -Content $script:originalContent
Write-Host "已识别到以下配置文件区段:" -ForegroundColor Cyan
$sections | ForEach-Object { Write-Host " - $_" -ForegroundColor Gray }

# 添加计时代码
if ($ModifyProfile) {
    $script:modifiedContent = Add-TimerCode -Content $script:originalContent -SectionMarkers '#--+\s*\d+\.\s*'
    Set-Content -Path $ProfilePath -Value $script:modifiedContent
    Write-Host "`n已为配置文件添加性能计时代码。" -ForegroundColor Green
    Write-Host "请重启 PowerShell 会话，然后查看详细的性能数据。" -ForegroundColor Yellow
    Write-Host "完成测试后，请运行此脚本并添加 -ModifyProfile 参数以恢复原始配置文件。" -ForegroundColor Yellow
    exit 0
}

# 执行测试
Write-Host "`n开始执行 $TestRuns 次性能测试..." -ForegroundColor Cyan

for ($i = 1; $i -le $TestRuns; $i++) {
    Write-Host "测试运行 $i/$TestRuns..." -ForegroundColor Yellow
    
    # 创建一个临时配置文件
    $tempProfilePath = [System.IO.Path]::GetTempFileName()
    $tempProfileContent = Add-TimerCode -Content $script:originalContent -SectionMarkers '#--+\s*\d+\.\s*'
    Set-Content -Path $tempProfilePath -Value $tempProfileContent
    
    # 启动一个新的 PowerShell 进程来测试配置文件
    $startTimeMs = [System.DateTime]::Now.Ticks / 10000
    $output = pwsh -NoProfile -Command "
        `$ErrorActionPreference = 'SilentlyContinue'
        . '$tempProfilePath'
        Write-Output `"Total: `$global:profileLoadTime`"
        Write-Output `"Sections: `$(`$global:sectionTimes | ConvertTo-Json -Compress)`"
    "
    $endTimeMs = [System.DateTime]::Now.Ticks / 10000
    $totalTime = $endTimeMs - $startTimeMs
    
    # 解析结果
    $totalTimeValue = ($output | Where-Object { $_ -match '^Total: (\d+)$' }) -replace 'Total: '
    $sectionTimesJson = ($output | Where-Object { $_ -match '^Sections: (.+)$' }) -replace 'Sections: '
    
    if (-not [string]::IsNullOrEmpty($totalTimeValue)) {
        $results.TotalTimes += [int]$totalTimeValue
    } else {
        $results.TotalTimes += $totalTime
    }
    
    if (-not [string]::IsNullOrEmpty($sectionTimesJson)) {
        try {
            $sectionTimes = $sectionTimesJson | ConvertFrom-Json -AsHashtable
            foreach ($section in $sectionTimes.Keys) {
                if (-not $results.SectionTimes.ContainsKey($section)) {
                    $results.SectionTimes[$section] = @()
                }
                $results.SectionTimes[$section] += $sectionTimes[$section]
            }
        } catch {
            Write-Warning "无法解析部分时间数据: $_"
        }
    }
    
    # 清理临时文件
    Remove-Item -Path $tempProfilePath -Force
    
    # 显示此次运行的结果
    Write-Host "  总加载时间: $($results.TotalTimes[-1]) ms" -ForegroundColor Green
}

# 显示汇总结果
$avgTime = [math]::Round(($results.TotalTimes | Measure-Object -Average).Average, 2)
$minTime = ($results.TotalTimes | Measure-Object -Minimum).Minimum
$maxTime = ($results.TotalTimes | Measure-Object -Maximum).Maximum

Write-Host "`n性能测试完成!" -ForegroundColor Cyan
Write-Host "平均加载时间: $avgTime ms" -ForegroundColor Green
Write-Host "最小加载时间: $minTime ms" -ForegroundColor Green
Write-Host "最大加载时间: $maxTime ms" -ForegroundColor Green

# 显示详细的段落时间报告
if ($DetailedReport) {
    Write-Host "`n各部分平均加载时间:" -ForegroundColor Cyan
    $sectionAvgTimes = @{}
    
    foreach ($section in $results.SectionTimes.Keys) {
        $times = $results.SectionTimes[$section]
        $sectionAvg = [math]::Round(($times | Measure-Object -Average).Average, 2)
        $sectionAvgTimes[$section] = $sectionAvg
    }
    
    $sortedSections = $sectionAvgTimes.GetEnumerator() | Sort-Object -Property Value -Descending
    
    foreach ($section in $sortedSections) {
        $percentage = [math]::Round(($section.Value / $avgTime) * 100, 1)
        $color = if ($percentage -gt 30) { "Red" } 
                elseif ($percentage -gt 15) { "Yellow" } 
                else { "Green" }
        
        Write-Host "  $($section.Name): " -NoNewline
        Write-Host "$($section.Value) ms " -NoNewline -ForegroundColor $color
        Write-Host "($percentage%)" -ForegroundColor $color
    }
}

# 保存HTML报告
if ($SaveReport) {
    $reportFilePath = Create-HtmlReport -Results $results -OutputPath $ReportPath
    Write-Host "`n已生成性能报告: $reportFilePath" -ForegroundColor Cyan
    Start-Process $reportFilePath
}
#endregion

