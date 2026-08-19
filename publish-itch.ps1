# Publish a previously built RustGame artifact to itch.io with Butler.
#
# This is deliberately separate from publish.ps1. The ordinary publisher builds
# and deploys the WebHatchery catalog; this script takes those generated dist/
# artifacts, stages an itch-specific standalone package, and optionally pushes
# it to the channels named by the project's itch.json.

param(
    [string]$ProjectDir,
    [ValidateSet("all", "html5", "windows")]
    [string]$Channel = "all",
    [string]$ButlerPath = "",
    [string]$UserVersion = "",
    [switch]$Preview,
    [switch]$Status,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ManagementRoot = $PSScriptRoot
$WorkspaceRoot = Split-Path -Parent $ManagementRoot

function Write-Utf8File {
    param([string]$Path, [string]$Content)

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Remove-ChildDirectory {
    param([string]$ParentDir, [string]$ChildDir)

    if (-not (Test-Path $ChildDir)) { return }

    $resolvedParent = (Resolve-Path $ParentDir).Path.TrimEnd('\', '/')
    $resolvedChild = (Resolve-Path $ChildDir).Path.TrimEnd('\', '/')
    $childPrefix = $resolvedParent + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedChild.StartsWith($childPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove staging path outside its parent: $resolvedChild"
    }

    Remove-Item -LiteralPath $resolvedChild -Recurse -Force
}

function Get-JsonProperty {
    param($Object, [string[]]$Names, $Default = $null)

    if ($null -eq $Object) { return $Default }
    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return $property.Value
        }
    }
    return $Default
}

function Get-ProjectInfo {
    param(
        [string]$Root,
        [switch]$RequireArtifacts
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = (Get-Location).Path
    }
    if (-not (Test-Path $Root -PathType Container)) {
        throw "Project directory not found: $Root"
    }

    $Root = (Get-Item $Root).FullName
    $cargoPath = Join-Path $Root "Cargo.toml"
    $pagePath = Join-Path $Root "game_page.json"
    $distDir = Join-Path $Root "dist"
    $webglDir = Join-Path $distDir "webgl"

    if (-not (Test-Path $cargoPath -PathType Leaf)) {
        throw "Cargo.toml not found: $cargoPath"
    }
    if (-not (Test-Path $pagePath -PathType Leaf)) {
        throw "game_page.json not found: $pagePath"
    }
    if ($RequireArtifacts -and -not (Test-Path $webglDir -PathType Container)) {
        throw "WebGL artifacts not found: $webglDir. Run .\publish.ps1 first."
    }

    $cargo = Get-Content $cargoPath -Raw -Encoding UTF8
    $packageName = $null
    if ($cargo -match '(?m)^\s*name\s*=\s*"([^"]+)"') {
        $packageName = $matches[1]
    }
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        $clientCargo = Join-Path $Root "client\Cargo.toml"
        if (Test-Path $clientCargo -PathType Leaf) {
            $clientText = Get-Content $clientCargo -Raw -Encoding UTF8
            if ($clientText -match '(?m)^\s*name\s*=\s*"([^"]+)"') {
                $packageName = $matches[1]
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        throw "Could not find a Cargo package name in $cargoPath"
    }

    try {
        $page = Get-Content $pagePath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "Could not parse $pagePath : $($_.Exception.Message)"
    }

    $wasmBase = [string](Get-JsonProperty $page @("wasm") $packageName)
    if ([string]::IsNullOrWhiteSpace($wasmBase)) { $wasmBase = $packageName }

    $targetDir = Join-Path $Root "target"
    try {
        Push-Location $Root
        try {
            $metadata = cargo metadata --format-version 1 --no-deps 2>$null | ConvertFrom-Json
            if ($metadata.target_directory) { $targetDir = [string]$metadata.target_directory }
        } finally {
            Pop-Location
        }
    } catch {
        Write-Warning "Could not resolve Cargo target directory; using $targetDir"
    }

    $windowsArchives = @(Get-ChildItem $distDir -Filter "*_windows.zip" -File -ErrorAction SilentlyContinue)
    if ($windowsArchives.Count -gt 1) {
        throw "Expected one Windows archive in $distDir, found: $($windowsArchives.Name -join ', ')"
    }

    return [pscustomobject]@{
        ProjectRoot = $Root
        ProjectSlug = Split-Path $Root -Leaf
        PackageName = $packageName
        WasmFileName = "$wasmBase.wasm"
        DistDir = $distDir
        WebGLDir = $webglDir
        TargetDir = $targetDir
        Page = $page
        WindowsArchive = if ($windowsArchives.Count -eq 1) { $windowsArchives[0] } else { $null }
    }
}

function Read-ItchConfig {
    param([pscustomobject]$Info)

    $path = Join-Path $Info.ProjectRoot "itch.json"
    if (-not (Test-Path $path -PathType Leaf)) {
        throw "itch.json not found: $path"
    }

    try {
        $config = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "Could not parse $path : $($_.Exception.Message)"
    }

    $target = [string](Get-JsonProperty $config @("target") $null)
    if ([string]::IsNullOrWhiteSpace($target) -or $target -notmatch '^[^/\s]+/[^:\s]+$') {
        throw "itch.json target must look like owner/game: $path"
    }

    $channels = Get-JsonProperty $config @("channels") $null
    $html5Channel = [string](Get-JsonProperty $config @("html5_channel") $null)
    $windowsChannel = [string](Get-JsonProperty $config @("windows_channel") $null)
    if ($null -ne $channels) {
        if ([string]::IsNullOrWhiteSpace($html5Channel)) { $html5Channel = [string](Get-JsonProperty $channels @("html5") "html5") }
        if ([string]::IsNullOrWhiteSpace($windowsChannel)) { $windowsChannel = [string](Get-JsonProperty $channels @("windows") "windows") }
    }
    if ([string]::IsNullOrWhiteSpace($html5Channel)) { $html5Channel = "html5" }
    if ([string]::IsNullOrWhiteSpace($windowsChannel)) { $windowsChannel = "windows" }

    foreach ($channelName in @($html5Channel, $windowsChannel)) {
        if ($channelName -notmatch '^[a-z0-9][a-z0-9-]*$') {
            throw "itch.io channel names must use lower-case kebab-case: $channelName"
        }
    }

    return [pscustomobject]@{
        Path = $path
        Target = $target
        Html5Channel = $html5Channel
        WindowsChannel = $windowsChannel
        UserVersion = [string](Get-JsonProperty $config @("user_version", "version") "")
    }
}

function Get-ButlerExecutable {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path $RequestedPath -PathType Leaf)) {
            throw "Butler executable not found: $RequestedPath"
        }
        return (Get-Item $RequestedPath).FullName
    }

    $bundled = Join-Path $ManagementRoot "itch-butler\butler.exe"
    if (Test-Path $bundled -PathType Leaf) { return (Get-Item $bundled).FullName }

    $command = Get-Command butler -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    throw "Butler was not found. Pass -ButlerPath or install it on PATH."
}

