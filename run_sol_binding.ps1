$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$luaExe = Join-Path $toolDir 'lua.exe'
$buildLua = Join-Path $toolDir 'build.lua'

if (-not (Test-Path -LiteralPath $luaExe -PathType Leaf)) {
    throw "[ERROR] lua.exe not found: $luaExe"
}
if (-not (Test-Path -LiteralPath $buildLua -PathType Leaf)) {
    throw "[ERROR] build.lua not found: $buildLua"
}

Write-Host "[sol-binding] toolDir : $toolDir"
Write-Host "[sol-binding] Running : $luaExe build.lua"
Write-Host ''

Push-Location -LiteralPath $toolDir
try {
    & $luaExe $buildLua
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
}
finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host "[ERROR] sol_binding failed with exit code $exitCode"
}
else {
    Write-Host '[sol-binding] Done.'
}

exit $exitCode
