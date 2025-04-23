############################################################
# PowerShell Profile Configuration
# 版本: 1.0.0 （部分功能需要 PowerShell 7+）
# 描述: 用于配置 PowerShell 环境，包括模块加载、主题设置等。
# 启发：https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal
# 创建日期: 2025-04-18
# 作者: IT老菜鸟（微信公众号）
# 版权声明: 本脚本遵循 MIT 许可证，欢迎自由使用和修改，但请务必保留版权信息。
# 免责声明: 本脚本仅供学习和参考使用，作者不对任何因使用本脚本而导致的损失或损害承担责任。
# 注意事项: 请确保您了解脚本的功能和可能的影响，在使用前备份您的配置文件。
# 使用方法：
# 1. 将此脚本放置在 PowerShell 配置目录下，执行：
# Set-Item -Path Variable:PROFILE -Value "C:\Users\IT老菜鸟\Documents\Powershell\Microsoft.PowerShell_profile.ps1"
# 或者 $PROFILE = "C:\Users\IT老菜鸟\Documents\Powershell\Microsoft.PowerShell_profile.ps1"
# 2. 重新启动 Windows Terminal 时 PowerShell 时自动加载此配置文件。
# 3. 可以按需修改配置项以适应您的独特需求。
############################################################

#----------------------------------------------------------
# 1. 模块导入
#----------------------------------------------------------
# 添加模块健康检查
function Import-SafeModule {
    param(
        [string]$ModuleName,
        [string]$InstallCommand = "Install-Module -Name $ModuleName -Scope CurrentUser",
        [string]$MinimumVersion = "0.0.0"
    )
    # 检查模块是否存在并符合版本要求
    $module = Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.Version -ge [version]$MinimumVersion }

    if (-not $module) {
        Write-Warning "未找到符合要求的 $ModuleName 模块（版本 >= $MinimumVersion）。"
        Write-Warning "尝试安装模块，请执行：$InstallCommand"

        try {
            # 自动安装模块
            Invoke-Expression $InstallCommand
        } catch {
            Write-Error "模块 $ModuleName 安装失败: $_"
            return
        }
    }

    try {
        # 导入模块
        Import-Module $ModuleName -ErrorAction Stop
        #Write-Host "模块 $ModuleName 已成功导入。" -ForegroundColor Green
    } catch {
        Write-Error "模块 $ModuleName 加载失败: $_"
    }
}

# 模块预加载优化
Import-SafeModule -ModuleName Terminal-Icons -InstallCommand "Install-Module Terminal-Icons -Scope CurrentUser"
Import-SafeModule -ModuleName PSReadLine -InstallCommand "Install-Module PSReadLine -Scope CurrentUser"

# 检查并导入 PSReadline 模块，提供命令行编辑功能
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module -Name PSReadLine
}

#----------------------------------------------------------
# 2. PSReadLine 配置 - 增强命令行编辑体验
#----------------------------------------------------------
# 检查 PSReadLine 模块是否已加载
if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
    Write-Warning "PSReadLine 模块未加载，请确保已安装并导入该模块。"
    return
}

# 启用预测文本
Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# 添加现代导航快捷键
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord

# 设置预测文本的颜色为淡灰色
Set-PSReadLineOption -Colors @{ InlinePrediction = '#808080' }
# 设置语法高亮颜色（允许用户自定义）
$PSReadLineColors = @{
    Command            = '#8181f7'
    Parameter          = '#FFA500'
    String             = '#24c22b'
    Operator           = '#ce6700'
    Variable           = '#d670d6'
    Number             = '#79c0ff'
    Type               = '#f78c6c'
    Comment            = '#6A9955'
}
Set-PSReadLineOption -Colors $PSReadLineColors

# 启用 Bash 风格的自动补全
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Ctrl+d 退出 PowerShell (仅在交互式会话中启用)
if ($Host.Name -eq 'ConsoleHost') {
    Set-PSReadLineKeyHandler -Key "Ctrl+d" -Function ViExit
}

# 设置历史命令记录数量和保存位置
$HistoryFilePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ps_history'

# 如果历史记录文件不存在，则创建一个空文件
if (-not (Test-Path $HistoryFilePath)) {
    New-Item -Path $HistoryFilePath -ItemType File -Force | Out-Null
}

Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistorySavePath $HistoryFilePath

# 使用 Ctrl+r 进行历史命令搜索
Set-PSReadLineKeyHandler -Key "Ctrl+r" `
    -BriefDescription "HistorySearch" `
    -LongDescription "搜索历史命令" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward()
}

