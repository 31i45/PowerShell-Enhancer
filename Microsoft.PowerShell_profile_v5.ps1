[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
# [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
# === 性能测试计时器开始 ===
$global:profileLoadStart = [System.Diagnostics.Stopwatch]::StartNew()
$global:sectionTimers = @{}
$global:sectionData = @{}

function Mark-ProfileSection {
    param([string]$SectionName, [string]$Action = "Start", [string]$Category = "General")
    $key = "$Category.$SectionName"
    if ($Action -eq "Start") {
        $global:sectionTimers[$key] = [System.Diagnostics.Stopwatch]::StartNew()
        $global:sectionData[$key] = @{
            "StartTime" = Get-Date
            "Category" = $Category
            "Name" = $SectionName
        }
    } elseif ($Action -eq "End" -and $global:sectionTimers.ContainsKey($key)) {
        $global:sectionTimers[$key].Stop()
        $global:sectionData[$key]["Duration"] = $global:sectionTimers[$key].ElapsedMilliseconds
        $global:sectionData[$key]["EndTime"] = Get-Date
    }
}

# --- Only load essential modules, no install or checks ---
$CoreModules = @("PSReadLine")
foreach ($mod in $CoreModules) {
    try { Import-Module $mod -ErrorAction SilentlyContinue } catch {}
}

# --- PSReadLine config (fast, no checks) ---
try {
    Set-PSReadLineOption -Colors @{
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
    Set-PSReadLineKeyHandler -Key "Ctrl+RightArrow" -Function ForwardWord
    Set-PSReadLineKeyHandler -Key "Ctrl+LeftArrow" -Function BackwardWord
    Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete
    Set-PSReadLineKeyHandler -Key "Ctrl+r" -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key "UpArrow" -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key "DownArrow" -Function HistorySearchForward
} catch {}

# --- Defer all heavy work to on-demand functions ---
function Setup-NerdFont { Write-Host "NerdFont setup deferred. Run this function when needed." }
function Initialize-OhMyPoshTheme { Write-Host "OhMyPosh theme setup deferred. Run this function when needed." }
function Get-SysInfo { Write-Host "System info deferred. Run this function when needed." }
function Initialize-LoggingSystem { Write-Host "Logging system deferred. Run this function when needed." }
function Configure-TerminalScrollbar { Write-Host "Terminal scrollbar config deferred. Run this function when needed." }

# --- Performance report ---
$global:profileLoadStart.Stop()
$global:profileLoadTime = $global:profileLoadStart.ElapsedMilliseconds
Write-Host "Profile loaded in $global:profileLoadTime ms" -ForegroundColor Yellow
function Show-ProfilePerformance { Write-Host "Profile loaded in $global:profileLoadTime ms" -ForegroundColor Yellow }
Set-Alias -Name "profile-perf" -Value Show-ProfilePerformance -Description "显示配置文件加载性能报告" -Scope Global

# --- Oh-My-Posh Theme Management (Optimized) ---

# 1. Hardcode the default theme for fast startup
$ompThemesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
$ompDefaultTheme = Join-Path $ompThemesDir 'dracula.omp.json'  # Change to your favorite theme

if (Test-Path $ompDefaultTheme) {
    oh-my-posh init pwsh --config $ompDefaultTheme | Invoke-Expression
    # Write-Host "已加载默认 oh-my-posh 主题: dracula" -ForegroundColor Cyan
} else {
    Write-Warning "未找到默认 oh-my-posh 主题: $ompDefaultTheme"
}

# 2. Function to search and switch themes with tab completion
function Set-OhMyPoshTheme {
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $themesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
            if (Test-Path $themesDir) {
                Get-ChildItem $themesDir -Filter '*.omp.json' | 
                    Where-Object { $_.Name -like "$wordToComplete*" } |
                    ForEach-Object { $_.Name }
            }
        })]
        [string]$Theme
    )

    $themesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
    if (-not (Test-Path $themesDir)) {
        Write-Warning "oh-my-posh 主题目录不存在: $themesDir"
        return
    }

    if (-not $Theme) {
        # List all themes if no argument
        Write-Host "可用主题：" -ForegroundColor Cyan
        Get-ChildItem $themesDir -Filter '*.omp.json' | ForEach-Object { Write-Host $_.Name }
        return
    }

    $themePath = Join-Path $themesDir $Theme
    if (-not (Test-Path $themePath)) {
        Write-Warning "未找到主题: $Theme"
        return
    }

    oh-my-posh init pwsh --config $themePath | Invoke-Expression
    Write-Host "已切换到 oh-my-posh 主题: $Theme" -ForegroundColor Green
}

Set-Alias -Name "omp-theme" -Value Set-OhMyPoshTheme -Description "切换 oh-my-posh 主题，支持Tab补全" -Scope Global
