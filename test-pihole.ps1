#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run the Pi-hole BATS test suite on Windows using Docker.

.DESCRIPTION
    Runs the pi-hole sub-repo BATS test suite for a given distribution.
    Executes test/run.sh inside a Docker helper container that has access
    to the host Docker daemon, matching the same approach used by the CI.

.PARAMETER Distro
    The distribution to test (e.g. debian_12, ubuntu_24, alpine_3_23).
    Run without this parameter to list all available distributions.

.PARAMETER Help
    Display this help information.

.EXAMPLE
    .\test-pihole.ps1
    List available distributions

.EXAMPLE
    .\test-pihole.ps1 -Distro debian_12
    Run the full test suite against Debian 12

.EXAMPLE
    .\test-pihole.ps1 -Distro centos_9
    Run the full test suite against CentOS 9 (includes SELinux tests)
#>

param(
    [string]$Distro,
    [switch]$Help
)

# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Locate the pi-hole sub-repo
$piholeDir = Join-Path $PSScriptRoot 'pi-hole'
if (-not (Test-Path $piholeDir)) {
    Write-Error "pi-hole directory not found at $piholeDir"
    Write-Host "Run init-workspace.ps1 to clone all sub-repositories." -ForegroundColor Yellow
    exit 1
}

$testDir = Join-Path $piholeDir 'test'

# If no distro given, list available options and exit
if (-not $Distro) {
    Write-Host "Available distributions:" -ForegroundColor Cyan
    Get-ChildItem $testDir -Filter '_*.Dockerfile' |
        ForEach-Object { $_.Name -replace '^_', '' -replace '\.Dockerfile$', '' } |
        Sort-Object |
        ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "Usage: .\test-pihole.ps1 -Distro <distro>" -ForegroundColor Green
    exit 0
}

# Validate the requested distro has a Dockerfile
$dockerfile = Join-Path $testDir "_${Distro}.Dockerfile"
if (-not (Test-Path $dockerfile)) {
    Write-Error "Unknown distro '$Distro'."
    Write-Host "Run .\test-pihole.ps1 without arguments to list available distros." -ForegroundColor Yellow
    exit 1
}

Write-Host "Running Pi-hole BATS tests for: $Distro" -ForegroundColor Green
Write-Host ""

# Convert Windows path to Unix-style for Docker volume mount
$workDir = $piholeDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Run test/run.sh inside a docker:cli helper container.
# The Docker socket is mounted so the script can call docker buildx, docker run,
# and docker exec against the host daemon (DooD pattern — same as build-docker.ps1).
# dos2unix ensures LF line endings on scripts that may have been touched on Windows.
docker run --rm -t `
    -e "DISTRO=$Distro" `
    -v "${piholeDir}:${workDir}" `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -w "${workDir}" `
    docker:cli `
    sh -c "apk add -q bash git dos2unix ncurses parallel && dos2unix test/run.sh test/helpers/mocks.bash test/test_automated_install.bats test/test_ftl.bats test/test_network.bats test/test_utils.bats test/test_selinux.bats 2>/dev/null; bash test/run.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Error "Tests failed for $Distro (exit code $LASTEXITCODE)"
}

exit $LASTEXITCODE
