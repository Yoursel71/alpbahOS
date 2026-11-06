# Updates HostName of alp-builder / alp-m2-gen2 in ~/.ssh/config from VM MACs.
# Run on the Windows host (any agent): powershell -NoProfile -File scripts\refresh-ssh-hosts.ps1
$ErrorActionPreference = 'Stop'
$cfgPath = Join-Path $env:USERPROFILE '.ssh\config'
$map = @{ 'alp-builder' = 'alpbah-builder'; 'alp-m2-gen2' = 'alpbahOS-M2-SSH-Gen2' }

$sw = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '172.*' -and $_.InterfaceAlias -like '*Default*' } | Select-Object -First 1
if (-not $sw) { throw 'Default Switch adapter not found' }
$base = ($sw.IPAddress -split '\.')[0..1] -join '.'

function Find-Ip($mac) {
    $m = ($mac -replace '(..)(?!$)', '$1-')
    $n = Get-NetNeighbor -LinkLayerAddress $m -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "$base.*" -and $_.State -ne 'Unreachable' } | Select-Object -First 1
    if ($n) { return $n.IPAddress }
    $pool = [RunspaceFactory]::CreateRunspacePool(1, 64); $pool.Open(); $jobs = @()
    foreach ($third in 16..31) { foreach ($last in 1..254) {
        $ip = "$base.$third.$last"
        $ps = [PowerShell]::Create().AddScript({ param($i) (New-Object Net.NetworkInformation.Ping).Send($i, 150) | Out-Null }).AddArgument($ip)
        $ps.RunspacePool = $pool; $jobs += @{ P = $ps; H = $ps.BeginInvoke() } } }
    foreach ($j in $jobs) { $j.P.EndInvoke($j.H); $j.P.Dispose() }; $pool.Close()
    $n = Get-NetNeighbor -LinkLayerAddress $m -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "$base.*" } | Select-Object -First 1
    if ($n) { return $n.IPAddress } else { return $null }
}

$cfg = Get-Content -Raw $cfgPath
foreach ($alias in $map.Keys) {
    $vm = $map[$alias]
    if ((Get-VM -Name $vm).State -ne 'Running') { Write-Output "$alias : VM $vm not running"; continue }
    $mac = (Get-VMNetworkAdapter -VMName $vm | Select-Object -First 1).MacAddress
    $ip = Find-Ip $mac
    if (-not $ip) { Write-Output "$alias : IP not found (guest still booting?)"; continue }
    $pattern = '(?m)(^Host [^\r\n]*\b' + [regex]::Escape($alias) + '\b[^\r\n]*\r?\n\s+HostName )\S+'
    $cfg = [regex]::Replace($cfg, $pattern, ('${1}' + $ip))
    Write-Output "$alias -> $ip"
}
Set-Content -Path $cfgPath -Value $cfg -NoNewline
