param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source

Push-Location $root
try {
    & $dotnet build .\MiddleFlow.Windows.sln -c $Configuration -p:EnableWindowsTargeting=true
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }

    & $dotnet run --project .\tests\MiddleFlow.Core.Tests\MiddleFlow.Core.Tests.csproj -c $Configuration --no-build -p:EnableWindowsTargeting=true
    if ($LASTEXITCODE -ne 0) { throw "Core smoke tests failed." }

    & $dotnet run --project .\tests\MiddleFlow.Windows.Tests\MiddleFlow.Windows.Tests.csproj -c $Configuration --no-build -p:EnableWindowsTargeting=true
    if ($LASTEXITCODE -ne 0) { throw "Windows input layout test failed." }
}
finally {
    Pop-Location
}
