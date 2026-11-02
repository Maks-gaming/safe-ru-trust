# Запуск: install.bat (сам попросит права администратора). Удаление: uninstall.bat
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$mine = '^CN=Safe RU Trust '
foreach ($s in 'Cert:\LocalMachine\Root','Cert:\LocalMachine\CA','Cert:\CurrentUser\CA') {
  Get-ChildItem $s | Where-Object { $_.Subject -match $mine -or $_.Issuer -match $mine } | Remove-Item
}
$ff = 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox\Certificates'
if ($Uninstall) {
  # ponytail: снимает значение, даже если его задал кто-то другой; отдельно не отслеживаем
  Remove-ItemProperty $ff -Name ImportEnterpriseRoots -ErrorAction SilentlyContinue
  'Removed.'; return
}
Import-Certificate "$PSScriptRoot\safe-ru-trust-root.crt" -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate "$PSScriptRoot\safe-ru-trust-cross.crt" -CertStoreLocation Cert:\LocalMachine\CA | Out-Null
New-Item $ff -Force | Out-Null
Set-ItemProperty $ff -Name ImportEnterpriseRoots -Value 1 -Type DWord
'Installed. Restart Firefox if it is open.'
