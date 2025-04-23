############################################################
# PowerShell Profile Configuration
# 版本: 2.0.0 （部分功能需要 PowerShell 7+）
# 描述: 用于配置 PowerShell 环境，包括模块加载、主题设置等。
# 启发：https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal
# 创建日期: 2025-04-20
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
# $DebugPreference = "SilentlyContinue" # 调试模式，设置为 "Continue" 以启用调试输出
# $VerbosePreference = 'Continue' # 启用详细输出
#----------------------------------------------------------
# 1. 模块导入与依赖管理
#----------------------------------------------------------
function Import-SafeModule {
    param(
        [string]$ModuleName,
        [string]$InstallCommand = "Install-Module -Name $ModuleName -Scope CurrentUser",
        [string]$MinimumVersion = "0.0.0",
        [switch]$UseWinget = $false,
        [switch]$SkipImport = $false,
        [string]$ModuleDescription = ""
    )
    $moduleLoaded = $false

    # 检查模块是否已安装
    if ($UseWinget) {
        if (-not (Get-Command $ModuleName -ErrorAction SilentlyContinue)) {
            Write-Warning "$ModuleName 未检测到，尝试通过 winget 安装..."
            try {
                Invoke-Expression $InstallCommand
                Write-Host "$ModuleName 已成功安装。" -ForegroundColor Green
            } catch {
                Write-Warning "$ModuleName 安装失败，请手动安装或检查 winget 配置。"
                return
            }
        }
    } else {
        $module = Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.Version -ge [version]$MinimumVersion }
        if (-not $module) {
            Write-Warning "未找到符合要求的 $ModuleName 模块（版本 >= $MinimumVersion）。"
            Write-Warning "尝试安装模块..."
            try {
                Invoke-Expression $InstallCommand
                Write-Host "$ModuleName 已成功安装。" -ForegroundColor Green
            } catch {
                Write-Error "模块 $ModuleName 安装失败: $_"
                return
            }
        }
    }

    # 尝试加载模块
    if (-not $SkipImport) {
        try {
            Import-Module $ModuleName -ErrorAction Stop
            $moduleLoaded = $true
        } catch {
            Write-Error "模块 $ModuleName 加载失败: $_"
        }
    }

    # 输出统一的加载成功消息
    if ($moduleLoaded -or $SkipImport) {
        # Write-Host "$ModuleName 模块已成功加载。" -ForegroundColor Green
    }
}

function Select-And-ImportModules {
    # 动态获取已安装的模块列表
    $installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name -Unique
    $selectedModules = $installedModules | Out-GridView -Title "选择要加载的模块" -PassThru

    if ($selectedModules) {
        foreach ($module in $selectedModules) {
            Import-SafeModule -ModuleName $module
        }
    } else {
        Write-Host "未选择任何模块。" -ForegroundColor Yellow
    }
}

# Git 安装与验证
function Check-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning "git 命令未找到，尝试通过 winget 安装 Git..."
        try {
            winget install --id Git.Git -e --source winget
            Write-Host "Git 已成功安装。" -ForegroundColor Green
        } catch {
            Write-Warning "Git 安装失败，请手动安装。下载地址: https://git-scm.com/"
            return $false
        }
    }

    # 验证 Git 是否已正确添加到 PATH
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning "Git 未正确配置，请确保已将其添加到 PATH 环境变量中。"
        return $false
    }
    # Write-Host "Git 已正确配置。" -ForegroundColor Green
    return $true
}

# 确保 Git 可用
if (-not (Check-Git)) {
    Write-Warning "Git 未正确安装或配置，某些功能可能无法正常工作。"
}

