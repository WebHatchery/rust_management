<#
.SYNOPSIS
Ranks Rust game repositories by changes since their last production deployment.

.DESCRIPTION
Looks up each local game's latest successful production event in Project Roost,
then compares its recorded Git commit with local HEAD, the working tree, and the
configured upstream branch. Remote refs are read from the local Git cache unless
-Fetch is supplied.

.EXAMPLE
.\prod-drift.ps1

.EXAMPLE
.\prod-drift.ps1 -Fetch -MinimumChangedFiles 10

.EXAMPLE
.\prod-drift.ps1 -OutputFormat Json -Top 10
#>

[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'https://webhatchery.au/project_roost/api/v1',
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Fetch = $false,
    [switch]$IncludeCurrent = $false,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MinimumChangedFiles = 1,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$MinimumCommits = 1,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Top = 0,
    [ValidateSet('Table', 'Json', 'Csv')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& git -C $Repository @Arguments 2>$null)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output
    }
}

function Get-RoostSlug {
    param([Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Project)

    $pagePath = Join-Path $Project.FullName 'game_page.json'
    if (Test-Path -LiteralPath $pagePath) {
        try {
            $page = Get-Content -LiteralPath $pagePath -Raw | ConvertFrom-Json
            $configured = ([string]$page.roost_slug).Trim()
            if ($configured) {
                return $configured
            }
        }
        catch {
            Write-Warning "Could not read ${pagePath}: $($_.Exception.Message)"
        }
    }

    $slug = $Project.Name.Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9_]+', '_').Trim('_')
    if ($slug.StartsWith('rust_')) {
        return $slug
    }
    return "rust_$slug"
}

function Get-LatestProductionDeployment {
    param([Parameter(Mandatory = $true)][string]$ProjectSlug)

    $escaped = [uri]::EscapeDataString($ProjectSlug)
    $url = "$($ApiBaseUrl.TrimEnd('/'))/deployments?project=$escaped&limit=20"
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
    if (-not $response.success) {
        throw "Project Roost rejected the deployment request for $ProjectSlug."
    }

    $latest = $response.data.latest.production
    if ($null -ne $latest -and $latest.status -eq 'success') {
        return $latest
    }

    return @($response.data.deployments | Where-Object {
        $_.environment -eq 'production' -and $_.status -eq 'success'
    } | Select-Object -First 1)[0]
}

function Get-IntegerOutput {
    param([Parameter(Mandatory = $true)]$GitResult)

    if ($GitResult.ExitCode -ne 0 -or $GitResult.Output.Count -eq 0) {
        return $null
    }

    $value = 0
    if ([int]::TryParse(([string]$GitResult.Output[0]).Trim(), [ref]$value)) {
        return $value
    }
    return $null
}

function Get-DiffStats {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Range
    )

    $result = Invoke-Git -Repository $Repository -Arguments @('diff', '--numstat', $Range, '--')
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $files = 0
    $added = 0
    $deleted = 0
    foreach ($line in $result.Output) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) {
            continue
        }
        $parts = ([string]$line) -split "`t", 3
        if ($parts.Count -lt 3) {
            continue
        }
        $files++
        if ($parts[0] -match '^\d+$') {
            $added += [int]$parts[0]
        }
        if ($parts[1] -match '^\d+$') {
            $deleted += [int]$parts[1]
        }
    }

    return [pscustomobject]@{
        Files = $files
        Added = $added
        Deleted = $deleted
    }
}

function Join-Notes {
    param([System.Collections.Generic.List[string]]$Notes)

    if ($Notes.Count -eq 0) {
        return ''
    }
    return $Notes -join '; '
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git is required but was not found on PATH.'
    exit 1
}

if (-not (Test-Path -LiteralPath $WorkspaceRoot -PathType Container)) {
    Write-Error "Workspace root not found: $WorkspaceRoot"
    exit 1
}
$WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path

$projects = @(Get-ChildItem -LiteralPath $WorkspaceRoot -Directory | Where-Object {
    (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName 'Cargo.toml')) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName 'publish.ps1'))
} | Sort-Object Name)

