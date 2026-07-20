#Requires -Version 7.0

<#
.SYNOPSIS
Commits (and optionally pushes) index.html changes across Rust game projects.

.DESCRIPTION
Iterates through game directories in the RustGames workspace and commits any changes
to index.html files using a caller-supplied commit message. Each game is its own git
repo, so the commit (and optional push) runs inside each project directory.

.PARAMETER Message
The commit message to use. Required. Multi-line messages are supported.

.PARAMETER ProjectDirs
Optional array of specific project directories to process. If not specified, processes
all top-level directories except excluded ones (template, macroquad-toolkit, docs, etc).
Names passed explicitly here bypass the exclude list.

.PARAMETER Push
After committing, run 'git push' in each repo that had a commit.

.PARAMETER DryRun
Shows what would be committed/pushed without actually doing it.

.EXAMPLE
.\commit-index-html.ps1 -Message "Add Ko-fi support widget to index.html"
# Commits index.html changes in all games

.EXAMPLE
.\commit-index-html.ps1 -Message "Add Ko-fi support widget" -Push
# Commits and pushes index.html changes in all games

.EXAMPLE
.\commit-index-html.ps1 -Message "..." -ProjectDirs auction_game,toybox -DryRun
# Shows what would be committed for only auction_game and toybox
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [string[]]$ProjectDirs,
    [switch]$Push,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Excluded directories that aren't games
$Exclude = @("template", "macroquad-toolkit", "docs", "archive", "target", "Release", "assets", ".cargo-target", "scripts")

# Get the RustGames directory (where this script lives)
$RustGamesRoot = Split-Path -Parent $PSScriptRoot

Write-Host "RustGames root: $RustGamesRoot" -ForegroundColor Cyan

# Determine which projects to process
if ($ProjectDirs) {
    $ProjectPaths = $ProjectDirs | ForEach-Object {
        Join-Path $RustGamesRoot $_
    }
} else {
    $ProjectPaths = Get-ChildItem -Path $RustGamesRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $Exclude } |
        Select-Object -ExpandProperty FullName
}

if (-not $ProjectPaths) {
    Write-Host "No projects found to process." -ForegroundColor Yellow
    exit 0
}

$CommitMessage = $Message

$ProcessedCount = 0
$ChangedCount = 0
$PushedCount = 0

foreach ($ProjectPath in $ProjectPaths) {
    $ProjectName = Split-Path -Leaf $ProjectPath
    $IndexHtmlPath = Join-Path $ProjectPath "index.html"

    if (-not (Test-Path $ProjectPath -PathType Container)) {
        Write-Host "  ⊘ $ProjectName - directory not found" -ForegroundColor Gray
        continue
    }

    $ProcessedCount++

    if (-not (Test-Path $IndexHtmlPath)) {
        Write-Host "  ○ $ProjectName - no index.html found" -ForegroundColor Gray
        continue
    }

    Push-Location $ProjectPath

    try {
        # Check git status for index.html
        $GitStatus = & git status --short index.html 2>$null

        if ($GitStatus) {
            Write-Host "  ✓ $ProjectName - found changes to index.html" -ForegroundColor Green

            if ($DryRun) {
                Write-Host "    [DRY RUN] Would commit with message:" -ForegroundColor Yellow
                Write-Host "    $($CommitMessage -replace "`n", "`n    ")" -ForegroundColor Yellow
                if ($Push) {
                    Write-Host "    [DRY RUN] Would push" -ForegroundColor Yellow
                }
            } else {
                & git add index.html
                & git commit -m $CommitMessage
                Write-Host "    ✓ Committed" -ForegroundColor Green
                $ChangedCount++

                if ($Push) {
                    & git push
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    ✓ Pushed" -ForegroundColor Green
                        $PushedCount++
                    } else {
                        Write-Host "    ✗ Push failed (exit $LASTEXITCODE)" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "  ○ $ProjectName - no changes to index.html" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ✗ $ProjectName - error: $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Processed: $ProcessedCount projects"
Write-Host "  $(if ($DryRun) { "Would commit" } else { "Committed" }): $ChangedCount projects"
if ($Push) {
    Write-Host "  $(if ($DryRun) { "Would push" } else { "Pushed" }): $PushedCount projects"
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Re-run without -DryRun to commit changes." -ForegroundColor Yellow
}
