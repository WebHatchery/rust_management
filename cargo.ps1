# Forward Cargo arguments verbatim. In PowerShell quote '--' so the shell does
# not consume it before this script receives compiler/test/game arguments.
# Do not add a param block: these are Cargo's options, not PowerShell options.
$ErrorActionPreference = 'Stop'
$cargoArguments = @($args)
if ($cargoArguments.Count -eq 0) { throw 'Usage: cargo.ps1 <check|build|test|clippy|run|...> [Cargo arguments]' }
Import-Module (Join-Path $PSScriptRoot 'scripts/cargo-pool.psm1')
if ($cargoArguments[0] -eq 'clean') { throw 'Pool caches are shared. Clean them only during coordinated maintenance, outside this launcher.' }
if ($cargoArguments[0] -notin @('check', 'build', 'test', 'clippy', 'run', 'rustc', 'doc', 'bench', 'b', 'c', 't', 'r')) {
    if ($cargoArguments[0] -notin @('fmt', 'metadata', 'locate-project', 'tree', 'fetch', 'update', 'generate-lockfile', 'version', '--version', '-V', 'help', '--help', '-h')) {
        throw 'Use a supported Cargo subcommand first; custom aliases and leading toolchain/global options cannot bypass the pool.'
    }
    & cargo @cargoArguments
    exit $LASTEXITCODE
}
# Output overrides bypass the lease. Use policy settings rather than per-call caches.
$separator = [Array]::IndexOf($cargoArguments, '--')
if ($cargoArguments[0] -eq 'clippy' -and $separator -lt 0 -and @($cargoArguments | Where-Object { $_ -match '^-[ADWF](.*)$' }).Count) {
    throw "PowerShell consumes bare -- for scripts. Use '--' before compiler flags, for example clippy '--' -D warnings."
}
$buildArguments = if ($separator -ge 0) { @($cargoArguments | Select-Object -First $separator) } else { $cargoArguments }
if (@($buildArguments | Where-Object { $_ -match '^--(target-dir|config)(=|$)' }).Count) {
    throw 'The pool owns target-dir and configuration. Put shared options in workspace configuration.'
}
if ($cargoArguments[0] -in @('run', 'r') -and @($buildArguments | Where-Object { $_ -match '^--message-format(=|$)' }).Count) {
    throw 'Pooled run reserves message-format to discover the executable.'
}
$projectRoot = (Get-Location).Path
for ($i = 0; $i -lt $buildArguments.Count; $i++) {
    if ($buildArguments[$i] -eq '--manifest-path') { $projectRoot = Split-Path (Resolve-Path $buildArguments[$i + 1]).Path -Parent }
    elseif ($buildArguments[$i] -like '--manifest-path=*') { $projectRoot = Split-Path (Resolve-Path $buildArguments[$i].Substring(16)).Path -Parent }
}
$lease = $null
$stagedFiles = @()
$code = 1
try {
    $lease = Enter-RustGameBuildPool -ProjectRoot $projectRoot
    if ($cargoArguments[0] -in @('run', 'r')) {
        $runArguments = if ($separator -ge 0) { @($cargoArguments | Select-Object -Skip ($separator + 1)) } else { @() }
        $compileArguments = @('build', '--message-format=json-render-diagnostics') + @($buildArguments | Select-Object -Skip 1)
        $executables = @(Invoke-RustGameCargo -Arguments $compileArguments | ForEach-Object {
            $message = $_ | ConvertFrom-Json
            if ($message.reason -eq 'compiler-artifact' -and $message.executable -and -not $message.profile.test) { $message.executable }
        })
        $code = $LASTEXITCODE
        if ($code -ne 0) { exit $code }
        if ($executables.Count -ne 1) { throw 'Select exactly one executable with --bin or --example.' }
        $source = $executables[0]
        if ([IO.Path]::GetExtension($source) -ne '.exe') { throw 'Pooled run supports native Windows executables; use publishing for WebGL.' }
        $runRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'target/run'
        [IO.Directory]::CreateDirectory($runRoot) | Out-Null
        $executable = Join-Path $runRoot ("{0}-{1}.exe" -f [IO.Path]::GetFileNameWithoutExtension($source), [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $source -Destination $executable
        $stagedFiles += $executable
        Save-RustGameBuildLocation $lease
        # Retain the game working directory for assets and saves, but release the
        # compiler slot before the player's window starts.
        Exit-RustGameBuildPool $lease
        & $executable @runArguments
        $code = $LASTEXITCODE
    } else {
        Invoke-RustGameCargo -Arguments $cargoArguments
        $code = $LASTEXITCODE
        if ($code -eq 0) { Save-RustGameBuildLocation $lease }
    }
} finally {
    Exit-RustGameBuildPool $lease
    foreach ($file in $stagedFiles) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
}
exit $code
