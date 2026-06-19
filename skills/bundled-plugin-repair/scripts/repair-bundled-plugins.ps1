<#
.SYNOPSIS
    Repair Codex bundled marketplace plugins cache.

.DESCRIPTION
    This script repairs the Codex bundled marketplace plugins cache by:
    1. Killing any running extension-host.exe (Chrome Native Messaging) that may lock files
    2. Finding the current Codex WindowsApps installation path
    3. Backing up the stale cache directory with a timestamp
    4. Creating a junction (directory symlink) pointing to the installation source

    After running this script, restart Codex for changes to take effect.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Codex Bundled Plugin Repair ==="
Write-Host ""

# ---------------------------------------------------------------------------
# Step 1: Kill extension-host.exe if running
# ---------------------------------------------------------------------------
Write-Host "[1/5] Killing extension-host.exe processes..."
$extHost = Get-Process -Name "extension-host" -ErrorAction SilentlyContinue
if ($extHost) {
    $extHost | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction Stop
            Write-Host "  Killed extension-host.exe (PID $($_.Id))"
        } catch {
            Write-Warning "  Failed to kill PID $($_.Id): $_"
        }
    }
} else {
    Write-Host "  No extension-host.exe processes found."
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 2: Locate the Codex WindowsApps installation
# ---------------------------------------------------------------------------
Write-Host "[2/5] Locating Codex installation..."
$codexPackage = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue
if (-not $codexPackage) {
    # Fallback: find from running Codex process
    $codexProc = Get-Process -Name "Codex" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($codexProc) {
        $exePath = $codexProc.MainModule.FileName
        Write-Host "  Found Codex process: $exePath"
        if ($exePath -match '(C:\\Program Files\\WindowsApps\\OpenAI\.Codex_[^\\]+)') {
            $installLocation = $matches[1]
            Write-Host "  InstallLocation from process: $installLocation"
            $codexPackage = [PSCustomObject]@{ InstallLocation = $installLocation; Version = "detected" }
        }
    }
    if (-not $codexPackage) {
        Write-Error "Could not find Codex Appx package. Is Codex installed via Microsoft Store?"
        exit 1
    }
}
if (-not $codexPackage) {
    Write-Error "Could not find Codex Appx package. Is Codex installed via Microsoft Store?"
    exit 1
}

Write-Host "  Package: $($codexPackage.PackageFullName)"
Write-Host "  Version: $($codexPackage.Version)"
Write-Host "  InstallLocation: $($codexPackage.InstallLocation)"

$sourcePath = Join-Path $codexPackage.InstallLocation "app\resources\plugins\openai-bundled"
if (-not (Test-Path $sourcePath)) {
    Write-Error "Source plugins path not found at: $sourcePath"
    exit 1
}
Write-Host "  Source verified: $sourcePath"
Write-Host ""

# ---------------------------------------------------------------------------
# Step 3: Update config.toml to point source directly to WindowsApps
# (bypasses the stale cache and removes the \\?\ prefix that breaks junctions)
# ---------------------------------------------------------------------------
Write-Host "[3/6] Updating config.toml..."
$configPath = "$env:USERPROFILE\.codex\config.toml"
if (Test-Path $configPath) {
    # Backup
    Copy-Item $configPath "$configPath.bak-plugin-repair" -Force -ErrorAction SilentlyContinue
    
    # Read config
    $config = Get-Content $configPath -Raw -Encoding UTF8
    $oldConfig = $config
    
    # Update source to point to WindowsApps directly (no \\?\ prefix)
    $config = $config -replace 'source = ''.*?openai-bundled.*?''', "source = '$sourcePath'"
    
    # Update last_updated
    $now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $config = $config -replace 'last_updated = ".*?"', "last_updated = `"$now`""
    
    if ($config -ne $oldConfig) {
        $config | Set-Content -Path $configPath -Encoding UTF8 -NoNewline
        Write-Host "  Config updated: source = $sourcePath"
        Write-Host "  Config updated: last_updated = $now"
    } else {
        Write-Host "  Config already up to date."
    }
} else {
    Write-Warning "  Config.toml not found at $configPath"
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 4: Build cache path
# ---------------------------------------------------------------------------
$cacheParent = "$env:USERPROFILE\.codex\.tmp\bundled-marketplaces"
$cachePath = Join-Path $cacheParent "openai-bundled"

if (-not (Test-Path $cachePath)) {
    Write-Host "[4/6] Cache directory does not exist: $cachePath"
    Write-Host "  Creating directly..."
} else {
    Write-Host "[4/6] Backing up existing cache..."
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $cacheParent "openai-bundled.bak-$stamp"
    try {
        Move-Item -LiteralPath $cachePath -Destination $backupPath -Force -ErrorAction Stop
        Write-Host "  Backed up to: $backupPath"
    } catch {
        Write-Error "  Failed to backup cache: $_"
        exit 1
    }
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 5: Remove stale cache directory (cleanup backup reference)
# ---------------------------------------------------------------------------
Write-Host "[5/6] Ensuring cache path is clear..."
if (Test-Path $cachePath) {
    Remove-Item -LiteralPath $cachePath -Recurse -Force -ErrorAction Stop
    Write-Host "  Removed stale: $cachePath"
} else {
    Write-Host "  Path is clear."
}
Write-Host ""

# ---------------------------------------------------------------------------
# Step 6: Create junction
# ---------------------------------------------------------------------------
Write-Host "[6/6] Creating junction..."
try {
    cmd /c "mklink /J `"$cachePath`" `"$sourcePath`""
    if ($LASTEXITCODE -ne 0) {
        throw "mklink returned exit code $LASTEXITCODE"
    }
    Write-Host "  Junction created: $cachePath -> $sourcePath"
} catch {
    Write-Error "  Failed to create junction: $_"
    exit 1
}
Write-Host ""

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
Write-Host "=== Verification ==="
$junctionTest = cmd /c "dir `"$cachePath`"" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Junction is in place."
    # Verify plugins are visible
    $pluginCount = (Get-ChildItem $cachePath -Recurse -Depth 1 -Directory).Count
    Write-Host "  Plugin directories under junction: $pluginCount"
    Get-ChildItem "$cachePath\plugins" -Depth 0 | Select-Object Name | Format-Table -AutoSize
} else {
    Write-Warning "  Could not verify junction. Please check manually."
}

Write-Host ""
Write-Host "=== Done ==="
Write-Host "Please restart Codex for the changes to take effect."
Write-Host "Backup saved at: $backupPath (you can delete it once everything works)"
