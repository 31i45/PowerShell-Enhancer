#Requires -Version 5.0
<#
.SYNOPSIS
    Basic System Maintenance Script
.DESCRIPTION
    This script performs essential system maintenance tasks including:
    - Browser cache cleanup
    - Temporary files cleanup (including Windows temp files)
    - Disk space monitoring
    - Recycle bin emptying
    
    The script can be run manually or scheduled through Task Scheduler.
.PARAMETER Tasks
    Comma-separated list of tasks to run: BrowserCache, TempFiles, DiskCheck, All
.PARAMETER LogOnly
    If specified, only logs issues without displaying interactive output (good for scheduled tasks)
.EXAMPLE
    .\System-Maintenance-Basic.ps1 -Tasks All
    Runs all maintenance tasks with interactive output
.EXAMPLE
    .\System-Maintenance-Basic.ps1 -Tasks BrowserCache,TempFiles -LogOnly
    Runs browser cache and temp file cleanup with logging only (good for scheduled tasks)
.NOTES
    Created by: AI Assistant
    Date: May 24, 2025
    Version: 1.0
#>

param (
    [Parameter()]
    [ValidateSet("BrowserCache", "TempFiles", "DiskCheck", "All")]
    [string[]]$Tasks = "All",
    
    [Parameter()]
    [switch]$LogOnly
)

# Script configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogPath = Join-Path -Path $ScriptPath -ChildPath "Maintenance-Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "Maintenance-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$MinimumFreeSpacePercent = 15

# Ensure log directory exists
if (-not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Log function
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info",
        
        [Parameter()]
        [switch]$NoOutput
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Add to log file
    Add-Content -Path $LogFile -Value $logMessage
    
    # Display to console if not in LogOnly mode
    if (-not $LogOnly -and -not $NoOutput) {
        switch ($Level) {
            "Info" { Write-Host $logMessage -ForegroundColor White }
            "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
            "Error" { Write-Host $logMessage -ForegroundColor Red }
            "Success" { Write-Host $logMessage -ForegroundColor Green }
        }
    }
}

# Start the log
Write-Log -Message "======== System Maintenance Started ========" -Level Info

