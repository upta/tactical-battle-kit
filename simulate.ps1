# The balance gate: run every sim suite under src/sim/suites headlessly and
# fail if any suite fails. No window, no validation kit, no import race: this
# is the half of verification that runs in CI.
#
#   ./simulate.ps1                       # every suite
#   ./simulate.ps1 -Suite skirmish_mirror_is_fair
#   ./simulate.ps1 -Runs 500 -Seed 7     # override the suite's counts
#   ./simulate.ps1 -Suite x -Trace       # keep one run's full event log
param(
    [string]$Suite = "",
    [int]$Runs = 0,
    [int]$Seed = -1,
    [switch]$Trace,
    [string]$GodotExe = $env:GODOT_EXE,
    # The Godot project to run in. Defaults to src/ (this repo's layout) or the
    # script's own directory when it holds project.godot, so a consumer can copy
    # this file to its root unchanged.
    [string]$ProjectPath = "",
    # Suite directory relative to the project.
    [string]$SuiteDir = "sim/suites"
)

$ErrorActionPreference = "Stop"

if (-not $GodotExe) {
    $command = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        Write-Host "Could not locate godot.exe. Set GODOT_EXE or put Godot on PATH." -ForegroundColor Red
        exit 2
    }
    $GodotExe = $command.Source
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectPath) {
    $ProjectPath = if (Test-Path (Join-Path $root "src/project.godot")) { Join-Path $root "src" } else { $root }
}
$project = (Resolve-Path $ProjectPath).Path
# PowerShell variables are case-insensitive: this must not be named $suiteDir.
$suitePath = Join-Path $project $SuiteDir
$suites = @(Get-ChildItem -Path $suitePath -Filter "*.json" -File | Sort-Object Name)
if ($Suite) {
    $suites = @($suites | Where-Object { $_.BaseName -eq $Suite -or $_.Name -eq $Suite })
    if ($suites.Count -eq 0) {
        Write-Host "No suite named '$Suite' under $suitePath." -ForegroundColor Red
        exit 2
    }
}

# A cold .godot cache makes the first launch import assets; do it once up front
# so suite output is not interleaved with import chatter.
if (-not (Test-Path (Join-Path $project ".godot/imported"))) {
    Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--import", "--path", $project -Wait -WindowStyle Hidden | Out-Null
}

$results = @()
$worst = 0
foreach ($file in $suites) {
    $log = Join-Path $env:TEMP ("sim_{0}.log" -f $file.BaseName)
    $args = @(
        "--headless", "--path", $project,
        "--script", "res://addons/tactical_battle_kit/sim/sim_cli.gd",
        "--log-file", $log,
        "--", "--suite", ("res://" + $SuiteDir.TrimEnd("/") + "/" + $file.Name)
    )
    if ($Runs -gt 0) { $args += @("--runs", $Runs) }
    if ($Seed -ge 0) { $args += @("--seed", $Seed) }
    if ($Trace) { $args += "--trace" }

    Write-Host ("Running {0}..." -f $file.BaseName) -ForegroundColor Cyan
    $proc = Start-Process -FilePath $GodotExe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
    $resultLine = if (Test-Path $log) { (Select-String -Path $log -Pattern '^RESULT ' | Select-Object -Last 1).Line } else { $null }
    $errors = if (Test-Path $log) { @(Select-String -Path $log -Pattern '^(USER |SCRIPT )?ERROR:' ) } else { @() }
    $status = "runtime_error"
    $duration = 0
    if ($resultLine) {
        $json = $resultLine.Substring(7) | ConvertFrom-Json
        $status = $json.status
        $duration = $json.duration_msec
    }
    if ($errors.Count -gt 0 -and $status -eq "pass") { $status = "runtime_error (log has ERROR lines)" }
    # The RESULT line is the verdict. The process exit code only matters when the run never
    # printed one: Godot mono builds sometimes die with an access violation during teardown
    # (negative exit code) after every artifact is already written.
    $code = if ($resultLine) { [int]$json.exit_code } else { 2 }
    if ($errors.Count -gt 0 -and $code -eq 0) { $code = 2 }
    if ($code -ne 0) { $worst = [Math]::Max($worst, $code) }
    $results += [pscustomobject]@{ Suite = $file.BaseName; Status = $status; Exit = $code; Ms = $duration; Log = $log }
    if (Test-Path $log) {
        Select-String -Path $log -Pattern '^(FAILED|ARTIFACTS) ' | ForEach-Object { Write-Host ("  " + $_.Line) }
        $errors | Select-Object -First 5 | ForEach-Object { Write-Host ("  " + $_.Line) -ForegroundColor Red }
    }
}

Write-Host ""
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($worst -ne 0) {
    Write-Host "Sim suites FAILED (worst exit $worst)." -ForegroundColor Red
} else {
    Write-Host "All sim suites passed." -ForegroundColor Green
}
exit $worst
