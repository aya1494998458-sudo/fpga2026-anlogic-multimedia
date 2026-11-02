$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$suite=Join-Path $root 'tools\oss-cad-suite'
$env:PATH="$suite\bin;$suite\lib;$env:PATH"
New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force | Out-Null
$iverilog=if(Test-Path "$suite\bin\iverilog.exe"){"$suite\bin\iverilog.exe"}else{(Get-Command iverilog -ErrorAction Stop).Source}
$vvp=if(Test-Path "$suite\bin\vvp.exe"){"$suite\bin\vvp.exe"}else{(Get-Command vvp -ErrorAction Stop).Source}
$rtl=@(Get-ChildItem (Join-Path $root 'rtl') -Filter *.v | ForEach-Object {$_.FullName})
$rtl+=Join-Path $root 'project\src\user_source\hdl_source\SD\frame_fifo_write.v'
$rtl+=Join-Path $root 'project\src\user_source\hdl_source\hdmi_audio_tone_i2s_64fs.v'
$rtl+=Join-Path $root 'project\src\user_source\hdl_source\SD\frame_read_write.v'
$rtl+=Join-Path $root 'project\src\user_source\hdl_source\SD\frame_fifo_read.v'
$rtl+=Join-Path $root 'project\src\user_source\hdl_source\video_rgb_to_axis_640x480.v'
$rtl+=Join-Path $root 'tb\models\wfifo_model.v'
$tests=@(Get-ChildItem (Join-Path $root 'tb') -Filter 'tb_*.v')
Push-Location $root
try {
 foreach($test in $tests){
  $out=Join-Path $root ('reports\'+$test.BaseName+'.vvp')
  & $iverilog -g2012 -s $test.BaseName -o $out @rtl $test.FullName
  if($LASTEXITCODE -ne 0){throw "Compile failed: $($test.Name)"}
  & $vvp $out 2>&1 | Tee-Object (Join-Path $root ('reports\'+$test.BaseName+'.log'))
  if($LASTEXITCODE -ne 0){throw "Simulation failed: $($test.Name)"}
 }
}finally {Pop-Location}



