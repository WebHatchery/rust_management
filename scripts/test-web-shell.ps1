param(
    [string]$OutputDir = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'publish-logs/web-shell-tests')
)

$ErrorActionPreference = 'Stop'
$management = Split-Path $PSScriptRoot -Parent
. (Join-Path $management 'publish.ps1') -Help *> $null

function Assert-Shell {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

# Import helpers only: no Butler, credentials, build, or deployment dispatch.
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $management 'publish-itch.ps1'), [ref]$null, [ref]$null)
foreach ($function in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($function.Extent.Text))
}

$projects = @(Get-ChildItem $WorkspaceRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'game_page.json') })
$count = 0
foreach ($project in $projects) {
    $info = [pscustomobject]@{ ProjectRoot = $project.FullName; GameSlug = $project.Name; ProjectSlug = $project.Name }
    foreach ($platform in @('webhatchery', 'itch')) {
        $folder = Join-Path $OutputDir "$platform/$($project.Name)"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $path = Join-Path $folder 'index.html'
        Assert-Shell (New-RustGameIndexHtml $info $path -Platform $platform) "Render failed: $($project.Name)/$platform"
        Update-PackagedIndexPaths $path
        $html = Get-Content $path -Raw
        Assert-Shell ($html -notmatch '\{\{[A-Z_]+\}\}') "Unresolved template token: $path"
        Assert-Shell ($html -match 'id="glcanvas"') "Canvas missing: $path"
        Assert-Shell ($html -match 'storage\.js\?v=') "Persistence bridge missing: $path"
        Assert-Shell ($html -notmatch "window.addEventListener\('click'") "Global focus thief returned: $path"
        if ($platform -eq 'itch') {
            $html = Rewrite-ItchIndex $html
            Write-Utf8File $path $html
            Assert-Shell ($html -match 'class="viewport-game"') "Itch must fill its embed: $path"
            Assert-Shell ($html -notmatch 'bug-report|roost-br|ko-fi|kofiWidget|game-info|back-link|_windows.zip') "Site content leaked into itch: $path"
            Assert-Shell ($html -notmatch '(?:src|href)="(?:/|\.\./)') "Non-local itch reference: $path"
        } else {
            Assert-Shell ($html -match 'About This Game' -and $html -match 'game-sidebar') "Game details missing: $path"
            Assert-Shell ($html -notmatch 'class="viewport-game"') "WebHatchery details hidden: $path"
            Assert-Shell ($html -match 'bug-report.js\?v=' -and $html -match 'kofiWidgetOverlay') "Site controls missing: $path"
        }
        $count++
    }
}

# Exercise the real staging path with a disposable copy of Idle Hands assets.
# It must replace even a stale/custom index and exclude Windows downloads.
$projectRoot = Join-Path $WorkspaceRoot 'idle_hands'
$fixture = Join-Path $OutputDir 'staging'
$webgl = Join-Path $fixture 'webgl'
New-Item -ItemType Directory -Path $webgl -Force | Out-Null
Write-Utf8File (Join-Path $webgl 'index.html') '<p>Obsolete custom launcher</p>'
Write-Utf8File (Join-Path $webgl 'idle_hands.wasm') 'fixture'
Write-Utf8File (Join-Path $webgl 'old_windows.zip') 'fixture'
Write-Utf8File (Join-Path $webgl 'bug-report.js') 'fixture'
$info = [pscustomobject]@{
    ProjectRoot = $projectRoot; ProjectSlug = 'idle_hands'
    DistDir = $fixture; WebGLDir = $webgl; WasmFileName = 'idle_hands.wasm'
}
$package = New-ItchHtml5Package $info
$index = Get-Content (Join-Path $package 'index.html') -Raw
Assert-Shell ($index -match 'data-platform="itch"') 'Staging did not regenerate the canonical itch launcher.'
Assert-Shell (-not (Test-Path (Join-Path $package 'old_windows.zip'))) 'Windows download leaked into HTML5 staging.'
Assert-Shell (-not (Test-Path (Join-Path $package 'bug-report.js'))) 'Bug widget leaked into HTML5 staging.'
Assert-Shell ($index -notmatch 'bug-report|ko-fi|Obsolete custom launcher') 'Stale site shell survived staging.'
Write-Host "Web shell checks passed: $count pages across $($projects.Count) games, plus standalone itch staging."
Write-Host "Browser fixtures: $OutputDir"
