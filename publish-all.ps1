# publish-all-prod.ps1
# Runs publish.ps1 -p in every child folder under this workspace root.

# This script lives in rust_management/ (alongside publish.ps1); the games live
# in its parent, which is the Cargo workspace root.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptDir
$excludedFolders = @('template', 'target', 'assets', 'macroquad-toolkit', 'rust_management', 'Release', 'publish-logs')

Get-ChildItem -Path $workspaceRoot -Directory | ForEach-Object {
    if ($excludedFolders -contains $_.Name) {
        Write-Host "Skipping excluded folder: $($_.Name)" -ForegroundColor DarkGray
        return
    }

    $subDir = $_.FullName
    $publishScript = Join-Path $subDir 'publish.ps1'

    if (Test-Path $publishScript) {
        Write-Host "=== Publishing: $($_.Name) ===" -ForegroundColor Cyan
        Push-Location $subDir
        try {
            & $publishScript 
        }
        catch {
            Write-Host "ERROR publishing $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "Skipping $($_.Name): no publish.ps1" -ForegroundColor DarkGray
    }
}
