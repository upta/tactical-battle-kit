# The in-engine validation gate: the scenario suite under src/validation/scenarios,
# parallel with a serial re-run of failures, screenshots included. This is the
# half of verification that needs a windowed engine; ./simulate.ps1 is the
# headless half. Requires PowerShell 7 (the runner fans out with
# ForEach-Object -Parallel).
#
#   ./validate.ps1                  # the Definition-of-Done gate
#   ./validate.ps1 -RepeatCount 3   # flakiness check
param(
    [int]$RepeatCount = 1,
    [string]$GodotExe = $env:GODOT_EXE
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $root "tools/run_all_scenarios.ps1"
if (-not (Test-Path $runner)) {
    Write-Host "tools/run_all_scenarios.ps1 is missing: run ./setup.ps1 to materialize the validation kit symlinks." -ForegroundColor Red
    exit 2
}

$runnerArgs = @("-ProjectPath", (Join-Path $root "src"), "-RepeatCount", $RepeatCount)
if ($GodotExe) { $runnerArgs += @("-GodotExe", $GodotExe) }

& pwsh -NoProfile -File $runner @runnerArgs
exit $LASTEXITCODE