if ($projects.Count -eq 0) {
    Write-Error "No Rust game repositories were found under $WorkspaceRoot."
    exit 1
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($project in $projects) {
    $slug = Get-RoostSlug -Project $project
    $notes = [System.Collections.Generic.List[string]]::new()

    try {
        $deployment = Get-LatestProductionDeployment -ProjectSlug $slug
    }
    catch {
        $rows.Add([pscustomobject]@{
            Project = $project.Name; RoostSlug = $slug; DeployedAt = $null; AgeDays = $null
            DeployedCommit = $null; Comparison = 'unavailable'; LocalCommits = $null
            RemoteCommits = $null; LocalFiles = $null; RemoteFiles = $null
            DirtyFiles = $null; Ahead = $null; Behind = $null; Added = $null
            Deleted = $null; Status = 'Roost error'; Notes = $_.Exception.Message
            Path = $project.FullName
        })
        continue
    }

    if ($null -eq $deployment) {
        $rows.Add([pscustomobject]@{
            Project = $project.Name; RoostSlug = $slug; DeployedAt = $null; AgeDays = $null
            DeployedCommit = $null; Comparison = 'none'; LocalCommits = $null
            RemoteCommits = $null; LocalFiles = $null; RemoteFiles = $null
            DirtyFiles = @(Invoke-Git -Repository $project.FullName -Arguments @('status', '--porcelain')).Output.Count
            Ahead = $null; Behind = $null; Added = $null; Deleted = $null
            Status = 'Never deployed'; Notes = 'No successful production event in Project Roost.'
            Path = $project.FullName
        })
        continue
    }

    if ($Fetch) {
        $fetchResult = Invoke-Git -Repository $project.FullName -Arguments @('fetch', '--all', '--quiet')
        if ($fetchResult.ExitCode -ne 0) {
            $notes.Add('Fetch failed; remote counts may be stale.')
        }
    }

    $deployedAt = [datetime]::MinValue
    $parsedDate = [datetime]::TryParse([string]$deployment.deployed_at, [ref]$deployedAt)
    $ageDays = if ($parsedDate) { [math]::Max(0, [math]::Floor(((Get-Date) - $deployedAt).TotalDays)) } else { $null }

    $baseCommit = ([string]$deployment.git_commit).Trim()
    $comparison = 'deployed SHA'
    $baseValid = $false
    if ($baseCommit) {
        $verify = Invoke-Git -Repository $project.FullName -Arguments @('cat-file', '-e', "$baseCommit^{commit}")
        $baseValid = $verify.ExitCode -eq 0
    }

    if (-not $baseValid -and $parsedDate) {
        $fallback = Invoke-Git -Repository $project.FullName -Arguments @(
            'rev-list', '-1', "--before=$($deployedAt.ToString('o'))", 'HEAD'
        )
        if ($fallback.ExitCode -eq 0 -and $fallback.Output.Count -gt 0) {
            $baseCommit = ([string]$fallback.Output[0]).Trim()
            $baseValid = $baseCommit -ne ''
            $comparison = 'date fallback'
            $notes.Add('The deployment SHA was missing or unavailable; used the last commit before the deployment date.')
        }
    }

    $dirtyResult = Invoke-Git -Repository $project.FullName -Arguments @('status', '--porcelain')
    $dirtyFiles = if ($dirtyResult.ExitCode -eq 0) { @($dirtyResult.Output).Count } else { $null }

    $localCommits = $null
    $localStats = $null
    if ($baseValid) {
        $localCommits = Get-IntegerOutput (Invoke-Git -Repository $project.FullName -Arguments @(
            'rev-list', '--count', "$baseCommit..HEAD"
        ))
        $localStats = Get-DiffStats -Repository $project.FullName -Range "$baseCommit..HEAD"

        $ancestor = Invoke-Git -Repository $project.FullName -Arguments @(
            'merge-base', '--is-ancestor', $baseCommit, 'HEAD'
        )
        if ($ancestor.ExitCode -ne 0) {
            $notes.Add('The deployed commit is not an ancestor of local HEAD.')
        }
    }
    else {
        $comparison = 'unavailable'
        $notes.Add('No deployed commit or date-based fallback exists in this repository.')
    }

    $upstreamResult = Invoke-Git -Repository $project.FullName -Arguments @(
        'rev-parse', '--abbrev-ref', '@{upstream}'
    )
    $upstream = if ($upstreamResult.ExitCode -eq 0 -and $upstreamResult.Output.Count -gt 0) {
        ([string]$upstreamResult.Output[0]).Trim()
    } else {
        $null
    }

    $ahead = $null
    $behind = $null
    $remoteCommits = $null
    $remoteStats = $null
    if ($upstream) {
        $divergence = Invoke-Git -Repository $project.FullName -Arguments @(
            'rev-list', '--left-right', '--count', "HEAD...$upstream"
        )
        if ($divergence.ExitCode -eq 0 -and $divergence.Output.Count -gt 0) {
            $counts = @(([string]$divergence.Output[0]) -split '\s+' | Where-Object { $_ -ne '' })
            if ($counts.Count -ge 2) {
                $ahead = [int]$counts[0]
                $behind = [int]$counts[1]
            }
        }
        if ($baseValid) {
            $remoteCommits = Get-IntegerOutput (Invoke-Git -Repository $project.FullName -Arguments @(
                'rev-list', '--count', "$baseCommit..$upstream"
            ))
            $remoteStats = Get-DiffStats -Repository $project.FullName -Range "$baseCommit..$upstream"
        }
    }
    else {
        $notes.Add('No upstream branch is configured.')
    }

    $localFiles = if ($null -ne $localStats) { $localStats.Files } else { $null }
    $remoteFiles = if ($null -ne $remoteStats) { $remoteStats.Files } else { $null }
    $added = if ($null -ne $localStats) { $localStats.Added } else { $null }
    $deleted = if ($null -ne $localStats) { $localStats.Deleted } else { $null }
    $hasDrift = ($localCommits -gt 0) -or ($remoteCommits -gt 0) -or ($dirtyFiles -gt 0) -or ($behind -gt 0)
    $status = if ($hasDrift) { 'Drift' } else { 'Current' }

    $rows.Add([pscustomobject]@{
        Project = $project.Name
        RoostSlug = $slug
        DeployedAt = [string]$deployment.deployed_at
        AgeDays = $ageDays
        DeployedCommit = [string]$deployment.git_commit
        Comparison = $comparison
        LocalCommits = $localCommits
        RemoteCommits = $remoteCommits
        LocalFiles = $localFiles
        RemoteFiles = $remoteFiles
        DirtyFiles = $dirtyFiles
        Ahead = $ahead
        Behind = $behind
        Added = $added
        Deleted = $deleted
        Status = $status
        Notes = Join-Notes -Notes $notes
        Path = $project.FullName
    })
}

$filtered = @($rows | Where-Object {
    if ($_.Status -notin @('Current', 'Drift')) {
        return $true
    }
    if ($IncludeCurrent -and $_.Status -eq 'Current') {
        return $true
    }
    $largestFiles = [math]::Max([int]$_.LocalFiles, [int]$_.RemoteFiles)
    $largestCommits = [math]::Max([int]$_.LocalCommits, [int]$_.RemoteCommits)
    return $_.Status -eq 'Drift' -and (
        $largestFiles -ge $MinimumChangedFiles -or
        $largestCommits -ge $MinimumCommits -or
        [int]$_.DirtyFiles -gt 0 -or
        [int]$_.Behind -gt 0
    )
})

$filtered = @($filtered | Sort-Object `
    @{ Expression = { [math]::Max([int]$_.LocalFiles, [int]$_.RemoteFiles) }; Descending = $true }, `
    @{ Expression = { [math]::Max([int]$_.LocalCommits, [int]$_.RemoteCommits) }; Descending = $true }, `
    @{ Expression = { [int]$_.DirtyFiles }; Descending = $true }, `
    Project)

if ($Top -gt 0) {
    $filtered = @($filtered | Select-Object -First $Top)
}

switch ($OutputFormat) {
    'Json' {
        $filtered | ConvertTo-Json -Depth 4
    }
    'Csv' {
        $filtered | ConvertTo-Csv -NoTypeInformation
    }
    default {
        if (-not $Fetch) {
            Write-Host 'Remote counts use cached tracking refs. Re-run with -Fetch for current remote data.' -ForegroundColor DarkYellow
        }
        if ($filtered.Count -eq 0) {
            Write-Host 'No repositories matched the requested drift thresholds.' -ForegroundColor Green
        }
        else {
            $filtered | Format-Table -AutoSize `
                Project, `
                @{ Label = 'Deployed'; Expression = { ([string]$_.DeployedAt) -replace ' .*$', '' } }, `
                @{ Label = 'Age'; Expression = { $_.AgeDays } }, `
                @{ Label = 'LCommits'; Expression = { $_.LocalCommits } }, `
                @{ Label = 'RCommits'; Expression = { $_.RemoteCommits } }, `
                @{ Label = 'LFiles'; Expression = { $_.LocalFiles } }, `
                @{ Label = 'RFiles'; Expression = { $_.RemoteFiles } }, `
                @{ Label = 'Dirty'; Expression = { $_.DirtyFiles } }, `
                Ahead, Behind, `
                @{ Label = 'Churn'; Expression = { "+$($_.Added)/-$($_.Deleted)" } }, `
                Status

            $noted = @($filtered | Where-Object { $_.Notes })
            if ($noted.Count -gt 0) {
                Write-Host 'Notes:' -ForegroundColor DarkYellow
                $noted | ForEach-Object { Write-Host "  $($_.Project): $($_.Notes)" }
            }
        }
    }
}

exit 0
