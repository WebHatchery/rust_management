param()

$ErrorActionPreference = "Stop"

$managementRoot = Split-Path -Parent $PSScriptRoot
$publisherPath = Join-Path $managementRoot "publish.ps1"
$batchPublisherPath = Join-Path $managementRoot "publish-all-ftp.ps1"

function Assert-Condition {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

# Dot-source the publisher in help mode so its helper functions can be tested
# without building, deploying, tracking, or contacting FTP.
. $publisherPath -Help *> $null

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("rustgames-publish-safety-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$packageDir = Join-Path $testRoot "package"
$deployDir = Join-Path $testRoot "deploy"
$archiveSourceDir = Join-Path $testRoot "archive-source"
$archivePath = Join-Path $testRoot "package.zip"
$previousNativeExitCode = $global:LASTEXITCODE

try {
    foreach ($directory in @($projectRoot, $packageDir, $deployDir, $archiveSourceDir)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText((Join-Path $archiveSourceDir "payload.txt"), "archive payload")
    Compress-Archive `
        -Path (Join-Path $archiveSourceDir "*") `
        -DestinationPath $archivePath `
        -CompressionLevel Optimal
    Assert-Condition (Test-Path -LiteralPath $archivePath -PathType Leaf) "Compress-Archive did not create the disposable package."

    [System.IO.File]::WriteAllText(
        (Join-Path $projectRoot "asset_packs.json"),
        '{"packs":[{"source":"assets","output":"assets.zip","delete_source":true}]}',
        [System.Text.UTF8Encoding]::new($false)
    )

    foreach ($name in @("index.html", "current.wasm")) {
        [System.IO.File]::WriteAllText((Join-Path $packageDir $name), $name)
        [System.IO.File]::WriteAllText((Join-Path $deployDir $name), $name)
    }

    foreach ($name in @(
        "current_windows.zip",
        "old.wasm",
        "old_windows.zip",
        "assets.zip",
        ".server.pid",
        ".htaccess",
        "verify.html",
        "notes.zip",
        "storage.js"
    )) {
        [System.IO.File]::WriteAllText((Join-Path $deployDir $name), $name)
    }

    $info = [pscustomobject]@{ ProjectRoot = $projectRoot }
    $indexPath = Join-Path $packageDir "index.html"
    Write-Utf8File $indexPath '<link href="../shared.css?old=1"><script src="mq_js_bundle.js"></script>'
    Update-PackagedIndexPaths $indexPath
    $versionedIndex = Get-Content -LiteralPath $indexPath -Raw
    $expectedVersion = (Get-FileHash (Join-Path (Get-RustGameWebSourceDir) "shared.css") -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
    Assert-Condition ($versionedIndex.Contains("../shared.css?v=$expectedVersion")) "Packaged stylesheet did not receive its content version."
    Update-PackagedIndexPaths $indexPath
    Assert-Condition ((Get-Content -LiteralPath $indexPath -Raw) -eq $versionedIndex) "Repeated packaging changed stable stylesheet references."

    # Load only the pure itch rewrite function; never dispatch Butler in this test.
    $itchAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $managementRoot "publish-itch.ps1"), [ref]$null, [ref]$null)
    $rewrite = $itchAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Rewrite-ItchIndex" }, $true)
    . ([scriptblock]::Create($rewrite.Extent.Text))
    $itchIndex = Rewrite-ItchIndex $versionedIndex
    Assert-Condition ($itchIndex.Contains("href=`"shared.css?v=$expectedVersion`"")) "Itch package did not localize the versioned stylesheet."

    Remove-RustGameObsoleteLocalReleaseFiles `
        -Info $info `
        -DeployDir $deployDir `
        -PackageDir $packageDir `
        -WindowsArchiveName "current_windows.zip"

    foreach ($name in @("old.wasm", "old_windows.zip", "assets.zip")) {
        Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $deployDir $name))) "Publisher-owned stale file was not removed: $name"
    }

    foreach ($name in @(
        "index.html",
        "current.wasm",
        "current_windows.zip",
        ".server.pid",
        ".htaccess",
        "verify.html",
        "notes.zip",
        "storage.js"
    )) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $deployDir $name)) "Current or unmanaged file was removed: $name"
    }

    $publisherText = Get-Content -LiteralPath $publisherPath -Raw
    Assert-Condition ($publisherText -notmatch '(?m)^\s*Compress-Archive[^\r\n]*-ProgressAction\b') "Compress-Archive still uses the PowerShell 7-only ProgressAction parameter."

    $batchPublisherText = Get-Content -LiteralPath $batchPublisherPath -Raw
    Assert-Condition ($batchPublisherText -notmatch '\$LASTEXITCODE') "Batch publisher still bases child-script success on LASTEXITCODE."

    $global:LASTEXITCODE = 23
    & $publisherPath -Help *> $null
    $helpSucceeded = $?
    Assert-Condition $helpSucceeded "A successful publisher dispatch was not reported through the PowerShell success stream."

    Write-Host "Publish safety checks passed." -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $testLeaf = Split-Path -Leaf $resolvedTestRoot
        if (-not $resolvedTestRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            -not $testLeaf.StartsWith("rustgames-publish-safety-", [System.StringComparison]::Ordinal)) {
            throw "Refusing to remove unexpected test directory: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
    $global:LASTEXITCODE = $previousNativeExitCode
}
