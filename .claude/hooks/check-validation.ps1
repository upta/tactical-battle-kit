# Stop hook: block ending the turn when kit or example code changed but no
# verification run is newer than the change. Freshness only; proving GREEN is
# the Definition of Done's job (CLAUDE.md). Either gate counts: a sim suite
# report (./simulate.ps1) or a scenario summary (./validate.ps1). Which one a
# change needs is the DoD's call, not this hook's.
$hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
if ($hookInput.stop_hook_active) { exit 0 }

$repo = git rev-parse --show-toplevel 2>$null
if (-not $repo) { exit 0 }
Set-Location $repo

# Working-tree changes to kit or example code, with the vendored/generated trees cut out.
$changed = @(git status --porcelain -- 'src' ':(exclude)src/addons/agentic_godot_validation' ':(exclude)src/artifacts' ':(exclude)src/tools' |
        ForEach-Object { $_.Substring(3).Trim('"') })
if ($changed.Count -eq 0) { exit 0 }

# Newest mtime among the changes. Entries that no longer exist on disk
# (deletions, rename sources) count as "changed right now": a deletion
# deserves a verification run too, and a missing mtime must fail toward
# blocking, not toward passing.
$newestChange = Get-Date '2000-01-01'
foreach ($path in $changed) {
    if (Test-Path $path) {
        $mtime = (Get-Item $path -Force).LastWriteTime
        if ($mtime -gt $newestChange) { $newestChange = $mtime }
    } else {
        $newestChange = Get-Date
        break
    }
}

$newestRun = Get-ChildItem 'src/artifacts' -Recurse -Include 'summary.json', 'report.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $newestRun -or $newestChange -gt $newestRun.LastWriteTime) {
    @{ decision = 'block'; reason = 'Kit or example code changed since the last verification run. Run ./simulate.ps1 (headless sim suites) and/or ./validate.ps1 (in-engine scenarios, then look at the screenshots) before ending the turn (validate-gameplay skill).' } | ConvertTo-Json -Compress
}
exit 0
