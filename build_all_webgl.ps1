# This script lives in rust_management/; the games and Release/ are in its parent.
$ManagementRoot = $PSScriptRoot
$rootDir = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $rootDir "Release"
$excludedFolders = @("Release", "template", "target", "assets", "macroquad-toolkit")
$projects = Get-ChildItem -Path $rootDir -Directory |
    Where-Object {
        $excludedFolders -notcontains $_.Name -and
        (Test-Path (Join-Path $_.FullName "publish.ps1")) -and
        (Test-Path (Join-Path $_.FullName "index.html"))
    } |
    Sort-Object Name |
    Select-Object -ExpandProperty Name

Write-Host "=== Starting Batch WebGL Build ===" -ForegroundColor Cyan
Write-Host "Output Directory: $releaseDir"
Write-Host ""

# Clean release directory
if (Test-Path $releaseDir) {
    Write-Host "Cleaning old release directory..." -ForegroundColor Gray
    Remove-Item $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

# Copy shared front-end assets (stylesheet + bug-report widget) referenced by each
# game's index.html as ../<asset>.
$sharedAssets = @("shared.css", "bug-report.css", "bug-report.js")
foreach ($asset in $sharedAssets) {
    $assetPath = Join-Path (Join-Path $ManagementRoot "web") $asset
    if (Test-Path $assetPath) {
        Copy-Item $assetPath -Destination $releaseDir -Force
        Write-Host "Copied $asset" -ForegroundColor Green
    } else {
        Write-Warning "$asset not found in root"
    }
}

foreach ($proj in $projects) {
    Write-Host "Processing: $proj" -ForegroundColor Magenta
    $projDir = Join-Path $rootDir $proj
    
    if (-not (Test-Path $projDir)) {
        Write-Warning "Project directory not found: $projDir"
        continue
    }


    # Run publish script
    Push-Location $projDir
    if (Test-Path ".\publish.ps1") {
        Write-Host "  Building WebGL and Windows..." -ForegroundColor Yellow
        # Run the publish script to build artifacts (Both WebGL and Windows by default)
        powershell -ExecutionPolicy Bypass -File .\publish.ps1
        
        if ($LASTEXITCODE -eq 0) {
            # Create project release folder
            $destDir = Join-Path $releaseDir $proj
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            
            # Copy dist/webgl contents (wasm, js, assets)
            $distWebgl = Join-Path $projDir "dist\webgl"
            
            if (Test-Path $distWebgl) {
                Copy-Item "$distWebgl\*" -Destination $destDir -Recurse -Force
                Write-Host "  Copied WebGL artifacts." -ForegroundColor Green
            } else {
                Write-Warning "  dist/webgl not found for $proj"
            }
            
            # Copy Windows Zip (created by publish.ps1)
            $distDir = Join-Path $projDir "dist"
            $zipFiles = Get-ChildItem -Path $distDir -Filter "*_windows.zip" -ErrorAction SilentlyContinue
            
            if ($zipFiles) {
                # There should be only one, but take the first just in case
                $zipFile = $zipFiles[0]
                Copy-Item $zipFile.FullName -Destination $destDir -Force
                Write-Host "  Copied Windows zip: $($zipFile.Name)" -ForegroundColor Green
            } else {
                Write-Warning "  Windows zip not found in $distDir (Did you build Release?)"
            }

        } else {
            Write-Error "  Build failed for $proj"
        }
    } else {
        Write-Warning "  publish.ps1 not found in $proj"
    }
    Pop-Location
    Write-Host ""
}

# Generate Index HTML
Write-Host "Generating Release Index..." -ForegroundColor Cyan
$indexContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebHatchery Games (Release)</title>
    <link rel="stylesheet" href="shared.css">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #1a1a1a; color: #f0f0f0; margin: 0; padding: 20px; text-align: center; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { margin-bottom: 40px; color: #4caf50; font-size: 3em; text-shadow: 2px 2px 4px rgba(0,0,0,0.5); }
        .game-list { display: flex; flex-wrap: wrap; justify-content: center; gap: 20px; }
        .game-card { background: #2d2d2d; border-radius: 10px; padding: 20px; width: 250px; transition: transform 0.2s, box-shadow 0.2s; box-shadow: 0 4px 6px rgba(0,0,0,0.3); border: 1px solid #333; display: flex; flex-direction: column; align-items: center; }
        .game-card:hover { transform: translateY(-5px); box-shadow: 0 8px 12px rgba(0,0,0,0.5); border-color: #4caf50; }
        .game-title { font-size: 1.5em; margin-bottom: 15px; color: #fff; text-transform: capitalize; }
        .play-btn { display: inline-block; padding: 10px 25px; background-color: #4caf50; color: white; text-decoration: none; border-radius: 5px; font-weight: bold; transition: background-color 0.2s; margin-bottom: 10px; width: 80%; }
        .play-btn:hover { background-color: #45a049; }
        .download-link { color: #888; font-size: 0.9em; text-decoration: none; margin-top: 5px; }
        .download-link:hover { color: #fff; text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>WebHatchery Games</h1>
        <div class="game-list">
"@

foreach ($proj in $projects) {
    if (Test-Path "$releaseDir\$proj\index.html") {
        $exeLink = ""
        $displayName = $proj.Replace('_', ' ')
        
        # Look for the copied zip in the destination folder
        $projDest = "$releaseDir\$proj"
        $zipFiles = Get-ChildItem -Path $projDest -Filter "*_windows.zip" -ErrorAction SilentlyContinue
        
        if ($zipFiles) {
            $zipName = $zipFiles[0].Name
            $exeLink = "<a href=`"$proj/$zipName`" class=`"download-link`" download>Download for Windows (.zip)</a>"
        }

        $gameIndex = Join-Path $projDest "index.html"
        if (Test-Path $gameIndex) {
            $indexHtml = Get-Content $gameIndex -Raw -Encoding UTF8
            if ($indexHtml -match '<title>([^<|]+)') {
                $displayName = $matches[1].Trim()
            }
        }

        $indexContent += @"
            <div class="game-card">
                <div class="game-title">$displayName</div>
                <a href="$proj/index.html" class="play-btn">Play in Browser</a>
                $exeLink
            </div>
"@
    }
}

$indexContent += @"
        </div>
    </div>
    <!-- Ko-fi support widget (https://ko-fi.com/webhatchery) -->
    <script src='https://storage.ko-fi.com/cdn/scripts/overlay-widget.js'></script>
    <script>
        kofiWidgetOverlay.draw('webhatchery', {
            'type': 'floating-chat',
            'floating-chat.donateButton.text': 'Support me',
            'floating-chat.donateButton.background-color': '#00b9fe',
            'floating-chat.donateButton.text-color': '#fff'
        });
    </script>
</body>
</html>
"@

$indexContent | Out-File (Join-Path $releaseDir "index.html") -Encoding UTF8
Write-Host "Index generated." -ForegroundColor Green

Write-Host "=== Batch Build Complete ===" -ForegroundColor Cyan
Write-Host "Builds available in: $releaseDir" -ForegroundColor Green
