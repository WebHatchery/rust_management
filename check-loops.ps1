<#
.SYNOPSIS
    Reports which live Claude Code sessions have an armed /loop.

.DESCRIPTION
    Loop state is session-scoped, so no session can see another's loops:
    CronList only reports the current session's jobs, and a dynamic (self-paced)
    /loop exposes nothing queryable at all. check-loops.py reconstructs the
    picture from ~/.claude/sessions and the per-session transcripts, replaying
    the ScheduleWakeup / CronCreate / CronDelete events to see what is still
    armed. This is a thin PowerShell wrapper around it.

.PARAMETER ArmedOnly
    Hide sessions with no armed loop.
#>
[CmdletBinding()]
param(
    [switch]$ArmedOnly
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'check-loops.py'
if (-not (Test-Path $script)) {
    throw "Script not found: $script"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) {
    throw "Python not found on PATH. Install Python, or run `"python $script`" another way."
}

$arguments = @($script)
if ($ArmedOnly) { $arguments += '--armed-only' }

$global:LASTEXITCODE = 0
& $python.Source @arguments
exit $LASTEXITCODE