# 加载常用模块
$ModulesToLoad = @(
    # 核心终端增强模块
    @{ Name = "PSReadLine"; InstallCommand = "Install-Module PSReadLine -Scope CurrentUser" },
    @{ Name = "oh-my-posh"; InstallCommand = "winget install JanDeDobbeleer.OhMyPosh -e --id JanDeDobbeleer.OhMyPosh -h"; UseWinget = $true; SkipImport = $true },
    @{ Name = "posh-git"; InstallCommand = "Install-Module posh-git -Scope CurrentUser" },
    @{ Name = "Terminal-Icons"; InstallCommand = "Install-Module Terminal-Icons  -Repository PSGallery -Scope CurrentUser" },
    @{ Name = "z"; InstallCommand = "Install-Module z -Scope CurrentUser" }, # 目录跳转模块

    # 系统管理与自动化模块
    @{ Name = "PowerShellGet"; InstallCommand = "Install-Module PowerShellGet -Scope CurrentUser" },
    @{ Name = "PSWindowsUpdate"; InstallCommand = "Install-Module PSWindowsUpdate -Scope CurrentUser" },
    @{ Name = "Carbon"; InstallCommand = "Install-Module Carbon -Scope CurrentUser" },

    # 测试与调试模块
    @{ Name = "Pester"; InstallCommand = "Install-Module Pester -Scope CurrentUser" },

    # 美化与通知模块
    @{ Name = "PSWriteColor"; InstallCommand = "Install-Module PSWriteColor -Scope CurrentUser" },
    @{ Name = "BurntToast"; InstallCommand = "Install-Module BurntToast -Scope CurrentUser" },

    # Web 仪表盘模块
    @{ Name = "Universal"; InstallCommand = "Install-Module Universal -Scope CurrentUser -AllowClobber" }
)

foreach ($module in $ModulesToLoad) {
    $useWinget = $module.UseWinget -eq $true
    $skipImport = $module.SkipImport -eq $true
    Import-SafeModule -ModuleName $module.Name -InstallCommand $module.InstallCommand -UseWinget:$useWinget -SkipImport:$skipImport
}

# 提供图形弹窗交互式模块选择功能
# Select-And-ImportModules # 可选：启用图形化模块选择功能

#----------------------------------------------------------
# 2. PSReadLine 配置（优化版）
#----------------------------------------------------------

# 默认颜色主题
$DefaultPSReadLineColors = @{
    InlinePrediction = '#808080'
    Command          = '#8181f7'
    Parameter        = '#FFA500'
    String           = '#24c22b'
    Operator         = '#ce6700'
    Variable         = '#d670d6'
    Number           = '#79c0ff'
    Type             = '#f78c6c'
    Comment          = '#6A9955'
}

# 默认快捷键绑定
$DefaultPSReadLineKeyBindings = @(
    @{ Key = "Ctrl+RightArrow"; Function = "ForwardWord" },
    @{ Key = "Ctrl+LeftArrow"; Function = "BackwardWord" },
    @{ Key = "Tab"; Function = "MenuComplete" },
    @{ Key = "Ctrl+r"; Function = "ReverseSearchHistory" },
    @{ Key = "UpArrow"; Function = "HistorySearchBackward" },
    @{ Key = "DownArrow"; Function = "HistorySearchForward" }
)

# 配置 PSReadLine 颜色主题
function Configure-PSReadLineColors {
    param (
        [hashtable]$Colors = $DefaultPSReadLineColors
    )
    # 检查 PSReadLine 模块是否已加载
    if (-not (Get-Module -Name PSReadLine)) {
        Write-Warning "PSReadLine 模块未加载，无法配置颜色主题。"
        return
    }

    try {
        Set-PSReadLineOption -Colors $Colors
        # Write-Host "PSReadLine 颜色主题已成功应用。" -ForegroundColor Green
    } catch {
        Write-Warning "设置 PSReadLine 颜色主题时发生错误：$($_.Exception.Message)"
    }
}

# 配置 PSReadLine 快捷键绑定
function Configure-PSReadLineKeyBindings {
    param (
        [array]$KeyBindings = $DefaultPSReadLineKeyBindings
    )
    foreach ($binding in $KeyBindings) {
        try {
            Set-PSReadLineKeyHandler -Key $binding.Key -Function $binding.Function
        } catch {
            Write-Warning "绑定快捷键 $($binding.Key) 时发生错误：$($_.Exception.Message)"
        }
    }
}

