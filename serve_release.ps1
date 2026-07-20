# Simple HTTP Server for Release Preview
# This script lives in rust_management/; Release/ is in its parent.
$releaseDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Release"

if (-not (Test-Path $releaseDir)) {
    Write-Error "Release directory not found! Run build_all_webgl.ps1 first."
    exit 1
}

Write-Host "Starting local server for Web Hatchery Games..." -ForegroundColor Cyan
Write-Host "Serving: $releaseDir"
Write-Host "URL:     http://localhost:8000" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop."
Write-Host ""

# Push to release dir and start python server
Push-Location $releaseDir
try {
    python -m http.server 8000
} catch {
    Write-Warning "Python not found or failed. Trying python3..."
    try {
        python3 -m http.server 8000
    } catch {
        Write-Error "Could not start server. Please ensure Python is installed."
    }
}
Pop-Location
