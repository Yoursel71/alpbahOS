# Headless VM screenshot via Hyper-V WMI (works over SSH, no desktop/VMConnect needed).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vm-screenshot.ps1 -VmName alpbahOS-M2-SSH-Gen2 -Out C:\Users\thewo\shot.png
param([string]$VmName = 'alpbahOS-M2-SSH-Gen2', [string]$Out = "$env:TEMP\vmshot.png", [int]$Width = 1024, [int]$Height = 768)
Add-Type -AssemblyName System.Drawing
$ns = 'root\virtualization\v2'
$vm = Get-CimInstance -Namespace $ns -ClassName Msvm_ComputerSystem -Filter "ElementName='$VmName'"
$svc = Get-CimInstance -Namespace $ns -ClassName Msvm_VirtualSystemManagementService
$sd = Get-CimAssociatedInstance -InputObject $vm -ResultClassName Msvm_VirtualSystemSettingData | Where-Object VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' | Select-Object -First 1
$r = Invoke-CimMethod -InputObject $svc -MethodName GetVirtualSystemThumbnailImage -Arguments @{ TargetSystem = $sd; WidthPixels = [uint16]$Width; HeightPixels = [uint16]$Height }
if ($r.ReturnValue -ne 0 -or -not $r.ImageData) { throw "thumbnail failed rc=$($r.ReturnValue)" }
$bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format16bppRgb565)
$bd = $bmp.LockBits((New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)), 'WriteOnly', $bmp.PixelFormat)
[System.Runtime.InteropServices.Marshal]::Copy([byte[]]$r.ImageData, 0, $bd.Scan0, [Math]::Min($r.ImageData.Length, $bd.Stride * $Height))
$bmp.UnlockBits($bd); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output "saved $Out"
