param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [ValidateSet("x64")]
    [string]$Platform = "x64",

    [string]$CertSubject = "SakuraVDD Test",

    [string]$Inf2CatOs = "10_x64",

    [switch]$NoSign,

    [switch]$NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathPattern,

        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    $tool = Get-ChildItem -Path $PathPattern -Recurse -Filter $Filter -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if (-not $tool) {
        throw "Required tool not found: $Filter under $PathPattern"
    }

    return $tool.FullName
}

function Find-MsBuildAmd64 {
    $vswhere = Join-Path "${env:ProgramFiles(x86)}" "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found. Install Visual Studio 2022 first."
    }

    $found = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\amd64\MSBuild.exe" |
        Select-Object -First 1

    if (-not $found) {
        throw "AMD64 MSBuild.exe not found via vswhere."
    }

    return $found
}

function Ensure-TestCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubjectName
    )

    $fullSubject = "CN=$SubjectName"
    $existing = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $fullSubject } | Select-Object -First 1
    if ($existing) {
        return $existing
    }

    Write-Host "Creating test code-signing certificate: $fullSubject"
    return New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $fullSubject `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -KeyExportPolicy Exportable `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(3)
}

function Ensure-CatalogExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir,

        [Parameter(Mandatory = $true)]
        [string]$Inf2CatExe,

        [Parameter(Mandatory = $true)]
        [string]$OsSpec
    )

    $catPath = Join-Path $PackageDir "mttvdd.cat"
    if (Test-Path $catPath) {
        return $catPath
    }

    Write-Host "Catalog missing. Running Inf2Cat..."
    & $Inf2CatExe /driver:"$PackageDir" /os:$OsSpec /uselocaltime /verbose
    if ($LASTEXITCODE -ne 0) {
        throw "Inf2Cat failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-Path $catPath)) {
        throw "Inf2Cat completed but catalog is still missing: $catPath"
    }

    return $catPath
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$driverRoot = Join-Path $repoRoot "Virtual Display Driver (HDR)\MttVDD"
$vcxproj = Join-Path $driverRoot "MttVDD.vcxproj"
$releaseRoot = Join-Path $driverRoot "$Platform\$Configuration"
$packageDir = Join-Path $releaseRoot "MttVDD"

if (-not (Test-Path $vcxproj)) {
    throw "Project file not found: $vcxproj"
}

$msbuild = Find-MsBuildAmd64
$inf2cat = Find-Tool -PathPattern "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Filter "Inf2Cat.exe"
$signtool = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\x64\\" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $signtool) {
    throw "x64 signtool.exe not found under Windows Kits bin."
}

if (-not $NoBuild) {
    $atls = Get-ChildItem "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC" -Recurse -Filter "atls.lib" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\x64\\" } |
        Select-Object -First 1
    if (-not $atls) {
        throw "atls.lib not found. Install ATL/MFC components for MSVC v143 (x64/x86) first."
    }

    Write-Host "Building driver project..."
    & $msbuild $vcxproj /t:Rebuild /p:Configuration=$Configuration /p:Platform=$Platform /p:PreferredToolArchitecture=x64
    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild failed with exit code $LASTEXITCODE. Fix compile/link errors before packaging."
    }
}

if (-not (Test-Path $packageDir)) {
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
}

$infSource = Join-Path $releaseRoot "MttVDD.inf"
$dllSource = Join-Path $releaseRoot "MttVDD.dll"
$settingsSource = Join-Path (Join-Path $repoRoot "Virtual Display Driver (HDR)") "vdd_settings.xml"

if (-not (Test-Path $infSource)) { throw "Built INF not found: $infSource" }
if (-not (Test-Path $dllSource)) { throw "Built DLL not found: $dllSource" }
if (-not (Test-Path $settingsSource)) { throw "Settings XML not found: $settingsSource" }

Copy-Item $infSource (Join-Path $packageDir "MttVDD.inf") -Force
Copy-Item $dllSource (Join-Path $packageDir "MttVDD.dll") -Force
Copy-Item $settingsSource (Join-Path $packageDir "vdd_settings.xml") -Force

$catPath = Ensure-CatalogExists -PackageDir $packageDir -Inf2CatExe $inf2cat -OsSpec $Inf2CatOs

if (-not $NoSign) {
    $cert = Ensure-TestCertificate -SubjectName $CertSubject
    if (-not $cert) {
        throw "Certificate not available for signing."
    }

    Write-Host "Signing catalog: $catPath"
    & $signtool sign /v /fd SHA256 /s My /sm /n $CertSubject /tr http://timestamp.digicert.com /td SHA256 $catPath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool sign failed with exit code $LASTEXITCODE."
    }

    Write-Host "Verifying signature..."
    & $signtool verify /v /pa $catPath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool verify failed with exit code $LASTEXITCODE."
    }
}

Write-Host ""
Write-Host "Package build complete."
Write-Host "Package directory: $packageDir"
Get-ChildItem $packageDir | Select-Object Name, Length, LastWriteTime
