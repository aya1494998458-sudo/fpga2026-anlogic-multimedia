param([Parameter(Mandatory=$true)][string]$ReferenceRoot)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$entries=Get-Content -LiteralPath (Join-Path $root 'dependencies.json') -Raw | ConvertFrom-Json
foreach($entry in $entries){
 $source=Join-Path $ReferenceRoot $entry.file
 if(!(Test-Path -LiteralPath $source)){throw "Missing dependency: $($entry.file)"}
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256){throw "Dependency hash mismatch: $($entry.file)"}
 $dest=Join-Path $root $entry.file
 if(Test-Path -LiteralPath $dest){if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256){throw "Existing file differs: $dest"};continue}
 New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
 Copy-Item -LiteralPath $source -Destination $dest
}
Write-Host 'Dependencies restored and SHA256 verified. No license files copied.'