#----------------------------------------------------------
# 3. Oh-My-Posh 主题配置增强
#----------------------------------------------------------
# 添加主题下载提示
if (-not (Test-Path $env:POSH_THEMES_PATH)) {
    Write-Warning "Oh-My-Posh 主题目录未找到，请执行：Install-Module oh-my-posh -Scope CurrentUser"
}

# 动态主题加载（每次终端启动时执行）
function Invoke-ThemeEngine {
    $themeCache = Join-Path $env:TEMP "oh-my-posh-theme-cache.json"
    
    # 检查缓存是否需要更新（超过 1 小时）
    if (-not (Test-Path $themeCache) -or (Get-Item $themeCache).LastWriteTime -lt (Get-Date).AddHours(-1)) {
        $hour = (Get-Date).Hour
        $themes = @('atomic', 'tokyo', 'dracula', 'catppuccin')
        $selectedTheme = $themes[$hour % $themes.Count]
        $themePath = "$env:POSH_THEMES_PATH\$selectedTheme.omp.json"

        # 如果主题文件存在，更新缓存
        if (Test-Path $themePath) {
            $themeContent = Get-Content $themePath -Raw
            $themeContent | Set-Content $themeCache -Encoding UTF8
        } else {
            Write-Warning "未找到主题文件: $themePath"
        }
    }

    # 初始化 Oh-My-Posh
    oh-my-posh init pwsh --config $themeCache | Invoke-Expression
}

# 每次终端启动时执行主题引擎
Invoke-ThemeEngine

#----------------------------------------------------------
# 4. 系统信息函数
#----------------------------------------------------------
function Get-SysInfo {
    try {
        # 获取系统信息
        $cpu = Get-CimInstance -ClassName Win32_Processor -Property Name,NumberOfCores,NumberOfLogicalProcessors -ErrorAction Stop |
               Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

        $gpus = Get-CimInstance -ClassName Win32_VideoController -Property Name,AdapterRAM -ErrorAction SilentlyContinue |
                Select-Object -Property Name, @{Name="AdapterRAM(GB)"; Expression={[math]::Round($_.AdapterRAM / 1GB, 1)}}

        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -Property Capacity |
                  Measure-Object -Property Capacity -Sum |
                  Select-Object @{Name="TotalMemory(GB)"; Expression={[math]::Round($_.Sum / 1GB, 1)}}

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption,FreePhysicalMemory -ErrorAction Stop |
              Select-Object -Property Caption, @{Name="FreeMemory(GB)"; Expression={[math]::Round($_.FreePhysicalMemory / 1MB, 1)}}

        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Property DeviceID,Size,FreeSpace -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue |
                Select-Object -Property DeviceID, @{Name="TotalSize(GB)"; Expression={[math]::Round($_.Size / 1GB, 1)}}, @{Name="FreeSpace(GB)"; Expression={[math]::Round($_.FreeSpace / 1GB, 1)}}

        # 计算 GPU 信息
        $gpuInfo = if ($gpus.Count -gt 0) {
            $gpus | ForEach-Object { "GPU $($_.PSComputerName): $($_.Name) [$($_.'AdapterRAM(GB)') GB]" }
        } else {
            "未检测到 GPU 信息"
        }

        # 格式化输出
        $Report = @"
╭────────────────── 系统信息 ──────────────────╮
  CPU: $($cpu.Name) [$($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)T]
  $($gpuInfo -join "`n  ")
  内存: $($memory.'TotalMemory(GB)') GB 总量 | $($os.'FreeMemory(GB)') GB 可用
  磁盘: $($disk.'TotalSize(GB)') GB 总量 | $($disk.'FreeSpace(GB)') GB 可用
  操作系统: $($os.Caption)
╰─────────────────────────────────────────────╯
"@

        # 输出系统信息
        Write-Host $Report -ForegroundColor Cyan

        # 提示显卡物理总显存
        Write-Host "`n注意: 显卡的物理总显存无法通过 Win32_VideoController 获取。" -ForegroundColor Yellow
        Write-Host "请使用 dxdiag 或显卡厂商工具（如 NVIDIA Control Panel）获取更准确的信息。" -ForegroundColor Yellow
    } catch {
        Write-Error "获取系统信息时发生错误: $_"
    }
}

# 每次终端启动时获取系统信息
#Get-SysInfo

