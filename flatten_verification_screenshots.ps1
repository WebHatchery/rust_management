param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$verificationDirs = Get-ChildItem -LiteralPath $resolvedRoot -Directory -Recurse -Force |
    Where-Object { $_.FullName -match '[\\/]docs[\\/]verification$' }
$extensions = @('.png', '.jpg', '.jpeg', '.webp')

foreach ($verificationDir in $verificationDirs) {
    $nestedImages = Get-ChildItem -LiteralPath $verificationDir.FullName -File -Recurse -Force |
        Where-Object {
            $extensions -contains $_.Extension.ToLowerInvariant() -and
            -not $_.DirectoryName.Equals($verificationDir.FullName, [StringComparison]::OrdinalIgnoreCase)
        }
    foreach ($group in $nestedImages | Group-Object Name) {
        $destination = Join-Path $verificationDir.FullName $group.Name
        $candidates = @($group.Group)
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            $candidates += Get-Item -LiteralPath $destination
        }
        $winner = $candidates |
            Sort-Object LastWriteTimeUtc, FullName -Descending |
            Select-Object -First 1
        Write-Host "Keep $($winner.FullName) -> $destination"
        if (-not $WhatIf) {
            if (-not $winner.FullName.Equals($destination, [StringComparison]::OrdinalIgnoreCase)) {
                Copy-Item -LiteralPath $winner.FullName -Destination $destination -Force
                (Get-Item -LiteralPath $destination).LastWriteTimeUtc = $winner.LastWriteTimeUtc
            }
            foreach ($candidate in $group.Group) {
                Remove-Item -LiteralPath $candidate.FullName -Force
            }
        }
    }

    if (-not $WhatIf) {
        Get-ChildItem -LiteralPath $verificationDir.FullName -Directory -Recurse -Force |
            Sort-Object FullName -Descending |
            Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
            Remove-Item -Force
    }
}
