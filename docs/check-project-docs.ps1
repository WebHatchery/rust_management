param(
    [switch]$IncludeWorkspaceRoot,
    [string[]]$ProjectRoot = @()
)

$ErrorActionPreference = "Stop"

$syncScript = Join-Path $PSScriptRoot "sync-project-docs.ps1"

if ($ProjectRoot.Count -gt 0) {
    & $syncScript -Check -IncludeWorkspaceRoot:$IncludeWorkspaceRoot -ProjectRoot $ProjectRoot
} else {
    & $syncScript -Check -IncludeWorkspaceRoot:$IncludeWorkspaceRoot
}

if (-not $?) {
    exit 1
}

exit 0
