# Refresh existing local page artifacts without rebuilding games or uploading.
# In particular, retain the WASM already staged for itch (which may be a demo).
param([string[]]$Project = @())

$ErrorActionPreference = 'Stop'
$management = Split-Path $PSScriptRoot -Parent
. (Join-Path $management 'publish.ps1') -Help *> $null
. (Join-Path $management 'publish-itch.ps1') -Help *> $null
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projects = @(Get-ChildItem $WorkspaceRoot -Directory | Where-Object {
    (Test-Path (Join-Path $_.FullName 'game_page.json')) -and
    ($Project.Count -eq 0 -or $_.Name -in $Project)
})
foreach ($name in $Project) {
    if ($name -notin $projects.Name) { throw "Unknown game: $name" }
}
$updated = 0
foreach ($game in $projects) {
    $page = Get-RustGamePageData $game.FullName
    if ($null -eq $page) { throw "Invalid game_page.json: $($game.Name)" }
    $info = [pscustomobject]@{
        ProjectRoot = $game.FullName; GameSlug = $game.Name; ProjectSlug = $game.Name
        WasmFileName = (Get-IndexWasmFileName $game.FullName $game.Name)
    }
    foreach ($folder in @((Join-Path $game.FullName 'dist/webgl'), (Join-Path $WorkspaceRoot "Release/$($game.Name)"))) {
        if (-not (Test-Path (Join-Path $folder 'index.html'))) { continue }
        $index = Join-Path $folder 'index.html'
        if (-not (New-RustGameIndexHtml $info $index)) { throw "Could not render $index" }
        Update-PackagedIndexPaths $index
        $updated++
    }
    $webIndex = Join-Path $game.FullName 'dist/webgl/index.html'
    $archives = @(Get-ChildItem (Join-Path $game.FullName 'dist') -Filter '*_webgl.zip' -File -ErrorAction SilentlyContinue)
    if (Test-Path $webIndex) {
        foreach ($archive in $archives) {
            $zip = [System.IO.Compression.ZipFile]::Open($archive.FullName, [System.IO.Compression.ZipArchiveMode]::Update)
            try {
                $entry = $zip.GetEntry('index.html')
                if ($null -ne $entry) { $entry.Delete() }
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $webIndex, 'index.html') | Out-Null
            } finally { $zip.Dispose() }
        }
    }
    $itch = Join-Path $game.FullName 'dist/itch-webgl'
    if (Test-Path (Join-Path $itch 'index.html')) {
        Update-ItchHtml5Shell -Info $info -PackageDir $itch
        $updated++
    }
    Write-Host "Refreshed $($game.Name)"
}
$release = Join-Path $WorkspaceRoot 'Release'
if (Test-Path $release) {
    foreach ($asset in @('shared.css', 'bug-report.css', 'bug-report.js')) {
        Copy-Item (Join-Path $management "web/$asset") $release -Force
    }
}
Write-Host "Updated $updated local pages across $($projects.Count) games. No builds or uploads."
