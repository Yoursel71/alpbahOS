param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
$vmName = 'alpbahOS-M2-SSH-Gen2'
$artifact = 'F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen2-test.vhdx'
$vmRoot = "F:\alpbahOS-build\vms\$vmName"
$workingDisk = Join-Path $vmRoot "$vmName.vhdx"
$switchName = 'Default Switch'

if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "Test image is missing: $artifact"
}
$actual = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
if ($actual -ne $ExpectedSha256.ToUpperInvariant()) {
    throw "Test image SHA-256 mismatch: $actual"
}
if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
    throw "VM already exists; refusing to replace it: $vmName"
}
if (Test-Path -LiteralPath $workingDisk) {
    throw "Working disk already exists; refusing to overwrite it: $workingDisk"
}
$switch = Get-VMSwitch -Name $switchName -ErrorAction Stop

New-Item -ItemType Directory -Path $vmRoot -Force | Out-Null
Copy-Item -LiteralPath $artifact -Destination $workingDisk
$workingHash = (Get-FileHash -LiteralPath $workingDisk -Algorithm SHA256).Hash
if ($workingHash -ne $ExpectedSha256.ToUpperInvariant()) {
    throw "Working copy SHA-256 mismatch: $workingHash"
}

New-VM -Name $vmName -Generation 2 -MemoryStartupBytes 2GB -NoVHD `
    -Path $vmRoot -SwitchName $switch.Name | Out-Null
Set-VMProcessor -VMName $vmName -Count 2
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
Set-VM -Name $vmName -AutomaticCheckpointsEnabled $false
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
Add-VMHardDiskDrive -VMName $vmName -Path $workingDisk `
    -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0
$bootDisk = Get-VMHardDiskDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $bootDisk -EnableSecureBoot Off

Start-VM -Name $vmName | Out-Null
$deadline = (Get-Date).AddMinutes(3)
$ipv4 = @()
do {
    Start-Sleep -Seconds 5
    $ipv4 = @(Get-VMNetworkAdapter -VMName $vmName |
        ForEach-Object IPAddresses |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })
} while ($ipv4.Count -eq 0 -and (Get-Date) -lt $deadline)

Get-VM -Name $vmName | Select-Object Name, State, Generation, ProcessorCount, MemoryAssigned
Get-VMHardDiskDrive -VMName $vmName | Select-Object VMName, ControllerType, Path
if ($ipv4.Count -gt 0) {
    "IPv4: $($ipv4 -join ', ')"
} else {
    'IPv4: DHCP address not reported yet; VM remains running for console/network diagnosis.'
}