function Get-ReferencedRuntimeFiles {
    param([string]$Index)

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($Index, '(?:src|href)="(?:\.\./)?shared-assets/runtime/([^"?]+)')) {
        $name = $match.Groups[1].Value
        if (-not $files.Contains($name)) { $files.Add($name) }
    }
    return @($files)
}

function Get-ReferencedWindowsDownload {
    param([string]$Index)

    $match = [regex]::Match($Index, 'href="([^"?]+_windows\.zip)(?:\?[^"?]*)?"')
    if (-not $match.Success) { return $null }
    $value = $match.Groups[1].Value.Replace('\', '/')
    if ($value.Contains('/') -or $value.Contains('..')) {
        throw "Windows download path must be a file in the package root: $value"
    }
    return $value
}

function Get-RuntimeSource {
    param([string]$Name)

    $candidates = @(
        (Join-Path (Join-Path $WorkspaceRoot "Release\shared-assets\runtime") $Name),
        (Join-Path (Join-Path $ManagementRoot "web") $Name)
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Rewrite-ItchIndex {
    param([string]$Index)

    $Index = $Index.Replace('    <link rel="stylesheet" href="../bug-report.css">', '')
    $Index = [regex]::Replace($Index, '(?s)\s*<!-- Player bug reporting.*?<script src="\.\./bug-report\.js"></script>', '')
    $Index = [regex]::Replace($Index, '(?s)\s*<!-- Ko-fi support widget.*?kofiWidgetOverlay\.draw.*?</script>', '')
    $Index = [regex]::Replace($Index, '<a href="\.\./"[^>]*>.*?</a>', '')
    $Index = $Index.Replace('<a href="/">Web Hatchery</a>', 'Web Hatchery')
    $Index = $Index.Replace('href="../shared.css"', 'href="shared.css"')
    $Index = [regex]::Replace($Index, '(?<attribute>(?:src|href)=")\.\./shared-assets/', '${attribute}shared-assets/')
    $Index = [regex]::Replace($Index, 'href="dist/([^"?]+)"', 'href="$1"')
    return $Index
}

function Assert-LocalPackageReferences {
    param([string]$PackageDir)

    $indexPath = Join-Path $PackageDir "index.html"
    $index = Get-Content $indexPath -Raw -Encoding UTF8
    $references = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($index, '(?:src|href)="([^"]+)"')) {
        $references.Add($match.Groups[1].Value)
    }
    foreach ($match in [regex]::Matches($index, 'load\(["'']([^"'']+)["'']\)')) {
        $references.Add($match.Groups[1].Value)
    }

    foreach ($reference in $references) {
        $pathOnly = ($reference -split '[?#]', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly) -or
            $pathOnly.StartsWith('#') -or
            $pathOnly -match '^(?i:mailto:|https?://|data:|javascript:)') { continue }
        if ($pathOnly.StartsWith('/') -or $pathOnly.StartsWith('../')) {
            throw "Itch package contains a non-local reference: $reference"
        }

        $candidate = Join-Path $PackageDir ($pathOnly.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path $candidate -PathType Leaf)) {
            throw "Itch package reference is missing: $reference"
        }
    }
}

