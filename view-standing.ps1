<#
.SYNOPSIS
    Serves this folder over HTTP and opens standing.html in the browser.

.DESCRIPTION
    standing.html renders standing.md live via fetch(), so standing.md stays the
    single source of truth. Browsers block fetch() when a page is opened directly
    from disk (file://), so double-clicking standing.html can't load the Markdown.
    This script starts a tiny local web server and opens the live page instead.

    Edit standing.md and just refresh the browser — nothing is duplicated.

.PARAMETER Port
    Port to serve on (default 8080).
#>
[CmdletBinding()]
param(
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$url  = "http://localhost:$Port/standing.html"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) {
    throw "Python not found on PATH. Install Python, or serve $root over HTTP another way and open $url."
}

Write-Host "Serving $root at $url" -ForegroundColor Green
Write-Host "Edit standing.md and refresh the browser. Press Ctrl+C to stop." -ForegroundColor DarkGray

Start-Process $url
& $python.Source -m http.server $Port --directory $root
