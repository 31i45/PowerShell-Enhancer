# 自处理执行策略的 PowerShell 脚本

# 检查当前执行策略
$currentPolicy = Get-ExecutionPolicy

# 如果执行策略限制脚本运行，创建一个新的 PowerShell 进程并使用 Bypass 策略
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
    Write-Host "当前执行策略: $currentPolicy - 需要提升权限以运行脚本" -ForegroundColor Yellow
    
    # 获取当前脚本的完整路径
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # 创建一个新的 PowerShell 进程，使用 Bypass 策略执行当前脚本
    $params = @(
        "-ExecutionPolicy", "Bypass",
        "-NoProfile",
        "-File", $scriptPath
    )
    
    # 以当前用户身份启动新的 PowerShell 进程
    Start-Process -FilePath "PowerShell.exe" -ArgumentList $params -Wait -NoNewWindow
    
    # 退出当前受限的 PowerShell 进程
    exit
}

# 设置编码为 UTF-8，解决中文路径问题
$OutputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8

# 随机选择 oh-my-posh 主题
$randomTheme = (Get-ChildItem 'C:\Program Files (x86)\oh-my-posh\themes' -Filter '*.omp.json' -File | Get-Random).FullName

# 初始化 oh-my-posh
oh-my-posh init pwsh --config $randomTheme | Invoke-Expression

# 可选：显示当前使用的主题
Write-Host "当前使用的主题: $((Split-Path $randomTheme -Leaf) -replace '\.omp\.json$', '')" -ForegroundColor Cyan