function Assert-ItchPackageLimits {
    param([string]$PackageDir)

    $root = (Resolve-Path $PackageDir).Path
    $files = @(Get-ChildItem $root -Recurse -File)
    $totalBytes = 0L
    foreach ($file in $files) {
        $totalBytes += $file.Length
        $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
        if ($relative.Length -gt 240) { throw "Itch path exceeds 240 characters: $relative" }
        if ($file.Length -gt 200MB) { throw "Itch file exceeds 200 MB: $relative" }
    }
    if ($files.Count -gt 1000) { throw "Itch HTML5 package contains more than 1,000 files: $($files.Count)" }
    if ($totalBytes -gt 500MB) { throw "Itch HTML5 package exceeds 500 MB unpacked: $totalBytes bytes" }

    Write-Host "HTML5 package: $($files.Count) files, $totalBytes bytes" -ForegroundColor Gray
}

function New-ItchHtml5Package {
    param([pscustomobject]$Info)

    $packageDir = Join-Path $Info.DistDir "itch-webgl"
    Remove-ChildDirectory $Info.DistDir $packageDir
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    Copy-Item -Path (Join-Path $Info.WebGLDir "*") -Destination $packageDir -Recurse -Force

    $indexPath = Join-Path $packageDir "index.html"
    if (-not (Test-Path $indexPath -PathType Leaf)) { throw "WebGL package has no index.html: $indexPath" }
    $index = Get-Content $indexPath -Raw -Encoding UTF8

    $expectedWasmPath = Join-Path $packageDir $Info.WasmFileName
    if (-not (Test-Path $expectedWasmPath -PathType Leaf)) {
        throw "WebGL package is missing the WASM named by game_page.json: $($Info.WasmFileName)"
    }

    $thumbnail = Join-Path $packageDir "catalog_thumbnail.png"
    if (Test-Path $thumbnail -PathType Leaf) { Remove-Item -LiteralPath $thumbnail -Force }

    $sharedCss = Join-Path $ManagementRoot "web\shared.css"
    if (-not (Test-Path $sharedCss -PathType Leaf)) { throw "Shared stylesheet not found: $sharedCss" }
    Copy-Item $sharedCss $packageDir -Force

    $runtimeDestination = Join-Path $packageDir "shared-assets\runtime"
    New-Item -ItemType Directory -Path $runtimeDestination -Force | Out-Null
    foreach ($runtimeName in Get-ReferencedRuntimeFiles $index) {
        $source = Get-RuntimeSource $runtimeName
        if ($null -eq $source) { throw "Runtime bridge not found for itch package: $runtimeName" }
        Copy-Item $source (Join-Path $runtimeDestination $runtimeName) -Force
    }

    if ($index -match '(?:src|href)="storage\.js') {
        $customStorage = Join-Path $Info.ProjectRoot "storage.js"
        if (-not (Test-Path $customStorage -PathType Leaf)) {
            throw "The WebGL page references custom storage.js, but it is missing: $customStorage"
        }
        Copy-Item $customStorage $packageDir -Force
    }

    $windowsDownload = Get-ReferencedWindowsDownload $index
    if ($null -ne $windowsDownload) {
        if ($null -eq $Info.WindowsArchive) {
            throw "The WebGL page references $windowsDownload, but no *_windows.zip exists in $($Info.DistDir)"
        }
        Copy-Item $Info.WindowsArchive.FullName (Join-Path $packageDir $windowsDownload) -Force
    }

    $index = Rewrite-ItchIndex $index
    Write-Utf8File $indexPath $index
    Assert-LocalPackageReferences $packageDir
    Assert-ItchPackageLimits $packageDir

    Write-Host "Prepared itch HTML5 package: $packageDir" -ForegroundColor Green
    return $packageDir
}

