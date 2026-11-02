# One-line removal (elevates itself):
# irm https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/remove.ps1 | iex
$global:SrtUninstall = $true
try { irm https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.ps1 | iex } finally { Remove-Variable SrtUninstall -Scope Global }
