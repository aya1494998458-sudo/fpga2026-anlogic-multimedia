param([string]$RepositoryName='fpga2026-anlogic-multimedia')
$ErrorActionPreference='Stop'
if($RepositoryName -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid repository name'}
$root=Split-Path $PSScriptRoot -Parent
$gh=if(Get-Command gh -ErrorAction SilentlyContinue){(Get-Command gh).Source}else{Join-Path (Split-Path $root -Parent) '_工具/gh/bin/gh.exe'}
if(!(Test-Path -LiteralPath $gh)){throw 'Install official GitHub CLI and add gh to PATH'}
& $gh auth status
if($LASTEXITCODE -ne 0){throw 'Run gh auth login first; credentials must stay local'}
Push-Location $root
try {
 if(@(git status --porcelain).Count -gt 0){throw 'Review and commit local changes first'}
 $remote=git remote get-url origin 2>$null
 if($LASTEXITCODE -eq 0){throw "Existing origin preserved. Verify it belongs to this project before pushing: $remote"}
 & $gh repo create $RepositoryName --private --source . --remote origin --push
 if($LASTEXITCODE -ne 0){throw 'Create or push failed; no success claimed'}
 $account=& $gh api user --jq .login
 $fullName="$account/$RepositoryName"
 & $gh repo view $fullName --json url,isPrivate,defaultBranchRef
 if($LASTEXITCODE -ne 0){throw 'Remote repository verification failed'}
 $local=git rev-parse HEAD
 $head=git ls-remote origin refs/heads/main
 if($LASTEXITCODE -ne 0 -or $head -notmatch "^$local\s"){throw 'Remote main does not match local HEAD'}
 & $gh api "repos/$fullName/contents/README.md" --jq .path
 if($LASTEXITCODE -ne 0){throw 'Remote file verification failed'}
 Write-Host 'Private repository push and remote HEAD/README verified. Record the displayed URL and SHA.'
}finally{Pop-Location}