function Invoke-Butler {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Host "Butler: $Executable $($Arguments -join ' ')" -ForegroundColor DarkGray
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Butler failed with exit code $LASTEXITCODE."
    }
}

function Publish-Channel {
    param(
        [string]$Executable,
        [string]$Source,
        [string]$Target,
        [string]$Version,
        [bool]$IsHtml5
    )

    if ($Preview) {
        $arguments = @("push-preview", "--changes-only", $Source, $Target)
        Invoke-Butler $Executable $arguments
        return
    }

    $arguments = @("push", "--assume-yes", "--if-changed")
    if ($DryRun) { $arguments += "--dry-run" }
    if ($IsHtml5) { $arguments += "--auto-wrap" }
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $arguments += @("--userversion", $Version)
    }
    $arguments += @($Source, $Target)
    Invoke-Butler $Executable $arguments
}

function Show-ChannelStatus {
    param([string]$Executable, [string]$Target)
    Invoke-Butler $Executable @("status", $Target)
}

if ($Help) {
    Write-Host "Usage: .\publish-itch.ps1 [-ProjectDir <path>] [-Channel all|html5|windows] [-Preview] [-Status] [-DryRun] [-ButlerPath <path>] [-UserVersion <value>]"
    Write-Host "Run the project's ordinary .\publish.ps1 first; this script only stages and publishes its dist/ artifacts."
    exit 0
}

$info = Get-ProjectInfo $ProjectDir -RequireArtifacts:($Channel -in @("all", "html5") -and -not $Status)
$config = Read-ItchConfig $info
$butler = Get-ButlerExecutable $ButlerPath

if ($Status) {
    Write-Host "=== $($info.ProjectSlug) itch.io status ===" -ForegroundColor Cyan
    if ($Channel -in @("all", "html5")) {
        Show-ChannelStatus $butler "$($config.Target):$($config.Html5Channel)"
    }
    if ($Channel -in @("all", "windows")) {
        Show-ChannelStatus $butler "$($config.Target):$($config.WindowsChannel)"
    }
    exit 0
}

$version = $UserVersion
if ([string]::IsNullOrWhiteSpace($version)) { $version = $config.UserVersion }

$publishHtml5 = $Channel -in @("all", "html5")
$publishWindows = $Channel -in @("all", "windows")
$html5Package = $null
if ($publishHtml5) {
    $html5Package = New-ItchHtml5Package $info
}

$targets = @()
if ($publishHtml5) {
    $targets += [pscustomobject]@{
        Source = $html5Package
        Target = "$($config.Target):$($config.Html5Channel)"
        IsHtml5 = $true
    }
}
if ($publishWindows) {
    if ($null -eq $info.WindowsArchive) {
        throw "Windows channel requested, but no *_windows.zip exists in $($info.DistDir). Run .\publish.ps1 first."
    }
    $targets += [pscustomobject]@{
        Source = $info.WindowsArchive.FullName
        Target = "$($config.Target):$($config.WindowsChannel)"
        IsHtml5 = $false
    }
}

Write-Host "=== $($info.ProjectSlug) itch.io publisher ===" -ForegroundColor Cyan
Write-Host "Target: $($config.Target)"
Write-Host "Channel mode: $Channel"
Write-Host ""

foreach ($entry in $targets) {
    if ($DryRun -or $Preview) {
        $mode = if ($Preview) { "preview" } else { "dry-run" }
        Write-Host "[$mode] $($entry.Source) -> $($entry.Target)" -ForegroundColor Yellow
    }
    Publish-Channel $butler $entry.Source $entry.Target $version $entry.IsHtml5
}

Write-Host "=== Complete ===" -ForegroundColor Cyan
