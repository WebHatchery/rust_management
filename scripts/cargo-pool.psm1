# A lease covers Cargo and consumers of its outputs, never an interactive game.
Set-StrictMode -Version Latest
$script:activeLease = $null

function Get-RustGameBuildPolicy {
    $policy = Get-Content (Join-Path $PSScriptRoot '../workspace/build-policy.json') -Raw | ConvertFrom-Json
    if ($policy.slots -lt 1 -or $policy.slots -gt 16 -or $policy.jobs_per_slot -lt 1) {
        throw 'Build policy requires 1-16 slots and at least one compiler job per slot.'
    }
    return $policy
}

function Assert-RustGameMacroquad {
    param([string]$ProjectRoot)
    $policy = Get-RustGameBuildPolicy
    $manifest = Join-Path $ProjectRoot 'Cargo.toml'
    $pin = [regex]::Escape('"=' + $policy.macroquad_version + '"')
    $content = Get-Content -LiteralPath $manifest -Raw
    if ($content -notmatch "(?m)^macroquad\s*=\s*(?:\{\s*version\s*=\s*)?$pin") {
        throw "Macroquad must be pinned to =$($policy.macroquad_version) in $manifest."
    }
    $json = & cargo metadata --manifest-path $manifest --format-version 1 --locked
    if ($LASTEXITCODE -ne 0) { throw 'Cannot verify the locked Macroquad version. Resolve dependencies before publishing.' }
    $metadata = $json | ConvertFrom-Json
    $versions = @($metadata.packages | Where-Object name -eq 'macroquad' | Select-Object -ExpandProperty version -Unique)
    if ($versions.Count -ne 1 -or $versions[0] -ne $policy.macroquad_version) {
        throw "The resolved Macroquad version must be $($policy.macroquad_version); found $($versions -join ', ')."
    }
}

function Get-PoolProjectKey {
    param([string]$ProjectRoot)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($ProjectRoot.ToLowerInvariant())
        ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 20)
    } finally { $sha.Dispose() }
}

function Open-PoolLock {
    param([string]$Path)
    try {
        return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
        # Windows sharing/lock violations mean another process owns the lease.
        if (($_.Exception.HResult -band 0xffff) -in @(32, 33)) { return $null }
        throw
    }
}

