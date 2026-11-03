param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [string]$Version = "2.0.0"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
$normalizedVersion = $Version.Trim().TrimStart([char[]]@("v", "V"))
if ([string]::IsNullOrWhiteSpace($normalizedVersion)) {
    throw "Version must not be empty."
}
$normalizedVersion = $normalizedVersion -replace '[^0-9A-Za-z.-]', '-'
$output = Join-Path $root "dist\$Runtime"
$archive = Join-Path $root "dist\MiddleFlow-$normalizedVersion-$Runtime.zip"

Push-Location $root
try {
    & $dotnet publish .\src\MiddleFlow.Windows\MiddleFlow.Windows.csproj `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -p:EnableWindowsTargeting=true `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:EnableCompressionInSingleFile=true `
        -p:DebugType=None `
        -p:DebugSymbols=false `
        -o $output
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $Runtime." }

    Copy-Item .\README.md (Join-Path $output "README.md") -Force
    $license = Join-Path (Split-Path -Parent $root) "LICENSE"
    if (Test-Path $license) {
        Copy-Item $license (Join-Path $output "LICENSE") -Force
    }
    Compress-Archive -Path (Join-Path $output "*") -DestinationPath $archive -Force
    Write-Host "Published $Runtime to $output"
    Write-Host "Version: $normalizedVersion"
    Write-Host "Archive: $archive"
}
finally {
    Pop-Location
}
