# PowerShell setup script for Windows
# Creates/verifies junctions/symlinks for submodule addons and skills

param(
    [string]$ConfigFile = "symlink-config.txt"
)

Write-Host "Setting up submodule symlinks..." -ForegroundColor Green

# Get the script's directory (project root)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir $ConfigFile

# Check if config file exists
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found: $configPath" -ForegroundColor Red
    Write-Host "Expected format: target_path=source_path" -ForegroundColor Yellow
    exit 1
}

# Read and parse configuration
$linkConfigs = @()
Get-Content $configPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        if ($line -match "^(.+)=(.+)$") {
            $target = $matches[1].Trim()
            $source = $matches[2].Trim()
            $linkConfigs += @{
                Target = Join-Path $scriptDir $target
                Source = Join-Path $scriptDir $source
                TargetRel = $target
                SourceRel = $source
            }
        }
    }
}

if ($linkConfigs.Count -eq 0) {
    Write-Host "No symlink configurations found in $ConfigFile" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($linkConfigs.Count) symlink configuration(s)" -ForegroundColor Cyan
Write-Host ""

# Track changes made
$changesMade = @()

# Process each symlink configuration
foreach ($config in $linkConfigs) {
    $action = "NONE"

    # Check if source exists
    if (-not (Test-Path $config.Source)) {
        Write-Host "❌ $($config.TargetRel) -> ERROR: Source not found ($($config.SourceRel))" -ForegroundColor Red
        Write-Host "   Make sure submodules are initialized: git submodule update --init --recursive" -ForegroundColor Yellow
        continue
    }

    # Determine if source is a file or directory
    $sourceIsFile = (Get-Item $config.Source) -isnot [System.IO.DirectoryInfo]

    # Check current state of target
    $needsCreation = $true
    if (Test-Path $config.Target) {
        $item = Get-Item $config.Target -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            try {
                if ($sourceIsFile) {
                    $needsCreation = $false
                    Write-Host "✅ $($config.TargetRel) -> $($config.SourceRel) (already correct)" -ForegroundColor Green
                } else {
                    $testFiles = Get-ChildItem $config.Target -ErrorAction Stop
                    if ($testFiles.Count -gt 0) {
                        $needsCreation = $false
                        Write-Host "✅ $($config.TargetRel) -> $($config.SourceRel) (already correct)" -ForegroundColor Green
                    }
                }
            } catch {
                # Link might be broken, needs recreation
            }
        }

        if ($needsCreation) {
            Write-Host "🔄 $($config.TargetRel) -> $($config.SourceRel) (recreating)" -ForegroundColor Yellow
            Remove-Item -Path $config.Target -Recurse -Force
            $action = "RECREATED"
        }
    } else {
        Write-Host "➕ $($config.TargetRel) -> $($config.SourceRel) (creating)" -ForegroundColor Cyan
        $action = "CREATED"
    }

    # Create the symlink/junction if needed
    if ($needsCreation) {
        # Create parent directory if needed
        $targetParent = Split-Path $config.Target -Parent
        if (-not (Test-Path $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }

        # Calculate relative path for the symlink. Resolve-Path -Relative instead of
        # [System.IO.Path]::GetRelativePath, which is .NET Core-only — under Windows
        # PowerShell 5.1 it throws MethodNotFound and only the junction fallback saved us.
        Push-Location (Split-Path $config.Target -Parent)
        try { $relativePath = (Resolve-Path -Path $config.Source -Relative) } finally { Pop-Location }

        if ($sourceIsFile) {
            # File symlink
            $result = cmd /c "mklink `"$($config.Target)`" `"$relativePath`"" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "   ERROR: Failed to create file symlink: $result" -ForegroundColor Red
                continue
            }
        } else {
            # Directory symlink
            $result = cmd /c "mklink /D `"$($config.Target)`" `"$relativePath`"" 2>&1
            if ($LASTEXITCODE -ne 0) {
                # If symlink fails, try junction with absolute path
                $result = cmd /c "mklink /J `"$($config.Target)`" `"$($config.Source)`"" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "   ERROR: Failed to create link: $result" -ForegroundColor Red
                    continue
                }
            }
        }

        $changesMade += "$action $($config.TargetRel) -> $($config.SourceRel)"
    }
}

Write-Host ""
if ($changesMade.Count -gt 0) {
    Write-Host "Changes made:" -ForegroundColor Green
    $changesMade | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }
} else {
    Write-Host "No changes needed - all symlinks are correct!" -ForegroundColor Green
}

# One-time Godot asset import: a fresh clone has no .godot/imported cache, and game instances
# launched before the first import hang on import-cache contention (worst when the validation
# suite fans out in parallel). The validation runners guard for this too — this just front-loads
# the wait to setup time. Skipped when Godot isn't installed yet.
$gameProject = Join-Path $scriptDir "src"
$godotExe = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { (Get-Command godot.exe -ErrorAction SilentlyContinue).Source }
if ((Test-Path (Join-Path $gameProject "project.godot")) -and -not (Test-Path (Join-Path $gameProject ".godot/imported"))) {
    if ($godotExe) {
        Write-Host ""
        Write-Host "Importing Godot project assets (one-time)..." -ForegroundColor Cyan
        & $godotExe --headless --import --path $gameProject | Out-Null
    } else {
        Write-Host ""
        Write-Host "Godot not on PATH — skipping the one-time asset import (the validation runners will do it on first use)." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