# 配置 PSReadLine 模块
function Configure-PSReadLine {
    if (Get-Module -Name PSReadLine) {
        $psReadLineVersion = (Get-Module -Name PSReadLine).Version
        # Write-Host "检测到 PSReadLine 版本：$psReadLineVersion" -ForegroundColor Cyan

        # 根据版本启用功能
        if ($psReadLineVersion -ge [Version]"2.2.0") {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
            # Write-Host "已启用 PSReadLine 的预测功能。" -ForegroundColor Green
        } else {
            Write-Warning "PSReadLine 版本较低，无法启用预测功能。请升级到 2.2.0 或更高版本。"
            Write-Host "升级命令：Install-Module -Name PSReadLine -Scope CurrentUser -Force" -ForegroundColor Yellow
        }

        # 设置历史记录选项
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd

        # 配置颜色主题
        Configure-PSReadLineColors

        # 配置快捷键绑定
        Configure-PSReadLineKeyBindings
    } else {
        Write-Warning "未检测到 PSReadLine 模块，请确保已安装。"
        Write-Host "安装命令：Install-Module -Name PSReadLine -Scope CurrentUser" -ForegroundColor Yellow
    }
}

# 调用配置函数
# $DebugPreference = "Continue"
Configure-PSReadLine

#----------------------------------------------------------
# 3. 字体检查与设置（针对 Windows Terminal 和字体目录）
#----------------------------------------------------------
function Set-NerdFont {
    # 定义支持的 Nerd Font 字体关键字（保持原始定义）
    $nerdFontKeywords = @("CaskaydiaCove Nerd Font Mono", "CaskaydiaCove Nerd Font")

    # 定义用户字体目录和系统字体目录
    $fontPaths = @("$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "C:\Windows\Fonts")
    $fontFound = $false
    $matchedFont = ""

    # 检查用户字体和系统字体目录
    foreach ($path in $fontPaths) {
        if (Test-Path $path) {
            $fonts = Get-ChildItem -Path $path -Filter "*.ttf" | Select-Object -ExpandProperty Name
            foreach ($keyword in $nerdFontKeywords) {
                # 动态处理关键字：移除空格并忽略大小写
                $regexKeyword = ($keyword -replace '\s', '').ToLower()
                foreach ($font in $fonts) {
                    # 模糊匹配：忽略空格和大小写，并允许文件名包含额外描述
                    if ($font.ToLower() -replace '\s', '' -like "*$regexKeyword*") {
                        #Write-Host "已找到 Nerd Font：$keyword `n路径：$path" -ForegroundColor Green
                        $fontFound = $true
                        $matchedFont = $keyword
                        break
                    }
                }
                if ($fontFound) { break }
            }
        }
        if ($fontFound) { break }
    }

    # 如果未找到字体，提示用户手动下载和安装
    if (-not $fontFound) {
        Write-Warning "未检测到 Nerd Font，请手动下载并安装："
        Write-Host "下载地址：https://github.com/ryanoasis/nerd-fonts/releases" -ForegroundColor Cyan
        return
    }

    # 修改 Windows Terminal 配置文件
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $wtSettingsPath)) {
        Write-Warning "未找到 Windows Terminal 配置文件，请确保已安装 Windows Terminal。"
        return
    }

    # 备份配置文件并修改
    try {
        Copy-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak" -Force
        $wtSettings = Get-Content -Path $wtSettingsPath -Raw | ConvertFrom-Json

        # 修改默认字体设置
        if ($wtSettings.profiles.defaults -and $wtSettings.profiles.defaults.font) {
            $wtSettings.profiles.defaults.font.face = $matchedFont
            #Write-Host "已将 Windows Terminal 的默认字体设置为：$matchedFont" -ForegroundColor Green
        } else {
            Write-Warning "未找到默认字体设置，无法修改字体。"
        }

        # 保存更新后的配置
        $wtSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath -Encoding UTF8
    } catch {
        Write-Warning "无法修改 Windows Terminal 配置文件：$($_.Exception.Message)"
    }
}

