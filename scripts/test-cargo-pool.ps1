# Real process/OS-lock integration checks. Uses only standard target/pool state;
# no fabricated Cargo projects, copied source trees, or alternate manifests.
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'cargo-pool.psm1'
$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module $modulePath
function Assert-PoolTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$workers = @()
$lease = $null
$environmentNames = @('CARGO_TARGET_DIR', 'CARGO_BUILD_BUILD_DIR', 'RUSTC_WRAPPER', 'CARGO_INCREMENTAL', 'CARGO_BUILD_JOBS', 'SCCACHE_CACHE_SIZE')
$originalEnv = @{}
foreach ($name in $environmentNames) {
    $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $policy = Get-RustGameBuildPolicy
    Assert-PoolTest ($policy.slots -eq 3) 'This saturation test expects the default three-slot policy.'
    foreach ($game in @('alchemy_tower', 'apartment', 'auction_game')) {
        $workers += Start-Job -ArgumentList $modulePath, (Join-Path $workspaceRoot $game) -ScriptBlock {
            param($ModulePath, $Project)
            $ErrorActionPreference = 'Stop'
            Import-Module $ModulePath
            $held = Enter-RustGameBuildPool -ProjectRoot $Project -TimeoutSeconds 15
            try {
                [pscustomobject]@{ Slot = $held.Slot; WorkerPid = $PID; Target = $env:CARGO_TARGET_DIR; Build = $env:CARGO_BUILD_BUILD_DIR }
                Start-Sleep -Seconds 45
            } finally { Exit-RustGameBuildPool $held }
        }
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $heldSlots = @(foreach ($worker in $workers) { Receive-Job $worker -Keep | Where-Object { $_.PSObject.Properties['Slot'] } })
        if ($heldSlots.Count -eq 3) { break }
        if ($timer.Elapsed.TotalSeconds -gt 25) { throw 'Concurrent workers failed to acquire three slots.' }
        Start-Sleep -Milliseconds 200
    } while ($true)
    Assert-PoolTest (@($heldSlots.Slot | Select-Object -Unique).Count -eq 3) 'Concurrent workers shared a slot.'
    Assert-PoolTest (@($heldSlots | Where-Object { $_.Target -ne $_.Build }).Count -eq 0) 'Build-dir escaped the pool.'
    Write-Host 'PASS: three concurrent projects occupy distinct slots.'

    $timedOut = $false
    try { $lease = Enter-RustGameBuildPool -ProjectRoot (Join-Path $workspaceRoot 'biofoundry') -TimeoutSeconds 0 }
    catch { $timedOut = $_.Exception.Message -like '*Cargo build slot*' }
    Assert-PoolTest $timedOut 'The fourth build bypassed pool capacity.'
    Write-Host 'PASS: pool saturation has a bounded wait.'

    $timedOut = $false
    try { $lease = Enter-RustGameBuildPool -ProjectRoot (Join-Path $workspaceRoot 'apartment') -TimeoutSeconds 0 }
    catch { $timedOut = $_.Exception.Message -like '*project build lease*' }
    Assert-PoolTest $timedOut 'Two builds of the same project were admitted.'
    Write-Host 'PASS: concurrent builds of one project serialize.'

    # Kill only the process ID reported by our own child job. The OS must free
    # its lease even if PowerShell cannot execute finally.
    Stop-Process -Id $heldSlots[0].WorkerPid -Force
    $lease = Enter-RustGameBuildPool -ProjectRoot (Join-Path $workspaceRoot 'biofoundry') -TimeoutSeconds 5
    Assert-PoolTest ($lease.Slot -eq $heldSlots[0].Slot) 'A terminated process stranded a slot.'
    Exit-RustGameBuildPool $lease
    $lease = $null
    Write-Host 'PASS: abrupt process termination releases the OS lease.'

    foreach ($scenario in @(
        @{ Label = 'unset'; Value = $null },
        @{ Label = 'configured'; Value = 'caller-setting' },
        @{ Label = 'empty'; Value = '' }
    )) {
        $before = @{}
        foreach ($name in $environmentNames) {
            if ($null -eq $scenario.Value) {
                Remove-Item "Env:$name" -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable($name, $scenario.Value, 'Process')
            }
            $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        }
        # Older PowerShell/.NET versions cannot retain empty environment values.
        if ($scenario.Label -eq 'empty' -and $null -eq $before['CARGO_TARGET_DIR']) { continue }
        foreach ($consumerFails in @($false, $true)) {
            try {
                $lease = Enter-RustGameBuildPool -ProjectRoot (Join-Path $workspaceRoot 'biofoundry') -TimeoutSeconds 5
                if ($consumerFails) { throw 'simulated consumer failure' }
            } catch {
                Assert-PoolTest ($consumerFails -and $_.Exception.Message -eq 'simulated consumer failure') "Unexpected lease failure: $_"
            } finally { Exit-RustGameBuildPool $lease; $lease = $null }
            foreach ($name in $before.Keys) {
                Assert-PoolTest ((Test-Path "Env:$name") -eq ($null -ne $before[$name])) "Changed environment presence ($($scenario.Label)): $name"
                Assert-PoolTest ([Environment]::GetEnvironmentVariable($name, 'Process') -ceq $before[$name]) "Leaked environment setting ($($scenario.Label)): $name"
            }
        }
    }
    Write-Host 'PASS: successful and failed consumers preserve unset, configured and supported empty environment values.'
} finally {
    Exit-RustGameBuildPool $lease
    foreach ($worker in $workers) { Stop-Job $worker -ErrorAction SilentlyContinue; Remove-Job $worker -Force -ErrorAction SilentlyContinue }
    foreach ($name in $originalEnv.Keys) {
        if ($null -eq $originalEnv[$name]) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($name, $originalEnv[$name], 'Process') }
    }
}