# Function to clean browser caches
function Clear-BrowserCaches {
    Write-Log -Message "Starting browser cache cleanup..." -Level Info
    
    $totalCleared = 0
    $browserPaths = @{
        "Edge" = @{
            "Path" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
            "Cleared" = 0
        }
        "Chrome" = @{
            "Path" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" 
            "Cleared" = 0
        }
        "Firefox" = @{
            "Path" = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\cache2"
            "Cleared" = 0
        }
        "Brave" = @{
            "Path" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
            "Cleared" = 0
        }
    }
    
    foreach ($browser in $browserPaths.Keys) {
        $path = $browserPaths[$browser].Path
        
        # Skip if browser cache doesn't exist
        if (-not (Test-Path -Path $path -ErrorAction SilentlyContinue)) {
            Write-Log -Message "${browser} cache not found at $path" -Level Info
            continue
        }
        
        try {
            # Calculate size before cleanup
            $sizeBefore = (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
            
            # Clear the browser cache
            Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                
            # Also clear Code Cache if it exists
            $codeCachePath = $path -replace "Cache$", "Code Cache"
            if (Test-Path -Path $codeCachePath) {
                Get-ChildItem -Path $codeCachePath -Recurse -Force -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Calculate cleared space
            $clearedMB = [math]::Round($sizeBefore/1MB, 2)
            $browserPaths[$browser].Cleared = $clearedMB
            $totalCleared += $clearedMB
            
            Write-Log -Message "Cleared ${browser} cache: $clearedMB MB" -Level Success
        }
        catch {
            Write-Log -Message "Error clearing ${browser} cache: $($_.Exception.Message)" -Level Error
        }
    }
    
    Write-Log -Message "Browser cache cleanup complete. Total cleared: $([math]::Round($totalCleared, 2)) MB" -Level Success
    return $totalCleared
}

# Function to clean temporary files
function Clear-TempFiles {
    Write-Log -Message "Starting temporary files cleanup..." -Level Info
    
    $tempPaths = @(
        @{Name = "Windows Temp"; Path = "$env:SystemRoot\Temp"},
        @{Name = "User Temp"; Path = "$env:TEMP"},
        @{Name = "Prefetch"; Path = "$env:SystemRoot\Prefetch"},
        @{Name = "Windows Update Cache"; Path = "$env:SystemRoot\SoftwareDistribution\Download"}
    )
    
    $totalCleared = 0
    
    foreach ($tempLocation in $tempPaths) {
        try {
            # Calculate size before cleanup
            $sizeBefore = (Get-ChildItem -Path $tempLocation.Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
            
            # Clear the temp files
            Get-ChildItem -Path $tempLocation.Path -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { -not $_.PSIsContainer } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            
            # Calculate cleared space
            $clearedMB = [math]::Round($sizeBefore/1MB, 2)
            $totalCleared += $clearedMB
            
            Write-Log -Message "Cleared $($tempLocation.Name): $clearedMB MB" -Level Success
        }
        catch {
            Write-Log -Message "Error clearing $($tempLocation.Name): $($_.Exception.Message)" -Level Error
        }
    }
    
    # Empty Recycle Bin
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Log -Message "Emptied Recycle Bin" -Level Success
    }
    catch {
        Write-Log -Message "Error emptying Recycle Bin: $($_.Exception.Message)" -Level Error
    }
    
    Write-Log -Message "Temporary files cleanup complete. Total cleared: $([math]::Round($totalCleared, 2)) MB" -Level Success
    return $totalCleared
}

# Function to check disk space
function Check-DiskSpace {
    Write-Log -Message "Starting disk space check..." -Level Info
    
    $issues = @()
    $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    
    foreach ($disk in $disks) {
        $freeSpacePercent = ($disk.FreeSpace / $disk.Size) * 100
        $freeSpaceGB = [math]::Round($disk.FreeSpace/1GB, 2)
        $totalSpaceGB = [math]::Round($disk.Size/1GB, 2)
        
        $message = "Drive $($disk.DeviceID): $freeSpaceGB GB free of $totalSpaceGB GB ($([math]::Round($freeSpacePercent, 2))%)"
        
        if ($freeSpacePercent -lt $MinimumFreeSpacePercent) {
            Write-Log -Message $message -Level Warning
            $issues += "Low disk space on drive $($disk.DeviceID): $([math]::Round($freeSpacePercent, 2))% free"
        }
        else {
            Write-Log -Message $message -Level Success
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Log -Message "Disk space issues found: $($issues.Count)" -Level Warning
        foreach ($issue in $issues) {
            Write-Log -Message "- $issue" -Level Warning
        }
    }
    else {
        Write-Log -Message "All drives have adequate free space" -Level Success
    }
    
    return $issues
}

# Function to generate a summary report
function Get-MaintenanceSummary {
    param (
        [Parameter()]
        [double]$BrowserCacheCleared = 0,
        
        [Parameter()]
        [double]$TempFilesCleared = 0,
        
        [Parameter()]
        [array]$DiskIssues = @()
    )
    
    $totalClearedMB = $BrowserCacheCleared + $TempFilesCleared
    $totalClearedGB = [math]::Round($totalClearedMB/1024, 2)
    
    Write-Log -Message "======== Maintenance Summary ========" -Level Info
    Write-Log -Message "Total space cleared: $totalClearedMB MB ($totalClearedGB GB)" -Level Info
    
    if ($DiskIssues.Count -gt 0) {
        Write-Log -Message "Disk space issues found: $($DiskIssues.Count)" -Level Warning
        foreach ($issue in $DiskIssues) {
            Write-Log -Message "- $issue" -Level Warning
        }
    }
    else {
        Write-Log -Message "No disk space issues found" -Level Success
    }
    
    Write-Log -Message "Maintenance log saved to: $LogFile" -Level Info
    Write-Log -Message "======== System Maintenance Completed ========" -Level Info
}

# Execute requested tasks
$browserCacheCleared = 0
$tempFilesCleared = 0
$diskIssues = @()

if ($Tasks -contains "All" -or $Tasks -contains "BrowserCache") {
    $browserCacheCleared = Clear-BrowserCaches
}

if ($Tasks -contains "All" -or $Tasks -contains "TempFiles") {
    $tempFilesCleared = Clear-TempFiles
}

if ($Tasks -contains "All" -or $Tasks -contains "DiskCheck") {
    $diskIssues = Check-DiskSpace
}

# Generate summary
Get-MaintenanceSummary -BrowserCacheCleared $browserCacheCleared -TempFilesCleared $tempFilesCleared -DiskIssues $diskIssues

# If run in interactive mode, pause at the end
if (-not $LogOnly) {
    Write-Host "`nMaintenance complete. Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

