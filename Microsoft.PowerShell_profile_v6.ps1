# Ultra-Fast PowerShell Profile

$global:profileLoadStart = [System.Diagnostics.Stopwatch]::StartNew()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# PSReadLine 快速配置
try {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
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
        Error            = '#ff5555'
    } -PredictionSource HistoryAndPlugin
    Set-PSReadLineKeyHandler -Key "Ctrl+RightArrow" -Function ForwardWord
    Set-PSReadLineKeyHandler -Key "Ctrl+LeftArrow" -Function BackwardWord
    Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete
    Set-PSReadLineKeyHandler -Key "Ctrl+r" -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key "UpArrow" -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key "DownArrow" -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key "Ctrl+v" -Function Paste
    Set-PSReadLineKeyHandler -Key "Ctrl+u" -Function BackwardDeleteLine
    Set-PSReadLineKeyHandler -Key "Ctrl+w" -Function BackwardKillWord
} catch {}

# Oh-My-Posh 默认主题
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompThemesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
    $ompDefaultTheme = Join-Path $ompThemesDir 'jandedobbeleer.omp.json'
    if (Test-Path $ompDefaultTheme) {
        oh-my-posh init pwsh --config $ompDefaultTheme | Invoke-Expression
        Write-Host "已加载 oh-my-posh 主题: jandedobbeleer" -ForegroundColor Cyan
    }
}
# 主题切换函数，支持Tab补全
function Set-OhMyPoshTheme {
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete)
            $themesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
            if (Test-Path $themesDir) {
                Get-ChildItem $themesDir -Filter '*.omp.json' |
                    Where-Object { -not $wordToComplete -or $_.Name.ToLower().StartsWith($wordToComplete.ToLower()) } |
                    ForEach-Object { $_.Name }
            }
        })]
        [string]$Theme = 'jandedobbeleer.omp.json'
    )
    $themesDir = 'C:\Program Files (x86)\oh-my-posh\themes'
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Warning "oh-my-posh 未安装或未在 PATH 中。"
        return
    }
    if (-not $Theme) {
        Write-Host "可用主题：" -ForegroundColor Cyan
        Get-ChildItem $themesDir -Filter '*.omp.json' | ForEach-Object { Write-Host $_.Name }
        return
    }
    $themePath = Join-Path $themesDir $Theme
    if (Test-Path $themePath) {
        oh-my-posh init pwsh --config $themePath | Invoke-Expression
        Write-Host "已切换到 oh-my-posh 主题: $Theme" -ForegroundColor Green
    } else {
        Write-Warning "未找到主题: $Theme"
    }
}
Set-Alias omp-theme Set-OhMyPoshTheme

# 性能报告
$global:profileLoadTime = $global:profileLoadStart.ElapsedMilliseconds
function Show-ProfilePerformance { Write-Host "Profile loaded in $global:profileLoadTime ms" -ForegroundColor Yellow }
Set-Alias profile-perf Show-ProfilePerformance
profile-perf
