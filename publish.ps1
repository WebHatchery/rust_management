# Shared RustGames publisher helpers.

param(
    [switch]$RustGamePublish,
    [switch]$RustGameFtpUpload,
    [switch]$RustGameRecordDeployment,
    [string]$ProjectName,
    [string]$ProjectSlug,
    [string]$ProjectDir,
    [string]$SourceDir,
    [string]$DeployDir,
    [string]$Environment,
    [string]$TargetType,
    [string]$RemotePath,
    [string]$PublishMode,
    [string]$Status = "success",
    [switch]$SkipBuild = $false,
    [switch]$WindowsOnly = $false,
    [switch]$WebGLOnly = $false,
    [switch]$DeployOnly = $false,
    [Alias('p')] [switch]$Production = $false,
    [switch]$FTP = $false,
    [switch]$SkipFtpCatalog = $false,
    [switch]$SkipFtpSharedAssets = $false,
    [switch]$RustGamesSharedAssetsFtpUpload,
    [switch]$RustGamesCatalogFtpUpload,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# This script lives in rust_management/ alongside the shared web shell, docs and
# tooling. The games, the Cargo workspace and the build outputs (Release/,
# target/, publish-logs/) live in its PARENT directory. Anything that resolves a
# game, Release/ or the workspace must use $WorkspaceRoot; anything that resolves
# tooling or shared web assets must use $ManagementRoot.
$ManagementRoot = $PSScriptRoot
$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

$EnvFile = "D:\WebHatchery\.env"
$CatalogThumbnailFileName = "catalog_thumbnail.png"
$FtpManifestFileName = "_ftp_manifest.json"
$SharedAssetsDirectoryName = "shared-assets"
$SharedRuntimeDirectoryName = "runtime"
$SharedFontsDirectoryName = "fonts"
# Root-level web assets that live at the games root and are referenced by every game's
# index.html as ../<name> (shared.css plus the player bug-report widget).
$CatalogWebAssetFileNames = @("shared.css", "bug-report.css", "bug-report.js")
$RajdhaniSemiBoldFileName = "Rajdhani-SemiBold.ttf"

function Write-DryRun($message) {
    Write-Host "[DRY-RUN] $message" -ForegroundColor DarkYellow
}

function Import-DotEnvFile {
    param([string]$Path)

    $config = @{}
    if (-not (Test-Path $Path)) { return $config }

    foreach ($rawLine in (Get-Content $Path)) {
        $line = ($rawLine -as [string]).Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) { continue }
        if ($line -match '^\s*([^#=\s]+)\s*=\s*(.*)\s*$') {
            $name = $matches[1]
            $value = $matches[2].Trim().Trim('"').Trim("'")
            $config[$name] = $value
        }
    }

    return $config
}

function Get-ConfigValue {
    param([hashtable]$Config, [string]$Name, [string]$Default = $null)

    if ($Config.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace($Config[$Name])) {
        return $Config[$Name]
    }

    $envValue = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) { return $envValue }

    return $Default
}

function Convert-ToBool {
    param($Value, [bool]$Default)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }

    switch ($Value.ToString().Trim().ToLowerInvariant()) {
        { $_ -in @("1", "true", "yes", "on") } { return $true }
        { $_ -in @("0", "false", "no", "off") } { return $false }
        default { return $Default }
    }
}

