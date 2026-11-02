$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$tdHome=if($env:ANLOGIC_TD_HOME){$env:ANLOGIC_TD_HOME}else{'D:\FPGA_Tools\Anlogic_TD'}
$td=Join-Path $tdHome 'bin\td_commands_prompt.exe'
$log=Join-Path $root ('reports\td_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.log')
$script=(Join-Path $PSScriptRoot 'build.tcl').Replace('\','/')
Push-Location (Join-Path $root 'project\src\td_project')
try { & $td $script 2>&1 | Tee-Object -FilePath $log; $code=$LASTEXITCODE }
finally { Pop-Location }
Write-Host "Exit=$code; log=$log. Inspect final.ts; exit 0 is not timing closure."
exit $code
