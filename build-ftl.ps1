#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build FTL locally on Windows using Docker.

.DESCRIPTION
    Builds Pi-hole FTL in the official build container and copies the binary
    to docker-pi-hole/src/pihole-FTL for use with build.ps1 -l

    This script searches upward from its location to find the repository's
    FTL/ directory, so it will continue to work if you move it around inside
    the repository.

.EXAMPLE
    .\build-ftl.ps1
    Build FTL with default settings

.EXAMPLE
    .\build-ftl.ps1 clean
    Clean the build directory before building

.NOTES
    Run .\build-ftl.ps1 help for all available build.sh options
#>

# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

# Search upward for the FTL directory (repo root/FTL)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$maxLevels = 8
$current = $scriptDir
$ftlDir = $null
for ($i = 0; $i -lt $maxLevels; $i++) {
    $candidate = Join-Path $current 'FTL'
    if (Test-Path $candidate) { $ftlDir = $candidate; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}

if (-not $ftlDir) {
    Write-Host "Error: FTL directory not found."
    Write-Host "Please clone the FTL repository into the repository root:"
    Write-Host "  git clone https://github.com/pi-hole/FTL.git"
    exit 1
}

# Check FTL/build.sh exists
if (-not (Test-Path (Join-Path $ftlDir 'build.sh'))) {
    Write-Host "Error: FTL/build.sh not found. Is this a valid FTL repository?"
    exit 1
}

Write-Host "Building FTL using official build container..."
Write-Host "FTL directory: $ftlDir"
Write-Host ""

# Convert Windows path to Unix-style for Docker volume mount
$workDir = $ftlDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# If invoked with --no-hint, remove it from args so build.sh doesn't see it
$suppressHint = $false
if ($args) {
    $filtered = @()
    foreach ($a in $args) {
        if ($a -eq '--no-hint') { $suppressHint = $true; continue }
        $filtered += $a
    }
    $args = $filtered
}

# Build command with arguments
$bashCommand = "bash build.sh " + ($args -join ' ')

# Run build.sh in the official FTL build container
# Set CI_ARCH=linux/amd64 since we're building on x86-64 (Windows/Docker Desktop)
docker run --rm `
    -e CI_ARCH=linux/amd64 `
    -v "${ftlDir}:${workDir}" `
    -w "${workDir}" `
    ghcr.io/pi-hole/ftl-build:nightly `
    bash -c "dos2unix build.sh 2>/dev/null; $bashCommand"

if ($LASTEXITCODE -eq 0) {
    # Copy the built binary to docker-pi-hole/src/
    # The build script may place the binary in the FTL root directory
    $ftlBinary = Join-Path $ftlDir 'pihole-FTL'
    if (Test-Path $ftlBinary) {
        Write-Host ""
        Write-Host "Build successful! Copying binary to docker-pi-hole/src/pihole-FTL..."

        # Determine repository root (parent of FTL)
        $repoRoot = Split-Path $ftlDir -Parent
        $destDir = Join-Path (Join-Path $repoRoot 'docker-pi-hole') 'src'

        # Create dest directory if it doesn't exist
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item $ftlBinary (Join-Path $destDir 'pihole-FTL') -Force
        Write-Host "Done!"
        Write-Host ""
        if (-not $suppressHint) {
            Write-Host "You can now build docker-pi-hole with your local FTL binary:"
            Write-Host "  .\build-docker.ps1 -l"
        }
    } else {
        Write-Host ""
        Write-Host "Warning: Built binary not found at $ftlBinary"
        Write-Host "Check FTL/cmake/pihole-FTL or FTL/pihole-FTL"
    }
}

exit $LASTEXITCODE
