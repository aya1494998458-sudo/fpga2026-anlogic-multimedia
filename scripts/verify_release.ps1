$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$m=Get-Content -LiteralPath (Join-Path $root 'reports/release_manifest.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath (Join-Path $root $m.bitstream) -Algorithm SHA256).Hash.ToLower() -ne $m.sha256){throw 'Bitstream hash mismatch'}
foreach($d in (Get-Content -LiteralPath (Join-Path $root 'dependencies.json') -Raw | ConvertFrom-Json)){
 $p=Join-Path $root $d.file
 if(!(Test-Path -LiteralPath $p)){throw "Restore official dependency: $($d.file)"}
 if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() -ne $d.sha256){throw "Dependency hash mismatch: $($d.file)"}
}
Write-Host 'Release bitstream and official dependencies verified.'
