# Shared by install.ps1 and update.ps1. ASCII only: PowerShell 5.1 reads BOM-less files as ANSI.
$script:Mine = '^CN=Safe RU Trust '
# Automatic updates may only touch these zones, plus the exact foreign names below. Anything else needs a new installer.
$script:Tlds = 'ru','su','xn--p1ai'
$script:ExactForeign = 'sberbank.com','vtb.com','tochka.com'
$script:Denied = 'gov.ru','com.ru','net.ru','org.ru','pp.ru','msk.ru','spb.ru','edu.ru','ac.ru','gov.su','com.su','net.su','org.su'

function Read-Der([byte[]]$b, [int]$i) {
  $tag = $b[$i]; $n = [int]$b[$i + 1]; $h = 2
  if ($n -ge 0x80) {
    $c = $n - 0x80; if ($c -lt 1 -or $c -gt 3) { throw 'bad DER length' }
    $n = 0; for ($k = 0; $k -lt $c; $k++) { $n = $n * 256 + $b[$i + 2 + $k] }; $h += $c
  }
  if ($i + $h + $n -gt $b.Length) { throw 'truncated DER' }
  [pscustomobject]@{ Tag = [int]$tag; Start = $i + $h; Len = $n; Next = $i + $h + $n }
}

# Returns @{Permitted=[dns names]; Excluded=[raw IP byte arrays]}, throws on anything unexpected.
function Read-NameConstraints([byte[]]$b) {
  $seq = Read-Der $b 0; if ($seq.Tag -ne 0x30 -or $seq.Next -ne $b.Length) { throw 'bad NameConstraints' }
  $r = @{ Permitted = @(); Excluded = @() }
  $i = $seq.Start
  while ($i -lt $seq.Next) {
    $part = Read-Der $b $i
    if ($part.Tag -ne 0xA0 -and $part.Tag -ne 0xA1) { throw 'bad subtrees tag' }
    $j = $part.Start
    while ($j -lt $part.Next) {
      $st = Read-Der $b $j; if ($st.Tag -ne 0x30) { throw 'bad subtree' }
      $name = Read-Der $b $st.Start
      if ($name.Next -ne $st.Next) { throw 'min/max in subtree not allowed' }
      if ($part.Tag -eq 0xA0) {
        if ($name.Tag -ne 0x82) { throw 'permitted subtree is not a DNS name' }
        $r.Permitted += [Text.Encoding]::ASCII.GetString($b, $name.Start, $name.Len)
      } else {
        if ($name.Tag -ne 0x87) { throw 'excluded subtree is not an IP range' }
        $ip = New-Object byte[] $name.Len; [Array]::Copy($b, $name.Start, $ip, 0, $name.Len)
        $r.Excluded += ,$ip
      }
      $j = $st.Next
    }
    $i = $part.Next
  }
  $r
}

function Assert-DomainAllowed([string]$d) {
  if ($d -cnotmatch '^[a-z0-9-]+(\.[a-z0-9-]+)+$') { throw "domain not allowed (format): $d" }
  if ($script:Denied -contains $d) { throw "domain not allowed (public suffix): $d" }
  $tld = $d.Substring($d.LastIndexOf('.') + 1)
  if ($script:Tlds -notcontains $tld -and $script:ExactForeign -notcontains $d) { throw "domain not allowed (zone): $d" }
}

function Assert-Root([Security.Cryptography.X509Certificates.X509Certificate2]$c) {
  if ($c.Subject -notmatch ($script:Mine + '\S+$') -or $c.Subject -ne $c.Issuer) { throw "unexpected root subject: $($c.Subject)" }
  $e = $c.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.30' }
  if (-not $e -or -not $e.Critical) { throw 'root has no critical name constraints' }
  $nc = Read-NameConstraints $e.RawData
  if ($nc.Permitted.Count -lt 1) { throw 'root permits nothing' }
  $nc.Permitted | ForEach-Object { Assert-DomainAllowed $_ }
  # DNS constraints do not cover IP SANs, so every IP must be excluded.
  $all = $nc.Excluded | Where-Object { ($_.Length -eq 8 -or $_.Length -eq 32) -and -not ($_ | Where-Object { $_ -ne 0 }) }
  if (@($all | Where-Object { $_.Length -eq 8 }).Count -ne 1 -or @($all | Where-Object { $_.Length -eq 32 }).Count -ne 1) { throw 'root does not exclude all IP addresses' }
}

function Assert-Cross($cross, $root, $upstream) {
  if ($cross.Subject -ne $upstream.Subject) { throw 'cross subject differs from upstream' }
  if ($cross.GetPublicKeyString() -ne $upstream.GetPublicKeyString()) { throw 'cross key differs from upstream' }
  if ($cross.Issuer -ne $root.Subject) { throw 'cross is not issued by root' }
}

function Install-Certs([string]$rootPath, [string]$crossPath) {
  $new = (Import-Certificate $rootPath -CertStoreLocation Cert:\LocalMachine\Root).Thumbprint,
         (Import-Certificate $crossPath -CertStoreLocation Cert:\LocalMachine\CA).Thumbprint
  Remove-Certs -Keep $new
}

function Remove-Certs([string[]]$Keep = @()) {
  foreach ($s in 'Cert:\LocalMachine\Root', 'Cert:\LocalMachine\CA', 'Cert:\CurrentUser\CA') {
    Get-ChildItem $s | Where-Object { ($_.Subject -match $script:Mine -or $_.Issuer -match $script:Mine) -and $Keep -notcontains $_.Thumbprint } | Remove-Item
  }
}

function Read-Cert([string]$p) { New-Object Security.Cryptography.X509Certificates.X509Certificate2 (,[IO.File]::ReadAllBytes($p)) }
