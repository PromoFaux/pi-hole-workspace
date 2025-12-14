#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build FTL locally on Windows using Docker.

.DESCRIPTION
    Builds Pi-hole FTL in the official build container and copies the binary
    to docker-pi-hole/src/pihole-FTL for use with build-docker.ps1 -Local

    This script searches upward from its location to find the repository's
    FTL/ directory, so it will continue to work if you move it around inside
    the repository.

.PARAMETER Help
    Display this help information.

.EXAMPLE
    .\build-ftl.ps1
    Build FTL with default settings

.EXAMPLE
    .\build-ftl.ps1 clean
    Clean the build directory before building

.EXAMPLE
    .\build-ftl.ps1 -Help
    Show this help information

.NOTES
    Run .\build-ftl.ps1 help to see all available build.sh options
#>

param(
    [switch]$Help
)

# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

# Handle help request
if ($Help -or $args -contains '--help' -or $args -contains '-h' -or $args -contains 'help') {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
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
    Write-Error "FTL directory not found."
    Write-Error "Please clone the FTL repository into the repository root:"
    Write-Host "  git clone https://github.com/pi-hole/FTL.git" -ForegroundColor Cyan
    exit 1
}

# Check FTL/build.sh exists
if (-not (Test-Path (Join-Path $ftlDir 'build.sh'))) {
    Write-Error "FTL/build.sh not found. Is this a valid FTL repository?"
    exit 1
}

Write-Host "Building FTL using official build container..." -ForegroundColor Green
Write-Host "FTL directory: $ftlDir" -ForegroundColor Cyan
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
Write-Host "Executing: $bashCommand" -ForegroundColor Cyan
Write-Host ""

docker run --rm `
    -e CI_ARCH=linux/amd64 `
    -e TERM=xterm `
    -v "${ftlDir}:${workDir}" `
    -w "${workDir}" `
    ghcr.io/pi-hole/ftl-build:latest `
    bash -c "dos2unix build.sh 2>/dev/null; $bashCommand && ./pihole-FTL create-default-config pihole.toml"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build command failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Copy the built binary to docker-pi-hole/src/
# The build script may place the binary in the FTL root directory
$ftlBinary = Join-Path $ftlDir 'pihole-FTL'
if (Test-Path $ftlBinary) {
    Write-Host ""
    Write-Host "Build successful! Copying binary to docker-pi-hole/src/pihole-FTL..." -ForegroundColor Green

    # Determine repository root (parent of FTL)
    $repoRoot = Split-Path $ftlDir -Parent
    $destDir = Join-Path (Join-Path $repoRoot 'docker-pi-hole') 'src'

    # Create dest directory if it doesn't exist
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item $ftlBinary (Join-Path $destDir 'pihole-FTL') -Force
    Write-Host "✓ Done!" -ForegroundColor Green

    # Generate default pihole.toml configuration file
    # The file should have been created by the Docker build container
    Write-Host ""
    Write-Host "Checking for pihole.toml configuration..." -ForegroundColor Green
    $configFile = Join-Path $ftlDir 'pihole.toml'

    # Add a small delay to ensure file is synced from Docker volume
    Start-Sleep -Milliseconds 500

    if (Test-Path $configFile) {
        Write-Host "✓ Generated pihole.toml" -ForegroundColor Green
        
        # Update documentation from the generated config
        Write-Host ""
        Write-Host "Updating FTL configuration documentation..." -ForegroundColor Green
        $toolsDir = Join-Path $ftlDir 'tools'
        $docsDir = Join-Path $repoRoot 'docs'
        $docsConfigFile = Join-Path (Join-Path $docsDir 'docs') 'ftldns' | Join-Path -ChildPath 'configfile.md'
        
        if (Test-Path $toolsDir) {
            $pythonScript = Join-Path $toolsDir 'pihole_toml_to_markdown.py'
            if (Test-Path $pythonScript) {
                $result = & python $pythonScript $configFile $docsConfigFile 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Updated documentation at docs/docs/ftldns/configfile.md" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Failed to generate documentation" -ForegroundColor Yellow
                    Write-Host $result
                }
            } else {
                Write-Host "⚠ pihole_toml_to_markdown.py not found at $pythonScript" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠ tools directory not found at $toolsDir" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ pihole.toml not found at $configFile" -ForegroundColor Yellow
        Write-Host "   The Docker build may not have generated it successfully" -ForegroundColor Yellow
    }

    Write-Host ""
    if (-not $suppressHint) {
        Write-Host "You can now build docker-pi-hole with your local FTL binary:" -ForegroundColor Green
        Write-Host "  .\build-docker.ps1 -Local" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Warning "Built binary not found at $ftlBinary"
    Write-Host "Check FTL/cmake/pihole-FTL or FTL/pihole-FTL" -ForegroundColor Yellow
}

exit $LASTEXITCODE