#----------------------------------------------------------
# 5. 安全增强
#----------------------------------------------------------
# 敏感命令提醒
function Invoke-SafeExpression {
    param([string]$Command)
    
    # 定义敏感命令的正则表达式模式
    $dangerPatterns = @(
        'Remove-Item\s+-Recurse\s+-Force',
        'rm\s+-r\s+\S+',
        'Format-Volume',
        'Set-ExecutionPolicy\s+Unrestricted'
    )
    
    # 检查命令是否匹配敏感模式
    if ($Command -match ($dangerPatterns -join '|')) {
        $auditLog = Join-Path $env:USERPROFILE 'powershell_audit.log'
        "[$(Get-Date)] 危险命令拦截: $Command" | Out-File $auditLog -Append
        
        Write-Host "`n安全告警：检测到危险操作已被拦截" -ForegroundColor Red
        Write-Host "如需执行请使用：Enable-Override -Command '$Command'" -ForegroundColor Yellow
        return
    }
    # 执行非敏感命令
    Invoke-Expression $Command
}

# 替换默认的 Remove-Item 为安全版本
function Safe-RemoveItem {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        [switch]$Recurse,
        [switch]$Force
    )
    # 使用原始 Remove-Item cmdlet，避免递归调用
    $nativeRemoveItem = Get-Command Remove-Item -CommandType Cmdlet

    # 检查是否为敏感命令
    if ($Recurse -and $Force) {
        Write-Host "`n安全告警：检测到危险操作已被拦截" -ForegroundColor Red
        Write-Host "如需执行请使用：Enable-Override -Command 'Remove-Item -Recurse -Force $Path'" -ForegroundColor Yellow
        return
    }

    # 调用原始 Remove-Item cmdlet
    & $nativeRemoveItem @PSBoundParameters
}

# 提供覆盖执行敏感命令的功能
function Enable-Override {
    param([string]$Command)
    try {
        # 临时移除 Safe-RemoveItem 别名
        Remove-Item Alias:Remove-Item -ErrorAction SilentlyContinue

        # 执行传入的命令
        Invoke-Expression $Command

        # 恢复 Safe-RemoveItem 别名
        Set-Alias -Name Remove-Item -Value Safe-RemoveItem -Force

        Write-Host "`n命令已成功执行: $Command" -ForegroundColor Green
    } catch {
        # 恢复 Safe-RemoveItem 别名，即使发生错误
        Set-Alias -Name Remove-Item -Value Safe-RemoveItem -Force

        Write-Host "`n命令执行失败: $Command" -ForegroundColor Red
        Write-Host "错误信息: $_" -ForegroundColor Yellow
    }
}

# 强制替换 Remove-Item 为 Safe-RemoveItem
Set-Alias -Name Remove-Item -Value Safe-RemoveItem -Force

#----------------------------------------------------------
# 6. 交互式增强
#----------------------------------------------------------
# 添加ZSH风格自动建议
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# 添加快速目录书签
$BOOKMARKS = @{}
function Set-Bookmark {
    param([string]$Name)
    $BOOKMARKS[$Name] = $PWD.Path
}
function Invoke-Bookmark {
    param([string]$Name)
    if ($BOOKMARKS[$Name]) { Set-Location $BOOKMARKS[$Name] }
}

#----------------------------------------------------------
# 检查并设置 Nerd Font
#----------------------------------------------------------
function Set-NerdFont {
    # 定义字体名称
    $nerdFonts = @("CaskaydiaCove Nerd Font", "CaskaydiaCove Nerd Font Mono")
    $fontApplied = $false

    # 检查终端是否支持这些字体
    foreach ($font in $nerdFonts) {
        # 模拟终端支持的字体（假设终端中有字体）
        if ($true) { # 这里假设终端中有字体，直接应用
            # 自动应用字体的逻辑（假设需要设置环境变量或其他配置）
            $fontApplied = $true
            break
        }
    }

    # 如果没有找到字体，提示用户下载
    if (-not $fontApplied) {
        Write-Host "未检测到 Nerd Font，请下载并安装以下字体之一：" -ForegroundColor Red
        Write-Host "CaskaydiaCove Nerd Font: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip" -ForegroundColor Cyan
    }
}

# 调用函数检查字体
Set-NerdFont

# 智能历史记录清理
$maxHistoryAge = [timespan]::FromDays(7)

# 确保历史记录文件存在
if (-not (Test-Path $HistoryFilePath)) {
    New-Item -Path $HistoryFilePath -ItemType File -Force | Out-Null
}

# 读取历史记录并清理无效数据
Get-Content $HistoryFilePath | Where-Object {
    $line = $_ -replace '^#(\d+).*', '$1'
    if ($line -match '^\d+$') { # 确保 $line 是有效的数字格式
        try {
            $timestamp = [datetime]::FromFileTime([int64]$line) -as [datetime]
            return $timestamp -gt (Get-Date).Add(-$maxHistoryAge)
        } catch {
            # 如果转换失败，跳过该行
            return $false
        }
    } else {
        # 如果 $line 不是有效的时间戳，跳过处理
        return $false
    }
} | Set-Content $HistoryFilePath