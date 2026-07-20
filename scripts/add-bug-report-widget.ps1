<#
.SYNOPSIS
    Adds the shared "Report a Bug" widget to every Rust game's index.html.

.DESCRIPTION
    Idempotently injects two things into each game page:
      1. <link rel="stylesheet" href="../bug-report.css"> after the shared.css link.
      2. A <div id="roost-bug-report" ...> mount + <script src="../bug-report.js">
         block just before </body>, with data-roost-slug set to rust_<gamedir>.

    Pages that already contain id="roost-bug-report" are left untouched, so the
    script is safe to re-run after adding new games. The canonical copy lives in
    template/index.html; this script propagates it to existing games.

.PARAMETER Root
    RustGames root. Defaults to the parent of this script's folder.

.PARAMETER DryRun
    Report what would change without writing any files.
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Directories that are not games (mirrors the Cargo workspace excludes).
$excluded = @("template", "target", "assets", "macroquad-toolkit", "archive", "docs", "Release", "scripts", "publish-logs", "title_screeshots")

$cssLink = '    <link rel="stylesheet" href="../bug-report.css">'

$changed = @()
$skipped = @()
$missing = @()

Get-ChildItem -Path $Root -Directory | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
    $dir = $_
    $indexPath = Join-Path $dir.FullName "index.html"
    $cargoPath = Join-Path $dir.FullName "Cargo.toml"

    if (-not (Test-Path $indexPath) -or -not (Test-Path $cargoPath)) {
        return
    }

    $content = Get-Content -Path $indexPath -Raw

    if ($content -match 'id="roost-bug-report"') {
        $skipped += $dir.Name
        return
    }

    $slug = "rust_" + $dir.Name.ToLower()
    $block = @"

    <!-- Player bug reporting -> Project Roost Fix Queue (shared widget). -->
    <div id="roost-bug-report" data-roost-slug="$slug"></div>
    <script src="../bug-report.js"></script>
"@

    $original = $content

    # 1. CSS link after the shared.css <link>, else before </head>.
    if ($content -notmatch 'href="\.\./bug-report\.css"') {
        if ($content -match '(?m)^(?<line>\s*<link[^>]*shared\.css[^>]*>\s*)$') {
            $content = $content -replace '(?m)^(\s*<link[^>]*shared\.css[^>]*>\s*)$', "`$1`r`n$cssLink"
        }
        elseif ($content -match '</head>') {
            $content = $content -replace '</head>', "$cssLink`r`n</head>"
        }
    }

    # 2. Widget mount + script before the final </body>.
    if ($content -match '</body>') {
        $lastIndex = $content.LastIndexOf('</body>')
        $content = $content.Substring(0, $lastIndex) + $block + "`r`n" + $content.Substring($lastIndex)
    }
    else {
        Write-Warning "  $($dir.Name): no </body> found; skipped widget block."
        $missing += $dir.Name
        return
    }

    if ($content -eq $original) {
        $skipped += $dir.Name
        return
    }

    if ($DryRun) {
        Write-Host "[dry-run] would update $($dir.Name) (slug: $slug)" -ForegroundColor Yellow
    }
    else {
        Set-Content -Path $indexPath -Value $content -NoNewline -Encoding UTF8
        Write-Host "Updated $($dir.Name) (slug: $slug)" -ForegroundColor Green
    }
    $changed += $dir.Name
}

Write-Host ""
Write-Host "Changed: $($changed.Count)  Skipped (already present): $($skipped.Count)  Warnings: $($missing.Count)" -ForegroundColor Cyan
if ($skipped.Count -gt 0) { Write-Host "  Skipped: $($skipped -join ', ')" -ForegroundColor DarkGray }
if ($missing.Count -gt 0) { Write-Host "  No </body>: $($missing -join ', ')" -ForegroundColor DarkYellow }
