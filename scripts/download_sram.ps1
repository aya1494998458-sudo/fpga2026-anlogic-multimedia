param([switch]$ProgramSram)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$manifest=Join-Path $root 'reports\release_manifest.json'
if(!(Test-Path -LiteralPath $manifest)){throw 'No verified release manifest yet.'}
$release=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
$bit=Join-Path $root $release.bitstream
if((Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash -ne $release.sha256){throw 'Bitstream hash mismatch.'}
if(!$release.timing_pass){throw 'This build has unresolved timing. Programming is blocked by this script.'}
$bw='D:\FPGA_Tools\Anlogic_TD\bin\bw_commands_prompt.exe'
$stamp=Get-Date -Format yyyyMMdd_HHmmss
$script=Join-Path $root ('reports\sram_'+$stamp+'.tcl')
$content='if {[catch {'+"`nread_device_id -cable 0`n"
if($ProgramSram){
 $content+='download -bit {'+$bit.Replace('\','/')+'} -mode jtag -cable 0'+"`n"
}else {Write-Host 'Read-only detection. To intentionally program temporary SRAM use -ProgramSram.'}
$content+='} message]} {puts stderr "SRAM_TOOL_ERROR: $message"; exit 1}'+"`n"
if($ProgramSram){$content+='puts "SRAM_PROGRAM_COMMAND_COMPLETED"'+"`n"}
$content+="exit`n"
Set-Content -LiteralPath $script -Value $content -Encoding ascii
$result=@(& $bw $script.Replace('\','/') 2>&1)
$code=$LASTEXITCODE
$result | Tee-Object (Join-Path $root ('reports\sram_'+$stamp+'.log'))
if($code -ne 0 -or ($result -join "`n") -match 'ERROR:|SRAM_TOOL_ERROR'){throw 'Official tool reported an error; inspect the saved log.'}
if($ProgramSram -and ($result -join "`n") -notmatch 'SRAM_PROGRAM_COMMAND_COMPLETED'){throw 'No download completion marker.'}
exit 0
