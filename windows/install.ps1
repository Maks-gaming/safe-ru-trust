# Run via install.bat (asks for admin rights). Remove via uninstall.bat.
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$pf = "$env:ProgramFiles\SafeRUTrust"   # admin-only: this folder is executed as SYSTEM
$ff = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Certificates'
$task = 'SafeRUTrust update'
if ($Uninstall) {
  Unregister-ScheduledTask $task -Confirm:$false -ErrorAction SilentlyContinue
  Remove-Certs
  Remove-Item $pf -Recurse -Force -ErrorAction SilentlyContinue
  # ponytail: drops the value even if someone else set it; we do not track who did
  Remove-ItemProperty $ff -Name ImportEnterpriseRoots -ErrorAction SilentlyContinue
  'Removed.'; return
}
$root = Read-Cert "$PSScriptRoot\safe-ru-trust-root.crt"
Assert-Root $root
Assert-Cross (Read-Cert "$PSScriptRoot\safe-ru-trust-cross.crt") $root (Read-Cert "$PSScriptRoot\upstream.crt")
Install-Certs "$PSScriptRoot\safe-ru-trust-root.crt" "$PSScriptRoot\safe-ru-trust-cross.crt"
New-Item $ff -Force | Out-Null
Set-ItemProperty $ff -Name ImportEnterpriseRoots -Value 1 -Type DWord

New-Item -ItemType Directory $pf -Force | Out-Null
foreach ($f in 'common.ps1', 'update.ps1', 'signer.crt', 'upstream.crt') { Copy-Item "$PSScriptRoot\$f" "$pf\$f" -Force }
$serial = (Get-Content "$PSScriptRoot\manifest.txt" | Where-Object { $_ -match '^serial=' }) -replace '^serial=', ''
Set-Content "$pf\serial.txt" $serial.Trim() -Encoding ascii
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$pf\update.ps1`""
$t = New-ScheduledTaskTrigger -Daily -At 12:00 -RandomDelay (New-TimeSpan -Hours 4)
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$p = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask $task -Action $a -Trigger $t -Settings $s -Principal $p -Force | Out-Null
'Installed, daily updates enabled. Restart your browser if it is open.'
