param()

$ErrorActionPreference = 'Stop'
$managementRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('rustgames-drift-' + [guid]::NewGuid().ToString('N'))
$fixtureManagement = Join-Path $testRoot 'rust_management'
$shell = (Get-Process -Id $PID).Path

function Assert-Condition([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Row([string]$Project, [int]$Commits = 0, [int]$Dirty = 0) {
    return [pscustomobject]@{
        Project = $Project; Status = 'Drift'; Comparison = 'deployed SHA'
        DeploymentAncestor = $true; LocalCommits = $Commits; LocalFiles = $Commits
        DirtyFiles = $Dirty; RemoteCommits = 0; Behind = 0; Notes = ''
    }
}

function Invoke-Case([object[]]$Rows, [string[]]$Options = @('-ChangedOnly'), [string]$Fail = '') {
    ConvertTo-Json -InputObject @($Rows) | Set-Content (Join-Path $fixtureManagement 'rows.json')
    Set-Content (Join-Path $fixtureManagement 'fail.txt') $Fail
    $callsPath = Join-Path $fixtureManagement 'calls.jsonl'
    if (Test-Path $callsPath) { Remove-Item -LiteralPath $callsPath }
    $ErrorActionPreference = 'Continue' # Windows PowerShell wraps expected native stderr as errors.
    $output = & $shell -NoProfile -File (Join-Path $fixtureManagement 'publish-all-ftp.ps1') @Options 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $calls = @(if (Test-Path $callsPath) { Get-Content $callsPath | ConvertFrom-Json })
    return [pscustomobject]@{ Code = $code; Calls = $calls; Output = $output -join "`n" }
}

try {
    New-Item -ItemType Directory -Path $fixtureManagement -Force | Out-Null
    Copy-Item (Join-Path $managementRoot 'publish-all-ftp.ps1') $fixtureManagement
    foreach ($name in @('updated', 'dirty', 'current', 'remote', 'new')) {
        $directory = New-Item -ItemType Directory -Path (Join-Path $testRoot $name)
        Set-Content (Join-Path $directory.FullName 'publish.ps1') '# fixture'
    }
    @'
param($WorkspaceRoot, [switch]$IncludeCurrent, [switch]$Fetch, $OutputFormat)
Get-Content (Join-Path $PSScriptRoot 'rows.json') -Raw
exit 0
'@ | Set-Content (Join-Path $fixtureManagement 'prod-drift.ps1')
    @'
param([switch]$RustGamesSharedAssetsFtpUpload, [switch]$RustGamesCatalogFtpUpload,
    [switch]$RustGamePublish, $ProjectDir, [switch]$Production, [switch]$FTP,
    [switch]$SkipBuild, [switch]$SkipFtpSharedAssets, [switch]$SkipFtpCatalog, [switch]$DryRun)
$kind = if ($RustGamesSharedAssetsFtpUpload) { 'shared' } elseif ($RustGamesCatalogFtpUpload) { 'catalog' } else { Split-Path -Leaf $ProjectDir }
[pscustomobject]@{ Kind = $kind; DryRun = [bool]$DryRun; Production = [bool]$Production
    FTP = [bool]$FTP; SkipBuild = [bool]$SkipBuild; SkipShared = [bool]$SkipFtpSharedAssets
    SkipCatalog = [bool]$SkipFtpCatalog } | ConvertTo-Json -Compress | Add-Content (Join-Path $PSScriptRoot 'calls.jsonl')
if ($kind -eq (Get-Content (Join-Path $PSScriptRoot 'fail.txt') -Raw).Trim()) { Write-Error 'Fixture failure'; exit 1 }
'@ | Set-Content (Join-Path $fixtureManagement 'publish.ps1')

    $updated = New-Row 'updated' 2
    $dirty = New-Row 'dirty' 0 1
    $current = New-Row 'current'
    $current.Status = 'Current'
    $remote = New-Row 'remote'
    $remote.RemoteCommits = 3
    $remote.Behind = 3
    $new = New-Row 'new'
    $new.Status = 'Never deployed'
    $result = Invoke-Case @($updated, $dirty, $current, $remote, $new) @('-ChangedOnly', '-DryRun', '-Fetch')
    Assert-Condition ($result.Code -eq 0 -and $result.Calls.Count -eq 0 -and $result.Output -match 'Previewed: 3') 'Selective preview built or uploaded games, or selected the wrong games.'
    $result = Invoke-Case @($updated, $dirty, $current, $remote, $new)
    Assert-Condition ($result.Code -eq 0) $result.Output
    Assert-Condition (($result.Calls.Kind -join ',') -eq 'shared,dirty,new,updated,catalog') "Incorrect publish selection or shared/catalog ordering: $($result.Output)"
    Assert-Condition (@($result.Calls | Where-Object { $_.DryRun }).Count -eq 0) 'Live publish was changed to a dry run.'
    foreach ($call in @($result.Calls | Where-Object { $_.Kind -notin @('shared', 'catalog') })) {
        Assert-Condition ($call.Production -and $call.FTP -and $call.SkipShared -and $call.SkipCatalog -and -not $call.SkipBuild) 'Game publish flags are incorrect.'
    }

    $result = Invoke-Case @($current, $remote)
    Assert-Condition ($result.Code -eq 0 -and $result.Calls.Count -eq 0) 'No-op performed uploads.'
    foreach ($problem in @('Roost error', 'fallback', 'diverged', 'unknown')) {
        $row = New-Row 'updated' 2
        switch ($problem) {
            'Roost error' { $row.Status = 'Roost error' }
            'fallback' { $row.Comparison = 'date fallback' }
            'diverged' { $row.DeploymentAncestor = $false }
            'unknown' { $row.LocalCommits = $null }
        }
        $result = Invoke-Case @($row, $dirty)
        Assert-Condition ($result.Code -ne 0 -and $result.Calls.Count -eq 0) "Unsafe comparison uploaded: $problem"
    }
    $result = Invoke-Case @($updated) @('-ChangedOnly', '-SkipBuild')
    Assert-Condition ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Stale build reuse was allowed.'
    foreach ($failure in @('shared', 'updated', 'catalog')) {
        $result = Invoke-Case @($updated) @('-ChangedOnly') $failure
        Assert-Condition ($result.Code -ne 0) "Failure returned success: $failure"
        if ($failure -ne 'catalog') {
            Assert-Condition ($result.Calls.Kind -notcontains 'catalog') 'Catalog uploaded after failure.'
        }
    }
    $result = Invoke-Case @() @('-DryRun')
    Assert-Condition ($result.Code -eq 0 -and $result.Calls.Count -eq 7) 'Default full publish changed.'
    Write-Host 'Production drift publishing checks passed.' -ForegroundColor Green
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Split-Path -Leaf $resolved).StartsWith('rustgames-drift-')) {
        throw "Refusing to remove unexpected test directory: $resolved"
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