# 调用字体检查与设置函数
# $DebugPreference = "Continue"
Set-NerdFont

#----------------------------------------------------------
# 4. Oh-My-Posh 主题管理（优化版）
#----------------------------------------------------------

function Get-ThemePath {
    param(
        [string]$ThemeName
    )

    # 确保主题名称不重复添加扩展名
    if (-not $ThemeName.EndsWith(".omp.json")) {
        $ThemeName += ".omp.json"
    }

    # 定义主题路径列表（按优先级排序）
    $themePaths = @(
        $env:POSH_THEMES_PATH,
        "$env:USERPROFILE\.poshthemes",
        "C:\ProgramData\oh-my-posh\themes"
    )

    foreach ($path in $themePaths) {
        if ($path -and (Test-Path $path)) {
            $themePath = Join-Path $path $ThemeName
            Write-Debug "检查路径：$themePath"
            if (Test-Path $themePath) {
                Write-Debug "找到主题文件：$themePath"
                return $themePath
            }
        } else {
            Write-Debug "路径不存在或无效：$path"
        }
    }

    Write-Warning "未找到主题文件：$ThemeName"
    return $null
}

function Select-Theme {
    # 获取所有主题文件名
    $themes = Get-ChildItem -Path "$env:POSH_THEMES_PATH" -Filter "*.omp.json" | Select-Object -ExpandProperty Name

    if (-not $themes -or $themes.Count -eq 0) {
        Write-Warning "未找到任何主题文件，请检查 $env:POSH_THEMES_PATH 是否正确。"
        return $null
    }

    # 根据当前时间动态选择主题
    $hour = (Get-Date).Hour
    $selectedTheme = $themes[$hour % $themes.Count]
    Write-Debug "选择的主题：$selectedTheme"

    return $selectedTheme
}

function Invoke-ThemeEngine {
    param(
        [switch]$ForceUpdate
    )

    $selectedTheme = Select-Theme
    if (-not $selectedTheme) {
        Write-Warning "未能选择主题，无法继续。"
        return
    }

    $themePath = Get-ThemePath -ThemeName $selectedTheme

    if ($themePath) {
        Write-Debug "加载主题文件路径：$themePath"
        try {
            # 使用更安全的调用方式
            & oh-my-posh init pwsh --config $themePath | Invoke-Expression
            # Write-Host "Oh-My-Posh 已成功加载主题：$selectedTheme" -ForegroundColor Green
        } catch {
            Write-Warning "加载 Oh-My-Posh 主题时发生错误：$($_.Exception.Message)"
        }
    } else {
        Write-Warning "未找到主题文件：$selectedTheme"
    }
}

function Register-ThemeRotationJob {
    param(
        [int]$IntervalInMinutes = 60  # 默认每小时切换一次主题
    )

    # 检查是否已有注册的任务
    $existingJob = Get-ScheduledJob -Name "ThemeRotation" -ErrorAction SilentlyContinue
    if ($existingJob) {
        Write-Warning "主题轮询任务已注册。"
        return
    }

    # 创建触发器
    $trigger = New-JobTrigger -Once -RepetitionInterval ([TimeSpan]::FromMinutes($IntervalInMinutes)) -At (Get-Date)

    # 注册任务
    Register-ScheduledJob -Name "ThemeRotation" -ScriptBlock {
        try {
            Import-Module oh-my-posh -ErrorAction SilentlyContinue
            Invoke-ThemeEngine
        } catch {
            Write-Warning "主题轮询任务中发生错误：$($_.Exception.Message)"
        }
    } -Trigger $trigger -ScheduledJobOption (New-ScheduledJobOption -RunElevated)

    Write-Host "主题轮询任务已注册，每 $IntervalInMinutes 分钟切换一次主题。" -ForegroundColor Green
}

