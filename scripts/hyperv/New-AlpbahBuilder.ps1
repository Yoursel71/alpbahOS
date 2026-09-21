[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$UbuntuIso,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$UbuntuIsoSha256,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SwitchName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BuildRoot = 'F:\alpbahOS-build',

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$VMName = 'alpbah-builder',

    [Parameter()]
    [ValidateRange(2, 16)]
    [int]$ProcessorCount = 6,

    [Parameter()]
    [ValidateRange(6, 18)]
    [int]$MemoryGB = 12,

    [Parameter()]
    [ValidateRange(80, 230)]
    [int]$DiskSizeGB = 210
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Bu betik Hyper-V değişiklikleri için yönetici PowerShell oturumu gerektirir.'
}

foreach ($commandName in 'Get-VM', 'New-VM', 'New-VHD', 'Set-VMFirmware') {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Hyper-V PowerShell komutu bulunamadı: $commandName"
    }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($BuildRoot)
$resolvedIso = (Resolve-Path -LiteralPath $UbuntuIso).Path
$isoHash = (Get-FileHash -LiteralPath $resolvedIso -Algorithm SHA256).Hash
if ($isoHash -ne $UbuntuIsoSha256.ToUpperInvariant()) {
    throw "Ubuntu ISO SHA256 uyuşmuyor. Beklenen: $UbuntuIsoSha256 Bulunan: $isoHash"
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "Hyper-V sanal anahtarı bulunamadı: $SwitchName"
}

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    throw "Aynı adla bir VM zaten var: $VMName"
}

$vmDirectory = Join-Path $resolvedRoot "vms\$VMName"
$vhdDirectory = Join-Path $resolvedRoot 'vhdx'
$vhdPath = Join-Path $vhdDirectory "$VMName.vhdx"
if (Test-Path -LiteralPath $vhdPath) {
    throw "Hedef VHDX zaten var: $vhdPath"
}

$description = "Gen2 builder VM '$VMName' ($ProcessorCount vCPU, $MemoryGB GB RAM, $DiskSizeGB GB VHDX)"
if (-not $PSCmdlet.ShouldProcess($vmDirectory, "Create $description")) {
    return
}

New-Item -ItemType Directory -Path $vmDirectory, $vhdDirectory -Force | Out-Null
New-VHD -Path $vhdPath -Dynamic -SizeBytes ([int64]$DiskSizeGB * 1GB) | Out-Null

try {
    $vm = New-VM -Name $VMName -Generation 2 -Path $vmDirectory -VHDPath $vhdPath -SwitchName $SwitchName
    Set-VM -VM $vm -ProcessorCount $ProcessorCount -MemoryStartupBytes ([int64]$MemoryGB * 1GB) -DynamicMemory:$false -AutomaticCheckpointsEnabled:$false
    Set-VMProcessor -VM $vm -ExposeVirtualizationExtensions:$false
    Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority
    Add-VMDvdDrive -VM $vm -Path $resolvedIso | Out-Null
    $dvd = Get-VMDvdDrive -VM $vm
    Set-VMFirmware -VM $vm -FirstBootDevice $dvd
}
catch {
    Write-Error "VM oluşturma tamamlanamadı. Oluşmuş olabilecek hedefleri incele: $vmDirectory ve $vhdPath. $($_.Exception.Message)"
    throw
}

[pscustomobject]@{
    VMName = $VMName
    Generation = 2
    ProcessorCount = $ProcessorCount
    MemoryGB = $MemoryGB
    VHDPath = $vhdPath
    VHDMaxGB = $DiskSizeGB
    IsoPath = $resolvedIso
    IsoSha256 = $isoHash
    SwitchName = $SwitchName
    SecureBootTemplate = 'MicrosoftUEFICertificateAuthority'
} | Format-List

Write-Host 'Builder VM oluşturuldu. Otomatik başlatılmadı; Ubuntu kurulumunu Hyper-V Manager üzerinden başlatabilirsin.'
