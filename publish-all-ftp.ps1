# publish-all-ftp.ps1
# Publishes shared assets once, runs each child game FTP publish, then uploads the catalog once.
#
# Always writes a full transcript to publish-logs\publish-all-ftp_<timestamp>.log
# for after-the-fact review; the path is printed at the start and the end.

param(
    [switch]$SkipBuild = $false,
    [switch]$DryRun = $false
)

# Compress-Archive progress records are noisy inside the transcript's project
# pipeline and can be recorded as false "pipeline stopped" errors.
$ProgressPreference = "SilentlyContinue"

# This script lives in rust_management/ (alongside publish.ps1); the games,
# Release/ and publish-logs/ live in its parent, the Cargo workspace root.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptDir
$excludedFolders = @('template', 'target', 'assets', 'macroquad-toolkit', 'web', 'docs', 'Release', 'archive', 'publish-logs', 'scripts', 'title_screeshots', 'rust_management')
$rootPublisher = Join-Path $scriptDir 'publish.ps1'
$failedProjects = @()
$publishedProjects = @()
$skippedProjects = @()
$exitCode = 0

# --- transcript ----------------------------------------------------------
$logDir = Join-Path $workspaceRoot 'publish-logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir ("publish-all-ftp_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'))

$transcribing = $false
try {
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcribing = $true
} catch {
    Write-Warning "Could not start transcript ($($_.Exception.Message)); continuing without a log file."
}

Write-Host "Log file: $logPath" -ForegroundColor DarkCyan
Write-Host "Started:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkCyan
if ($DryRun) { Write-Host "Mode:     DRY RUN (nothing is uploaded)" -ForegroundColor DarkYellow }
Write-Host ""

try {
    Write-Host "=== Publishing shared RustGames assets ===" -ForegroundColor Cyan
    & $rootPublisher -RustGamesSharedAssetsFtpUpload -DryRun:$DryRun
    $sharedAssetsSucceeded = $?
    if (-not $sharedAssetsSucceeded) {
        Write-Host "ERROR publishing shared RustGames assets" -ForegroundColor Red
        $exitCode = 1
        return
    }

    Get-ChildItem -Path $workspaceRoot -Directory | ForEach-Object {
        # Capture the name now: inside catch, $_ is the ErrorRecord, not this directory.
        $projectName = $_.Name
        $subDir = $_.FullName

        if ($excludedFolders -contains $projectName) {
            Write-Host "Skipping excluded folder: $projectName" -ForegroundColor DarkGray
            return
        }

        # Tooling/config directories (.cargo, .claude, .vscode, ...) are not games.
        if ($projectName.StartsWith('.')) { return }

        $publishScript = Join-Path $subDir 'publish.ps1'
        if (-not (Test-Path $publishScript)) {
            Write-Host "Skipping ${projectName}: no publish.ps1" -ForegroundColor DarkGray
            $skippedProjects += $projectName
            return
        }

        Write-Host ""
        Write-Host "=== Publishing: $projectName ===" -ForegroundColor Cyan
        $started = Get-Date
        Push-Location $subDir
        try {
            & $rootPublisher `
                -RustGamePublish `
                -ProjectDir $subDir `
                -Production `
                -FTP `
                -SkipBuild:$SkipBuild `
                -SkipFtpSharedAssets `
                -SkipFtpCatalog `
                -DryRun:$DryRun
            $projectSucceeded = $?
            if (-not $projectSucceeded) {
                $failedProjects += $projectName
                Write-Host "ERROR publishing $projectName" -ForegroundColor Red
            } else {
                $publishedProjects += $projectName
                Write-Host ("OK: $projectName ({0:n1}s)" -f ((Get-Date) - $started).TotalSeconds) -ForegroundColor Green
            }
        }
        catch {
            $failedProjects += $projectName
            Write-Host "ERROR publishing ${projectName}: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        }
        finally {
            Pop-Location
        }
    }

    if ($failedProjects.Count -gt 0) {
        Write-Host ""
        Write-Host "Skipping catalog FTP upload because these projects failed: $($failedProjects -join ', ')" -ForegroundColor Red
        $exitCode = 1
        return
    }

    Write-Host ""
    Write-Host "=== Publishing RustGames catalog ===" -ForegroundColor Cyan
    & $rootPublisher -RustGamesCatalogFtpUpload -DryRun:$DryRun
    $catalogSucceeded = $?
    if (-not $catalogSucceeded) {
        Write-Host "ERROR publishing RustGames catalog" -ForegroundColor Red
        $exitCode = 1
        return
    }
}
finally {
    # --- summary ---------------------------------------------------------
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Finished:  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Published: $($publishedProjects.Count)" -ForegroundColor Green
    if ($publishedProjects.Count -gt 0) {
        $publishedProjects | Sort-Object | ForEach-Object { Write-Host "  OK      $_" -ForegroundColor Green }
    }
    if ($skippedProjects.Count -gt 0) {
        Write-Host "Skipped:   $($skippedProjects.Count)" -ForegroundColor DarkGray
        $skippedProjects | Sort-Object | ForEach-Object { Write-Host "  SKIP    $_" -ForegroundColor DarkGray }
    }
    if ($failedProjects.Count -gt 0) {
        Write-Host "Failed:    $($failedProjects.Count)" -ForegroundColor Red
        $failedProjects | Sort-Object | ForEach-Object { Write-Host "  FAILED  $_" -ForegroundColor Red }
    } else {
        Write-Host "Failed:    0" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Log file: $logPath" -ForegroundColor DarkCyan
    Write-Host "Review with:  Select-String -Path '$logPath' -Pattern 'ERROR|FAILED|Warning|WARN'" -ForegroundColor DarkCyan

    if ($transcribing) { try { Stop-Transcript | Out-Null } catch { } }
}

exit $exitCode
