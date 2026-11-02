# One-line install of the latest release (elevates itself):
# irm https://raw.githubusercontent.com/Maks-gaming/safe-ru-trust/main/windows/get.ps1 | iex
& {
  $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
  $d = Join-Path $env:TEMP "safe-ru-trust-$([guid]::NewGuid())"
  New-Item -ItemType Directory $d | Out-Null
  try {
    Invoke-WebRequest -UseBasicParsing 'https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-windows.zip' -OutFile "$d\w.zip"
    Expand-Archive "$d\w.zip" "$d\x"
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File "$d\x\install.ps1"
    } else {
      Start-Process "$d\x\install.bat" -Verb RunAs -Wait
    }
  } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}
