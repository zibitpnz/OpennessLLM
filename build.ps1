param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDir = Join-Path $scriptDir "bin"
$outExe = Join-Path $binDir "OpennessLLM.exe"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $csc)) {
    throw "C# compiler was not found: $csc"
}

New-Item -ItemType Directory -Force -Path $binDir | Out-Null

& $csc `
    /nologo `
    /platform:x64 `
    /target:exe `
    /optimize+ `
    /reference:System.IO.Compression.dll `
    /reference:System.IO.Compression.FileSystem.dll `
    /out:$outExe `
    (Join-Path $scriptDir "Program.cs")

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Built: $outExe"
