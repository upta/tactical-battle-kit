# Tiny static server for the exported web build: correct wasm mime type, no
# caching, and optional cross-origin-isolation headers. The default
# single-threaded export needs no special headers (matching itch.io);
# -CrossOriginIsolation exists for a future thread_support build, which needs
# COOP/COEP for SharedArrayBuffer.
param(
    [int]$Port = 8060,
    [string]$Root = "",
    [switch]$CrossOriginIsolation
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectPath
if (-not $Root) { $Root = Join-Path $repoRoot "build\web" }

if (-not (Test-Path (Join-Path $Root "index.html"))) {
    Write-Host "No build at $Root - run src/tools/export_web.ps1 first." -ForegroundColor Red
    exit 1
}

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "text/javascript"
    ".wasm" = "application/wasm"
    ".pck"  = "application/octet-stream"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".css"  = "text/css"
}

$rootFull = [System.IO.Path]::GetFullPath($Root)
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $Root at $prefix (Ctrl+C to stop)" -ForegroundColor Green

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))
        if ($relative -eq "") { $relative = "index.html" }

        # Containment check: never serve outside the build directory.
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $rootFull $relative))
        if (-not $resolved.StartsWith($rootFull) -or -not (Test-Path $resolved -PathType Leaf)) {
            $context.Response.StatusCode = 404
            $context.Response.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
        $context.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $context.Response.Headers.Add("Cache-Control", "no-store")
        if ($CrossOriginIsolation) {
            $context.Response.Headers.Add("Cross-Origin-Opener-Policy", "same-origin")
            $context.Response.Headers.Add("Cross-Origin-Embedder-Policy", "require-corp")
        }
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    }
} finally {
    $listener.Stop()
}
