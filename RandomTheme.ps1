$OutputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::UTF8
$randomTheme = (Get-ChildItem 'C:\Program Files (x86)\oh-my-posh\themes' -Filter '*.omp.json' -File | Get-Random).FullName
oh-my-posh init pwsh --config $randomTheme | Invoke-Expression
