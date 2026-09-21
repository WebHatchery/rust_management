param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$path = Join-Path $ProjectRoot '.vscode/settings.json'
$settings = @{}
if (Test-Path -LiteralPath $path) {
    $existing = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    foreach ($property in $existing.PSObject.Properties) { $settings[$property.Name] = $property.Value }
}
$command = @('powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'cargo.ps1'), 'check', '--message-format=json', '--all-targets')
$settings['rust-analyzer.check.overrideCommand'] = $command
$settings['rust-analyzer.cargo.buildScripts.overrideCommand'] = $command
# Run the command once for this editor window, rather than once per discovered
# workspace (which can include separate client/server workspaces).
$settings['rust-analyzer.check.invocationStrategy'] = 'once'
$settings['rust-analyzer.cargo.buildScripts.invocationStrategy'] = 'once'
[IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
$settings | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Configured pooled rust-analyzer checks in $path"
