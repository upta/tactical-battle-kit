# The balance gate: run every sim suite under src/sim/suites headlessly and
# fail if any suite fails. No window, no validation kit, no import race: this
# is the half of verification that runs in CI.
#
#   ./simulate.ps1                       # every suite
#   ./simulate.ps1 -Suite skirmish_mirror_is_fair
#   ./simulate.ps1 -Runs 500 -Seed 7     # override the suite's counts
#   ./simulate.ps1 -Suite x -Trace       # keep one run's full event log
#   ./simulate.ps1 -ProjectPath example-game   # any project that has the addon
#
# This is a thin wrapper: sim_cli.gd --suites does the discovery, the runs and
# the verdict, and prints a RESULT line per suite plus a SUMMARY line. This
# script imports, launches once, and renders those lines. A Linux CI needs no
# copy of it; the raw command is in sim_cli.gd's header.
param(
    [string]$Suite = "",
    [int]$Runs = 0,
    [int]$Seed = -1,
    [switch]$Trace,
    # Skip the import pass. Only safe when no script with a class_name and no
    # scene changed since the last import.
    [switch]$SkipImport,
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
$suiteRes = "res://" + $SuiteDir.TrimEnd("/")
if ($Suite) {
    $file = @(Get-ChildItem -Path $suitePath -Filter "*.json" -File | Where-Object { $_.BaseName -eq $Suite -or $_.Name -eq $Suite })
    if ($file.Count -eq 0) {
        Write-Host "No suite named '$Suite' under $suitePath." -ForegroundColor Red
        exit 2
    }
    $selector = @("--suite", ($suiteRes + "/" + $file[0].Name))
} else {
    $selector = @("--suites", $suiteRes)
}

# Import every time, not only on a cold cache: the class cache is what makes
# a project's class_name declarations resolvable, and a suite that ran against
# a stale cache fails with "Identifier not declared" on the class you just
# added. It is seconds; -SkipImport is there for a tight inner loop.
if (-not $SkipImport) {
    Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--import", "--path", $project -Wait -WindowStyle Hidden | Out-Null
}

# One log per project, so two projects (or two terminals) can run at once.
$log = Join-Path $env:TEMP ("sim_suites_{0}.log" -f (Split-Path -Leaf $project))
if (Test-Path $log) { Remove-Item $log }
$args = @(
    "--headless", "--path", $project,
    "--script", "res://addons/tactical_battle_kit/sim/sim_cli.gd",
    "--log-file", $log,
    "--"
) + $selector
if ($Runs -gt 0) { $args += @("--runs", $Runs) }
if ($Seed -ge 0) { $args += @("--seed", $Seed) }
if ($Trace) { $args += "--trace" }

Write-Host ("Running suites under {0}..." -f $suitePath) -ForegroundColor Cyan
$proc = Start-Process -FilePath $GodotExe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
$lines = if (Test-Path $log) { @(Get-Content $log) } else { @() }
$errors = @($lines | Where-Object { $_ -match '^(USER |SCRIPT )?ERROR:' })

$results = @()
$worst = 0
foreach ($line in @($lines | Where-Object { $_ -match '^RESULT ' })) {
    $json = $line.Substring(7) | ConvertFrom-Json
    $results += [pscustomobject]@{ Suite = $json.suite_id; Status = $json.status; Exit = [int]$json.exit_code; Ms = $json.duration_msec }
    $worst = [Math]::Max($worst, [int]$json.exit_code)
}
$lines | Where-Object { $_ -match '^(FAILED|ARTIFACTS) ' } | ForEach-Object { Write-Host ("  " + $_) }
$errors | Select-Object -First 5 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }

# The printed verdict is the verdict. The process exit code only matters when
# the run never printed one: Godot mono builds sometimes die with an access
# violation during teardown (negative exit code) after every artifact is
# already written. A whole-directory run must end with SUMMARY; a single
# suite has only its RESULT. Missing either means the engine died mid-run.
$summaryLine = $lines | Where-Object { $_ -match '^SUMMARY ' } | Select-Object -Last 1
if ($summaryLine) {
    $worst = [Math]::Max($worst, [int](($summaryLine.Substring(8) | ConvertFrom-Json).exit_code))
} elseif (-not $Suite -or $results.Count -eq 0) {
    Write-Host ("No verdict printed (process exit {0}); see {1}" -f $proc.ExitCode, $log) -ForegroundColor Red
    $worst = 2
}
if ($errors.Count -gt 0) { $worst = [Math]::Max($worst, 2) }

# After a whole-directory run in the kit's own project, prove the report
# pages: well-formed markup with the sections each report implies. The
# checker is a repo tool (src/tools), so a consumer's copy of this script
# skips it.
$checker = Join-Path $project "tools/check_reports.gd"
if (-not $Suite -and (Test-Path $checker)) {
    $checkLog = Join-Path $env:TEMP "check_reports.log"
    if (Test-Path $checkLog) { Remove-Item $checkLog }
    Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--path", $project, "--script", "res://tools/check_reports.gd", "--log-file", $checkLog -Wait -WindowStyle Hidden | Out-Null
    $checkLines = if (Test-Path $checkLog) { @(Get-Content $checkLog) } else { @() }
    $checkLines | Where-Object { $_ -match '^REPORT ' } | ForEach-Object { Write-Host ("  " + $_) }
    if (-not ($checkLines | Where-Object { $_ -match '^REPORT CHECK COMPLETE: [1-9][0-9]* pages, 0 failures' })) {
        Write-Host "Report pages FAILED their check; see $checkLog" -ForegroundColor Red
        $worst = [Math]::Max($worst, 2)
    }
}

Write-Host ""
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($worst -ne 0) {
    Write-Host ("Sim suites FAILED (worst exit {0}); log: {1}" -f $worst, $log) -ForegroundColor Red
} else {
    Write-Host "All sim suites passed."  -ForegroundColor Green
}
exit $worst