function Unregister-ThemeRotationJob {
    # 注销定时任务
    Unregister-ScheduledJob -Name "ThemeRotation" -ErrorAction SilentlyContinue
    Write-Host "主题轮询任务已注销。" -ForegroundColor Yellow
}

# 调用主题引擎
# $DebugPreference = "Continue"
Invoke-ThemeEngine # 与 Set-DefaultTheme 二选一

# 设置默认主题，支持动态设置主题名称
function Set-DefaultTheme {
    param(
        [string]$ThemeName = "jandedobbeleer"  # 默认主题为 jandedobbeleer
    )

    try {
        # 设置指定的主题
        $themePath = "$env:POSH_THEMES_PATH/$ThemeName.omp.json"
        if (-not (Test-Path $themePath)) {
            Write-Warning "主题文件未找到：$themePath"
            return
        }

        & oh-my-posh init pwsh --config $themePath | Invoke-Expression
        # Write-Host "Oh-My-Posh 已成功设置默认主题 $ThemeName。" -ForegroundColor Green
    } catch {
        Write-Warning "设置默认主题时发生错误：$($_.Exception.Message)"
    }
}

# 设置默认主题为 catppuccin_frappe
# $DebugPreference = "Continue"
# Set-DefaultTheme -ThemeName "catppuccin_frappe" # 如'atomic', 'tokyo', 'dracula', 'catppuccin'
# Set-DefaultTheme # 与 Invoke-ThemeEngine 二选一

