# Usage: run.ps1 <fixtures dir> <windows dir of the project>. Validates only (-DryRun), certificate stores are not touched.
param([string]$F, [string]$W)
$want = @{
  good = 'valid'; rollback = 'no update'; no_constraints = 'no critical name'; not_critical = 'no critical name'; foreign = 'zone'
  public_suffix = 'public suffix'; bare_tld = 'format'; dot_tld = 'format'; no_ip_exclusion = 'exclude all IP'; partial_ip_exclusion = 'exclude all IP'
  ip_permitted = 'not a DNS'; wrong_cross_key = 'cross key'; bad_signature = 'bad manifest'; hash_mismatch = 'hash mismatch'
}
$bad = 0
foreach ($c in ($want.Keys | Sort-Object)) {
  $d = Join-Path $env:TEMP ("srtt-" + [guid]::NewGuid()); New-Item -ItemType Directory $d | Out-Null
  Copy-Item "$F\signer.crt", "$F\upstream.crt" $d; '202601010000' | Set-Content "$d\serial.txt"
  $o = (& powershell -NoProfile -ExecutionPolicy Bypass -File "$W\update.ps1" -Base "$F\$c" -Dir $d -DryRun) -join ' '
  $ok = $o -match [regex]::Escape($want[$c])
  if (-not $ok) { $bad++ }
  "{0,-5} {1,-22} {2}" -f $(if ($ok) { 'ok' } else { 'FAIL' }), $c, $o
  Remove-Item $d -Recurse -Force
}
"failures: $bad"; exit $bad
