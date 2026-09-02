# gdformat + gdlint over the game's own scripts — addons/ (vendored) excluded.
# Uses gdtoolkit (pip3 install "gdtoolkit==4.*"); degrades with instructions
# when it isn't installed rather than failing mysteriously.
param(
    # Rewrite files with gdformat instead of just checking them.
    [switch]$Fix
)

$ErrorActionPreference = "Stop"

if ($null -eq (Get-Command gdformat -ErrorAction SilentlyContinue)) {
    Write-Host "gdtoolkit is not installed (gdformat/gdlint not on PATH)." -ForegroundColor Yellow
    Write-Host 'Install it with:  pip3 install "gdtoolkit==4.*"' -ForegroundColor Yellow
    exit 2
}

# This script lives at src/tools/; the Godot project is its parent.
$projectPath = Split-Path -Parent $PSScriptRoot
$files = @(Get-ChildItem -Path $projectPath -Recurse -Filter *.gd -File |
        Where-Object { $_.FullName -notmatch "\\addons\\" -and $_.FullName -notmatch "\\.godot\\" } |
        ForEach-Object { $_.FullName })

if ($files.Count -eq 0) {
    Write-Host "No scripts to lint." -ForegroundColor Yellow
    exit 0
}

Write-Host "Checking $($files.Count) script(s)..." -ForegroundColor Cyan

if ($Fix) {
    & gdformat @files
} else {
    & gdformat --check @files
}
$formatExit = $LASTEXITCODE

& gdlint @files
$lintExit = $LASTEXITCODE

if ($formatExit -ne 0 -or $lintExit -ne 0) {
    Write-Host ""
    Write-Host "Lint failed (gdformat=$formatExit, gdlint=$lintExit). Run with -Fix to apply formatting." -ForegroundColor Red
    exit 1
}

Write-Host "Format and lint clean." -ForegroundColor Green
exit 0
