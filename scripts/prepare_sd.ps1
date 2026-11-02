param([Parameter(Mandatory=$true)][ValidatePattern('^[E-Ze-z]$')][string]$DriveLetter,
      [switch]$IncludeAudio)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$vol=Get-Volume -DriveLetter $DriveLetter
if($vol.FileSystem -ne 'FAT32'){throw 'Requires an existing FAT32 card; this script never formats disks.'}
$dest=$DriveLetter+':\'
$sources=@(Get-ChildItem (Join-Path $root 'assets\official_bmp') -Filter *.bmp | Sort-Object Name | Select-Object -First 4)
if($IncludeAudio -and (Test-Path -LiteralPath (Join-Path $dest 'MUSIC.WAV'))){throw 'MUSIC.WAV already exists; no files overwritten.'}
for($i=0;$i -lt $sources.Count;$i++){
 $path=Join-Path $dest ('CONTEST'+$i+'.BMP')
 if(Test-Path -LiteralPath $path){throw "Destination already exists: $path. No files overwritten."}
}
for($i=0;$i -lt $sources.Count;$i++){
 Copy-Item -LiteralPath $sources[$i].FullName -Destination (Join-Path $dest ('CONTEST'+$i+'.BMP'))
}
Write-Host 'Copied short-name BMPs to root. Safely eject card before using it in board.'
if($IncludeAudio){Copy-Item -LiteralPath (Join-Path $root 'assets\MUSIC.WAV') -Destination (Join-Path $dest 'MUSIC.WAV')}
