# Export the Web preset and PROVE it produced a build. The exit code is not
# the check: godot --export-release exits 0 on an unknown preset having
# written nothing - the files' existence and size are the check.
#
# Self-sufficient on a fresh machine: web export needs the STANDARD editor -
# Godot 4's mono editor refuses web export outright, even for a pure-GDScript
# project, and the mono template bundle ships no web templates at all. If the
# resolved godot is mono (or missing, or the wrong version), a standard
# editor is downloaded to a local cache; the matching standard template
# bundle is installed on first use either way.
param(
    [string]$GodotExe = $env:GODOT_EXE,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

# Must match deploy.yml's GODOT_VERSION and src/project.godot's features tag.
$requiredVersion = "4.7.1"
$flavor = "stable"

$projectPath = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectPath
if (-not $OutDir) { $OutDir = Join-Path $repoRoot "build\web" }


function Get-GodotVersionInfo {
    param([string]$Exe)

    if (-not $Exe -or -not (Test-Path $Exe)) { return $null }
    $raw = (& $Exe --version 2>$null | Select-Object -First 1)
    if (-not $raw) { return $null }
    if ("$raw".Trim() -notmatch "^(\d+\.\d+(?:\.\d+)?)\.([a-z0-9]+)\.(mono\.)?") { return $null }
    return @{ Version = $Matches[1]; Flavor = $Matches[2]; IsMono = [bool]$Matches[3] }
}


function Install-StandardTemplatesIfMissing {
    $targetDir = Join-Path $env:APPDATA "Godot\export_templates\$requiredVersion.$flavor"
    if (Test-Path (Join-Path $targetDir "web_nothreads_release.zip")) { return }

    $tpzName = "Godot_v$requiredVersion-${flavor}_export_templates.tpz"
    $url = "https://github.com/godotengine/godot/releases/download/$requiredVersion-$flavor/$tpzName"
    $tpzPath = Join-Path $env:TEMP $tpzName

    Write-Host "Standard export templates for $requiredVersion.$flavor are not installed." -ForegroundColor Yellow
    Write-Host "Downloading (~1 GB, one time): $url" -ForegroundColor Cyan
    # PS 5.1's progress rendering slows large downloads to a crawl.
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $url -OutFile $tpzPath

    Write-Host "Extracting..." -ForegroundColor Cyan
    $extractDir = Join-Path $env:TEMP "godot_export_templates_extract"
    if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # The tpz is a zip; ZipFile doesn't care about the extension
    # (Expand-Archive does).
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tpzPath, $extractDir)

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Move-Item -Path (Join-Path $extractDir "templates\*") -Destination $targetDir -Force
    Remove-Item $tpzPath -Force
    Remove-Item -Recurse -Force $extractDir
    Write-Host "Templates installed to $targetDir" -ForegroundColor Green
}


function Get-StandardEditor {
    $cacheDir = Join-Path $env:LOCALAPPDATA "Godot\editor_standard\$requiredVersion"
    $exePath = Join-Path $cacheDir "Godot_v$requiredVersion-${flavor}_win64.exe"
    if (Test-Path $exePath) { return $exePath }

    $zipName = "Godot_v$requiredVersion-${flavor}_win64.exe.zip"
    $url = "https://github.com/godotengine/godot/releases/download/$requiredVersion-$flavor/$zipName"
    $zipPath = Join-Path $env:TEMP $zipName

    Write-Host "Downloading the standard $requiredVersion editor (~55 MB, one time): $url" -ForegroundColor Cyan
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $cacheDir)
    Remove-Item $zipPath -Force

    if (-not (Test-Path $exePath)) {
        throw "Downloaded editor zip did not contain the expected exe: $exePath"
    }
    Write-Host "Standard editor cached at $exePath" -ForegroundColor Green
    return $exePath
}


# Resolve the export binary: the provided/PATH godot if it is a standard
# (non-mono) build of the required version, else the cached standard editor.
if (-not $GodotExe) {
    $command = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { $GodotExe = $command.Source }
}

$info = Get-GodotVersionInfo -Exe $GodotExe
if ($null -eq $info -or $info.IsMono -or $info.Version -ne $requiredVersion) {
    if ($null -ne $info -and $info.IsMono) {
        Write-Host "PATH godot is the mono build ($($info.Version).$($info.Flavor).mono), which cannot export web." -ForegroundColor Yellow
    }
    $GodotExe = Get-StandardEditor
}

Install-StandardTemplatesIfMissing

if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Write-Host "Exporting Web preset to $OutDir..." -ForegroundColor Cyan
$indexPath = Join-Path $OutDir "index.html"
$p = Start-Process -FilePath $GodotExe -ArgumentList "--headless", "--path", $projectPath, "--export-release", "Web", $indexPath -Wait -PassThru -WindowStyle Hidden
Write-Host "godot exit code: $($p.ExitCode) (informational - the files below are the check)"

$required = @("index.html", "index.pck", "index.wasm")
$missing = @()
foreach ($name in $required) {
    $path = Join-Path $OutDir $name
    if (-not (Test-Path $path) -or (Get-Item $path).Length -eq 0) { $missing += $name }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Export did NOT produce a build. Missing or empty: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host ""
Get-ChildItem $OutDir | ForEach-Object { Write-Host ("  {0,12:n0} bytes  {1}" -f $_.Length, $_.Name) }
Write-Host ""
Write-Host "Web build ready. Serve it with: powershell src/tools/serve_web.ps1" -ForegroundColor Green
exit 0
