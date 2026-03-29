#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run the docker-pi-hole BATS test suite.

.DESCRIPTION
    Executes test/run.sh inside a Docker container, which builds the
    pihole:test image and runs the BATS test suite against it.

.PARAMETER Platform
    Target platform to build and test via emulation (e.g. linux/arm64).
    Defaults to the host architecture if not specified.

.EXAMPLE
    .\test-docker.ps1
    Run tests against the host architecture

.EXAMPLE
    .\test-docker.ps1 -Platform linux/arm64
    Run tests against linux/arm64 via QEMU emulation
#>

param(
    [string]$Platform = ""
)

# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

$dockerPiHoleDir = Join-Path $PSScriptRoot 'docker-pi-hole'
if (-not (Test-Path $dockerPiHoleDir)) {
    Write-Error "Could not find docker-pi-hole directory at: $dockerPiHoleDir"
    exit 2
}

# Convert Windows path to Unix-style for Docker volume mount
$workDir = $dockerPiHoleDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Optional platform argument
$platformEnv = if ($Platform) { @("-e", "CIPLATFORM=$Platform") } else { @() }

if ($Platform) {
    Write-Host "Testing platform: $Platform" -ForegroundColor Cyan
} else {
    Write-Host "Testing host architecture" -ForegroundColor Cyan
}
Write-Host ""

docker run --rm -t `
    -v "${dockerPiHoleDir}:${workDir}" `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -w "${workDir}" `
    @platformEnv `
    docker:cli `
    sh -c "apk add -q bash dos2unix git ncurses && dos2unix test/run.sh test/test_suite.bats 2>/dev/null; CIPLATFORM=${Platform} bash test/run.sh"

exit $LASTEXITCODE
