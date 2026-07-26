param(
    [switch]$Check,
    [switch]$IncludeWorkspaceRoot,
    [string[]]$ProjectRoot = @()
)

$ErrorActionPreference = "Stop"

$DocsDir = Split-Path -Parent $PSCommandPath
# Two roots, per CLAUDE.md: $ManagementRoot holds the canonical docs and the
# tooling; $WorkspaceRoot (its parent) holds the game repos. The scan must start
# at the workspace root — starting at $ManagementRoot only ever reached
# `template/` and `archive/*`, so the ~31 game copies were never checked or
# synced by the default (no -ProjectRoot) invocation.
$ManagementRoot = Split-Path -Parent $DocsDir
$WorkspaceRoot = Split-Path -Parent $ManagementRoot

$DocumentNames = @(
    "AGENTS.md",
    "CODE_STANDARDS.md",
    "MACROQUAD_TOOLKIT.md",
    "GAME_DEVELOPMENT_GUIDE.md"
)

$IgnoredDirectories = @(
    ".git",
    ".vscode",
    "docs",
    "target",
    "Release",
    "publish-logs",
    "title_screeshots"
)

function Get-RelativePath {
    param([string]$Path)

    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    if ($fullPath.Equals($WorkspaceRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return "."
    }
    if ($fullPath.StartsWith($WorkspaceRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($WorkspaceRoot.Length).TrimStart("\", "/")
    }
    return $fullPath
}

function Get-CargoProjectRoots {
    param([string]$Directory)

    $roots = @()
    $cargoManifest = Join-Path $Directory "Cargo.toml"
    $resolvedDirectory = (Resolve-Path -LiteralPath $Directory).Path

    if (Test-Path -LiteralPath $cargoManifest -PathType Leaf) {
        if ($IncludeWorkspaceRoot -or -not $resolvedDirectory.Equals($WorkspaceRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $roots += $resolvedDirectory
        }
    }

    foreach ($child in Get-ChildItem -LiteralPath $Directory -Directory -Force) {
        if ($IgnoredDirectories -contains $child.Name) {
            continue
        }
        $roots += Get-CargoProjectRoots -Directory $child.FullName
    }

    return $roots
}

function Test-GameProjectRoot {
    param([string]$Directory)

    $publishScript = Join-Path $Directory "publish.ps1"
    return Test-Path -LiteralPath $publishScript -PathType Leaf
}

function Resolve-ProjectRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $candidate = $Path
    } else {
        $candidate = Join-Path $WorkspaceRoot $Path
    }

    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    $manifest = Join-Path $resolved "Cargo.toml"
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Project root '$Path' does not contain Cargo.toml."
    }

    return $resolved
}

function Get-DocumentDestinations {
    param(
        [string]$ProjectRoot,
        [string]$DocumentName
    )

    $destinations = New-Object System.Collections.Generic.List[string]
    $destinations.Add((Join-Path $ProjectRoot $DocumentName))

    $projectDocsDir = Join-Path $ProjectRoot "docs"
    $projectDocsDocument = Join-Path $projectDocsDir $DocumentName
    if ((Test-Path -LiteralPath $projectDocsDocument -PathType Leaf) -and
        -not ((Resolve-Path -LiteralPath $projectDocsDir).Path.Equals($DocsDir, [StringComparison]::OrdinalIgnoreCase))) {
        $destinations.Add($projectDocsDocument)
    }

    return $destinations
}

foreach ($documentName in $DocumentNames) {
    $source = Join-Path $DocsDir $documentName
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing canonical document: $source"
    }
}

if ($ProjectRoot.Count -gt 0) {
    $projectRoots = $ProjectRoot | ForEach-Object { Resolve-ProjectRoot -Path $_ } | Sort-Object -Unique
} else {
    $projectRoots = Get-CargoProjectRoots -Directory $WorkspaceRoot |
        Where-Object { Test-GameProjectRoot -Directory $_ } |
        Sort-Object -Unique
}

if ($projectRoots.Count -eq 0) {
    throw "No Cargo project roots found."
}

$drift = @()

foreach ($projectRoot in $projectRoots) {
    foreach ($documentName in $DocumentNames) {
        $source = Join-Path $DocsDir $documentName
        $destinations = Get-DocumentDestinations -ProjectRoot $projectRoot -DocumentName $documentName

        foreach ($destination in $destinations) {
            $destinationLabel = Get-RelativePath -Path (Split-Path -Parent $destination)
            $documentLabel = if ($destinationLabel -eq ".") { $documentName } else { "$destinationLabel\$documentName" }

            if ($Check) {
                if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                    $drift += [PSCustomObject]@{
                        Path = $documentLabel
                        Status = "missing"
                    }
                    continue
                }

                $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
                $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
                if ($sourceHash -ne $destinationHash) {
                    $drift += [PSCustomObject]@{
                        Path = $documentLabel
                        Status = "different"
                    }
                }
            } else {
                Copy-Item -LiteralPath $source -Destination $destination -Force
                Write-Host "Synced $documentLabel"
            }
        }
    }
}

if ($Check) {
    if ($drift.Count -gt 0) {
        Write-Host "Standards document drift detected:"
        $drift | Sort-Object Path | ForEach-Object {
            Write-Host "- $($_.Path): $($_.Status)"
        }
        exit 1
    }

    Write-Host "All checked project standards documents match docs."
}

exit 0