function Enter-RustGameBuildPool {
    param(
        [string]$ProjectRoot = (Get-Location).Path,
        [ValidateSet('development', 'publish', 'capture')][string]$Purpose = 'development',
        [switch]$ReuseLast,
        [ValidateRange(0, 86400)][int]$TimeoutSeconds = 1800
    )
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot -ErrorAction Stop).Path
    if ($script:activeLease) {
        if ($script:activeLease.ProjectRoot -ne $ProjectRoot) { throw 'A nested build must use the same project.' }
        $script:activeLease.Depth++
        return $script:activeLease
    }
    $policy = Get-RustGameBuildPolicy
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $poolRoot = Join-Path $workspaceRoot 'target/pool'
    $stateRoot = Join-Path $poolRoot 'leases'
    [IO.Directory]::CreateDirectory($stateRoot) | Out-Null
    $key = Get-PoolProjectKey $ProjectRoot
    $statePath = Join-Path $stateRoot "$key-$Purpose.json"
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $projectLock = $null
    $slotLock = $null
    $savedEnv = @{}
    try {
        $reported = $false
        while (-not $projectLock) {
            $projectLock = Open-PoolLock (Join-Path $stateRoot "$key.lock")
            if ($projectLock) { break }
            if (-not $reported) { [Console]::Error.WriteLine('Waiting for another build of this project...'); $reported = $true }
            if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'Timed out waiting for the project build lease.' }
            Start-Sleep -Milliseconds 250
        }
        $preferred = ([Convert]::ToInt32($key.Substring(0, 6), 16) % [int]$policy.slots) + 1
        $previous = $null
        if (Test-Path -LiteralPath $statePath) {
            $previous = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            if ([int]$previous.slot -ge 1 -and [int]$previous.slot -le [int]$policy.slots) {
                $preferred = [int]$previous.slot
            } else {
                # Shrinking the idle pool must not keep admitting old slots.
                $previous = $null
            }
        }
        if ($ReuseLast -and -not $previous) { throw "No previous $Purpose build in the pool. Run once without SkipBuild." }
        $order = @($preferred) + @(1..[int]$policy.slots | Where-Object { $_ -ne $preferred })
        if ($ReuseLast) { $order = @($preferred) }
        $reported = $false
        while (-not $slotLock) {
            foreach ($candidate in $order) {
                $slotLock = Open-PoolLock (Join-Path $stateRoot "slot-$candidate.lock")
                if ($slotLock) { $slot = $candidate; break }
            }
            if ($slotLock) { break }
            if (-not $reported) { [Console]::Error.WriteLine('All eligible build slots are busy; waiting...'); $reported = $true }
            if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'Timed out waiting for a Cargo build slot.' }
            Start-Sleep -Milliseconds 250
        }
        $target = Join-Path $poolRoot "slot-$slot"
        [IO.Directory]::CreateDirectory($target) | Out-Null
        foreach ($name in @('CARGO_TARGET_DIR', 'CARGO_BUILD_BUILD_DIR', 'CARGO_BUILD_JOBS', 'RUSTC_WRAPPER', 'CARGO_INCREMENTAL', 'SCCACHE_CACHE_SIZE')) {
            $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        }
        $env:CARGO_TARGET_DIR = $target
        # A separate global build-dir must not silently reintroduce contention.
        $env:CARGO_BUILD_BUILD_DIR = $target
        $env:CARGO_BUILD_JOBS = [string]$policy.jobs_per_slot
        $cache = Get-Command sccache -CommandType Application -ErrorAction SilentlyContinue
        if (-not $cache) {
            # WinGet changes the user PATH, but already-open editors retain the
            # old process PATH until restarted. Discover the installed tool now.
            foreach ($directory in ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';')) {
                if (-not $directory) { continue }
                $candidate = Join-Path $directory 'sccache.exe'
                if (Test-Path -LiteralPath $candidate) { $cache = Get-Command $candidate; break }
            }
        }
        if ($policy.sccache -and $cache) {
            $env:RUSTC_WRAPPER = $cache.Source
            $env:CARGO_INCREMENTAL = '0'
            if (-not $env:SCCACHE_CACHE_SIZE) { $env:SCCACHE_CACHE_SIZE = $policy.sccache_cache_size }
        } elseif ($policy.sccache) {
            Write-Warning 'sccache is not installed; this lease uses ordinary Cargo compilation. See docs/CARGO_WORKSPACE.md.'
        }
        $script:activeLease = [pscustomobject]@{
            ProjectRoot = $ProjectRoot; TargetDir = $target; Slot = $slot; Depth = 1
            ProjectLock = $projectLock; SlotLock = $slotLock; SavedEnv = $savedEnv
            StatePath = $statePath; Released = $false
        }
        [Console]::Error.WriteLine("Cargo pool: slot $slot ($($policy.jobs_per_slot) compiler jobs).")
        return $script:activeLease
    } catch {
        foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
        if ($slotLock) { $slotLock.Dispose() }
        if ($projectLock) { $projectLock.Dispose() }
        throw
    }
}

function Save-RustGameBuildLocation {
    param($Lease)
    # Save only after a successful build; SkipBuild must never choose a new slot.
    @{ slot = $Lease.Slot } | ConvertTo-Json | Set-Content -LiteralPath $Lease.StatePath -Encoding UTF8
}

function Invoke-RustGameCargo {
    param([string[]]$Arguments)
    if (-not $script:activeLease) { throw 'Cargo compilation requires an active build-pool lease.' }
    # sccache 0.17 hashes CARGO_* environment values, including target/build
    # directories. Use equivalent Cargo CLI configuration during compilation
    # so slot-specific environment values do not defeat cross-slot cache hits.
    # Metadata still sees the lease environment outside this call.
    $targetEnv = $env:CARGO_TARGET_DIR
    $buildEnv = $env:CARGO_BUILD_BUILD_DIR
    $path = $script:activeLease.TargetDir | ConvertTo-Json -Compress
    try {
        Remove-Item Env:CARGO_TARGET_DIR, Env:CARGO_BUILD_BUILD_DIR -ErrorAction SilentlyContinue
        & cargo --config "build.target-dir=$path" --config "build.build-dir=$path" @Arguments
        $global:LASTEXITCODE = $LASTEXITCODE
    } finally {
        $env:CARGO_TARGET_DIR = $targetEnv
        $env:CARGO_BUILD_BUILD_DIR = $buildEnv
    }
}

function Exit-RustGameBuildPool {
    param($Lease)
    if (-not $Lease -or $Lease.Released) { return }
    $Lease.Depth--
    if ($Lease.Depth -gt 0) { return }
    try {
        foreach ($name in $Lease.SavedEnv.Keys) {
            [Environment]::SetEnvironmentVariable($name, $Lease.SavedEnv[$name], 'Process')
        }
    } finally {
        $Lease.SlotLock.Dispose()
        $Lease.ProjectLock.Dispose()
        $Lease.Released = $true
        $script:activeLease = $null
    }
}

Export-ModuleMember -Function Get-RustGameBuildPolicy, Assert-RustGameMacroquad, Enter-RustGameBuildPool, Exit-RustGameBuildPool, Save-RustGameBuildLocation, Invoke-RustGameCargo
