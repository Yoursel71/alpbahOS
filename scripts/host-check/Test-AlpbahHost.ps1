[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BuildRoot = 'F:\alpbahOS-build',

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$RequiredSpaceGB = 300,

    [Parameter()]
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

function Get-CommandVersion {
    param([Parameter(Mandatory)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return $null
    }

    try {
        $raw = & $command.Source '--version' 2>&1 | Select-Object -First 1
        return [string]$raw
    }
    catch {
        return 'installed (version unavailable)'
    }
}

$driveName = [System.IO.Path]::GetPathRoot($BuildRoot).TrimEnd('\').TrimEnd(':')
if (-not $driveName) {
    throw "BuildRoot bir sürücü harfi içermeli: $BuildRoot"
}

$volume = Get-Volume -DriveLetter $driveName -ErrorAction Stop
$partition = Get-Partition -DriveLetter $driveName -ErrorAction Stop
$disk = $partition | Get-Disk -ErrorAction Stop
$cpu = Get-CimInstance Win32_Processor
$system = Get-CimInstance Win32_ComputerSystem
$feature = Get-CimInstance Win32_OptionalFeature -Filter "Name='Microsoft-Hyper-V-All'" -ErrorAction SilentlyContinue
$services = Get-Service vmms, vmcompute, hns -ErrorAction SilentlyContinue
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$requiredBytes = [int64]$RequiredSpaceGB * 1GB
$hyperVCommands = @('Get-VM', 'New-VM', 'New-VHD')
$missingHyperVCommands = @($hyperVCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })

$checks = @(
    [pscustomobject]@{
        Name = 'Hyper-V feature'
        Passed = ($feature.InstallState -eq 1)
        Detail = if ($feature.InstallState -eq 1) { 'enabled' } else { "InstallState=$($feature.InstallState)" }
        Blocking = $true
    },
    [pscustomobject]@{
        Name = 'Hyper-V services'
        Passed = (@($services | Where-Object Status -ne 'Running').Count -eq 0)
        Detail = (($services | ForEach-Object { "$($_.Name)=$($_.Status)" }) -join ', ')
        Blocking = $true
    },
    [pscustomobject]@{
        Name = 'Hyper-V PowerShell commands'
        Passed = ($missingHyperVCommands.Count -eq 0)
        Detail = if ($missingHyperVCommands.Count) { "missing: $($missingHyperVCommands -join ', ')" } else { 'available' }
        Blocking = $true
    },
    [pscustomobject]@{
        Name = 'Administrative session'
        Passed = $isAdmin
        Detail = if ($isAdmin) { 'elevated' } else { 'not elevated; VM creation will require an elevated PowerShell' }
        Blocking = $false
    },
    [pscustomobject]@{
        Name = 'Build storage free space'
        Passed = ($volume.SizeRemaining -ge $requiredBytes)
        Detail = ('{0:N1} GB free; {1} GB required' -f ($volume.SizeRemaining / 1GB), $RequiredSpaceGB)
        Blocking = $true
    },
    [pscustomobject]@{
        Name = 'Host memory'
        Passed = ($system.TotalPhysicalMemory -ge 16GB)
        Detail = ('{0:N1} GiB installed' -f ($system.TotalPhysicalMemory / 1GB))
        Blocking = $true
    },
    [pscustomobject]@{
        Name = 'Host CPU capacity'
        Passed = (($cpu.NumberOfLogicalProcessors | Measure-Object -Sum).Sum -ge 8)
        Detail = ('{0} cores / {1} logical processors' -f (($cpu.NumberOfCores | Measure-Object -Sum).Sum), (($cpu.NumberOfLogicalProcessors | Measure-Object -Sum).Sum))
        Blocking = $true
    }
)

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    buildRoot = $BuildRoot
    host = [ordered]@{
        operatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
        processor = ($cpu.Name -join ', ')
        cores = (($cpu.NumberOfCores | Measure-Object -Sum).Sum)
        logicalProcessors = (($cpu.NumberOfLogicalProcessors | Measure-Object -Sum).Sum)
        memoryGiB = [math]::Round($system.TotalPhysicalMemory / 1GB, 1)
        elevated = $isAdmin
    }
    storage = [ordered]@{
        drive = "$driveName`:"
        fileSystem = $volume.FileSystem
        diskName = $disk.FriendlyName
        busType = [string]$disk.BusType
        mediaType = [string]$disk.MediaType
        totalGB = [math]::Round($volume.Size / 1GB, 1)
        freeGB = [math]::Round($volume.SizeRemaining / 1GB, 1)
        requestedBudgetGB = $RequiredSpaceGB
    }
    tools = [ordered]@{
        git = Get-CommandVersion git
        node = Get-CommandVersion node
        claude = if (Test-Path "$env:APPDATA\npm\claude.cmd") { (& "$env:APPDATA\npm\claude.cmd" --version 2>&1 | Select-Object -First 1) } else { $null }
    }
    checks = $checks
}

if (-not $ReportPath) {
    $ReportPath = Join-Path $BuildRoot 'reports\host-preflight.json'
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8

$checks | Select-Object Name, Passed, Blocking, Detail | Format-Table -AutoSize
Write-Host "Rapor: $ReportPath"

$blockingFailures = @($checks | Where-Object { $_.Blocking -and -not $_.Passed })
if ($blockingFailures.Count) {
    Write-Error "Host ön kontrolünde $($blockingFailures.Count) engelleyici sorun var."
    exit 2
}

if (-not $isAdmin) {
    Write-Warning 'Ön kontrol geçti; VM oluşturma betiğini yönetici PowerShell oturumunda çalıştır.'
}

exit 0