function Join-FtpPath {
    param([string]$Base, [string]$Child)

    $left = "/"
    if (-not [string]::IsNullOrWhiteSpace($Base)) {
        $left = $Base.Replace('\', '/').TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($left)) { $left = "/" }
    }

    $right = ""
    if (-not [string]::IsNullOrWhiteSpace($Child)) {
        $right = $Child.Replace('\', '/').TrimStart('/')
    }

    if ([string]::IsNullOrWhiteSpace($right)) { return $left }
    if ($left -eq "/") { return "/$right" }
    return "$left/$right"
}

function Get-RelativePath {
    param([string]$Root, [string]$Path)

    $normalizedRoot = $Root.TrimEnd('\', '/')
    if ($Path.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($normalizedRoot.Length).TrimStart('\', '/')
    }

    return $Path
}

function Get-TransferStats {
    param([string]$RootPath)

    $fileCount = 0
    $totalBytes = 0L
    if (-not (Test-Path $RootPath)) {
        return @{ FileCount = 0; TotalBytes = 0L }
    }

    Get-ChildItem $RootPath -Recurse -File | ForEach-Object {
        $fileCount++
        $totalBytes += $_.Length
    }

    return @{ FileCount = $fileCount; TotalBytes = $totalBytes }
}

function Format-ByteSize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

function Get-FileSha256Hex {
    param([string]$Path)

    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function New-FtpTransferManifest {
    param([string]$RootPath)

    $files = @()
    if (Test-Path $RootPath) {
        Get-ChildItem $RootPath -Recurse -File | Sort-Object FullName | ForEach-Object {
            $relativePath = (Get-RelativePath $RootPath $_.FullName).Replace('\', '/')
            if ($relativePath -ne $FtpManifestFileName) {
                $files += [pscustomobject]@{
                    path = $relativePath
                    size = [long]$_.Length
                    sha256 = Get-FileSha256Hex $_.FullName
                }
            }
        }
    }

    return [pscustomobject]@{
        version = 1
        files = $files
    }
}

function ConvertTo-FtpTransferManifestJson {
    param($Manifest)

    return ($Manifest | ConvertTo-Json -Depth 5)
}

function ConvertTo-FtpManifestMap {
    param($Manifest)

    $map = @{}
    if ($null -eq $Manifest -or $null -eq $Manifest.files) { return $map }

    foreach ($entry in @($Manifest.files)) {
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.path)) { continue }
        $map[([string]$entry.path).Replace('\', '/')] = $entry
    }

    return $map
}

function Test-FtpManifestEntryEqual {
    param($LocalEntry, [hashtable]$RemoteManifestMap)

    if ($null -eq $LocalEntry -or $null -eq $RemoteManifestMap) { return $false }
    $path = ([string]$LocalEntry.path).Replace('\', '/')
    if (-not $RemoteManifestMap.ContainsKey($path)) { return $false }

    $remoteEntry = $RemoteManifestMap[$path]
    if ([long]$remoteEntry.size -ne [long]$LocalEntry.size) { return $false }

    $remoteHash = ([string]$remoteEntry.sha256).ToLowerInvariant()
    $localHash = ([string]$LocalEntry.sha256).ToLowerInvariant()
    return $remoteHash -eq $localHash
}

function ConvertTo-RoostSlug {
    param([string]$Value)

    $slug = ($Value -as [string]).Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9_]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) { return "unknown_project" }
    return $slug
}

function Get-RustGameRoostSlug {
    param([string]$ProjectSlug, [string]$ProjectName, [string]$ProjectDir)

    if (-not [string]::IsNullOrWhiteSpace($ProjectSlug)) {
        return (ConvertTo-RoostSlug $ProjectSlug)
    }

    $base = $ProjectName
    if (-not [string]::IsNullOrWhiteSpace($ProjectDir) -and (Test-Path $ProjectDir)) {
        $base = Split-Path (Get-Item $ProjectDir).FullName -Leaf
    }

    $slug = ConvertTo-RoostSlug $base
    if ($slug.StartsWith("rust_")) { return $slug }
    return "rust_$slug"
}

function Remove-ChildDirectory {
    param([string]$ParentDir, [string]$ChildDir)

    if (-not (Test-Path $ChildDir)) { return }

    $resolvedParent = (Resolve-Path $ParentDir).Path.TrimEnd('\', '/')
    $resolvedChild = (Resolve-Path $ChildDir).Path.TrimEnd('\', '/')
    if (-not $resolvedChild.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Error "Refusing to remove path outside parent: $resolvedChild"
        exit 1
    }

    Remove-Item -LiteralPath $resolvedChild -Recurse -Force
}

function Copy-DirectoryClean {
    param([string]$SourceDir, [string]$DestinationParent, [string]$DirectoryName)

    if (-not (Test-Path $SourceDir)) { return }

    if (-not (Test-Path $DestinationParent)) {
        New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
    }

    $destination = Join-Path $DestinationParent $DirectoryName
    Remove-ChildDirectory $DestinationParent $destination
    Copy-Item $SourceDir -Destination $DestinationParent -Recurse -Force
}

function Get-RustGamesSharedAssetsSourceDir {
    return (Join-Path (Join-Path $WorkspaceRoot "Release") $SharedAssetsDirectoryName)
}

function Get-RustGamesSharedRajdhaniFontSourcePath {
    $candidates = @(
        (Join-Path $WorkspaceRoot "macroquad-toolkit\assets\fonts\$RajdhaniSemiBoldFileName"),
        (Join-Path (Get-RustGamesSharedAssetsSourceDir) "fonts\$RajdhaniSemiBoldFileName"),
        (Join-Path $WorkspaceRoot "finallanding\assets\fonts\$RajdhaniSemiBoldFileName"),
        (Join-Path $WorkspaceRoot "monsterhall\assets\fonts\$RajdhaniSemiBoldFileName"),
        (Join-Path $WorkspaceRoot "the_enchanters_ledger\assets\fonts\$RajdhaniSemiBoldFileName")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate -PathType Leaf) { return $candidate }
    }

    return $null
}

function Save-SharedRuntimeFile {
    param([string]$Uri, [string]$DestinationPath, [string]$DisplayName)

    try {
        Invoke-WebRequest -Uri $Uri -OutFile $DestinationPath
    } catch {
        if (Test-Path $DestinationPath -PathType Leaf) {
            Write-Warning "Could not refresh $DisplayName; using existing shared copy."
        } else {
            Write-Warning "Could not download shared runtime file $DisplayName"
        }
    }
}

function Sync-RustGamesSharedAssetsSource {
    param([switch]$DryRun)

    $sourceDir = Get-RustGamesSharedAssetsSourceDir
    $runtimeDir = Join-Path $sourceDir $SharedRuntimeDirectoryName
    $fontsDir = Join-Path $sourceDir $SharedFontsDirectoryName

    if ($DryRun) {
        Write-DryRun "Would prepare RustGames shared assets: $sourceDir"
        return $sourceDir
    }

    New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null

    Save-SharedRuntimeFile `
        -Uri "https://not-fl3.github.io/miniquad-samples/mq_js_bundle.js" `
        -DestinationPath (Join-Path $runtimeDir "mq_js_bundle.js") `
        -DisplayName "mq_js_bundle.js"

    Save-SharedRuntimeFile `
        -Uri "https://raw.githubusercontent.com/not-fl3/sapp-jsutils/master/js/sapp_jsutils.js" `
        -DestinationPath (Join-Path $runtimeDir "sapp_jsutils.js") `
        -DisplayName "sapp_jsutils.js"

    # storage.js is ours, not an upstream download: ship the canonical copy from
    # web/ so every game shares one localStorage bridge.
    foreach ($bridge in @("storage.js", "clipboard.js")) {
        $bridgeSource = Join-Path (Get-RustGameWebSourceDir) $bridge
        if (Test-Path $bridgeSource -PathType Leaf) {
            Copy-Item $bridgeSource (Join-Path $runtimeDir $bridge) -Force
        } else {
            Write-Warning "Shared web bridge not found: $bridgeSource"
        }
    }

    $fontSource = Get-RustGamesSharedRajdhaniFontSourcePath
    if ($null -ne $fontSource) {
        Copy-Item $fontSource (Join-Path $fontsDir $RajdhaniSemiBoldFileName) -Force
    } else {
        Write-Warning "Shared font source not found: $RajdhaniSemiBoldFileName"
    }

    return $sourceDir
}

function Sync-RustGamesSharedAssetsToLocalGamesRoot {
    param([string]$GamesRootDir, [switch]$DryRun)

    if ([string]::IsNullOrWhiteSpace($GamesRootDir)) { return }

    $sourceDir = Sync-RustGamesSharedAssetsSource -DryRun:$DryRun
    if ($DryRun) {
        Write-DryRun "Would sync RustGames shared assets to local games root: $GamesRootDir"
        return
    }

    if (Test-Path $sourceDir) {
        Copy-DirectoryClean $sourceDir $GamesRootDir $SharedAssetsDirectoryName
    }
}

function Remove-RustGameSharedFontDuplicate {
    param([string]$DestinationDir)

    $fontPath = Join-Path $DestinationDir "assets\fonts\$RajdhaniSemiBoldFileName"
    if (-not (Test-Path $fontPath -PathType Leaf)) { return }

    $fontSource = Get-RustGamesSharedRajdhaniFontSourcePath
    if ($null -eq $fontSource) { return }

    $sourceFile = Get-Item $fontSource
    $targetFile = Get-Item $fontPath
    if ($sourceFile.Length -ne $targetFile.Length) { return }
    if ((Get-FileSha256Hex $fontSource) -ne (Get-FileSha256Hex $fontPath)) { return }

    Remove-Item -LiteralPath $fontPath -Force
}

function Remove-RustGameObsoleteLocalSharedFiles {
    param([string]$GameDir)

    if (-not (Test-Path $GameDir)) { return }

    $obsoletePaths = @(
        "shared.css",
        "mq_js_bundle.js",
        "sapp_jsutils.js",
        "assets\fonts\$RajdhaniSemiBoldFileName"
    )

    foreach ($relativePath in $obsoletePaths) {
        $path = Join-Path $GameDir $relativePath
        if (Test-Path $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

function Join-ZipPath {
    param([string]$Base, [string]$Child)

    $left = ""
    if (-not [string]::IsNullOrWhiteSpace($Base)) {
        $left = $Base.Replace('\', '/').Trim('/')
    }

    $right = ""
    if (-not [string]::IsNullOrWhiteSpace($Child)) {
        $right = $Child.Replace('\', '/').Trim('/')
    }

    if ([string]::IsNullOrWhiteSpace($left)) { return $right }
    if ([string]::IsNullOrWhiteSpace($right)) { return $left }
    return "$left/$right"
}

function Get-OptionalPropertyValue {
    param($Object, [string[]]$Names, $Default = $null)

    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return $property.Value
        }
    }

    return $Default
}

function Get-RustGameAssetPackConfig {
    param([string]$ProjectRoot)

    $configPath = Join-Path $ProjectRoot "asset_packs.json"
    if (-not (Test-Path $configPath)) { return @() }

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($null -ne $config.packs) { return @($config.packs) }
        return @($config)
    } catch {
        Write-Warning "Could not read asset pack config: $configPath ($($_.Exception.Message))"
        return @()
    }
}

function New-RustGameAssetPack {
    param(
        [string]$SourceDir,
        [string]$OutputPath,
        [string]$EntryRoot,
        [string]$DisplayPath
    )

    if (-not (Test-Path $SourceDir)) {
        Write-Warning "Asset pack source not found: $SourceDir"
        return $false
    }

    $files = @(Get-ChildItem $SourceDir -Recurse -File)
    if ($files.Count -eq 0) {
        Write-Warning "Asset pack source has no files: $SourceDir"
        return $false
    }

    $outputParent = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputParent)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
    }
    if (Test-Path $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    $resolvedSource = (Resolve-Path $SourceDir).Path
    $archive = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $relativePath = (Get-RelativePath $resolvedSource $file.FullName).Replace('\', '/')
            $entryName = Join-ZipPath $EntryRoot $relativePath
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $file.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }

    $packFile = Get-Item $OutputPath
    Write-Host "  Packed asset library: $DisplayPath ($($files.Count) files, $(Format-ByteSize $packFile.Length))" -ForegroundColor Gray
    return $true
}

function Apply-RustGameAssetPacks {
    param([pscustomobject]$Info, [string]$DestinationDir)

    $packs = Get-RustGameAssetPackConfig $Info.ProjectRoot
    if ($packs.Count -eq 0) { return }

    foreach ($pack in $packs) {
        $sourceRel = Get-OptionalPropertyValue $pack @("source", "Source")
        if ([string]::IsNullOrWhiteSpace($sourceRel)) {
            Write-Warning "Skipping asset pack entry without a source."
            continue
        }

        $sourceRel = $sourceRel.ToString().Replace('\', '/').Trim('/')
        $outputRel = Get-OptionalPropertyValue $pack @("output", "Output") "$sourceRel.zip"
        $outputRel = $outputRel.ToString().Replace('\', '/').Trim('/')
        $entryRoot = Get-OptionalPropertyValue $pack @("entry_root", "entryRoot", "EntryRoot") $sourceRel
        $entryRoot = $entryRoot.ToString().Replace('\', '/').Trim('/')
        $deleteSourceValue = Get-OptionalPropertyValue $pack @("delete_source", "deleteSource", "DeleteSource") $true
        $deleteSource = Convert-ToBool $deleteSourceValue $true

        $sourceDir = Join-Path $DestinationDir ($sourceRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $outputPath = Join-Path $DestinationDir ($outputRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $packed = New-RustGameAssetPack $sourceDir $outputPath $entryRoot $outputRel

        if ($packed -and $deleteSource) {
            Remove-ChildDirectory $DestinationDir $sourceDir
        }
    }
}

function Remove-RustGameObsoleteLocalAssetPackSources {
    param([pscustomobject]$Info, [string]$DeployDir, [string]$PackageDir)

    if ([string]::IsNullOrWhiteSpace($DeployDir) -or -not (Test-Path $DeployDir)) { return }

    $packs = Get-RustGameAssetPackConfig $Info.ProjectRoot
    if ($packs.Count -eq 0) { return }

    foreach ($pack in $packs) {
        $deleteSourceValue = Get-OptionalPropertyValue $pack @("delete_source", "deleteSource", "DeleteSource") $true
        if (-not (Convert-ToBool $deleteSourceValue $true)) { continue }

        $sourceRel = Get-OptionalPropertyValue $pack @("source", "Source")
        if ([string]::IsNullOrWhiteSpace($sourceRel)) { continue }
        $sourceRel = $sourceRel.ToString().Replace('\', '/').Trim('/')

        $outputRel = Get-OptionalPropertyValue $pack @("output", "Output") "$sourceRel.zip"
        $outputRel = $outputRel.ToString().Replace('\', '/').Trim('/')

        $deploySourcePath = Join-Path $DeployDir ($sourceRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path $deploySourcePath)) { continue }

        $packageSourcePath = Join-Path $PackageDir ($sourceRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (Test-Path $packageSourcePath) { continue }

        $deployOutputPath = Join-Path $DeployDir ($outputRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path $deployOutputPath)) { continue }

        Remove-ChildDirectory $DeployDir $deploySourcePath
        Write-Host "  Removed obsolete packed source: $sourceRel/" -ForegroundColor Gray
    }
}

function Get-FirstCargoPackageName {
    param([string]$CargoToml)

    if (-not (Test-Path $CargoToml)) { return $null }
    $content = Get-Content $CargoToml -Raw
    if ($content -match '(?m)^\s*name\s*=\s*"([^"]+)"') {
        return $matches[1]
    }

    return $null
}

function Get-RustGameWebSourceDir {
    return (Join-Path $ManagementRoot "web")
}

# Reads a game's index page data file. Returns $null when the game has not been
# migrated to the shared shell yet.
function Get-RustGamePageData {
    param([string]$ProjectRoot)

    $dataPath = Join-Path $ProjectRoot "game_page.json"
    if (-not (Test-Path $dataPath -PathType Leaf)) { return $null }

    try {
        return (Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        Write-Warning "Could not parse $dataPath : $($_.Exception.Message)"
        return $null
    }
}

function Get-IndexWasmFileName {
    param([string]$ProjectRoot, [string]$DefaultName)

    $pageData = Get-RustGamePageData $ProjectRoot
    if ($null -ne $pageData -and -not [string]::IsNullOrWhiteSpace($pageData.wasm)) {
        return "$($pageData.wasm).wasm"
    }
    if ($null -ne $pageData) { return "$DefaultName.wasm" }

    $indexPath = Join-Path $ProjectRoot "index.html"
    if (-not (Test-Path $indexPath)) { return "$DefaultName.wasm" }

    $indexContent = Get-Content $indexPath -Raw
    if ($indexContent -match 'load\s*\(\s*["''`]([^"''`?]+\.wasm)') {
        return [System.IO.Path]::GetFileName($matches[1])
    }

    return "$DefaultName.wasm"
}

function ConvertTo-HtmlAttributeText {
    param([string]$Text)

    if ($null -eq $Text) { return "" }
    return ($Text -replace '&', '&amp;' -replace '"', '&quot;' -replace '<', '&lt;' -replace '>', '&gt;')
}

# Renders <game>/game_page.json through web/index.template.html.
# Returns $true when a page was written.
function New-RustGameIndexHtml {
    param([pscustomobject]$Info, [string]$DestinationPath)

    $pageData = Get-RustGamePageData $Info.ProjectRoot
    if ($null -eq $pageData) { return $false }

    $templatePath = Join-Path (Get-RustGameWebSourceDir) "index.template.html"
    if (-not (Test-Path $templatePath -PathType Leaf)) {
        Write-Warning "Shared index template not found: $templatePath"
        return $false
    }

    $slug = $Info.GameSlug
    $nl = "`r`n"

    $title = if ([string]::IsNullOrWhiteSpace($pageData.title)) { Get-DefaultGameTitle $slug } else { $pageData.title }
    $wasm = if ([string]::IsNullOrWhiteSpace($pageData.wasm)) { $slug } else { $pageData.wasm }
    $roostSlug = if ([string]::IsNullOrWhiteSpace($pageData.roost_slug)) { "rust_$slug" } else { $pageData.roost_slug }
    $rendering = if ([string]::IsNullOrWhiteSpace($pageData.canvas_rendering)) { "pixelated" } else { $pageData.canvas_rendering }
    $hint = if ([string]::IsNullOrWhiteSpace($pageData.controls_hint)) { "Click the game canvas to start" } else { $pageData.controls_hint }

    # `image-rendering: pixelated` needs the crisp-edges fallback; `auto` must not have it.
    $renderingCss = if ($rendering -eq "pixelated") { "pixelated;$nl            image-rendering: crisp-edges" } else { $rendering }

    $statusText = "Playable"
    $statusClass = "playable"
    if ($null -ne $pageData.status) {
        if (-not [string]::IsNullOrWhiteSpace($pageData.status.text)) { $statusText = $pageData.status.text }
        if (-not [string]::IsNullOrWhiteSpace($pageData.status.class)) { $statusClass = $pageData.status.class }
    }

    $canvasSize = ""
    if ($null -ne $pageData.canvas -and $null -ne $pageData.canvas.width -and $null -ne $pageData.canvas.height) {
        $canvasSize = " width=""$($pageData.canvas.width)"" height=""$($pageData.canvas.height)"""
    }

    # --- info sections -------------------------------------------------------
    $sections = New-Object System.Collections.Generic.List[string]
    if ($null -ne $pageData.about -and $pageData.about.Count -gt 0) {
        $paragraphs = ($pageData.about | ForEach-Object { "                        <p>$_</p>" }) -join $nl
        $sections.Add("                <section class=""info-section"">$nl                    <h2>About This Game</h2>$nl$paragraphs$nl                </section>")
    }

    foreach ($section in @($pageData.extra_sections)) {
        if ($null -eq $section) { continue }
        $sections.Add("                <section class=""info-section"" style=""margin-top: 1rem;"">$nl                    <h2>$($section.heading)</h2>$nl                    $($section.body)$nl                </section>")
    }

    if ($null -ne $pageData.controls -and $pageData.controls.Count -gt 0) {
        $items = ($pageData.controls | ForEach-Object {
            "                        <li><kbd>$($_.key)</kbd><span>$($_.desc)</span></li>"
        }) -join $nl
        $controlsBody = "                    <ul class=""controls-list"">$nl$items$nl                    </ul>"
        if (-not [string]::IsNullOrWhiteSpace($pageData.controls_note)) {
            $controlsBody += "$nl                    <p style=""margin-top: 0.75rem; color: var(--text-muted); font-size: 0.9rem;"">$($pageData.controls_note)</p>"
        }
        $sections.Add("                <section class=""info-section"" style=""margin-top: 1rem;"">$nl                    <h2>Controls</h2>$nl$controlsBody$nl                </section>")
    }

    $detailItems = ""
    if ($null -ne $pageData.details -and $pageData.details.Count -gt 0) {
        $detailItems = ($pageData.details | ForEach-Object {
            "                        <li><span class=""label"">$($_.label)</span><span class=""value"">$($_.value)</span></li>"
        }) -join $nl
    }

    $downloads = ""
    if ($null -ne $pageData.download -and -not [string]::IsNullOrWhiteSpace($pageData.download.href)) {
        $label = if ([string]::IsNullOrWhiteSpace($pageData.download.label)) { "Windows Build" } else { $pageData.download.label }
        $downloads = "$nl                <div class=""sidebar-section"">$nl                    <h3>Downloads</h3>$nl                    <a href=""$($pageData.download.href)"" class=""btn btn-secondary"" style=""width: 100%; justify-content: center;"" download>$label</a>$nl                </div>"
    }

    # Source-repository link. Omitted when the game has no public repository --
    # a private repo would 404 for players.
    $repository = ""
    if (-not [string]::IsNullOrWhiteSpace($pageData.repository)) {
        $githubIcon = '<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" fill="currentColor" style="flex-shrink: 0;"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.012 8.012 0 0 0 16 8c0-4.42-3.58-8-8-8z"></path></svg>'
        $repository = "$nl$nl                <div class=""sidebar-section"">$nl                    <h3>Source</h3>$nl                    <a href=""$($pageData.repository)"" class=""btn btn-secondary"" style=""width: 100%; justify-content: center; gap: 0.5rem;"" target=""_blank"" rel=""noopener noreferrer"">$nl                        $githubIcon$nl                        <span>View on GitHub</span>$nl                    </a>$nl                </div>"
    }

    # --- cache busters -------------------------------------------------------
    $wasmBust = ""
    if (-not [string]::IsNullOrWhiteSpace($pageData.wasm_cache_bust)) {
        # `date-now` has to stay a JS expression, so the load() call is templated
        # with string concatenation rather than a literal query string.
        $wasmBust = if ($pageData.wasm_cache_bust -eq "date-now") { '?v=" + Date.now() + "' } else { "?v=$($pageData.wasm_cache_bust)" }
    }
    $assetBust = ""
    if (-not [string]::IsNullOrWhiteSpace($pageData.asset_cache_bust)) {
        $assetBust = "?v=$($pageData.asset_cache_bust)"
    }

    # The shared bridge is referenced at its deployed path directly, so it needs
    # no rewrite pass; a game opting out keeps its own root-level copy.
    $storageSrc = if ($pageData.storage_js -eq "custom") {
        "storage.js"
    } else {
        "../$SharedAssetsDirectoryName/$SharedRuntimeDirectoryName/storage.js"
    }

    # Pointer lock is emitted as a JS literal: null, or the game's logical
    # resolution plus the HUD rects that must stay clickable.
    $pointerLock = "null"
    if ($null -ne $pageData.pointer_lock) {
        $pointerLock = ($pageData.pointer_lock | ConvertTo-Json -Compress -Depth 5)
    }

    $description = ""
    if ($null -ne $pageData.about -and $pageData.about.Count -gt 0) {
        $description = ConvertTo-HtmlAttributeText (($pageData.about[0] -replace '<[^>]+>', '').Trim())
    }

    $html = Get-Content $templatePath -Raw -Encoding UTF8
    $replacements = @{
        "{{TITLE}}"            = $title
        "{{DESCRIPTION}}"      = $description
        "{{CANVAS_RENDERING}}" = $renderingCss
        "{{CANVAS_SIZE}}"      = $canvasSize
        "{{CONTROLS_HINT}}"    = $hint
        "{{INFO_SECTIONS}}"    = ($sections -join "$nl$nl")
        "{{STATUS_TEXT}}"      = $statusText
        "{{STATUS_CLASS}}"     = $statusClass
        "{{DETAILS}}"          = $detailItems
        "{{DOWNLOADS}}"        = $downloads
        "{{REPOSITORY}}"       = $repository
        "{{WASM}}"             = "$wasm.wasm"
        "{{WASM_CACHE_BUST}}"  = $wasmBust
        "{{ASSET_CACHE_BUST}}" = $assetBust
        "{{STORAGE_JS_SRC}}"   = $storageSrc
        "{{CLIPBOARD_JS_SRC}}" = "../$SharedAssetsDirectoryName/$SharedRuntimeDirectoryName/clipboard.js"
        "{{ROOST_SLUG}}"       = $roostSlug
        "{{POINTER_LOCK}}"     = $pointerLock
        "{{CUSTOM_CSS}}"       = ""
        "{{CUSTOM_JS}}"        = ""
        "{{PRE_LOAD_JS}}"      = ""
        "{{POST_LOAD_JS}}"     = ""
    }
    foreach ($token in $replacements.Keys) {
        $html = $html.Replace($token, $replacements[$token])
    }

    # Collapse the blank lines left behind by unused optional blocks.
    $html = $html -replace "(\r?\n){3,}", "$nl$nl"

    $html | Out-File $DestinationPath -Encoding UTF8 -NoNewline
    return $true
}

function Get-WindowsZipFileName {
    param([pscustomobject]$Info)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Info.WasmFileName)
    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = $Info.GameSlug
    }

    return "$($baseName)_windows.zip"
}

function Update-PackagedIndexPaths {
    param([string]$IndexPath)

    if (-not (Test-Path $IndexPath)) { return }

    $content = Get-Content $IndexPath -Raw
    $content = $content -replace 'href="(?:\.\./)?shared\.css"', 'href="../shared.css"'
    $content = $content -replace 'src="(?:\./)?mq_js_bundle\.js([^"]*)"', 'src="../shared-assets/runtime/mq_js_bundle.js$1"'
    $content = $content -replace 'src="(?:\./)?sapp_jsutils\.js([^"]*)"', 'src="../shared-assets/runtime/sapp_jsutils.js$1"'
    $content = $content -replace 'href="dist/([^"]+_windows\.zip)"', 'href="$1"'
    $content | Out-File $IndexPath -Encoding UTF8
}

function Get-PublishTimestamp {
    return (Get-Date).ToString("yyyy-MM-dd")
}

function Get-DefaultGameTitle {
    param([string]$GameSlug)

    if ([string]::IsNullOrWhiteSpace($GameSlug)) { return "Untitled Game" }

    return ([cultureinfo]::CurrentCulture.TextInfo).ToTitleCase(($GameSlug -replace "_", " "))
}

function Get-DefaultGameDescription {
    param([pscustomobject]$Info, [string]$FallbackTitle)

    $pageData = Get-RustGamePageData $Info.ProjectRoot
    if ($null -ne $pageData -and $null -ne $pageData.about -and $pageData.about.Count -gt 0) {
        return (($pageData.about[0] -replace '<[^>]+>', '').Trim())
    }

    $projectIndexPath = Join-Path $Info.ProjectRoot "index.html"
    if (Test-Path $projectIndexPath) {
        $indexContent = Get-Content $projectIndexPath -Raw
        if ($indexContent -match '(?is)<meta\s+name\s*=\s*"description"[^>]*content\s*=\s*"([^"]*)"') {
            return $matches[1].Trim()
        }
    }

    $cargoIndexPath = Join-Path $Info.PackageRoot "Cargo.toml"
    if (Test-Path $cargoIndexPath) {
        $cargoContent = Get-Content $cargoIndexPath -Raw
        if ($cargoContent -match '(?ms)^\s*description\s*=\s*"([^"]*)"') {
            return $matches[1].Trim()
        }
    }

    return "$FallbackTitle release"
}

function Get-RustGameCatalogThumbnailSource {
    param([pscustomobject]$Info)

    $rootThumbnail = Join-Path $Info.ProjectRoot $CatalogThumbnailFileName
    if (Test-Path $rootThumbnail -PathType Leaf) {
        return $rootThumbnail
    }

    $legacyScreenshot = Join-Path (Join-Path $ManagementRoot "title_screeshots") "$($Info.GameSlug).png"
    if (Test-Path $legacyScreenshot -PathType Leaf) {
        return $legacyScreenshot
    }

    return $null
}

function Get-RustGameCatalogThumbnailUrl {
    param([string]$GameSlug)

    if ([string]::IsNullOrWhiteSpace($GameSlug)) { return $null }

    $normalizedSlug = $GameSlug.Trim().ToLowerInvariant()
    $rootThumbnail = Join-Path (Join-Path $WorkspaceRoot $normalizedSlug) $CatalogThumbnailFileName
    if (Test-Path $rootThumbnail -PathType Leaf) {
        return "$normalizedSlug/$CatalogThumbnailFileName"
    }

    return $null
}

function Sync-RustGameCatalogThumbnail {
    param([pscustomobject]$Info, [string]$DestinationDir, [switch]$DryRun)

    $thumbnailSource = Get-RustGameCatalogThumbnailSource -Info $Info
    if ([string]::IsNullOrWhiteSpace($thumbnailSource)) {
        Write-Host "  Catalog thumbnail missing for $($Info.GameSlug); card will use title banner fallback." -ForegroundColor DarkGray
        return $false
    }

    $rootThumbnail = Join-Path $Info.ProjectRoot $CatalogThumbnailFileName

    if ($DryRun) {
        Write-DryRun "Would sync catalog thumbnail: $thumbnailSource -> $rootThumbnail"
        if (-not [string]::IsNullOrWhiteSpace($DestinationDir)) {
            Write-DryRun "Would copy catalog thumbnail to: $DestinationDir"
        }
        return $true
    }

    if (-not $thumbnailSource.Equals($rootThumbnail, [System.StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item $thumbnailSource $rootThumbnail -Force
        $thumbnailSource = $rootThumbnail
        Write-Host "  Copied catalog thumbnail to project root: $CatalogThumbnailFileName" -ForegroundColor Gray
    }

    if (-not [string]::IsNullOrWhiteSpace($DestinationDir) -and (Test-Path $DestinationDir)) {
        Copy-Item $thumbnailSource (Join-Path $DestinationDir $CatalogThumbnailFileName) -Force
        Write-Host "  Copied: $CatalogThumbnailFileName" -ForegroundColor Gray
    }

    return $true
}

function Get-ArchiveSlugLookup {
    param([string]$ArchiveRoot)

    $lookup = @{}
    if (-not (Test-Path $ArchiveRoot)) { return $lookup }

    Get-ChildItem -Path $ArchiveRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $slug = $_.Name.Trim()
        if (-not [string]::IsNullOrWhiteSpace($slug)) {
            $lookup[$slug.ToLowerInvariant()] = $true
        }
    }

    return $lookup
}

function Get-ActiveRustGameSlugLookup {
    param([string]$WorkspaceRoot)

    $lookup = @{}
    $ignoredDirectories = @("archive", "assets", "docs", "macroquad-toolkit", "publish-logs", "Release", "target", "template", "title_screeshots", ".vscode")

    if (-not (Test-Path $WorkspaceRoot)) { return $lookup }

    Get-ChildItem -Path $WorkspaceRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if ($ignoredDirectories -notcontains $_.Name) {
            $publishScript = Join-Path $_.FullName "publish.ps1"
            if (Test-Path $publishScript -PathType Leaf) {
                $lookup[$_.Name.ToLowerInvariant()] = $true
            }
        }
    }

    return $lookup
}

function Get-SlugFromPlayUrl {
    param([object]$Entry)

    if ($null -eq $Entry -or $null -eq $Entry.playUrl) { return $null }

    $playUrl = [string]$Entry.playUrl
    $playUrl = $playUrl.Trim()
    if ([string]::IsNullOrWhiteSpace($playUrl)) { return $null }

    $segments = $playUrl -split "[\\/]"
    if ($segments.Count -eq 0) { return $null }

    $slug = $segments[0].Trim()
    if ([string]::IsNullOrWhiteSpace($slug)) { return $null }

    return $slug.ToLowerInvariant()
}

function Set-CatalogField {
    param(
        [object]$Target,
        [string]$FieldName,
        [object]$FieldValue
    )

    if ($null -eq $Target -or [string]::IsNullOrWhiteSpace($FieldName)) {
        return
    }

    try {
        $property = $Target.PSObject.Properties[$FieldName]
        if ($null -ne $property) {
            try {
                $Target.$FieldName = $FieldValue
            } catch {
                $Target.PSObject.Properties.Remove($FieldName) | Out-Null
                $Target | Add-Member -NotePropertyName $FieldName -NotePropertyValue $FieldValue -Force
            }
        } else {
            $Target | Add-Member -NotePropertyName $FieldName -NotePropertyValue $FieldValue -Force
        }
    } catch {
        Write-Warning "Unable to set catalog field '$FieldName'."
    }
}

function Get-RustGameCatalogEntries {
    param([string]$CatalogIndexPath)

    if (-not (Test-Path $CatalogIndexPath)) {
        Write-Warning "Catalog index not found: $CatalogIndexPath"
        return $null
    }

    $catalogContent = Get-Content $CatalogIndexPath -Raw
    $pattern = '(?ms)^[ \t]*const games\s*=\s*\[(.*?)\]\s*;'
    $match = [regex]::Match($catalogContent, $pattern)

    if (-not $match.Success) {
        Write-Warning "Unable to locate embedded games array in catalog index."
        return $null
    }

    try {
        $jsonText = "[" + $match.Groups[1].Value + "]"
        return [pscustomobject]@{
            RawContent = $catalogContent
            GamesText  = $match.Value
            Catalog    = (ConvertFrom-Json -InputObject $jsonText)
            Match      = $match
        }
    } catch {
        Write-Warning "Failed to parse catalog games array: $($_.Exception.Message)"
        return $null
    }
}

function ConvertTo-RustGamesCatalogScript {
    param([object[]]$Games)

    $indent = "            "
    $gameArray = @()
    if ($null -ne $Games) {
        $gameArray = @($Games)
    }

    $json = ConvertTo-Json -InputObject $gameArray -Depth 25 -Compress:$false
    if ([string]::IsNullOrWhiteSpace($json)) { $json = "[]" }

    return $indent + "const games = " + ($json -replace "`r?`n", "`r`n$indent") + ";"
}

function Update-RustGamesCatalogIndex {
    param(
        [pscustomobject]$Info,
        [string]$CatalogIndexPath,
        [switch]$DryRun
    )

    if (-not (Test-Path $CatalogIndexPath)) {
        Write-Host "Skipping catalog update: release index not found at $CatalogIndexPath" -ForegroundColor Gray
        return $false
    }

    $parsed = Get-RustGameCatalogEntries -CatalogIndexPath $CatalogIndexPath
    if (-not $parsed) { return $false }

    $games = @()
    if ($null -ne $parsed.Catalog) {
        $games = @($parsed.Catalog)
    }

    $archiveLookup = Get-ArchiveSlugLookup -ArchiveRoot (Join-Path $ManagementRoot "archive")
    $activeGameLookup = Get-ActiveRustGameSlugLookup -WorkspaceRoot $WorkspaceRoot
    $archivedGamesRemoved = 0
    $staleGamesRemoved = 0
    $thumbnailUrlsRefreshed = 0
    $games = @(
        foreach ($game in $games) {
            $gameSlug = Get-SlugFromPlayUrl -Entry $game
            $isArchived = $false
            $isStale = $false
            if ($null -ne $game.playUrl -and [string]$game.playUrl -match '^(?i:archive)[\\/]') {
                $isArchived = $true
            } elseif (-not [string]::IsNullOrWhiteSpace($gameSlug) -and $archiveLookup.ContainsKey($gameSlug)) {
                $isArchived = $true
            } elseif (-not [string]::IsNullOrWhiteSpace($gameSlug) -and -not $activeGameLookup.ContainsKey($gameSlug)) {
                $isStale = $true
            }

            if (-not $isArchived -and -not $isStale) {
                $game
            } elseif ($isArchived) {
                $archivedGamesRemoved++
            } else {
                $staleGamesRemoved++
            }
        }
    )

    foreach ($game in $games) {
        $gameSlug = Get-SlugFromPlayUrl -Entry $game
        $catalogThumbnailUrl = Get-RustGameCatalogThumbnailUrl -GameSlug $gameSlug
        if (-not [string]::IsNullOrWhiteSpace($catalogThumbnailUrl) -and ([string]$game.thumbnailUrl) -ne $catalogThumbnailUrl) {
            Set-CatalogField -Target $game -FieldName "thumbnailUrl" -FieldValue $catalogThumbnailUrl
            $thumbnailUrlsRefreshed++
        }
    }

    $targetSlug = $Info.GameSlug
    $normalizedTargetSlug = if ([string]::IsNullOrWhiteSpace($targetSlug)) { "" } else { $targetSlug.ToLowerInvariant() }
    if ($archiveLookup.ContainsKey($normalizedTargetSlug)) {
        Write-Host "Catalog not updated: $targetSlug is in archive directory." -ForegroundColor Yellow
    }

    $title = Get-DefaultGameTitle $targetSlug
    $playUrl = "$targetSlug/index.html"
    $downloadFile = Get-WindowsZipFileName -Info $Info
    $downloadUrl = "$targetSlug/$downloadFile"
    $thumbnailUrl = "$targetSlug/$CatalogThumbnailFileName"
    $hasThumbnail = -not [string]::IsNullOrWhiteSpace((Get-RustGameCatalogThumbnailSource -Info $Info))
    $today = Get-PublishTimestamp

    if ($archiveLookup.ContainsKey($normalizedTargetSlug)) {
        if ($archivedGamesRemoved -gt 0) {
            Write-Host "Catalog updated: removed $archivedGamesRemoved archived game(s) from $CatalogIndexPath." -ForegroundColor Green
        } elseif ($staleGamesRemoved -gt 0) {
            Write-Host "Catalog updated: removed $staleGamesRemoved stale game(s) from $CatalogIndexPath." -ForegroundColor Green
        } else {
            Write-Host "Catalog unchanged: no archived entries found in $CatalogIndexPath." -ForegroundColor Gray
        }

        $replacementJson = ConvertTo-RustGamesCatalogScript -Games $games
        $updatedContent = $parsed.RawContent.Replace($parsed.GamesText, $replacementJson)

        if ($DryRun) {
            Write-DryRun "Would remove archive games from RustGames catalog entry at $CatalogIndexPath"
            return $true
        }

        $updatedContent | Out-File $CatalogIndexPath -Encoding UTF8
        return $true
    }

    if ($archivedGamesRemoved -gt 0) {
        Write-Host "Catalog updated: removed $archivedGamesRemoved archived game(s) from $CatalogIndexPath." -ForegroundColor Green
    }
    if ($staleGamesRemoved -gt 0) {
        Write-Host "Catalog updated: removed $staleGamesRemoved stale game(s) from $CatalogIndexPath." -ForegroundColor Green
    }
    if ($thumbnailUrlsRefreshed -gt 0) {
        Write-Host "Catalog updated: refreshed $thumbnailUrlsRefreshed thumbnail URL(s)." -ForegroundColor Green
    }

    $gameIndex = -1
    for ($i = 0; $i -lt $games.Count; $i++) {
        if (($games[$i].playUrl -as [string]) -ieq $playUrl) {
            $gameIndex = $i
            break
        }
    }

    if ($gameIndex -lt 0) {
        $description = Get-DefaultGameDescription -Info $Info -FallbackTitle $title
        $games = ,([pscustomobject]@{
            title = $title
            description = $description
            playUrl = $playUrl
            downloadUrl = $downloadUrl
            thumbnailUrl = $(if ($hasThumbnail) { $thumbnailUrl } else { $null })
            createdAt = $today
            addedAt = $today
            modifiedAt = $today
            genres = @("rust")
        }) + $games

        Write-Host "Catalog updated: added new game entry for $targetSlug." -ForegroundColor Green
    } else {
        $game = $games[$gameIndex]
        if ($null -eq $game.createdAt -and $null -eq $game.addedAt) {
            Set-CatalogField -Target $game -FieldName "createdAt" -FieldValue $today
            Set-CatalogField -Target $game -FieldName "addedAt" -FieldValue $today
        }
        if ($null -ne $game.addedAt -and $null -eq $game.createdAt) {
            Set-CatalogField -Target $game -FieldName "createdAt" -FieldValue $game.addedAt
        }
        if ($null -eq $game.title -or [string]::IsNullOrWhiteSpace([string]$game.title)) {
            Set-CatalogField -Target $game -FieldName "title" -FieldValue $title
        }
        if ($null -eq $game.playUrl -or [string]::IsNullOrWhiteSpace([string]$game.playUrl)) {
            Set-CatalogField -Target $game -FieldName "playUrl" -FieldValue $playUrl
        }
        if ($null -eq $game.downloadUrl -or [string]::IsNullOrWhiteSpace([string]$game.downloadUrl)) {
            Set-CatalogField -Target $game -FieldName "downloadUrl" -FieldValue $downloadUrl
        }
        if ($hasThumbnail) {
            Set-CatalogField -Target $game -FieldName "thumbnailUrl" -FieldValue $thumbnailUrl
        }
        Set-CatalogField -Target $game -FieldName "modifiedAt" -FieldValue $today

        Write-Host "Catalog updated: refreshed timestamps for $targetSlug." -ForegroundColor Green
    }

    $replacementJson = ConvertTo-RustGamesCatalogScript -Games $games
    $updatedContent = $parsed.RawContent.Replace($parsed.GamesText, $replacementJson)

    if ($DryRun) {
        Write-DryRun "Would update RustGames catalog entry at $CatalogIndexPath"
        return $true
    }

    $updatedContent | Out-File $CatalogIndexPath -Encoding UTF8
    return $true
}

function Resolve-CargoTargetDir {
    param([string]$ProjectRoot)

    $fallback = Join-Path $ProjectRoot "target"
    try {
        Push-Location $ProjectRoot
        try {
            $metadata = cargo metadata --format-version 1 --no-deps | ConvertFrom-Json
            if ($metadata.target_directory) {
                return $metadata.target_directory
            }
        } finally {
            Pop-Location
        }
    } catch {
        Write-Warning "Could not resolve Cargo target directory from metadata. Falling back to: $fallback"
    }

    return $fallback
}

function Get-RustGameProjectInfo {
    param([string]$ProjectRoot)

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = (Get-Location).Path
    }

    if (-not (Test-Path $ProjectRoot)) {
        Write-Error "Project directory not found: $ProjectRoot"
        exit 1
    }

    $ProjectRoot = (Get-Item $ProjectRoot).FullName
    $cargoToml = Join-Path $ProjectRoot "Cargo.toml"
    if (-not (Test-Path $cargoToml)) {
        Write-Error "Cargo.toml not found at: $cargoToml"
        exit 1
    }

    $gameSlug = Split-Path $ProjectRoot -Leaf
    $packageRoot = $ProjectRoot
    $packageName = Get-FirstCargoPackageName $cargoToml

    if ([string]::IsNullOrWhiteSpace($packageName)) {
        $clientCargo = Join-Path $ProjectRoot "client\Cargo.toml"
        $clientPackage = Get-FirstCargoPackageName $clientCargo
        if ([string]::IsNullOrWhiteSpace($clientPackage)) {
            Write-Error "Could not find a package name in $cargoToml or client\Cargo.toml"
            exit 1
        }

        $packageName = $clientPackage
        $packageRoot = Join-Path $ProjectRoot "client"
    }

    $wasmFileName = Get-IndexWasmFileName $ProjectRoot $packageName
    $targetDir = Resolve-CargoTargetDir $ProjectRoot

    return [pscustomobject]@{
        ProjectRoot = $ProjectRoot
        PackageRoot = $packageRoot
        GameSlug = $gameSlug
        PackageName = $packageName
        BinaryName = $packageName
        WasmFileName = $wasmFileName
        TargetDir = $targetDir
        DistDir = Join-Path $ProjectRoot "dist"
        RoostSlug = (Get-RustGameRoostSlug -ProjectSlug $null -ProjectName $gameSlug -ProjectDir $ProjectRoot)
    }
}

function Invoke-CargoBuild {
    param(
        [pscustomobject]$Info,
        [string[]]$Arguments,
        [string]$RustFlags
    )

    Push-Location $Info.ProjectRoot
    $previousRustFlags = [Environment]::GetEnvironmentVariable("RUSTFLAGS", "Process")
    try {
        if (-not [string]::IsNullOrWhiteSpace($RustFlags)) {
            if ([string]::IsNullOrWhiteSpace($previousRustFlags)) {
                $env:RUSTFLAGS = $RustFlags
            } else {
                $env:RUSTFLAGS = "$previousRustFlags $RustFlags"
            }
        }

        & cargo @Arguments
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Cargo build failed."
            exit 1
        }
    } finally {
        if ($null -eq $previousRustFlags) {
            Remove-Item Env:RUSTFLAGS -ErrorAction SilentlyContinue
        } else {
            $env:RUSTFLAGS = $previousRustFlags
        }
        Pop-Location
    }
}

function Copy-RustGameAssets {
    param([pscustomobject]$Info, [string]$DestinationDir)

    $assetsPath = Join-Path $Info.ProjectRoot "assets"
    if (Test-Path $assetsPath) {
        Copy-DirectoryClean $assetsPath $DestinationDir "assets"
        Apply-RustGameAssetPacks $Info $DestinationDir
    }
}

function ConvertTo-FtpUri {
    param([hashtable]$Config, [string]$RemotePath)

    $path = $RemotePath.Replace('\', '/')
    if (-not $path.StartsWith('/')) { $path = "/$path" }
    $segments = $path.Split('/') | ForEach-Object {
        if ($_ -eq "") { "" } else { [System.Uri]::EscapeDataString($_) }
    }
    $escapedPath = $segments -join '/'
    return "ftp://$($Config.Server):$($Config.Port)$escapedPath"
}

function New-FtpRequest {
    param([hashtable]$Config, [string]$RemotePath, [string]$Method)

    $ftp = [System.Net.FtpWebRequest]::Create((ConvertTo-FtpUri $Config $RemotePath))
    $ftp.Credentials = New-Object System.Net.NetworkCredential($Config.Username, $Config.Password)
    $ftp.Method = $Method
    $ftp.EnableSsl = [bool]$Config.UseSSL
    $ftp.UsePassive = [bool]$Config.PassiveMode
    $ftp.UseBinary = $true
    $ftp.KeepAlive = $false
    $ftp.Timeout = 30000
    $ftp.ReadWriteTimeout = 30000
    return $ftp
}

function Get-FtpTextFile {
    param([string]$RemotePath, [hashtable]$Config)

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
        $response = $ftp.GetResponse()
        try {
            $responseStream = $response.GetResponseStream()
            if ($null -eq $responseStream) { return $null }
            $reader = [System.IO.StreamReader]::new($responseStream, [System.Text.Encoding]::UTF8)
            try {
                return $reader.ReadToEnd()
            } finally {
                $reader.Close()
            }
        } finally {
            $response.Close()
        }
    } catch {
        return $null
    }
}

function Get-FtpTransferManifest {
    param([string]$RemotePath, [hashtable]$Config)

    $manifestJson = Get-FtpTextFile $RemotePath $Config
    if ([string]::IsNullOrWhiteSpace($manifestJson)) { return $null }

    try {
        return ($manifestJson | ConvertFrom-Json)
    } catch {
        Write-Warning "Could not parse FTP manifest: $RemotePath"
        return $null
    }
}

function Send-ContentToFTP {
    param([string]$Content, [string]$RemotePath, [hashtable]$Config)

    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::UploadFile)
        $ftp.ContentLength = $bytes.Length

        $memoryStream = [System.IO.MemoryStream]::new($bytes)
        try {
            $requestStream = $ftp.GetRequestStream()
            try {
                $memoryStream.CopyTo($requestStream)
            } finally {
                $requestStream.Close()
            }
        } finally {
            $memoryStream.Close()
        }

        $response = $ftp.GetResponse()
        $response.Close()
        return $true
    } catch {
        Write-Warning "Upload failed: $RemotePath ($($_.Exception.Message))"
        return $false
    }
}

function Test-FTPConnection {
    param([hashtable]$Config)

    try {
        $ftp = New-FtpRequest $Config $Config.RemoteRoot ([System.Net.WebRequestMethods+Ftp]::ListDirectory)
        $response = $ftp.GetResponse()
        $response.Close()
        return $true
    } catch {
        Write-Warning "FTP connection failed: $($_.Exception.Message)"
        return $false
    }
}

function New-FtpDirectory {
    param([string]$RemotePath, [hashtable]$Config)

    $path = $RemotePath.Replace('\', '/').TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq "/") { return }

    $current = ""
    foreach ($part in $path.TrimStart('/').Split('/')) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        $current = Join-FtpPath $current $part
        try {
            $ftp = New-FtpRequest $Config $current ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
            $response = $ftp.GetResponse()
            $response.Close()
        } catch {
            # FTP servers report an error when the directory already exists.
        }
    }
}

function Get-FtpParentPath {
    param([string]$RemotePath)

    $path = $RemotePath.Replace('\', '/')
    $index = $path.LastIndexOf('/')
    if ($index -le 0) { return "/" }
    return $path.Substring(0, $index)
}

function Get-FtpFileSize {
    param([string]$RemotePath, [hashtable]$Config)

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::GetFileSize)
        $response = $ftp.GetResponse()
        try {
            if ($response.ContentLength -lt 0) { return $null }
            return [long]$response.ContentLength
        } finally {
            $response.Close()
        }
    } catch {
        return $null
    }
}

function Test-StreamsEqual {
    param([System.IO.Stream]$Left, [System.IO.Stream]$Right)

    $bufferSize = 1048576
    $leftReader = [System.IO.BinaryReader]::new($Left)
    $rightReader = [System.IO.BinaryReader]::new($Right)

    while ($true) {
        $leftBytes = $leftReader.ReadBytes($bufferSize)
        $rightBytes = $rightReader.ReadBytes($bufferSize)

        if ($leftBytes.Length -ne $rightBytes.Length) { return $false }
        if ($leftBytes.Length -eq 0) { return $true }
        if (-not [System.Linq.Enumerable]::SequenceEqual($leftBytes, $rightBytes)) {
            return $false
        }
    }
}

function Test-FtpFileContentEqual {
    param([string]$LocalPath, [string]$RemotePath, [hashtable]$Config)

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
        $response = $ftp.GetResponse()
        try {
            $responseStream = $response.GetResponseStream()
            $fileStream = [System.IO.File]::OpenRead($LocalPath)
            try {
                return (Test-StreamsEqual $fileStream $responseStream)
            } finally {
                $fileStream.Close()
                if ($null -ne $responseStream) { $responseStream.Close() }
            }
        } finally {
            $response.Close()
        }
    } catch {
        return $null
    }
}

function Test-FtpFileIdentical {
    param([string]$LocalPath, [string]$RemotePath, [hashtable]$Config)

    $localFile = Get-Item $LocalPath
    $remoteSize = Get-FtpFileSize $RemotePath $Config
    if ($null -eq $remoteSize -or $remoteSize -ne $localFile.Length) {
        return $false
    }

    if ($localFile.Length -eq 0) {
        return $true
    }

    return (Test-FtpFileContentEqual $LocalPath $RemotePath $Config)
}

function Send-FileToFTP {
    param([string]$LocalPath, [string]$RemotePath, [hashtable]$Config)

    try {
        $file = Get-Item $LocalPath
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::UploadFile)
        $ftp.ContentLength = $file.Length

        $fileStream = [System.IO.File]::OpenRead($LocalPath)
        try {
            $requestStream = $ftp.GetRequestStream()
            try {
                $fileStream.CopyTo($requestStream)
            } finally {
                $requestStream.Close()
            }
        } finally {
            $fileStream.Close()
        }

        $response = $ftp.GetResponse()
        $response.Close()
        return $true
    } catch {
        Write-Warning "Upload failed: $RemotePath ($($_.Exception.Message))"
        return $false
    }
}

function Remove-FtpFileIfExists {
    param([string]$RemotePath, [hashtable]$Config)

    $remoteSize = Get-FtpFileSize $RemotePath $Config
    if ($null -eq $remoteSize) {
        return "missing"
    }

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::DeleteFile)
        $response = $ftp.GetResponse()
        $response.Close()
        return "deleted"
    } catch {
        Write-Warning "Delete failed: $RemotePath ($($_.Exception.Message))"
        return "failed"
    }
}

function Get-FtpDirectoryEntries {
    param([string]$RemotePath, [hashtable]$Config)

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::ListDirectory)
        $response = $ftp.GetResponse()
        try {
            $stream = $response.GetResponseStream()
            if ($null -eq $stream) { return $null }
            $reader = [System.IO.StreamReader]::new($stream)
            try {
                $entries = @()
                while (-not $reader.EndOfStream) {
                    $entry = $reader.ReadLine()
                    if (-not [string]::IsNullOrWhiteSpace($entry)) {
                        $entries += $entry.Trim()
                    }
                }
                return $entries
            } finally {
                $reader.Close()
            }
        } finally {
            $response.Close()
        }
    } catch {
        return $null
    }
}

function Resolve-FtpDirectoryEntryPath {
    param([string]$ParentPath, [string]$Entry)

    if ([string]::IsNullOrWhiteSpace($Entry)) { return $null }

    $parent = $ParentPath.Replace('\', '/').TrimEnd('/')
    $entryPath = $Entry.Replace('\', '/').Trim()
    if ($entryPath -eq "." -or $entryPath -eq "..") { return $null }

    if ($entryPath.StartsWith("$parent/", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $entryPath
    }

    $leaf = ($entryPath -split '/') | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "." -and $_ -ne ".."
    } | Select-Object -Last 1

    if ([string]::IsNullOrWhiteSpace($leaf)) { return $null }
    return Join-FtpPath $parent $leaf
}

function Remove-FtpDirectoryIfExists {
    param([string]$RemotePath, [hashtable]$Config)

    $entries = Get-FtpDirectoryEntries $RemotePath $Config
    if ($null -eq $entries) {
        return [pscustomobject]@{ Status = "missing"; Deleted = 0; Failures = 0 }
    }

    $deleted = 0
    $failures = 0
    foreach ($entry in $entries) {
        $childPath = Resolve-FtpDirectoryEntryPath $RemotePath $entry
        if ([string]::IsNullOrWhiteSpace($childPath)) { continue }
        if ($null -ne (Get-FtpFileSize $childPath $Config)) {
            $deleteResult = Remove-FtpFileIfExists $childPath $Config
            if ($deleteResult -eq "deleted") {
                $deleted++
            } elseif ($deleteResult -eq "failed") {
                $failures++
            }
            continue
        }

        $childResult = Remove-FtpDirectoryIfExists $childPath $Config
        $deleted += [int]$childResult.Deleted
        $failures += [int]$childResult.Failures
    }

    try {
        $ftp = New-FtpRequest $Config $RemotePath ([System.Net.WebRequestMethods+Ftp]::RemoveDirectory)
        $response = $ftp.GetResponse()
        $response.Close()
        return [pscustomobject]@{ Status = "deleted"; Deleted = $deleted; Failures = $failures }
    } catch {
        Write-Warning "Directory delete failed: $RemotePath ($($_.Exception.Message))"
        return [pscustomobject]@{ Status = "failed"; Deleted = $deleted; Failures = ($failures + 1) }
    }
}

function Send-DirectoryToFTP {
    param([string]$LocalPath, [string]$RemotePath, [hashtable]$Config)

    New-FtpDirectory $RemotePath $Config
    $localManifest = New-FtpTransferManifest $LocalPath
    $localManifestMap = ConvertTo-FtpManifestMap $localManifest
    $remoteManifestPath = Join-FtpPath $RemotePath $FtpManifestFileName
    $remoteManifestMap = ConvertTo-FtpManifestMap (Get-FtpTransferManifest $remoteManifestPath $Config)

    $uploaded = 0
    $skipped = 0
    $manifestSkipped = 0
    $failures = 0
    foreach ($file in (Get-ChildItem $LocalPath -Recurse -File)) {
        $relativePath = (Get-RelativePath $LocalPath $file.FullName).Replace('\', '/')
        if ($relativePath -eq $FtpManifestFileName) { continue }

        $remoteFile = Join-FtpPath $RemotePath $relativePath
        New-FtpDirectory (Get-FtpParentPath $remoteFile) $Config

        $localEntry = $localManifestMap[$relativePath]
        if (Test-FtpManifestEntryEqual $localEntry $remoteManifestMap) {
            $skipped++
            $manifestSkipped++
            Write-Host "  Skipped by manifest: $relativePath" -ForegroundColor DarkGray
            continue
        }

        if (Test-FtpFileIdentical $file.FullName $remoteFile $Config) {
            $skipped++
            Write-Host "  Skipped identical: $relativePath" -ForegroundColor DarkGray
            continue
        }

        if (Send-FileToFTP $file.FullName $remoteFile $Config) {
            $uploaded++
            Write-Host "  Uploaded: $relativePath" -ForegroundColor Gray
        } else {
            $failures++
        }
    }

    if ($failures -eq 0) {
        $manifestJson = ConvertTo-FtpTransferManifestJson $localManifest
        if (Send-ContentToFTP $manifestJson $remoteManifestPath $Config) {
            Write-Host "  Uploaded manifest: $FtpManifestFileName" -ForegroundColor DarkGray
        } else {
            $failures++
        }
    }

    $deleted = 0
    if ($failures -eq 0 -and $remoteManifestMap.Count -gt 0) {
        foreach ($remoteRelativePath in @($remoteManifestMap.Keys)) {
            if ($localManifestMap.ContainsKey($remoteRelativePath)) { continue }
            $remoteFile = Join-FtpPath $RemotePath $remoteRelativePath
            $deleteResult = Remove-FtpFileIfExists $remoteFile $Config
            if ($deleteResult -eq "deleted") {
                $deleted++
                Write-Host "  Removed obsolete remote file: $remoteRelativePath" -ForegroundColor Gray
            } elseif ($deleteResult -eq "failed") {
                $failures++
            }
        }
    }

    Write-Host "FTP transfer summary: $uploaded uploaded, $skipped skipped ($manifestSkipped by manifest), $deleted removed, $failures failed" -ForegroundColor Gray
    return ($failures -eq 0)
}

function Get-RustGameFtpConfig {
    $dotEnvConfig = Import-DotEnvFile $EnvFile
    $ftpPortValue = Get-ConfigValue $dotEnvConfig "FTP_PORT" "21"
    $ftpPort = 21
    if (-not [int]::TryParse($ftpPortValue, [ref]$ftpPort)) { $ftpPort = 21 }

    $config = @{
        Server = Get-ConfigValue $dotEnvConfig "FTP_SERVER"
        Username = Get-ConfigValue $dotEnvConfig "FTP_USERNAME"
        Password = Get-ConfigValue $dotEnvConfig "FTP_PASSWORD"
        Port = $ftpPort
        RemoteRoot = Get-ConfigValue $dotEnvConfig "FTP_REMOTE_ROOT" "/"
        UseSSL = Convert-ToBool (Get-ConfigValue $dotEnvConfig "FTP_USE_SSL") $false
        PassiveMode = Convert-ToBool (Get-ConfigValue $dotEnvConfig "FTP_PASSIVE_MODE") $true
    }

    $missingFtpConfig = @()
    if ([string]::IsNullOrWhiteSpace($config.Server)) { $missingFtpConfig += "FTP_SERVER" }
    if ([string]::IsNullOrWhiteSpace($config.Username)) { $missingFtpConfig += "FTP_USERNAME" }
    if ([string]::IsNullOrWhiteSpace($config.Password)) { $missingFtpConfig += "FTP_PASSWORD" }

    if ($missingFtpConfig.Count -gt 0) {
        Write-Error "FTP mode requires these settings in $EnvFile or environment variables: $($missingFtpConfig -join ', ')"
        exit 1
    }

    return $config
}

function Publish-RustGamesCatalogToFtp {
    param([string]$SourceDir, [switch]$DryRun)

    if ([string]::IsNullOrWhiteSpace($SourceDir)) {
        Write-Error "SourceDir is required for RustGames catalog FTP upload."
        exit 1
    }

    if (-not (Test-Path $SourceDir)) {
        if ($DryRun) {
            Write-DryRun "Catalog source directory does not exist yet: $SourceDir"
            Write-DryRun "Would upload RustGames catalog to the configured FTP catalog targets"
            return
        }

        Write-Error "RustGames catalog source directory not found: $SourceDir"
        exit 1
    }

    $catalogUploadEntries = @(
        [pscustomobject]@{ SourceName = "index.html"; RemoteName = "index.php"; Required = $true },
        [pscustomobject]@{ SourceName = "shared.css"; RemoteName = "shared.css"; Required = $false },
        [pscustomobject]@{ SourceName = "bug-report.css"; RemoteName = "bug-report.css"; Required = $false },
        [pscustomobject]@{ SourceName = "bug-report.js"; RemoteName = "bug-report.js"; Required = $false }
    )
    $obsoleteRemoteNames = @("index.html")
    $catalogFiles = @()
    foreach ($entry in $catalogUploadEntries) {
        $filePath = Join-Path $SourceDir $entry.SourceName
        if (Test-Path $filePath -PathType Leaf) {
            $catalogFiles += [pscustomobject]@{
                SourceFile = Get-Item $filePath
                RemoteName = $entry.RemoteName
            }
        } elseif ($entry.Required) {
            Write-Error "RustGames catalog index not found: $filePath"
            exit 1
        }
    }

    $totalBytes = 0L
    foreach ($catalogFile in $catalogFiles) {
        $totalBytes += $catalogFile.SourceFile.Length
    }

    $config = Get-RustGameFtpConfig
    $remoteDirs = @(
        (Join-FtpPath $config.RemoteRoot "games")
    )

    if ($DryRun) {
        foreach ($remoteDir in $remoteDirs) {
            $target = "ftp://$($config.Server):$($config.Port)$remoteDir"
            Write-DryRun "Would upload RustGames catalog to: $target"
        }
        Write-DryRun "Catalog source: $SourceDir"
        Write-DryRun "Files: $($catalogFiles.Count), Size: $(Format-ByteSize $totalBytes)"
        foreach ($obsoleteRemoteName in $obsoleteRemoteNames) {
            Write-DryRun "Would remove obsolete catalog file: $obsoleteRemoteName"
        }
        return
    }

    Write-Host ""
    Write-Host "Uploading games catalog..." -ForegroundColor Yellow
    foreach ($remoteDir in $remoteDirs) {
        $target = "ftp://$($config.Server):$($config.Port)$remoteDir"
        Write-Host "FTP catalog target: $target" -ForegroundColor Magenta
    }
    Write-Host "FTP catalog payload: $($catalogFiles.Count) files, $(Format-ByteSize $totalBytes)" -ForegroundColor Gray

    if (-not (Test-FTPConnection $config)) {
        exit 1
    }

    $uploaded = 0
    $skipped = 0
    $deleted = 0
    $failures = 0

    foreach ($remoteDir in $remoteDirs) {
        $target = "ftp://$($config.Server):$($config.Port)$remoteDir"
        New-FtpDirectory $remoteDir $config
        Write-Host "  Target: $target" -ForegroundColor DarkGray

        foreach ($catalogFile in $catalogFiles) {
            $file = $catalogFile.SourceFile
            $remoteFile = Join-FtpPath $remoteDir $catalogFile.RemoteName
            if (Test-FtpFileIdentical $file.FullName $remoteFile $config) {
                $skipped++
                Write-Host "    Skipped identical: $($catalogFile.RemoteName)" -ForegroundColor DarkGray
                continue
            }

            if (Send-FileToFTP $file.FullName $remoteFile $config) {
                $uploaded++
                Write-Host "    Uploaded: $($catalogFile.RemoteName)" -ForegroundColor Gray
            } else {
                $failures++
            }
        }

        foreach ($obsoleteRemoteName in $obsoleteRemoteNames) {
            $remoteFile = Join-FtpPath $remoteDir $obsoleteRemoteName
            $deleteResult = Remove-FtpFileIfExists $remoteFile $config
            if ($deleteResult -eq "deleted") {
                $deleted++
                Write-Host "    Removed obsolete: $obsoleteRemoteName" -ForegroundColor Gray
            } elseif ($deleteResult -eq "failed") {
                $failures++
            }
        }
    }

    Write-Host "FTP catalog transfer summary: $uploaded uploaded, $skipped skipped, $deleted removed, $failures failed" -ForegroundColor Gray

    if ($failures -eq 0) {
        Write-Host "Uploaded games catalog to FTP target" -ForegroundColor Green
    } else {
        Write-Error "Games catalog FTP upload completed with one or more failed files."
        exit 1
    }
}

function Publish-RustGamesSharedAssetsToFtp {
    param([switch]$DryRun)

    $sourceDir = Sync-RustGamesSharedAssetsSource -DryRun:$DryRun
    $config = Get-RustGameFtpConfig
    $remoteDir = Join-FtpPath $config.RemoteRoot "games/$SharedAssetsDirectoryName"
    $target = "ftp://$($config.Server):$($config.Port)$remoteDir"

    if ($DryRun) {
        Write-DryRun "Would upload RustGames shared assets to: $target"
        if (Test-Path $sourceDir) {
            $uploadStats = Get-TransferStats $sourceDir
            Write-DryRun "Shared assets source: $sourceDir"
            Write-DryRun "Files: $($uploadStats.FileCount), Size: $(Format-ByteSize $uploadStats.TotalBytes)"
        }
        return
    }

    if (-not (Test-Path $sourceDir)) {
        Write-Error "RustGames shared assets source directory not found: $sourceDir"
        exit 1
    }

    $uploadStats = Get-TransferStats $sourceDir
    Write-Host ""
    Write-Host "Uploading RustGames shared assets..." -ForegroundColor Yellow
    Write-Host "FTP shared assets target: $target" -ForegroundColor Magenta
    Write-Host "FTP shared assets payload: $($uploadStats.FileCount) files, $(Format-ByteSize $uploadStats.TotalBytes)" -ForegroundColor Gray

    if (-not (Test-FTPConnection $config)) {
        exit 1
    }

    if (Send-DirectoryToFTP $sourceDir $remoteDir $config) {
        Write-Host "Uploaded RustGames shared assets to FTP target" -ForegroundColor Green
    } else {
        Write-Error "RustGames shared assets FTP upload completed with one or more failed files."
        exit 1
    }
}

function Sync-RustGamesCatalogWebAssetsSource {
    # Refresh the staged copies of the root web assets (shared.css, bug-report.*) in
    # Release/ from their canonical source at the RustGames root, so per-game deploys
    # and FTP catalog uploads always ship the current versions.
    param([switch]$DryRun)

    $releaseDir = Join-Path $WorkspaceRoot "Release"

    foreach ($name in $CatalogWebAssetFileNames) {
        $source = Join-Path (Get-RustGameWebSourceDir) $name
        if (-not (Test-Path $source -PathType Leaf)) { continue }

        if ($DryRun) {
            Write-DryRun "Would refresh catalog web asset in Release: $name"
            continue
        }

        if (-not (Test-Path $releaseDir)) {
            New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
        }

        Copy-Item $source (Join-Path $releaseDir $name) -Force
    }
}

function Sync-RustGamesCatalogToLocalGamesRoot {
    param([string]$SourceDir, [string]$GamesRootDir, [switch]$DryRun)

    if ([string]::IsNullOrWhiteSpace($SourceDir) -or [string]::IsNullOrWhiteSpace($GamesRootDir)) {
        return
    }

    $indexPath = Join-Path $SourceDir "index.html"
    if (-not (Test-Path $indexPath -PathType Leaf)) {
        Write-Warning "RustGames catalog index not found for local games sync: $indexPath"
        return
    }

    $catalogFileNames = $CatalogWebAssetFileNames

    if ($DryRun) {
        Write-DryRun "Would sync RustGames catalog to local games root: $GamesRootDir"
        Write-DryRun "Would remove obsolete local games catalog file: index.html"
        return
    }

    if (-not (Test-Path $GamesRootDir)) {
        New-Item -ItemType Directory -Path $GamesRootDir -Force | Out-Null
    }

    foreach ($fileName in $catalogFileNames) {
        $sourcePath = Join-Path $SourceDir $fileName
        if (Test-Path $sourcePath -PathType Leaf) {
            Copy-Item $sourcePath (Join-Path $GamesRootDir $fileName) -Force
        }
    }

    Copy-Item $indexPath (Join-Path $GamesRootDir "index.php") -Force
    $obsoleteIndexPath = Join-Path $GamesRootDir "index.html"
    if (Test-Path $obsoleteIndexPath -PathType Leaf) {
        Remove-Item -LiteralPath $obsoleteIndexPath -Force
    }

    Write-Host "Catalog synced to local games root: $GamesRootDir" -ForegroundColor Green
}

function Add-TrackingUrl {
    param(
        [System.Collections.Generic.List[string]]$Urls,
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return }

    $normalized = $Url.TrimEnd('/')
    if (-not $Urls.Contains($normalized)) {
        [void]$Urls.Add($normalized)
    }
}

function Get-ProjectRoostTrackingUrls {
    param([string]$Environment = "preview")

    $dotEnvConfig = Import-DotEnvFile $EnvFile
    $urls = New-Object 'System.Collections.Generic.List[string]'
    $isProductionTracker = $Environment -in @("production", "local_production")

    if ($isProductionTracker) {
        Add-TrackingUrl $urls (Get-ConfigValue $dotEnvConfig "PROJECT_ROOST_API_URL_PRODUCTION")
    } else {
        Add-TrackingUrl $urls (Get-ConfigValue $dotEnvConfig "PROJECT_ROOST_API_URL_PREVIEW")
    }

    if ($urls.Count -eq 0) {
        if ($isProductionTracker) {
            Add-TrackingUrl $urls "https://webhatchery.au/project_roost/api/v1"
        } else {
            Add-TrackingUrl $urls "http://127.0.0.1/project_roost/api/v1"
        }
    }

    return $urls.ToArray()
}

function Get-GitCommit {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return $null
    }

    try {
        $commit = git -C $Path rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) {
            return ($commit -as [string]).Trim()
        }
    } catch {
    }

    return $null
}

function Record-ProjectRoostDeployment {
    param(
        [string]$ProjectName,
        [string]$ProjectSlug,
        [string]$ProjectDir,
        [string]$SourceDir,
        [string]$DeployDir,
        [string]$Environment,
        [string]$TargetType,
        [string]$RemotePath,
        [string]$PublishMode,
        [string]$Status,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Error "ProjectName is required for Project Roost deployment tracking."
        exit 1
    }

    $trackingProject = Get-RustGameRoostSlug -ProjectSlug $ProjectSlug -ProjectName $ProjectName -ProjectDir $ProjectDir

    if ($DryRun) {
        Write-DryRun "Would record Project Roost deployment for $trackingProject"
        return
    }

    $dotEnvConfig = Import-DotEnvFile $EnvFile
    $token = Get-ConfigValue $dotEnvConfig "PROJECT_ROOST_PUBLISH_TOKEN"
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "Project Roost publish tracking skipped: PROJECT_ROOST_PUBLISH_TOKEN is not configured" -ForegroundColor Gray
        return
    }

    if ([string]::IsNullOrWhiteSpace($Environment)) { $Environment = "preview" }
    if ([string]::IsNullOrWhiteSpace($TargetType)) { $TargetType = "filesystem" }
    if ([string]::IsNullOrWhiteSpace($PublishMode)) { $PublishMode = $Environment }
    if ([string]::IsNullOrWhiteSpace($Status)) { $Status = "success" }

    $apiUrls = Get-ProjectRoostTrackingUrls -Environment $Environment
    if ($apiUrls.Count -eq 0) {
        Write-Host "Project Roost publish tracking skipped: no API URLs are configured" -ForegroundColor Gray
        return
    }

    $actor = $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($actor)) { $actor = $env:USER }

    $body = @{
        project = $trackingProject
        environment = $Environment
        target_type = $TargetType
        status = $Status
        frontend_deployed = $true
        backend_deployed = $false
        destination_path = $DeployDir
        remote_path = $RemotePath
        source_path = $(if (-not [string]::IsNullOrWhiteSpace($ProjectDir)) { $ProjectDir } else { $SourceDir })
        publish_mode = $PublishMode
        git_commit = (Get-GitCommit $ProjectDir)
        actor = $actor
        deployed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json -Depth 4

    $headers = @{
        "X-Project-Roost-Publish-Token" = $token
    }

    $recorded = 0
    foreach ($apiUrl in $apiUrls) {
        try {
            $result = Invoke-RestMethod -Uri "$apiUrl/deployments/publish" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 10 -ErrorAction Stop
            if ($result.success) {
                $recorded++
            }
        } catch {
            Write-Warning "Project Roost publish tracking failed at ${apiUrl}: $($_.Exception.Message)"
        }
    }

    if ($recorded -gt 0) {
        Write-Host "Project Roost recorded $trackingProject publish to $Environment in $recorded tracker(s)" -ForegroundColor Cyan
    }
}

function Publish-RustGameToFtp {
    param([string]$ProjectName, [string]$ProjectSlug, [string]$ProjectDir, [string]$SourceDir, [switch]$DryRun)

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-Error "ProjectName is required for Rust game FTP upload."
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($SourceDir)) {
        Write-Error "SourceDir is required for Rust game FTP upload."
        exit 1
    }

    $config = Get-RustGameFtpConfig
    $remoteDir = Join-FtpPath $config.RemoteRoot "games/$ProjectName"
    $target = "ftp://$($config.Server):$($config.Port)$remoteDir"

    if (-not (Test-Path $SourceDir)) {
        if ($DryRun) {
            Write-DryRun "Source directory does not exist yet: $SourceDir"
            Write-DryRun "Would upload to: $target"
            Record-ProjectRoostDeployment `
                -ProjectName $ProjectName `
                -ProjectSlug $ProjectSlug `
                -ProjectDir $ProjectDir `
                -SourceDir $SourceDir `
                -DeployDir $null `
                -Environment "production" `
                -TargetType "ftp" `
                -RemotePath $remoteDir `
                -PublishMode "ftp-production" `
                -Status "success" `
                -DryRun:$DryRun
            return
        }

        Write-Error "FTP source directory not found: $SourceDir"
        exit 1
    }

    $uploadStats = Get-TransferStats $SourceDir
    if ($DryRun) {
        Write-DryRun "Would upload to: $target"
        Write-DryRun "Source: $SourceDir"
        Write-DryRun "Files: $($uploadStats.FileCount), Size: $(Format-ByteSize $uploadStats.TotalBytes)"
        Record-ProjectRoostDeployment `
            -ProjectName $ProjectName `
            -ProjectSlug $ProjectSlug `
            -ProjectDir $ProjectDir `
            -SourceDir $SourceDir `
            -DeployDir $null `
            -Environment "production" `
            -TargetType "ftp" `
            -RemotePath $remoteDir `
            -PublishMode "ftp-production" `
            -Status "success" `
            -DryRun:$DryRun
        return
    }

    Write-Host "FTP target: $target" -ForegroundColor Magenta
    Write-Host "FTP payload: $($uploadStats.FileCount) files, $(Format-ByteSize $uploadStats.TotalBytes)" -ForegroundColor Gray

    if (-not (Test-FTPConnection $config)) {
        exit 1
    }

    if (Send-DirectoryToFTP $SourceDir $remoteDir $config) {
        if (-not (Remove-RustGameObsoleteRemoteSharedFiles $remoteDir $config)) {
            Write-Error "FTP upload completed, but obsolete shared file cleanup failed."
            exit 1
        }
        if (-not (Remove-RustGameObsoleteRemoteAssetPackSources $remoteDir $ProjectDir $SourceDir $config)) {
            Write-Error "FTP upload completed, but obsolete packed asset cleanup failed."
            exit 1
        }

        Write-Host "Uploaded to: $target" -ForegroundColor Green
        Record-ProjectRoostDeployment `
            -ProjectName $ProjectName `
            -ProjectSlug $ProjectSlug `
            -ProjectDir $ProjectDir `
            -SourceDir $SourceDir `
            -DeployDir $null `
            -Environment "production" `
            -TargetType "ftp" `
            -RemotePath $remoteDir `
            -PublishMode "ftp-production" `
            -Status "success" `
            -DryRun:$DryRun
    } else {
        Write-Error "FTP upload completed with one or more failed files."
        exit 1
    }
}

function Remove-RustGameObsoleteRemoteAssetPackSources {
    param([string]$RemoteDir, [string]$ProjectDir, [string]$SourceDir, [hashtable]$Config)

    $packs = Get-RustGameAssetPackConfig $ProjectDir
    if ($packs.Count -eq 0) { return $true }

    $deleted = 0
    $failures = 0
    foreach ($pack in $packs) {
        $deleteSourceValue = Get-OptionalPropertyValue $pack @("delete_source", "deleteSource", "DeleteSource") $true
        if (-not (Convert-ToBool $deleteSourceValue $true)) { continue }

        $sourceRel = Get-OptionalPropertyValue $pack @("source", "Source")
        if ([string]::IsNullOrWhiteSpace($sourceRel)) { continue }
        $sourceRel = $sourceRel.ToString().Replace('\', '/').Trim('/')

        $sourcePath = Join-Path $SourceDir ($sourceRel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (Test-Path $sourcePath) { continue }

        $remoteSourcePath = Join-FtpPath $RemoteDir $sourceRel
        $result = Remove-FtpDirectoryIfExists $remoteSourcePath $Config
        if ($result.Status -eq "deleted") {
            $deleted += [int]$result.Deleted
            Write-Host "  Removed obsolete remote packed source: $sourceRel/" -ForegroundColor Gray
        } elseif ($result.Status -eq "failed") {
            $failures += [int]$result.Failures
        }
    }

    if ($deleted -gt 0 -or $failures -gt 0) {
        Write-Host "FTP obsolete packed asset cleanup: $deleted file(s) removed, $failures failure(s)" -ForegroundColor Gray
    }

    return ($failures -eq 0)
}

function Remove-RustGameObsoleteRemoteSharedFiles {
    param([string]$RemoteDir, [hashtable]$Config)

    $obsoletePaths = @(
        "shared.css",
        "mq_js_bundle.js",
        "sapp_jsutils.js",
        "assets/fonts/$RajdhaniSemiBoldFileName"
    )

    $deleted = 0
    $failures = 0
    foreach ($relativePath in $obsoletePaths) {
        $remoteFile = Join-FtpPath $RemoteDir $relativePath
        $deleteResult = Remove-FtpFileIfExists $remoteFile $Config
        if ($deleteResult -eq "deleted") {
            $deleted++
            Write-Host "  Removed obsolete shared copy: $relativePath" -ForegroundColor Gray
        } elseif ($deleteResult -eq "failed") {
            $failures++
        }
    }

    if ($deleted -gt 0 -or $failures -gt 0) {
        Write-Host "FTP obsolete shared cleanup: $deleted removed, $failures failed" -ForegroundColor Gray
    }

    return ($failures -eq 0)
}

function Publish-RustGameProject {
    param(
        [string]$ProjectDir,
        [switch]$SkipBuild,
        [switch]$WindowsOnly,
        [switch]$WebGLOnly,
        [switch]$DeployOnly,
        [switch]$Production,
        [switch]$FTP,
        [switch]$SkipFtpCatalog,
        [switch]$SkipFtpSharedAssets,
        [switch]$DryRun
    )

    if ($FTP) { $Production = $true }

    $info = Get-RustGameProjectInfo $ProjectDir
    $title = ($info.GameSlug -replace '_', ' ').ToUpperInvariant()
    $buildWindows = -not $WebGLOnly -and -not $DeployOnly
    $buildWebGL = -not $WindowsOnly -and -not $DeployOnly

    $dotEnvConfig = Import-DotEnvFile $EnvFile
    $previewRoot = Get-ConfigValue $dotEnvConfig "PREVIEW_ROOT" "D:\xampp\htdocs"
    $productionRoot = Get-ConfigValue $dotEnvConfig "PRODUCTION_ROOT" "D:\WebHatcheryProduction"
    $deployRoot = $(if ($Production) { $productionRoot } else { $previewRoot })
    $environmentLabel = $(if ($Production) { "Production" } else { "Preview" })
    $deployDir = Join-Path $deployRoot "games\$($info.GameSlug)"

    $totalSteps = 1
    if ($buildWindows) { $totalSteps += 2 }
    if ($buildWebGL) { $totalSteps += 2 }
    if ($FTP) { $totalSteps += 1 }
    $currentStep = 0

    Write-Host "=== $title Publisher ===" -ForegroundColor Cyan
    Write-Host "Game: $($info.GameSlug)"
    Write-Host "Package: $($info.PackageName)"
    Write-Host "Project Roost slug: $($info.RoostSlug)"
    Write-Host "Target: $environmentLabel -> $deployDir"
    Write-Host ""

    if (-not (Test-Path $info.DistDir)) {
        New-Item -ItemType Directory -Path $info.DistDir -Force | Out-Null
    }

    if ($buildWindows) {
        $currentStep++
        if (-not $SkipBuild) {
            Write-Host "[$currentStep/$totalSteps] Building Windows release..." -ForegroundColor Yellow
            Invoke-CargoBuild $info @("build", "--release", "-p", $info.PackageName, "--bin", $info.BinaryName)
            Write-Host "Windows build complete!" -ForegroundColor Green
        } else {
            Write-Host "[$currentStep/$totalSteps] Skipping Windows build" -ForegroundColor Gray
        }

        $currentStep++
        Write-Host "[$currentStep/$totalSteps] Packaging Windows build..." -ForegroundColor Yellow
        $windowsPackageDir = Join-Path $info.DistDir "windows"
        Remove-ChildDirectory $info.DistDir $windowsPackageDir
        New-Item -ItemType Directory -Path $windowsPackageDir -Force | Out-Null

        $exePath = Join-Path $info.TargetDir "release\$($info.BinaryName).exe"
        if (-not (Test-Path $exePath)) {
            Write-Error "Executable not found: $exePath"
            exit 1
        }

        Copy-Item $exePath $windowsPackageDir -Force
        Copy-RustGameAssets $info $windowsPackageDir
        Remove-RustGameSharedFontDuplicate $windowsPackageDir

        $windowsZipPath = Join-Path $info.DistDir (Get-WindowsZipFileName $info)
        if (Test-Path $windowsZipPath) { Remove-Item $windowsZipPath -Force }
        Compress-Archive -Path "$windowsPackageDir\*" -DestinationPath $windowsZipPath -CompressionLevel Optimal
        Write-Host "Windows package created!" -ForegroundColor Green
    }

    if ($buildWebGL) {
        $currentStep++
        if (-not $SkipBuild) {
            Write-Host "[$currentStep/$totalSteps] Building WebGL release..." -ForegroundColor Yellow
            $targets = rustup target list --installed
            if ($targets -notcontains "wasm32-unknown-unknown") {
                rustup target add wasm32-unknown-unknown
                if ($LASTEXITCODE -ne 0) { Write-Error "Could not install wasm32-unknown-unknown target."; exit 1 }
            }

            Invoke-CargoBuild $info @("build", "--release", "--target", "wasm32-unknown-unknown", "-p", $info.PackageName, "--bin", $info.BinaryName) "-C link-arg=--allow-undefined"

            if ($info.GameSlug -eq "nanite_swarm") {
                $wasmOpt = Get-Command wasm-opt -ErrorAction SilentlyContinue
                if ($wasmOpt) {
                    $naniteWasmPath = Join-Path $info.TargetDir "wasm32-unknown-unknown\release\$($info.BinaryName).wasm"
                    Write-Host "Optimizing WASM with wasm-opt -Oz..." -ForegroundColor Yellow
                    wasm-opt -Oz -o $naniteWasmPath $naniteWasmPath
                    if ($LASTEXITCODE -ne 0) { Write-Error "wasm-opt failed."; exit 1 }
                }
            }

            Write-Host "WebGL build complete!" -ForegroundColor Green
        } else {
            Write-Host "[$currentStep/$totalSteps] Skipping WebGL build" -ForegroundColor Gray
        }

        $currentStep++
        Write-Host "[$currentStep/$totalSteps] Packaging WebGL build..." -ForegroundColor Yellow
        $webGLPackageDir = Join-Path $info.DistDir "webgl"
        Remove-ChildDirectory $info.DistDir $webGLPackageDir
        New-Item -ItemType Directory -Path $webGLPackageDir -Force | Out-Null

        $wasmPath = Join-Path $info.TargetDir "wasm32-unknown-unknown\release\$($info.BinaryName).wasm"
        if (-not (Test-Path $wasmPath)) {
            $underscoreName = $info.BinaryName -replace '-', '_'
            $wasmPath = Join-Path $info.TargetDir "wasm32-unknown-unknown\release\$underscoreName.wasm"
        }
        if (-not (Test-Path $wasmPath)) {
            Write-Error "WASM not found for $($info.BinaryName) in $($info.TargetDir)"
            exit 1
        }

        Copy-Item $wasmPath (Join-Path $webGLPackageDir $info.WasmFileName) -Force
        if ($info.WasmFileName -ne "$($info.BinaryName).wasm") {
            Copy-Item $wasmPath (Join-Path $webGLPackageDir "$($info.BinaryName).wasm") -Force
        }

        # index.html is generated from web/index.template.html + game_page.json;
        # a hand-written index.html is only a fallback for unmigrated games.
        if (-not (New-RustGameIndexHtml -Info $info -DestinationPath (Join-Path $webGLPackageDir "index.html"))) {
            $indexPath = Join-Path $info.ProjectRoot "index.html"
            if (Test-Path $indexPath) {
                Copy-Item $indexPath $webGLPackageDir -Force
            } else {
                Write-Warning "No game_page.json and no index.html for $($info.GameSlug); the game will have no web page."
            }
        }

        Copy-RustGameAssets $info $webGLPackageDir
        Remove-RustGameSharedFontDuplicate $webGLPackageDir

        $storagePath = Join-Path $info.ProjectRoot "storage.js"
        if (Test-Path $storagePath) {
            Copy-Item $storagePath $webGLPackageDir -Force
        }

        Get-ChildItem -Path $info.DistDir -Filter "*_windows.zip" -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName $webGLPackageDir -Force
        }

        Sync-RustGameCatalogThumbnail -Info $info -DestinationDir $webGLPackageDir -DryRun:$DryRun | Out-Null

        Update-PackagedIndexPaths (Join-Path $webGLPackageDir "index.html")

        $webGLZipPath = Join-Path $info.DistDir "$($info.GameSlug)_webgl.zip"
        if (Test-Path $webGLZipPath) { Remove-Item $webGLZipPath -Force }
        Compress-Archive -Path "$webGLPackageDir\*" -DestinationPath $webGLZipPath -CompressionLevel Optimal
        Write-Host "WebGL package created!" -ForegroundColor Green
    }

    $currentStep++
    Write-Host ""
    Write-Host "[$currentStep/$totalSteps] Deploying to $environmentLabel..." -ForegroundColor Yellow

    $webGLSourceDir = Join-Path $info.DistDir "webgl"
    if ($DryRun) {
        Write-DryRun "Would deploy to: $deployDir"
        Sync-RustGamesSharedAssetsToLocalGamesRoot `
            -GamesRootDir (Join-Path $deployRoot "games") `
            -DryRun:$DryRun
    } else {
        if (-not (Test-Path $deployDir)) {
            New-Item -ItemType Directory -Path $deployDir -Force | Out-Null
        }

        Sync-RustGamesSharedAssetsToLocalGamesRoot `
            -GamesRootDir (Join-Path $deployRoot "games") `
            -DryRun:$DryRun

        Remove-RustGameObsoleteLocalSharedFiles $deployDir

        if (Test-Path $webGLSourceDir) {
            Get-ChildItem $webGLSourceDir -File | ForEach-Object {
                if ($_.Name -notin @("shared.css", "mq_js_bundle.js", "sapp_jsutils.js")) {
                    Copy-Item $_.FullName $deployDir -Force
                    Write-Host "  Copied: $($_.Name)" -ForegroundColor Gray
                }
            }

            $assetsDir = Join-Path $webGLSourceDir "assets"
            if (Test-Path $assetsDir) {
                Copy-DirectoryClean $assetsDir $deployDir "assets"
                Write-Host "  Copied: assets/" -ForegroundColor Gray
            }

            Remove-RustGameObsoleteLocalAssetPackSources $info $deployDir $webGLSourceDir
            Remove-RustGameSharedFontDuplicate $deployDir
            Update-PackagedIndexPaths (Join-Path $deployDir "index.html")
            Sync-RustGameCatalogThumbnail -Info $info -DestinationDir $deployDir -DryRun:$DryRun | Out-Null
        } else {
            Write-Warning "WebGL package directory not found: $webGLSourceDir"
        }

        Write-Host "Deployed to: $deployDir" -ForegroundColor Green
    }

    $roostEnvironment = $(if ($Production) { "local_production" } else { "preview" })
    $roostPublishMode = $(if ($Production) { "local-production" } else { "preview" })
    Record-ProjectRoostDeployment `
        -ProjectName $info.GameSlug `
        -ProjectSlug $info.RoostSlug `
        -ProjectDir $info.ProjectRoot `
        -SourceDir $webGLSourceDir `
        -DeployDir $deployDir `
        -Environment $roostEnvironment `
        -TargetType "filesystem" `
        -PublishMode $roostPublishMode `
        -Status "success" `
        -DryRun:$DryRun

    $releaseCatalogDir = Join-Path $WorkspaceRoot "Release"
    Sync-RustGamesCatalogWebAssetsSource -DryRun:$DryRun
    $releaseCatalogPath = Join-Path $releaseCatalogDir "index.html"
    $catalogIndexTargets = @()
    $catalogIndexTargets += $releaseCatalogPath

    $releaseCatalogUpdated = $false
    foreach ($targetPath in $catalogIndexTargets) {
        $catalogUpdated = Update-RustGamesCatalogIndex `
            -Info $info `
            -CatalogIndexPath $targetPath `
            -DryRun:$DryRun
        if ($targetPath -ieq $releaseCatalogPath) {
            $releaseCatalogUpdated = [bool]$catalogUpdated
        }
    }

    if ($releaseCatalogUpdated) {
        Sync-RustGamesCatalogToLocalGamesRoot `
            -SourceDir $releaseCatalogDir `
            -GamesRootDir (Join-Path $deployRoot "games") `
            -DryRun:$DryRun
    }

    if ($FTP) {
        $currentStep++
        Write-Host ""
        Write-Host "[$currentStep/$totalSteps] Uploading to FTP..." -ForegroundColor Yellow

        $ftpSourceDir = $deployDir
        if ($DryRun -and (Test-Path $webGLSourceDir)) {
            $ftpSourceDir = $webGLSourceDir
        }

        if (-not $SkipFtpSharedAssets) {
            Publish-RustGamesSharedAssetsToFtp -DryRun:$DryRun
        }

        Publish-RustGameToFtp `
            -ProjectName $info.GameSlug `
            -ProjectSlug $info.RoostSlug `
            -ProjectDir $info.ProjectRoot `
            -SourceDir $ftpSourceDir `
            -DryRun:$DryRun

        if (-not $SkipFtpCatalog) {
            if (-not $releaseCatalogUpdated) {
                Write-Error "RustGames release catalog was not updated; refusing to upload a stale catalog."
                exit 1
            }

            Publish-RustGamesCatalogToFtp `
                -SourceDir $releaseCatalogDir `
                -DryRun:$DryRun
        }
    }

    Write-Host ""
    Write-Host "=== Complete ===" -ForegroundColor Cyan
    Write-Host "Deploy: $deployDir" -ForegroundColor Green
    Write-Host ""
    Write-Host "Options: -SkipBuild, -WebGLOnly, -WindowsOnly, -DeployOnly, -Production (-p), -FTP, -DryRun" -ForegroundColor Yellow
}

if ($Help -or (-not $RustGamePublish -and -not $RustGameFtpUpload -and -not $RustGameRecordDeployment -and -not $RustGamesSharedAssetsFtpUpload -and -not $RustGamesCatalogFtpUpload)) {
    Write-Host "Usage:"
    Write-Host "  .\publish.ps1 -RustGamePublish -ProjectDir <path> [-SkipBuild] [-WebGLOnly] [-WindowsOnly] [-DeployOnly] [-Production|-p] [-FTP] [-SkipFtpSharedAssets] [-SkipFtpCatalog] [-DryRun]"
    Write-Host "  .\publish.ps1 -RustGameFtpUpload -ProjectName <name> -SourceDir <path> [-ProjectDir <path>] [-DryRun]"
    Write-Host "  .\publish.ps1 -RustGamesSharedAssetsFtpUpload [-DryRun]"
    Write-Host "  .\publish.ps1 -RustGamesCatalogFtpUpload [-DryRun]"
    Write-Host "  .\publish.ps1 -RustGameRecordDeployment -ProjectName <name> [-ProjectSlug <slug>] -ProjectDir <path> -SourceDir <path> -DeployDir <path> -Environment <preview|local_production|production> [-DryRun]"
    exit 0
}

if ($RustGamesSharedAssetsFtpUpload) {
    Publish-RustGamesSharedAssetsToFtp -DryRun:$DryRun
    exit 0
}

if ($RustGamesCatalogFtpUpload) {
    Publish-RustGamesCatalogToFtp `
        -SourceDir (Join-Path $WorkspaceRoot "Release") `
        -DryRun:$DryRun
    exit 0
}

if ($RustGamePublish) {
    Publish-RustGameProject `
        -ProjectDir $ProjectDir `
        -SkipBuild:$SkipBuild `
        -WindowsOnly:$WindowsOnly `
        -WebGLOnly:$WebGLOnly `
        -DeployOnly:$DeployOnly `
        -Production:$Production `
        -FTP:$FTP `
        -SkipFtpCatalog:$SkipFtpCatalog `
        -SkipFtpSharedAssets:$SkipFtpSharedAssets `
        -DryRun:$DryRun
    exit 0
}

if ($RustGameRecordDeployment) {
    Record-ProjectRoostDeployment `
        -ProjectName $ProjectName `
        -ProjectSlug $ProjectSlug `
        -ProjectDir $ProjectDir `
        -SourceDir $SourceDir `
        -DeployDir $DeployDir `
        -Environment $Environment `
        -TargetType $TargetType `
        -RemotePath $RemotePath `
        -PublishMode $PublishMode `
        -Status $Status `
        -DryRun:$DryRun
}

if ($RustGameFtpUpload) {
    Publish-RustGameToFtp -ProjectName $ProjectName -ProjectSlug $ProjectSlug -ProjectDir $ProjectDir -SourceDir $SourceDir -DryRun:$DryRun
}
