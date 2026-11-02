# Run daily by the SafeRUTrust scheduled task as SYSTEM. It never runs downloaded code: it only accepts certificates.
param(
  [string]$Base = 'https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download',
  [string]$Dir = $PSScriptRoot,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
. "$PSScriptRoot\common.ps1"
$log = "$Dir\update.log"
function Say($m) { $l = "$(Get-Date -Format s) $m"; $l; try { Add-Content $log $l -Encoding ascii } catch {} }

$t = Join-Path $env:TEMP ("srt-" + [guid]::NewGuid())
try {
  New-Item -ItemType Directory $t | Out-Null
  [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
  foreach ($f in 'manifest.txt', 'manifest.sig', 'safe-ru-trust-root.crt', 'safe-ru-trust-cross.crt') {
    if ($Base -match '^https://') { Invoke-WebRequest "$Base/$f" -OutFile "$t\$f" -UseBasicParsing -TimeoutSec 60 } else { Copy-Item "$Base\$f" "$t\$f" }
  }
  $signer = Read-Cert "$Dir\signer.crt"
  $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($signer)
  $mf = [IO.File]::ReadAllBytes("$t\manifest.txt")
  if (-not $rsa.VerifyData($mf, [IO.File]::ReadAllBytes("$t\manifest.sig"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) { throw 'bad manifest signature' }

  $m = @{}; foreach ($l in [Text.Encoding]::ASCII.GetString($mf) -split "`n") { if ($l -match '^(\w+)=(\S+)\s*$') { $m[$Matches[1]] = $Matches[2] } }
  if ($m.serial -notmatch '^\d{12}$') { throw 'bad serial' }
  $have = (Get-Content "$Dir\serial.txt" -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($have -and [int64]$m.serial -le [int64]$have) { Say "no update ($($m.serial) <= $have)"; return }

  foreach ($p in @('root_sha256', 'safe-ru-trust-root.crt'), @('cross_sha256', 'safe-ru-trust-cross.crt')) {
    if ((Get-FileHash "$t\$($p[1])" -Algorithm SHA256).Hash -ne $m[$p[0]].ToUpper()) { throw "hash mismatch: $($p[1])" }
  }
  $root = Read-Cert "$t\safe-ru-trust-root.crt"
  Assert-Root $root
  Assert-Cross (Read-Cert "$t\safe-ru-trust-cross.crt") $root (Read-Cert "$Dir\upstream.crt")
  if ($DryRun) { Say "valid $($m.version) ($($m.serial))"; return }
  Install-Certs "$t\safe-ru-trust-root.crt" "$t\safe-ru-trust-cross.crt"
  Set-Content "$Dir\serial.txt" $m.serial -Encoding ascii
  Say "updated to $($m.version) ($($m.serial))"
} catch {
  Say "REJECTED: $($_.Exception.Message)"; exit 1
} finally {
  Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
}