#----------------------------------------------------------
# 5. 系统信息函数
#----------------------------------------------------------
function Get-SysInfo {
    try {
        # 获取系统信息
        $cpu = Get-CimInstance -ClassName Win32_Processor -Property Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed -ErrorAction Stop |
               Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors, @{Name="MaxClockSpeed(MHz)"; Expression={$_.MaxClockSpeed}}

        $gpus = Get-CimInstance -ClassName Win32_VideoController -Property Name,AdapterRAM,DriverVersion -ErrorAction SilentlyContinue |
                Select-Object -Property Name, @{Name="AdapterRAM(GB)"; Expression={[math]::Round($_.AdapterRAM / 1GB, 1)}}, DriverVersion

        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -Property Capacity |
                  Measure-Object -Property Capacity -Sum |
                  Select-Object @{Name="TotalMemory(GB)"; Expression={[math]::Round($_.Sum / 1GB, 1)}}

        $os = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption,FreePhysicalMemory,LastBootUpTime -ErrorAction Stop |
              Select-Object -Property Caption, @{Name="FreeMemory(GB)"; Expression={[math]::Round($_.FreePhysicalMemory / 1MB, 1)}}, @{Name="LastBootUpTime"; Expression={[datetime]::Parse($_.LastBootUpTime)}}

        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Property DeviceID,Size,FreeSpace -Filter "DriveType=3" -ErrorAction SilentlyContinue |
                 Select-Object -Property DeviceID, @{Name="TotalSize(GB)"; Expression={[math]::Round($_.Size / 1GB, 1)}}, @{Name="FreeSpace(GB)"; Expression={[math]::Round($_.FreeSpace / 1GB, 1)}}

        $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue |
                           Select-Object -Property Description, IPAddress, DefaultIPGateway

        $bios = Get-CimInstance -ClassName Win32_BIOS -Property Manufacturer, SMBIOSBIOSVersion -ErrorAction SilentlyContinue |
                Select-Object -Property Manufacturer, SMBIOSBIOSVersion

        $motherboard = Get-CimInstance -ClassName Win32_BaseBoard -Property Manufacturer, Product -ErrorAction SilentlyContinue |
                       Select-Object -Property Manufacturer, Product

        # 格式化 GPU 信息
        $gpuInfo = if ($gpus.Count -gt 0) {
            $gpus | ForEach-Object { "GPU: $($_.Name) [$($_.'AdapterRAM(GB)') GB] (Driver: $($_.DriverVersion))" }
        } else {
            "未检测到 GPU 信息"
        }

        # 格式化磁盘信息
        $diskInfo = if ($disks.Count -gt 0) {
            $disks | ForEach-Object { "磁盘 $($_.DeviceID): $($_.'TotalSize(GB)') GB 总量 | $($_.'FreeSpace(GB)') GB 可用" }
        } else {
            "未检测到磁盘信息"
        }

        # 格式化网络信息
        $networkInfo = if ($networkAdapters.Count -gt 0) {
            $networkAdapters | Where-Object {
                # 仅显示有 IP 地址的适配器
                $_.IPAddress -and $_.IPAddress.Count -gt 0
            } | Sort-Object { $_.DefaultIPGateway -ne $null } -Descending | ForEach-Object {
                $ipAddresses = ($_.IPAddress -join ', ')
                $gateway = if ($_.DefaultIPGateway -and $_.DefaultIPGateway.Count -gt 0) {
                    ($_.DefaultIPGateway -join ', ')
                } else {
                    "无网关"
                }
                "网络适配器: $($_.Description)`n    IP: $ipAddresses`n    网关: $gateway"
            }
        } else {
            "未检测到网络适配器信息"
        }

        # 格式化输出
        $Report = @"
╭────────────────── 系统信息 ──────────────────╮
  CPU: $($cpu.Name) [$($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)T @ $($cpu.'MaxClockSpeed(MHz)') MHz]
  $($gpuInfo -join "`n  ")
  内存: $($memory.'TotalMemory(GB)') GB 总量 | $($os.'FreeMemory(GB)') GB 可用
  $($diskInfo -join "`n  ")
  $($networkInfo -join "`n  ")
  主板: $($motherboard.Manufacturer) $($motherboard.Product)
  BIOS: $($bios.Manufacturer) (版本: $($bios.SMBIOSBIOSVersion))
  操作系统: $($os.Caption)
  系统启动时间: $($os.LastBootUpTime)
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
# $DebugPreference = "Continue"
# Get-SysInfo

#----------------------------------------------------------
# 6. 配置 Windows Terminal 滚动条可见性
#----------------------------------------------------------
function Configure-TerminalScrollbar {
    param (
        [string]$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    )

    # 检查配置文件是否存在
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "未找到 Windows Terminal 配置文件：$SettingsPath"
        return
    }

    try {
        # 备份配置文件
        $BackupPath = "$SettingsPath.bak" 
        Copy-Item -Path $SettingsPath -Destination $BackupPath -Force
        # Write-Host "已备份配置文件到：$BackupPath" -ForegroundColor Green

        # 读取配置文件
        $Settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json

        # 修改滚动条可见性
        if (-not $Settings.profiles.defaults) {
            $Settings.profiles.defaults = @{}
        }
        $Settings.profiles.defaults.scrollbarState = "visible"

        # 保存修改后的配置
        $Settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsPath -Encoding UTF8
        # Write-Host "Windows Terminal 滚动条可见性已设置为 'visible'。" -ForegroundColor Green
    } catch {
        Write-Warning "修改 Windows Terminal 配置时发生错误：$($_.Exception.Message)"
    }
}

# 调用函数以配置滚动条
Configure-TerminalScrollbar

#----------------------------------------------------------
# 7. 高级日志管理（优化版）
#----------------------------------------------------------

# 日志文件路径
$TranscriptPath = Join-Path $env:USERPROFILE 'powershell_transcript.log'

# 初始化日志文件
function Initialize-LogFile {
    param (
        [string]$FilePath
    )
    if (-not (Test-Path $FilePath)) {
        try {
            New-Item -Path $FilePath -ItemType File -Force | Out-Null
            Write-Host "日志文件不存在，已创建空日志文件：$FilePath" -ForegroundColor Green
        } catch {
            Write-Warning "创建日志文件时发生错误：$($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

# 日志文件大小检查与归档
function Check-LogFileSize {
    param (
        [string]$FilePath,
        [int]$MaxSizeMB = 10
    )
    try {
        if (Test-Path $FilePath) {
            $logFile = Get-Item $FilePath
            if ($logFile.Length -gt ($MaxSizeMB * 1MB)) {
                $archivePath = "$FilePath.$(Get-Date -Format 'yyyyMMddHHmmss').bak"
                Move-Item -Path $FilePath -Destination $archivePath
                Write-Host "日志文件已归档到：$archivePath" -ForegroundColor Green

                # 创建一个新的空日志文件
                Initialize-LogFile -FilePath $FilePath
            }
        }
    } catch {
        Write-Warning "检查日志文件大小时发生错误：$($_.Exception.Message)"
    }
}

# 启用全局命令和输出记录
function Enable-TranscriptLogging {
    if (-not (Test-Path $TranscriptPath)) {
        try {
            New-Item -Path $TranscriptPath -ItemType File -Force | Out-Null
        } catch {
            Write-Warning "创建 Transcript 日志文件时发生错误：$($_.Exception.Message)"
            return
        }
    }
    try {
        Start-Transcript -Path $TranscriptPath -Append > $null 2>&1
        # Write-Host "命令和输出记录已启用，日志文件路径：$TranscriptPath" -ForegroundColor Green
    } catch {
        Write-Warning "启用 Transcript 日志记录时发生错误：$($_.Exception.Message)"
    }
}

# 停止全局命令和输出记录
function Disable-TranscriptLogging {
    try {
        Stop-Transcript
        Write-Host "命令和输出记录已禁用。" -ForegroundColor Yellow
    } catch {
        Write-Warning "停止 Transcript 日志记录时发生错误：$($_.Exception.Message)"
    }
}

# 清理日志
function Clear-Logs {
    param (
        [switch]$Backup,
        [datetime]$BeforeDate
    )

    if (-not (Test-Path $TranscriptPath)) {
        Write-Host "日志文件不存在，无需清理。" -ForegroundColor Yellow
        return
    }

    if ($Backup) {
        $backupPath = "$TranscriptPath.$(Get-Date -Format 'yyyyMMddHHmmss').bak"
        try {
            Copy-Item -Path $TranscriptPath -Destination $backupPath -Force
            Write-Host "日志已备份到：$backupPath" -ForegroundColor Green
        } catch {
            Write-Warning "备份日志时发生错误：$($_.Exception.Message)"
        }
    }

    if ($BeforeDate) {
        # 按时间范围清理日志
        try {
            $logs = Get-Content $TranscriptPath | Where-Object {
                if ($_ -match '^\[(.*?)\]') {
                    $logTime = [datetime]::Parse($matches[1])
                    return $logTime -ge $BeforeDate
                }
                return $true
            }
            $logs | Set-Content $TranscriptPath -Encoding UTF8
            Write-Host "日志已清理，保留 $BeforeDate 之后的记录。" -ForegroundColor Green
        } catch {
            Write-Warning "清理日志时发生错误：$($_.Exception.Message)"
        }
    } else {
        # 清理整个日志文件
        try {
            Remove-Item $TranscriptPath -Force
            Write-Host "日志已清理。" -ForegroundColor Green
        } catch {
            Write-Warning "清理日志文件时发生错误：$($_.Exception.Message)"
        }
    }
}

# 初始化日志管理
function Initialize-LoggingSystem {
    if (Initialize-LogFile -FilePath $TranscriptPath) {
        Check-LogFileSize -FilePath $TranscriptPath -MaxSizeMB 10
    }
    Enable-TranscriptLogging
    # Write-Host "日志管理已初始化。" -ForegroundColor Green
}

# 调用日志管理初始化
# $DebugPreference = "Continue"
Initialize-LoggingSystem
# Clear-Logs -Backup -BeforeDate (Get-Date).AddDays(-7) # 可选：清理日志，保留 7 天前的记录
# Clear-Logs -Backup # 可选：清理日志，备份当前日志文件
# Clear-Logs # 可选：清理日志，不备份