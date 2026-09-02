# Project-wide GDScript compile gate: import, then load every project-owned
# script and scene through a headless RUNTIME pass and fail on what that run
# logs.
#
# Deliberately not an editor pass. `--editor --quit-after N` compiles nothing:
# it registers global class names from a parse that discards errors, so a file
# of pure garbage came back "clean" at every frame count tried — and so did a
# duplicate dictionary key, the parse error the engine only raises on
# GDScript::reload. That false green cost an unattended run a full debug cycle,
# with all ten scenarios failing against a scene whose script had silently
# dropped off. Per-file `--check-only` is no use either: it false-errors on
# anything referencing an autoload (godot#78587). ResourceLoader.load() is the
# only thing that actually compiles, so compile_check.gd loads everything.
#
# Three gates, because silence used to read as success: the completion marker
# must be present with a nonzero script count, the exit code must be 0, and the
# runtime log must have zero ERROR lines. Runtime logs are strict on purpose —
# the 4.7.1 UID noise CLAUDE.md documents is editor-mode only, which is also
# why the import pass below is gated on its exit code alone.
param(
    [string]$GodotExe = $env:GODOT_EXE
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

# This script lives at src/tools/; the Godot project is its parent.
$projectPath = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP ("check_scripts_{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$marker = "COMPILE CHECK COMPLETE"

Write-Host "Importing..." -ForegroundColor Cyan
$import = Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--import", "--path", $projectPath -Wait -PassThru -WindowStyle Hidden
if ($import.ExitCode -ne 0) {
    Write-Host "Import failed with exit code $($import.ExitCode)." -ForegroundColor Red
    exit 1
}

Write-Host "Loading every script and scene (headless runtime pass)..." -ForegroundColor Cyan
$compileArgs = @(
    "--headless",
    "--path", $projectPath,
    "--script", "res://tools/compile_check.gd",
    "--log-file", $log
)
$compile = Start-Process -FilePath $GodotExe -ArgumentList $compileArgs -Wait -PassThru -WindowStyle Hidden

if (-not (Test-Path $log)) {
    Write-Host "The compile pass wrote no log to $log." -ForegroundColor Red
    exit 1
}

$failed = $false

# compile_check.gd's own verdict first, then the engine's raw diagnostics: the
# trailing context line is the `at:` location, which names the offending file.
$compileFails = @(Select-String -Path $log -Pattern "^COMPILE FAIL:")
$logErrors = @(Select-String -Path $log -Pattern "^(USER |SCRIPT )?ERROR:" -Context 0, 1)
if ($compileFails.Count -gt 0 -or $logErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "Script errors found:" -ForegroundColor Red
    $compileFails | ForEach-Object { Write-Host $_.Line }
    $logErrors | ForEach-Object { Write-Host $_.Line; $_.Context.PostContext | ForEach-Object { Write-Host "  $_" } }
    $failed = $true
}

$markerLine = @(Get-Content $log | Where-Object { $_.StartsWith($marker) })[0]
if (-not $markerLine) {
    Write-Host ""
    Write-Host "The compile pass never finished: no '$marker' line in the log." -ForegroundColor Red
    $failed = $true
}
else {
    # A walk that reached nothing would otherwise pass every other gate.
    $counted = [regex]::Match($markerLine, "(\d+) scripts")
    if (-not $counted.Success -or [int]$counted.Groups[1].Value -lt 1) {
        Write-Host ""
        Write-Host "The compile pass walked no scripts: $markerLine" -ForegroundColor Red
        $failed = $true
    }
}

if ($compile.ExitCode -ne 0) {
    Write-Host ""
    Write-Host "Compile pass failed with exit code $($compile.ExitCode)." -ForegroundColor Red
    $failed = $true
}

if ($failed) {
    Write-Host ""
    Write-Host "Full log: $log"
    exit 1
}

Write-Host $markerLine -ForegroundColor Green
exit 0
